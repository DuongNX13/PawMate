import { type Redis } from 'ioredis';

import { RedisActionQuotaStore } from '../src/security/redis-action-quota-store';

describe('Day 133 Redis action quota store', () => {
  it('passes all dimensions to one Lua transaction', async () => {
    const evalMock = jest.fn().mockResolvedValue([1, 2, 57, '', 0]);
    const timeMock = jest.fn().mockResolvedValue(['1800000000', '123']);
    const store = new RedisActionQuotaStore({
      eval: evalMock,
      time: timeMock,
    } as unknown as Redis);
    await expect(
      store.consume([
        { keyPrefix: 'q:a', limit: 3, windowSeconds: 60, amount: 1 },
        { keyPrefix: 'q:b', limit: 100, windowSeconds: 3600, amount: 5 },
      ]),
    ).resolves.toEqual({ allowed: true, remaining: 2, retryAfterSeconds: 57 });

    expect(evalMock).toHaveBeenCalledTimes(1);
    expect(timeMock).toHaveBeenCalledTimes(1);
    expect(evalMock.mock.calls[0]).toEqual([
      expect.not.stringContaining("redis.call('TIME')"),
      0,
      '2',
      '1800000000',
      '',
      '0',
      '',
      '',
      '0',
      '0',
      'q:a',
      '3',
      '60',
      '1',
      '0',
      'q:b',
      '100',
      '3600',
      '5',
      '0',
    ]);
  });

  it('passes idempotency and lease metadata to the atomic Redis decision', async () => {
    const evalMock = jest.fn().mockResolvedValue([1, 2, 57, 'lease-member', 0]);
    const store = new RedisActionQuotaStore({
      eval: evalMock,
      time: jest.fn().mockResolvedValue(['1800000000', '123']),
    } as unknown as Redis);

    await expect(
      store.consume(
        [{ keyPrefix: 'q:a', limit: 3, windowSeconds: 60, amount: 1 }],
        {
          decisionKey: 'q:decision',
          decisionTtlSeconds: 60,
          lease: {
            key: 'q:lease',
            member: 'lease-member',
            limit: 3,
            ttlSeconds: 900,
          },
        },
      ),
    ).resolves.toEqual({
      allowed: true,
      remaining: 2,
      retryAfterSeconds: 57,
      leaseMember: 'lease-member',
    });

    expect(evalMock.mock.calls[0]).toEqual([
      expect.any(String),
      0,
      '1',
      '1800000000',
      'q:decision',
      '60',
      'q:lease',
      'lease-member',
      '3',
      '900',
      'q:a',
      '3',
      '60',
      '1',
      '0',
    ]);
  });

  it('returns a rejected decision without hiding Retry-After', async () => {
    const store = new RedisActionQuotaStore({
      eval: jest.fn().mockResolvedValue([0, 0, 29, '', 0]),
      time: jest.fn().mockResolvedValue(['1800000000', '123']),
    } as unknown as Redis);
    await expect(
      store.consume([
        { keyPrefix: 'q:a', limit: 3, windowSeconds: 60, amount: 1 },
      ]),
    ).resolves.toEqual({ allowed: false, remaining: 0, retryAfterSeconds: 29 });
  });

  it('fails closed on Redis errors and malformed responses', async () => {
    const unavailable = new RedisActionQuotaStore({
      eval: jest
        .fn()
        .mockRejectedValue(new Error('ECONNREFUSED redis://secret')),
      time: jest.fn().mockResolvedValue(['1800000000', '123']),
    } as unknown as Redis);
    await expect(
      unavailable.consume([
        { keyPrefix: 'q:a', limit: 3, windowSeconds: 60, amount: 1 },
      ]),
    ).rejects.toMatchObject({ name: 'QuotaStoreUnavailableError' });

    const malformed = new RedisActionQuotaStore({
      eval: jest.fn().mockResolvedValue(['unexpected']),
      time: jest.fn().mockResolvedValue(['1800000000', '123']),
    } as unknown as Redis);
    await expect(
      malformed.consume([
        { keyPrefix: 'q:a', limit: 3, windowSeconds: 60, amount: 1 },
      ]),
    ).rejects.toMatchObject({ name: 'QuotaStoreUnavailableError' });
  });
});
