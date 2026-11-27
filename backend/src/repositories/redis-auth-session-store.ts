import Redis from 'ioredis';

import {
  type AuthSessionStore,
  type SessionRecord,
} from '../services/auth/auth-service';

const buildSessionKey = (sessionId: string) => `auth:session:${sessionId}`;
const buildUserSessionSetKey = (userId: string) =>
  `auth:user-sessions:${userId}`;

const serializeSession = (session: SessionRecord) =>
  JSON.stringify({
    ...session,
    expiresAt: session.expiresAt.toISOString(),
    revokedAt: session.revokedAt?.toISOString(),
    createdAt: session.createdAt.toISOString(),
  });

const parseSession = (value: string): SessionRecord => {
  const parsed = JSON.parse(value) as {
    id: string;
    userId: string;
    refreshTokenHash: string;
    previousRefreshTokenHash?: string;
    rotatedAt?: string;
    deviceId?: string;
    userAgent?: string;
    ipAddress?: string;
    expiresAt: string;
    revokedAt?: string;
    createdAt: string;
  };

  return {
    ...parsed,
    expiresAt: new Date(parsed.expiresAt),
    rotatedAt: parsed.rotatedAt ? new Date(parsed.rotatedAt) : undefined,
    revokedAt: parsed.revokedAt ? new Date(parsed.revokedAt) : undefined,
    createdAt: new Date(parsed.createdAt),
  };
};

// These operations span the session record and its per-user index. Lua keeps
// refresh rotation, revocation, and the active-session limit atomic in Redis.
const createSessionScript = `
local sessionKey = KEYS[1]
local userSessionsKey = KEYS[2]
local sessionPrefix = ARGV[1]
local sessionJson = ARGV[2]
local createdAtScore = tonumber(ARGV[3])
local ttlMs = tonumber(ARGV[4])
local sessionId = ARGV[5]
local maxActiveSessions = tonumber(ARGV[6])
local revokedAt = ARGV[7]

redis.call('SET', sessionKey, sessionJson, 'PX', ttlMs)
redis.call('ZADD', userSessionsKey, createdAtScore, sessionId)

local activeSessions = {}
local sessionIds = redis.call('ZRANGE', userSessionsKey, 0, -1)
for _, candidateId in ipairs(sessionIds) do
  local candidateKey = sessionPrefix .. candidateId
  local rawCandidate = redis.call('GET', candidateKey)
  if not rawCandidate then
    redis.call('ZREM', userSessionsKey, candidateId)
  else
    local candidate = cjson.decode(rawCandidate)
    if not candidate.revokedAt then
      table.insert(activeSessions, {
        id = candidateId,
        key = candidateKey,
        value = candidate
      })
    end
  end
end

local overflow = #activeSessions - maxActiveSessions
for index = 1, math.max(overflow, 0) do
  local candidate = activeSessions[index]
  local remainingTtl = redis.call('PTTL', candidate.key)
  candidate.value.revokedAt = revokedAt
  if remainingTtl > 0 then
    redis.call(
      'SET',
      candidate.key,
      cjson.encode(candidate.value),
      'PX',
      remainingTtl
    )
  else
    redis.call('DEL', candidate.key)
    redis.call('ZREM', userSessionsKey, candidate.id)
  end
end

local currentIndexTtl = redis.call('PTTL', userSessionsKey)
if currentIndexTtl < ttlMs then
  redis.call('PEXPIRE', userSessionsKey, ttlMs)
end
return math.max(overflow, 0)
`;

const rotateSessionScript = `
local sessionKey = KEYS[1]
local userSessionsKey = KEYS[2]
local expectedHash = ARGV[1]
local replacementJson = ARGV[2]
local ttlMs = tonumber(ARGV[3])
local sessionId = ARGV[4]
local userId = ARGV[5]
local createdAtScore = tonumber(ARGV[6])

local rawCurrent = redis.call('GET', sessionKey)
if not rawCurrent then
  return 0
end

local current = cjson.decode(rawCurrent)
if current.revokedAt
  or current.userId ~= userId
  or current.refreshTokenHash ~= expectedHash then
  return 0
end

redis.call('SET', sessionKey, replacementJson, 'PX', ttlMs)
redis.call('ZADD', userSessionsKey, createdAtScore, sessionId)
local currentIndexTtl = redis.call('PTTL', userSessionsKey)
if currentIndexTtl < ttlMs then
  redis.call('PEXPIRE', userSessionsKey, ttlMs)
end
return 1
`;

