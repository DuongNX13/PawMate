import {
  ACTION_QUOTA_POLICIES,
  MemoryActionQuotaStore,
  QuotaStoreUnavailableError,
  createActionQuotaGuard,
  type ActionQuotaStore,
} from '../src/security/distributed-action-quota';

describe('Day 133 distributed action quota contract', () => {
  const secret = 'day133-test-secret-material-at-least-32-bytes';

  it('locks the approved prelaunch limits before implementation', () => {
    expect(ACTION_QUOTA_POLICIES['auth.resend']).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          dimension: 'ip',
          limit: 10,
          windowSeconds: 3600,
        }),
        expect.objectContaining({
          dimension: 'account',
          limit: 3,
          windowSeconds: 3600,
        }),
      ]),
    );
    expect(ACTION_QUOTA_POLICIES['upload.ticket']).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          dimension: 'account',
          limit: 20,
          windowSeconds: 3600,
        }),
        expect.objectContaining({
          dimension: 'bytes',
          limit: 100 * 1024 * 1024,
          windowSeconds: 3600,
        }),
        expect.objectContaining({
          dimension: 'globalBytes',
          limit: 2 * 1024 * 1024 * 1024,
          windowSeconds: 86400,
        }),
      ]),
    );
  });

  it('permits N requests, rejects N+1 atomically, and recovers after reset', async () => {
    let nowMs = Date.UTC(2026, 8, 25, 0, 0, 0);
    const store = new MemoryActionQuotaStore(() => nowMs);
    const guard = createActionQuotaGuard({ store, secret });
    const input = {
      action: 'auth.resend' as const,
      dimensions: { ip: '203.0.113.8', account: 'User@Example.Test' },
    };

    await Promise.all(
      Array.from({ length: 3 }, () =>
        expect(guard.enforce(input)).resolves.toMatchObject({ allowed: true }),
      ),
    );

    await expect(guard.enforce(input)).rejects.toMatchObject({
      code: 'SEC_001',
      statusCode: 429,
      retryAfterSeconds: 3600,
    });

    const snapshotAfterReject = store.snapshot();
    expect(Object.values(snapshotAfterReject).sort((a, b) => a - b)).toEqual([
      3, 3,
    ]);
    expect(JSON.stringify(snapshotAfterReject)).not.toContain('203.0.113.8');
    expect(JSON.stringify(snapshotAfterReject)).not.toContain(
      'user@example.test',
    );

    nowMs += 3600 * 1000;
    await expect(guard.enforce(input)).resolves.toMatchObject({
      allowed: true,
    });
  });

  it('does not partially increment any dimension when one dimension is exhausted', async () => {
    const store = new MemoryActionQuotaStore(() => 1_800_000_000_000);
    const guard = createActionQuotaGuard({ store, secret });

    await Promise.all(
      Array.from({ length: 3 }, () =>
        guard.enforce({
          action: 'auth.resend',
          dimensions: { ip: '203.0.113.9', account: 'same@example.test' },
        }),
      ),
    );

    const before = store.snapshot();
    await expect(
      guard.enforce({
        action: 'auth.resend',
        dimensions: { ip: '203.0.113.10', account: 'same@example.test' },
      }),
    ).rejects.toMatchObject({ statusCode: 429 });
    expect(store.snapshot()).toEqual(before);
  });

  it('charges request and declared bytes in one decision', async () => {
    const store = new MemoryActionQuotaStore(() => 1_800_000_000_000);
    const guard = createActionQuotaGuard({ store, secret });

    await expect(
      guard.enforce({
        action: 'upload.ticket',
        dimensions: { ip: '203.0.113.11', account: 'user-1' },
        units: { bytes: 5 * 1024 * 1024 },
        idempotencyKey: 'day133-upload-charge',
      }),
    ).resolves.toMatchObject({ allowed: true });

    expect(Object.values(store.snapshot()).sort((a, b) => a - b)).toEqual([
      1,
      1,
      5 * 1024 * 1024,
      5 * 1024 * 1024,
    ]);
  });

  it('fails closed without disclosing identity when the distributed store is unavailable', async () => {
    const unavailableStore: ActionQuotaStore = {
      consume: async () => {
        throw new QuotaStoreUnavailableError('redis unavailable');
      },
    };
    const guard = createActionQuotaGuard({ store: unavailableStore, secret });

    await expect(
      guard.enforce({
        action: 'auth.login',
        dimensions: { ip: '203.0.113.12', account: 'secret@example.test' },
      }),
    ).rejects.toMatchObject({
      code: 'SEC_002',
      statusCode: 503,
      retryAfterSeconds: 5,
      message: expect.not.stringContaining('secret@example.test'),
    });
  });

  it('keeps the counter correct under concurrent calls', async () => {
    const store = new MemoryActionQuotaStore(() => 1_800_000_000_000);
    const guard = createActionQuotaGuard({ store, secret });
    const results = await Promise.allSettled(
      Array.from({ length: 12 }, () =>
        guard.enforce({
          action: 'auth.resend',
          dimensions: { ip: '203.0.113.13', account: 'race@example.test' },
        }),
      ),
    );

    expect(
      results.filter((result) => result.status === 'fulfilled'),
    ).toHaveLength(3);
    expect(
      results.filter((result) => result.status === 'rejected'),
    ).toHaveLength(9);
    expect(Math.max(...Object.values(store.snapshot()))).toBe(3);
  });

  it('does not double-charge an accepted idempotent replay', async () => {
    const store = new MemoryActionQuotaStore(() => 1_800_000_000_000);
    const guard = createActionQuotaGuard({ store, secret });
    const request = {
      action: 'adoption.request' as const,
      dimensions: {
        ip: '203.0.113.20',
        account: 'user-20',
        resource: 'listing-20',
      },
      idempotencyKey: 'day133-replay-key',
    };

    await expect(guard.enforce(request)).resolves.toMatchObject({
      allowed: true,
    });
    const afterFirst = store.snapshot();
    await expect(guard.enforce(request)).resolves.toMatchObject({
      allowed: true,
    });
    expect(store.snapshot()).toEqual(afterFirst);
  });

  it('emits one non-secret warning when a global budget crosses 80 percent', async () => {
    const store = new MemoryActionQuotaStore(() => 1_800_000_000_000);
    const onBudgetWarning = jest.fn();
    const guard = createActionQuotaGuard({
      store,
      secret,
      onBudgetWarning,
    });

    await Promise.all(
      Array.from({ length: 81 }, (_, index) =>
        guard.enforce({
          action: 'provider.email',
          dimensions: { account: `account-${index}` },
        }),
      ),
    );

    expect(onBudgetWarning).toHaveBeenCalledTimes(1);
    expect(onBudgetWarning).toHaveBeenCalledWith({
      action: 'provider.email',
      thresholdPercent: 80,
    });
    expect(JSON.stringify(onBudgetWarning.mock.calls)).not.toContain(
      'account-',
    );
  });

  it('bounds upload ticket leases and releases a bound media lease', async () => {
    const store = new MemoryActionQuotaStore(() => 1_800_000_000_000);
    const guard = createActionQuotaGuard({ store, secret });
    const decisions = await Promise.all(
      Array.from({ length: 3 }, (_, index) =>
        guard.enforce({
          action: 'upload.ticket',
          dimensions: { ip: '203.0.113.21', account: 'user-21' },
          units: { bytes: 1024 },
          idempotencyKey: `upload-ticket-${index}`,
        }),
      ),
    );
    const leases = decisions.map((decision) => {
      expect(decision.lease).toBeDefined();
      return decision.lease!;
    });

    await expect(
      guard.enforce({
        action: 'upload.ticket',
        dimensions: { ip: '203.0.113.21', account: 'user-21' },
        units: { bytes: 1024 },
        idempotencyKey: 'upload-ticket-over-limit',
      }),
    ).rejects.toMatchObject({ code: 'SEC_001', statusCode: 429 });

    await guard.bindLease(leases[0], 'media-21');
    await guard.releaseLease({
      action: 'upload.ticket',
      dimensions: { account: 'user-21' },
      resourceId: 'media-21',
    });

    await expect(
      guard.enforce({
        action: 'upload.ticket',
        dimensions: { ip: '203.0.113.21', account: 'user-21' },
        units: { bytes: 1024 },
        idempotencyKey: 'upload-ticket-after-release',
      }),
    ).resolves.toMatchObject({ allowed: true });
  });

  it('limits inline-photo concurrency only for the request lifetime', async () => {
    const store = new MemoryActionQuotaStore(() => 1_800_000_000_000);
    const guard = createActionQuotaGuard({ store, secret });
    const first = await guard.enforce({
      action: 'upload.inline-photo',
      dimensions: { ip: '203.0.113.22', account: 'user-22' },
      units: { bytes: 1024 },
      idempotencyKey: 'inline-1',
    });
    const second = await guard.enforce({
      action: 'upload.inline-photo',
      dimensions: { ip: '203.0.113.22', account: 'user-22' },
      units: { bytes: 1024 },
      idempotencyKey: 'inline-2',
    });

    await expect(
      guard.enforce({
        action: 'upload.inline-photo',
        dimensions: { ip: '203.0.113.22', account: 'user-22' },
        units: { bytes: 1024 },
        idempotencyKey: 'inline-3',
      }),
    ).rejects.toMatchObject({ code: 'SEC_001', statusCode: 429 });

    await guard.cancelLease(first.lease!);
    await guard.cancelLease(second.lease!);
    await expect(
      guard.enforce({
        action: 'upload.inline-photo',
        dimensions: { ip: '203.0.113.22', account: 'user-22' },
        units: { bytes: 1024 },
        idempotencyKey: 'inline-3',
      }),
    ).resolves.toMatchObject({ allowed: true });
  });
});
