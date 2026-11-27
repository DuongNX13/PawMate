import { createHmac } from 'node:crypto';

import { AppError } from '../errors/app-error';
import { SECURITY_ERROR_CODES } from '../errors/error-codes';

export { QuotaStoreUnavailableError } from './quota-store-error';

export type ActionQuotaId =
  | 'auth.register'
  | 'auth.verify'
  | 'auth.resend'
  | 'auth.login'
  | 'auth.refresh'
  | 'auth.oauth'
  | 'auth.logout'
  | 'provider.email'
  | 'discovery.read'
  | 'rescue.write'
  | 'rescue.comment'
  | 'chat.message'
  | 'chat.read-state'
  | 'adoption.request'
  | 'adoption.decision'
  | 'review.create'
  | 'review.helpful'
  | 'review.report'
  | 'upload.ticket'
  | 'upload.inline-photo';

export type QuotaDimension =
  | 'ip'
  | 'account'
  | 'session'
  | 'resource'
  | 'global'
  | 'bytes'
  | 'globalBytes';

export type ActionQuotaRule = {
  dimension: QuotaDimension;
  limit: number;
  windowSeconds: number;
  optional?: boolean;
};

const MiB = 1024 * 1024;
const GiB = 1024 * MiB;

export const ACTION_QUOTA_POLICIES: Record<
  ActionQuotaId,
  readonly ActionQuotaRule[]
> = {
  'auth.register': [
    { dimension: 'ip', limit: 10, windowSeconds: 15 * 60 },
    { dimension: 'account', limit: 3, windowSeconds: 24 * 60 * 60 },
  ],
  'auth.verify': [
    { dimension: 'ip', limit: 30, windowSeconds: 15 * 60 },
    { dimension: 'session', limit: 10, windowSeconds: 15 * 60 },
  ],
  'auth.resend': [
    { dimension: 'ip', limit: 10, windowSeconds: 60 * 60 },
    { dimension: 'account', limit: 3, windowSeconds: 60 * 60 },
  ],
  'auth.login': [
    { dimension: 'ip', limit: 30, windowSeconds: 15 * 60 },
    { dimension: 'account', limit: 10, windowSeconds: 15 * 60 },
  ],
  'auth.refresh': [
    { dimension: 'ip', limit: 120, windowSeconds: 15 * 60 },
    { dimension: 'session', limit: 30, windowSeconds: 15 * 60 },
  ],
  'auth.oauth': [
    { dimension: 'ip', limit: 20, windowSeconds: 15 * 60 },
    { dimension: 'session', limit: 10, windowSeconds: 15 * 60 },
  ],
  'auth.logout': [
    { dimension: 'ip', limit: 60, windowSeconds: 15 * 60 },
    { dimension: 'session', limit: 20, windowSeconds: 15 * 60 },
  ],
  'provider.email': [
    { dimension: 'account', limit: 3, windowSeconds: 60 * 60 },
    { dimension: 'global', limit: 100, windowSeconds: 60 * 60 },
  ],
  'discovery.read': [{ dimension: 'ip', limit: 120, windowSeconds: 60 }],
  'rescue.write': [
    { dimension: 'ip', limit: 120, windowSeconds: 15 * 60 },
    { dimension: 'account', limit: 60, windowSeconds: 15 * 60 },
    {
      dimension: 'resource',
      limit: 30,
      windowSeconds: 15 * 60,
      optional: true,
    },
  ],
  'rescue.comment': [
    { dimension: 'ip', limit: 120, windowSeconds: 15 * 60 },
    { dimension: 'account', limit: 30, windowSeconds: 5 * 60 },
    { dimension: 'resource', limit: 20, windowSeconds: 5 * 60 },
  ],
  'chat.message': [
    { dimension: 'ip', limit: 120, windowSeconds: 15 * 60 },
    { dimension: 'account', limit: 30, windowSeconds: 5 * 60 },
    { dimension: 'resource', limit: 20, windowSeconds: 5 * 60 },
  ],
  'chat.read-state': [
    { dimension: 'ip', limit: 240, windowSeconds: 15 * 60 },
    { dimension: 'account', limit: 120, windowSeconds: 15 * 60 },
    { dimension: 'resource', limit: 120, windowSeconds: 15 * 60 },
  ],
  'adoption.request': [
    { dimension: 'ip', limit: 60, windowSeconds: 24 * 60 * 60 },
    { dimension: 'account', limit: 20, windowSeconds: 24 * 60 * 60 },
    { dimension: 'resource', limit: 5, windowSeconds: 24 * 60 * 60 },
  ],
  'adoption.decision': [
    { dimension: 'ip', limit: 120, windowSeconds: 60 * 60 },
    { dimension: 'account', limit: 60, windowSeconds: 60 * 60 },
    { dimension: 'resource', limit: 30, windowSeconds: 60 * 60 },
  ],
  'review.create': [
    { dimension: 'ip', limit: 60, windowSeconds: 24 * 60 * 60 },
    { dimension: 'account', limit: 10, windowSeconds: 24 * 60 * 60 },
    { dimension: 'resource', limit: 5, windowSeconds: 24 * 60 * 60 },
  ],
  'review.helpful': [
    { dimension: 'ip', limit: 120, windowSeconds: 60 * 60 },
    { dimension: 'account', limit: 60, windowSeconds: 60 * 60 },
    { dimension: 'resource', limit: 20, windowSeconds: 60 * 60 },
  ],
  'review.report': [
    { dimension: 'ip', limit: 60, windowSeconds: 24 * 60 * 60 },
    { dimension: 'account', limit: 10, windowSeconds: 24 * 60 * 60 },
    { dimension: 'resource', limit: 10, windowSeconds: 24 * 60 * 60 },
  ],
  'upload.ticket': [
    { dimension: 'ip', limit: 40, windowSeconds: 60 * 60 },
    { dimension: 'account', limit: 20, windowSeconds: 60 * 60 },
    { dimension: 'bytes', limit: 100 * MiB, windowSeconds: 60 * 60 },
    { dimension: 'globalBytes', limit: 2 * GiB, windowSeconds: 24 * 60 * 60 },
  ],
  'upload.inline-photo': [
    { dimension: 'ip', limit: 20, windowSeconds: 60 * 60 },
    { dimension: 'account', limit: 10, windowSeconds: 60 * 60 },
    { dimension: 'bytes', limit: 50 * MiB, windowSeconds: 24 * 60 * 60 },
    { dimension: 'globalBytes', limit: GiB, windowSeconds: 24 * 60 * 60 },
  ],
};

