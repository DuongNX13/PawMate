import { type Redis } from 'ioredis';

import {
  type ActionQuotaStore,
  type QuotaCharge,
  type QuotaConsumeOptions,
  type QuotaStoreDecision,
} from './distributed-action-quota';
import { QuotaStoreUnavailableError } from './quota-store-error';

// Redis TIME and one Lua transaction make the boundary identical across API
// instances and ensure a rejected multi-dimension decision increments nothing.
const CONSUME_SCRIPT = `
local count = tonumber(ARGV[1])
local now = tonumber(ARGV[2])
local decisionKey = ARGV[3]
local decisionTtl = tonumber(ARGV[4])
local leaseKey = ARGV[5]
local leaseMember = ARGV[6]
local leaseLimit = tonumber(ARGV[7])
local leaseTtl = tonumber(ARGV[8])
local resolved = {}
local blockedRetry = 0

local decisionReplay = decisionKey ~= '' and redis.call('EXISTS', decisionKey) == 1

if leaseKey ~= '' then
  redis.call('ZREMRANGEBYSCORE', leaseKey, '-inf', now)
  local existing = redis.call('ZSCORE', leaseKey, leaseMember)
  if not existing and redis.call('ZCARD', leaseKey) >= leaseLimit then
    local earliest = redis.call('ZRANGE', leaseKey, 0, 0, 'WITHSCORES')
    local retry = 1
    if earliest[2] then retry = math.max(1, math.ceil(tonumber(earliest[2]) - now)) end
    return { 0, 0, retry, '', 0 }
  end
end

if decisionReplay then
  if leaseKey ~= '' then
    redis.call('ZADD', leaseKey, now + leaseTtl, leaseMember)
    redis.call('EXPIRE', leaseKey, leaseTtl)
  end
  return { 1, 2147483647, 1, leaseMember, 0 }
end

for index = 1, count do
  local offset = 9 + ((index - 1) * 5)
  local prefix = ARGV[offset]
  local limit = tonumber(ARGV[offset + 1])
  local window = tonumber(ARGV[offset + 2])
  local amount = tonumber(ARGV[offset + 3])
  local warnAt = tonumber(ARGV[offset + 4])
  local bucket = math.floor(now / window)
  local key = prefix .. ':' .. bucket
  local ttl = ((bucket + 1) * window) - now
  if ttl < 1 then ttl = 1 end
  local current = tonumber(redis.call('GET', key) or '0')
  resolved[index] = { key, limit, amount, ttl, current, warnAt }
  if current + amount > limit and ttl > blockedRetry then
    blockedRetry = ttl
  end
end

if blockedRetry > 0 then
  return { 0, 0, blockedRetry, '', 0 }
end

local minimumRemaining = nil
local maximumTtl = 1
local budgetWarning = 0
for index = 1, count do
  local item = resolved[index]
  local nextValue = redis.call('INCRBY', item[1], item[3])
  if nextValue == item[3] then redis.call('EXPIRE', item[1], item[4]) end
  if item[6] > 0 and item[5] < item[6] and nextValue >= item[6] then
    local warningSet = redis.call('SET', item[1] .. ':warn80', '1', 'EX', item[4], 'NX')
    if warningSet then budgetWarning = 1 end
  end
  local remaining = item[2] - nextValue
  if minimumRemaining == nil or remaining < minimumRemaining then
    minimumRemaining = remaining
  end
  if item[4] > maximumTtl then maximumTtl = item[4] end
end

if leaseKey ~= '' then
  redis.call('ZADD', leaseKey, now + leaseTtl, leaseMember)
  redis.call('EXPIRE', leaseKey, leaseTtl)
end
if decisionKey ~= '' then
  redis.call('SET', decisionKey, '1', 'EX', decisionTtl)
end

return { 1, minimumRemaining or 0, maximumTtl, leaseMember, budgetWarning }
`;

const BIND_LEASE_SCRIPT = `
local score = redis.call('ZSCORE', KEYS[1], ARGV[1])
if not score then return 0 end
redis.call('HSET', KEYS[2], ARGV[2], ARGV[1])
redis.call('EXPIRE', KEYS[2], tonumber(ARGV[3]))
return 1
`;

