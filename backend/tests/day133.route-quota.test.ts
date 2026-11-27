import { buildApp } from '../src/app';
import { AppError } from '../src/errors/app-error';
import { SECURITY_ERROR_CODES } from '../src/errors/error-codes';
import { type ActionQuotaGuard } from '../src/security/distributed-action-quota';
import { buildTestConfig } from './helpers/rescue-read-fixtures';

const allowDecision = {
  allowed: true as const,
  remaining: 10,
  retryAfterSeconds: 60,
};

const leaseMethods = {
  bindLease: async () => undefined,
  cancelLease: async () => undefined,
  releaseLease: async () => undefined,
};

describe('Day 133 route quota wiring', () => {
  it('returns the stable 429 envelope and Retry-After before auth side effects', async () => {
    const guard: ActionQuotaGuard = {
      ...leaseMethods,
      enforce: jest
        .fn()
        .mockRejectedValue(
          new AppError(
            SECURITY_ERROR_CODES.rateLimited,
            'Ban da thao tac qua nhanh. Vui long thu lai sau.',
            429,
            undefined,
            37,
          ),
        ),
    };
    const app = buildApp(
      { logger: false },
      { config: buildTestConfig(), actionQuotaGuard: guard },
    );

    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: { email: 'private@example.test', password: 'WrongPass123!' },
    });

    expect(response.statusCode).toBe(429);
    expect(response.headers['retry-after']).toBe('37');
    expect(response.json()).toMatchObject({
      success: false,
      error: { code: 'SEC_001' },
    });
    expect(response.body).not.toContain('private@example.test');
    expect(guard.enforce).toHaveBeenCalledWith({
      action: 'auth.login',
      dimensions: { ip: '127.0.0.1', account: 'private@example.test' },
    });
    await app.close();
  });

  it('stops a provider email side effect when the shared provider budget rejects', async () => {
    const sendEmailVerification = jest.fn().mockResolvedValue({
      status: 'verification-email-sent' as const,
    });
    const guard: ActionQuotaGuard = {
      ...leaseMethods,
      enforce: jest.fn(async (input) => {
        if (input.action === 'provider.email') {
          throw new AppError(
            SECURITY_ERROR_CODES.rateLimited,
            'Ban da thao tac qua nhanh. Vui long thu lai sau.',
            429,
            undefined,
            120,
          );
        }
        return allowDecision;
      }),
    };
    const app = buildApp(
      { logger: false },
      {
        config: buildTestConfig(),
        actionQuotaGuard: guard,
        emailVerificationGateway: {
          sendEmailVerification,
          verifyEmailToken: async () => ({ email: 'owner@example.test' }),
          resendEmailVerification: async () => undefined,
        },
      },
    );

    const response = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: 'provider-budget@example.test',
        password: 'StrongPass123!',
      },
    });

    expect(response.statusCode).toBe(429);
    expect(response.headers['retry-after']).toBe('120');
    expect(sendEmailVerification).not.toHaveBeenCalled();
    expect(guard.enforce).toHaveBeenCalledWith({
      action: 'provider.email',
      dimensions: { account: 'provider-budget@example.test' },
    });
    await app.close();
  });

  it('does not trust a spoofed forwarding header when no proxy is allowlisted', async () => {
    const enforce = jest.fn().mockResolvedValue(allowDecision);
    const app = buildApp(
      { logger: false },
      {
        config: { ...buildTestConfig(), trustedProxyCidrs: undefined },
        actionQuotaGuard: { enforce, ...leaseMethods },
        rescueReadService: {
          listCases: async () => ({ items: [], limit: 20 }),
          getCase: async () => ({ id: 'unused' }),
        } as never,
      },
    );

    const response = await app.inject({
      method: 'GET',
      url: '/rescue/cases',
      headers: { 'x-forwarded-for': '198.51.100.77' },
    });

    expect(response.statusCode).toBe(200);
    expect(enforce).toHaveBeenCalledWith({
      action: 'discovery.read',
      dimensions: { ip: '127.0.0.1' },
    });
    await app.close();
  });

  it('keeps the general body bound while allowing the explicit inline-photo envelope', async () => {
    const app = buildApp(
      { logger: false },
      {
        config: buildTestConfig(),
        actionQuotaGuard: {
          enforce: async () => allowDecision,
          ...leaseMethods,
        },
      },
    );
    const large = 'a'.repeat(1024 * 1024 + 128);

    const general = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'body@example.test',
        password: 'WrongPass123!',
        extra: large,
      },
    });
    expect(general.statusCode).toBe(413);

    const photo = await app.inject({
      method: 'POST',
      url: '/vets/vet-1/reviews/photos',
      payload: { fileName: 'photo.jpg', base64Data: large },
    });
    expect(photo.statusCode).toBe(401);
    expect(photo.json()).toMatchObject({ error: { code: 'REVIEW_005' } });
    await app.close();
  });
});