export type QuotaCharge = {
  keyPrefix: string;
  limit: number;
  windowSeconds: number;
  amount: number;
  warningThreshold?: number;
};

export type QuotaStoreDecision =
  | {
      allowed: true;
      remaining: number;
      retryAfterSeconds: number;
      leaseMember?: string;
      budgetWarning?: true;
    }
  | { allowed: false; remaining: 0; retryAfterSeconds: number };

export type QuotaLeaseRequest = {
  key: string;
  member: string;
  limit: number;
  ttlSeconds: number;
};

export type QuotaConsumeOptions = {
  decisionKey?: string;
  decisionTtlSeconds?: number;
  lease?: QuotaLeaseRequest;
};

export type ActionQuotaStore = {
  consume: (
    charges: readonly QuotaCharge[],
    options?: QuotaConsumeOptions,
  ) => Promise<QuotaStoreDecision>;
  bindLease?: (
    leaseKey: string,
    mappingKey: string,
    member: string,
    resourceMember: string,
    ttlSeconds: number,
  ) => Promise<void>;
  releaseLease?: (leaseKey: string, member: string) => Promise<void>;
  releaseBoundLease?: (
    leaseKey: string,
    mappingKey: string,
    resourceMember: string,
  ) => Promise<void>;
};

type MemoryCounter = { value: number; expiresAtMs: number };
type MemoryLease = { expiresAtMs: number };
type MemoryBinding = { member: string; expiresAtMs: number };

/** Test-only deterministic store. Production wiring must use Redis. */
export class MemoryActionQuotaStore implements ActionQuotaStore {
  private readonly counters = new Map<string, MemoryCounter>();

  private readonly decisions = new Map<string, number>();

  private readonly warnings = new Map<string, number>();

  private readonly leases = new Map<string, Map<string, MemoryLease>>();

  private readonly bindings = new Map<string, MemoryBinding>();

  constructor(private readonly now: () => number = Date.now) {}

  private readActiveLease(
    request: QuotaLeaseRequest | undefined,
    nowMs: number,
  ): {
    activeLeases?: Map<string, MemoryLease>;
    denied?: Extract<QuotaStoreDecision, { allowed: false }>;
  } {
    if (!request) return {};
    const activeLeases =
      this.leases.get(request.key) ?? new Map<string, MemoryLease>();
    activeLeases.forEach((lease, member) => {
      if (lease.expiresAtMs <= nowMs) activeLeases.delete(member);
    });
    if (
      !activeLeases.has(request.member) &&
      activeLeases.size >= request.limit
    ) {
      const earliestExpiry = Math.min(
        ...[...activeLeases.values()].map((lease) => lease.expiresAtMs),
      );
      return {
        denied: {
          allowed: false,
          remaining: 0,
          retryAfterSeconds: Math.max(
            1,
            Math.ceil((earliestExpiry - nowMs) / 1000),
          ),
        },
      };
    }
    return { activeLeases };
  }