const RELEASE_BOUND_LEASE_SCRIPT = `
local member = redis.call('HGET', KEYS[2], ARGV[1])
if not member then return 0 end
redis.call('HDEL', KEYS[2], ARGV[1])
return redis.call('ZREM', KEYS[1], member)
`;

const parseInteger = (value: unknown) => {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw new QuotaStoreUnavailableError('Invalid Redis quota response.');
  }
  return parsed;
};

const quotaOptionArguments = (options: QuotaConsumeOptions) => [
  options.decisionKey ?? '',
  String(options.decisionTtlSeconds ?? 0),
  options.lease?.key ?? '',
  options.lease?.member ?? '',
  String(options.lease?.limit ?? 0),
  String(options.lease?.ttlSeconds ?? 0),
];

const parseQuotaDecision = (raw: unknown): QuotaStoreDecision => {
  if (!Array.isArray(raw) || raw.length !== 5) {
    throw new QuotaStoreUnavailableError('Invalid Redis quota response.');
  }
  const allowed = parseInteger(raw[0]) === 1;
  const remaining = parseInteger(raw[1]);
  const retryAfterSeconds = Math.max(1, parseInteger(raw[2]));
  const leaseMember = raw[3] === '' ? undefined : String(raw[3]);
  const budgetWarning = parseInteger(raw[4]) === 1;
  return allowed
    ? {
        allowed: true,
        remaining,
        retryAfterSeconds,
        ...(leaseMember ? { leaseMember } : {}),
        ...(budgetWarning ? { budgetWarning: true } : {}),
      }
    : { allowed: false, remaining: 0, retryAfterSeconds };
};

export class RedisActionQuotaStore implements ActionQuotaStore {
  constructor(private readonly redis: Redis) {}

  async consume(
    charges: readonly QuotaCharge[],
    options: QuotaConsumeOptions = {},
  ): Promise<QuotaStoreDecision> {
    if (charges.length === 0) {
      throw new QuotaStoreUnavailableError('Quota decision has no charges.');
    }
    const args = charges.flatMap((charge) => [
      charge.keyPrefix,
      String(charge.limit),
      String(charge.windowSeconds),
      String(charge.amount),
      String(charge.warningThreshold ?? 0),
    ]);
    try {
      // Redis 3 marks TIME as non-deterministic and rejects writes later in the
      // same script. Read the authoritative Redis clock immediately before the
      // atomic write script instead of falling back to an API-host clock.
      const [redisSeconds] = await this.redis.time();
      const nowSeconds = parseInteger(redisSeconds);
      const raw = await this.redis.eval(
        CONSUME_SCRIPT,
        0,
        String(charges.length),
        String(nowSeconds),
        ...quotaOptionArguments(options),
        ...args,
      );
      return parseQuotaDecision(raw);
    } catch (error) {
      if (error instanceof QuotaStoreUnavailableError) throw error;
      throw new QuotaStoreUnavailableError('Redis quota decision failed.', {
        cause: error,
      });
    }
  }

  async bindLease(
    leaseKey: string,
    mappingKey: string,
    member: string,
    resourceMember: string,
    ttlSeconds: number,
  ) {
    try {
      const result = await this.redis.eval(
        BIND_LEASE_SCRIPT,
        2,
        leaseKey,
        mappingKey,
        member,
        resourceMember,
        String(ttlSeconds),
      );
      if (parseInteger(result) !== 1) {
        throw new QuotaStoreUnavailableError(
          'Quota lease is no longer active.',
        );
      }
    } catch (error) {
      if (error instanceof QuotaStoreUnavailableError) throw error;
      throw new QuotaStoreUnavailableError('Redis quota lease bind failed.', {
        cause: error,
      });
    }
  }

  async releaseLease(leaseKey: string, member: string) {
    try {
      await this.redis.zrem(leaseKey, member);
    } catch (error) {
      throw new QuotaStoreUnavailableError(
        'Redis quota lease release failed.',
        {
          cause: error,
        },
      );
    }
  }

  async releaseBoundLease(
    leaseKey: string,
    mappingKey: string,
    resourceMember: string,
  ) {
    try {
      await this.redis.eval(
        RELEASE_BOUND_LEASE_SCRIPT,
        2,
        leaseKey,
        mappingKey,
        resourceMember,
      );
    } catch (error) {
      throw new QuotaStoreUnavailableError(
        'Redis quota bound lease release failed.',
        { cause: error },
      );
    }
  }
}