const revokeSessionScript = `
local sessionKey = KEYS[1]
local revokedAt = ARGV[1]
local rawCurrent = redis.call('GET', sessionKey)
if not rawCurrent then
  return 0
end

local current = cjson.decode(rawCurrent)
if current.revokedAt then
  return 0
end

local remainingTtl = redis.call('PTTL', sessionKey)
if remainingTtl <= 0 then
  redis.call('DEL', sessionKey)
  return 0
end

current.revokedAt = revokedAt
redis.call('SET', sessionKey, cjson.encode(current), 'PX', remainingTtl)
return 1
`;

const revokeAllSessionsScript = `
local userSessionsKey = KEYS[1]
local sessionPrefix = ARGV[1]
local revokedAt = ARGV[2]
local revokedCount = 0
local sessionIds = redis.call('ZRANGE', userSessionsKey, 0, -1)

for _, sessionId in ipairs(sessionIds) do
  local sessionKey = sessionPrefix .. sessionId
  local rawCurrent = redis.call('GET', sessionKey)
  if not rawCurrent then
    redis.call('ZREM', userSessionsKey, sessionId)
  else
    local current = cjson.decode(rawCurrent)
    if not current.revokedAt then
      local remainingTtl = redis.call('PTTL', sessionKey)
      if remainingTtl > 0 then
        current.revokedAt = revokedAt
        redis.call(
          'SET',
          sessionKey,
          cjson.encode(current),
          'PX',
          remainingTtl
        )
        revokedCount = revokedCount + 1
      else
        redis.call('DEL', sessionKey)
        redis.call('ZREM', userSessionsKey, sessionId)
      end
    end
  end
end
return revokedCount
`;

export class RedisAuthSessionStore implements AuthSessionStore {
  constructor(private readonly redis: Redis) {}

  async listActiveSessionsByUser(userId: string) {
    const sessionIds = await this.redis.zrange(
      buildUserSessionSetKey(userId),
      0,
      -1,
    );
    if (sessionIds.length === 0) {
      return [];
    }

    const rawSessions = await this.redis.mget(
      sessionIds.map((sessionId) => buildSessionKey(sessionId)),
    );

    return rawSessions
      .filter((value): value is string => Boolean(value))
      .map(parseSession)
      .filter((session) => !session.revokedAt)
      .sort(
        (left, right) => left.createdAt.getTime() - right.createdAt.getTime(),
      );
  }

  async findSessionById(sessionId: string) {
    const rawValue = await this.redis.get(buildSessionKey(sessionId));
    return rawValue ? parseSession(rawValue) : undefined;
  }

  async createSession(
    session: SessionRecord,
    maxActiveSessions: number,
    revokedAt: Date,
  ) {
    const ttlMs = Math.max(session.expiresAt.getTime() - Date.now(), 1);
    await this.redis.eval(
      createSessionScript,
      2,
      buildSessionKey(session.id),
      buildUserSessionSetKey(session.userId),
      'auth:session:',
      serializeSession(session),
      session.createdAt.getTime().toString(),
      ttlMs.toString(),
      session.id,
      maxActiveSessions.toString(),
      revokedAt.toISOString(),
    );
  }

  async rotateSession(
    session: SessionRecord,
    expectedRefreshTokenHash: string,
  ) {
    const ttlMs = Math.max(session.expiresAt.getTime() - Date.now(), 1);
    const result = await this.redis.eval(
      rotateSessionScript,
      2,
      buildSessionKey(session.id),
      buildUserSessionSetKey(session.userId),
      expectedRefreshTokenHash,
      serializeSession(session),
      ttlMs.toString(),
      session.id,
      session.userId,
      session.createdAt.getTime().toString(),
    );
    return Number(result) === 1;
  }

  async revokeSession(sessionId: string, revokedAt: Date) {
    await this.redis.eval(
      revokeSessionScript,
      1,
      buildSessionKey(sessionId),
      revokedAt.toISOString(),
    );
  }

  async revokeAllSessionsForUser(userId: string, revokedAt: Date) {
    await this.redis.eval(
      revokeAllSessionsScript,
      1,
      buildUserSessionSetKey(userId),
      'auth:session:',
      revokedAt.toISOString(),
    );
  }
}