  private renewLease(
    request: QuotaLeaseRequest | undefined,
    activeLeases: Map<string, MemoryLease> | undefined,
    nowMs: number,
  ) {
    if (request && activeLeases) {
      activeLeases.set(request.member, {
        expiresAtMs: nowMs + request.ttlSeconds * 1000,
      });
      this.leases.set(request.key, activeLeases);
    }
  }

  private hasDecisionReplay(key: string | undefined, nowMs: number) {
    return key && (this.decisions.get(key) ?? 0) > nowMs;
  }

  async consume(
    charges: readonly QuotaCharge[],
    options: QuotaConsumeOptions = {},
  ): Promise<QuotaStoreDecision> {
    const nowMs = this.now();
    const decisionReplay = this.hasDecisionReplay(options.decisionKey, nowMs);

    const { activeLeases, denied } = this.readActiveLease(options.lease, nowMs);
    if (denied) return denied;

    if (decisionReplay) {
      this.renewLease(options.lease, activeLeases, nowMs);
      return {
        allowed: true,
        remaining: Number.MAX_SAFE_INTEGER,
        retryAfterSeconds: 1,
        ...(options.lease ? { leaseMember: options.lease.member } : {}),
      };
    }

    const resolved = charges.map((charge) => {
      const windowMs = charge.windowSeconds * 1000;
      const bucket = Math.floor(nowMs / windowMs);
      const key = `${charge.keyPrefix}:${bucket}`;
      const expiresAtMs = (bucket + 1) * windowMs;
      const current = this.counters.get(key);
      const value = current && current.expiresAtMs > nowMs ? current.value : 0;
      return { ...charge, key, expiresAtMs, value };
    });
    const blocked = resolved.filter(
      (charge) => charge.value + charge.amount > charge.limit,
    );
    if (blocked.length > 0) {
      return {
        allowed: false,
        remaining: 0,
        retryAfterSeconds: Math.max(
          1,
          ...blocked.map((charge) =>
            Math.ceil((charge.expiresAtMs - nowMs) / 1000),
          ),
        ),
      };
    }

    let budgetWarning = false;
    resolved.forEach((charge) => {
      const nextValue = charge.value + charge.amount;
      this.counters.set(charge.key, {
        value: nextValue,
        expiresAtMs: charge.expiresAtMs,
      });
      const warningKey = `${charge.key}:warn80`;
      const warningExpiresAt = this.warnings.get(warningKey) ?? 0;
      if (
        charge.warningThreshold &&
        charge.value < charge.warningThreshold &&
        nextValue >= charge.warningThreshold &&
        warningExpiresAt <= nowMs
      ) {
        this.warnings.set(warningKey, charge.expiresAtMs);
        budgetWarning = true;
      }
    });
    this.renewLease(options.lease, activeLeases, nowMs);
    if (options.decisionKey && options.decisionTtlSeconds) {
      this.decisions.set(
        options.decisionKey,
        nowMs + options.decisionTtlSeconds * 1000,
      );
    }
    return {
      allowed: true,
      remaining: Math.min(
        ...resolved.map(
          (charge) => charge.limit - charge.value - charge.amount,
        ),
      ),
      retryAfterSeconds: Math.max(
        1,
        ...resolved.map((charge) =>
          Math.ceil((charge.expiresAtMs - nowMs) / 1000),
        ),
      ),
      ...(options.lease ? { leaseMember: options.lease.member } : {}),
      ...(budgetWarning ? { budgetWarning: true as const } : {}),
    };
  }

  async bindLease(
    leaseKey: string,
    mappingKey: string,
    member: string,
    resourceMember: string,
    ttlSeconds: number,
  ) {
    const nowMs = this.now();
    const lease = this.leases.get(leaseKey)?.get(member);
    if (!lease || lease.expiresAtMs <= nowMs) {
      throw new Error('Lease is no longer active.');
    }
    this.bindings.set(`${mappingKey}:${resourceMember}`, {
      member,
      expiresAtMs: nowMs + ttlSeconds * 1000,
    });
  }

  async releaseLease(leaseKey: string, member: string) {
    this.leases.get(leaseKey)?.delete(member);
  }

  async releaseBoundLease(
    leaseKey: string,
    mappingKey: string,
    resourceMember: string,
  ) {
    const key = `${mappingKey}:${resourceMember}`;
    const binding = this.bindings.get(key);
    this.bindings.delete(key);
    if (binding && binding.expiresAtMs > this.now()) {
      this.leases.get(leaseKey)?.delete(binding.member);
    }
  }

  snapshot() {
    const nowMs = this.now();
    return Object.fromEntries(
      [...this.counters.entries()]
        .filter(([, counter]) => counter.expiresAtMs > nowMs)
        .map(([key, counter]) => [key, counter.value]),
    ) as Record<string, number>;
  }
}

export type ActionQuotaInput = {
  action: ActionQuotaId;
  dimensions: {
    ip?: string;
    account?: string;
    session?: string;
    resource?: string;
  };
  units?: { bytes?: number };
  idempotencyKey?: string;
};

export type ActionQuotaLease = {
  action: 'upload.ticket' | 'upload.inline-photo';
  leaseKey: string;
  mappingKey: string;
  member: string;
  ttlSeconds: number;
};

export type ActionQuotaGuard = {
  enforce: (input: ActionQuotaInput) => Promise<{
    allowed: true;
    remaining: number;
    retryAfterSeconds: number;
    lease?: ActionQuotaLease;
  }>;
  bindLease: (lease: ActionQuotaLease, resourceId: string) => Promise<void>;
  cancelLease: (lease: ActionQuotaLease) => Promise<void>;
  releaseLease: (input: {
    action: 'upload.ticket';
    dimensions: { account: string };
    resourceId: string;
  }) => Promise<void>;
};

export const createNoopActionQuotaGuard = (): ActionQuotaGuard => ({
  enforce: async () => ({
    allowed: true,
    remaining: Number.MAX_SAFE_INTEGER,
    retryAfterSeconds: 1,
  }),
  bindLease: async () => undefined,
  cancelLease: async () => undefined,
  releaseLease: async () => undefined,
});

const CONCURRENCY_POLICIES = {
  'upload.ticket': { limit: 3, ttlSeconds: 15 * 60 },
  'upload.inline-photo': { limit: 2, ttlSeconds: 30 },
} as const;

const normalizeDimension = (dimension: QuotaDimension, value: string) => {
  const trimmed = value.trim();
  if (dimension === 'account' && trimmed.includes('@'))
    return trimmed.toLowerCase();
  return trimmed;
};

const resolveDimensionValue = (
  rule: ActionQuotaRule,
  input: ActionQuotaInput,
) => {
  if (rule.dimension === 'global' || rule.dimension === 'globalBytes')
    return 'global';
  if (rule.dimension === 'bytes') return input.dimensions.account;
  return input.dimensions[rule.dimension];
};

const resolveAmount = (rule: ActionQuotaRule, input: ActionQuotaInput) => {
  if (rule.dimension !== 'bytes' && rule.dimension !== 'globalBytes') return 1;
  const bytes = input.units?.bytes;
  if (!Number.isSafeInteger(bytes) || (bytes ?? 0) <= 0) {
    throw new AppError(
      SECURITY_ERROR_CODES.quotaContextInvalid,
      'Khong the xac dinh dung luong de kiem soat han muc.',
      400,
    );
  }
  return bytes as number;
};

export const createActionQuotaGuard = (input: {
  store: ActionQuotaStore;
  secret: string;
  namespace?: string;
  onBudgetWarning?: (event: {
    action: ActionQuotaId;
    thresholdPercent: 80;
  }) => void;
}): ActionQuotaGuard => {
  const namespace = input.namespace ?? 'pawmate:q:v1';
  const hmacKey = createHmac('sha256', input.secret)
    .update('pawmate-abuse-key-v1')
    .digest();

  const digest = (purpose: string, value: string) =>
    createHmac('sha256', hmacKey)
      .update(`${purpose}\u0000${value}`)
      .digest('hex');

  const buildLeaseScope = (
    action: 'upload.ticket' | 'upload.inline-photo',
    account: string,
  ) => {
    const accountDigest = digest('lease-account', account.trim());
    const leaseKey = `${namespace}:${action}:lease:${accountDigest}`;
    return { leaseKey, mappingKey: `${leaseKey}:resources` };
  };

  const reportBudgetWarning = (
    decision: Extract<QuotaStoreDecision, { allowed: true }>,
    action: ActionQuotaId,
  ) => {
    if (decision.budgetWarning) {
      try {
        input.onBudgetWarning?.({ action, thresholdPercent: 80 });
      } catch {
        // Observability must not change an already accepted quota decision.
      }
    }
  };

  const guard: ActionQuotaGuard = {
    enforce: async (request) => {
      const rules = ACTION_QUOTA_POLICIES[request.action];
      const charges = rules.flatMap((rule): QuotaCharge[] => {
        const rawValue = resolveDimensionValue(rule, request);
        if (!rawValue) {
          if (rule.optional) return [];
          throw new AppError(
            SECURITY_ERROR_CODES.quotaContextInvalid,
            'Khong the xac dinh ngu canh kiem soat han muc.',
            400,
          );
        }
        const normalized = normalizeDimension(rule.dimension, rawValue);
        const dimensionDigest = digest(rule.dimension, normalized);
        return [
          {
            keyPrefix: `${namespace}:${request.action}:${rule.dimension}:${rule.windowSeconds}:${dimensionDigest}`,
            limit: rule.limit,
            windowSeconds: rule.windowSeconds,
            amount: resolveAmount(rule, request),
            ...((rule.dimension === 'global' ||
              rule.dimension === 'globalBytes') && {
              warningThreshold: Math.ceil(rule.limit * 0.8),
            }),
          },
        ];
      });

      const decisionKey = request.idempotencyKey?.trim()
        ? `${namespace}:${request.action}:decision:${digest(
            'idempotency',
            `${request.dimensions.account ?? ''}\u0000${request.idempotencyKey.trim()}`,
          )}`
        : undefined;
      const decisionTtlSeconds = Math.max(
        ...rules.map((rule) => rule.windowSeconds),
      );
      const concurrency =
        CONCURRENCY_POLICIES[
          request.action as keyof typeof CONCURRENCY_POLICIES
        ];
      let lease: ActionQuotaLease | undefined;
      if (concurrency) {
        const account = request.dimensions.account?.trim();
        const idempotencyKey = request.idempotencyKey?.trim();
        if (!account || !idempotencyKey) {
          throw new AppError(
            SECURITY_ERROR_CODES.quotaContextInvalid,
            'Khong the xac dinh ngu canh lease upload.',
            400,
          );
        }
        const scope = buildLeaseScope(
          request.action as ActionQuotaLease['action'],
          account,
        );
        lease = {
          action: request.action as ActionQuotaLease['action'],
          ...scope,
          member: digest('lease-member', idempotencyKey),
          ttlSeconds: concurrency.ttlSeconds,
        };
      }

      let decision: QuotaStoreDecision;
      try {
        decision = await input.store.consume(charges, {
          decisionKey,
          decisionTtlSeconds,
          ...(lease
            ? {
                lease: {
                  key: lease.leaseKey,
                  member: lease.member,
                  limit: concurrency.limit,
                  ttlSeconds: lease.ttlSeconds,
                },
              }
            : {}),
        });
      } catch {
        throw new AppError(
          SECURITY_ERROR_CODES.quotaUnavailable,
          'He thong dang tam thoi khong the kiem tra han muc. Vui long thu lai.',
          503,
          undefined,
          5,
        );
      }
      if (!decision.allowed) {
        throw new AppError(
          SECURITY_ERROR_CODES.rateLimited,
          'Ban da thao tac qua nhanh. Vui long thu lai sau.',
          429,
          undefined,
          decision.retryAfterSeconds,
        );
      }
      reportBudgetWarning(decision, request.action);
      return { ...decision, ...(lease ? { lease } : {}) };
    },
    bindLease: async (lease, resourceId) => {
      if (!input.store.bindLease)
        throw new Error('Quota lease binding unavailable.');
      await input.store.bindLease(
        lease.leaseKey,
        lease.mappingKey,
        lease.member,
        digest('lease-resource', resourceId.trim()),
        lease.ttlSeconds,
      );
    },
    cancelLease: async (lease) => {
      if (!input.store.releaseLease)
        throw new Error('Quota lease release unavailable.');
      await input.store.releaseLease(lease.leaseKey, lease.member);
    },
    releaseLease: async (request) => {
      if (!input.store.releaseBoundLease) {
        throw new Error('Quota bound lease release unavailable.');
      }
      const scope = buildLeaseScope(request.action, request.dimensions.account);
      await input.store.releaseBoundLease(
        scope.leaseKey,
        scope.mappingKey,
        digest('lease-resource', request.resourceId.trim()),
      );
    },
  };
  return guard;
};
