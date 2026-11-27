import { createAuthService } from '../src/services/auth/auth-service';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import { AppError } from '../src/errors/app-error';
import { buildTestConfig } from './helpers/rescue-read-fixtures';

describe('Day 133 account enumeration and lockout DoS contract', () => {
  it('returns the same registration shape for a new and existing email', async () => {
    const sendEmailVerification = jest.fn().mockResolvedValue({
      status: 'verification-email-sent' as const,
    });
    const service = createAuthService({
      config: buildTestConfig(),
      emailVerificationGateway: {
        sendEmailVerification,
        verifyEmailToken: async () => ({ email: 'owner@example.test' }),
        resendEmailVerification: async () => undefined,
      },
    });

    const first = await service.register({
      email: 'owner@example.test',
      password: 'StrongPass123!',
    });
    const duplicate = await service.register({
      email: 'owner@example.test',
      password: 'StrongPass123!',
    });

    expect(first).toMatchObject({
      message: 'Nếu email hợp lệ, hướng dẫn xác minh sẽ được gửi.',
      verificationStatus: 'pending',
    });
    expect(duplicate).toMatchObject({
      message: first.message,
      verificationStatus: first.verificationStatus,
      verificationExpiresAt: expect.any(String),
      resendAvailableAt: expect.any(String),
    });
    expect(duplicate.userId).not.toBe(first.userId);
    expect(sendEmailVerification).toHaveBeenCalledTimes(1);
  });

  it('returns one resend response for unknown, verified, and pending accounts', async () => {
    const resendEmailVerification = jest.fn().mockResolvedValue(undefined);
    const service = createAuthService({
      config: buildTestConfig(),
      now: () => new Date('2026-09-25T12:00:00.000Z'),
      emailVerificationGateway: {
        sendEmailVerification: async () => ({
          status: 'verification-email-sent' as const,
        }),
        verifyEmailToken: async () => ({ email: 'pending@example.test' }),
        resendEmailVerification,
      },
    });
    await service.register({
      email: 'pending@example.test',
      password: 'StrongPass123!',
    });
    const verified = await service.register({
      email: 'verified@example.test',
      password: 'StrongPass123!',
    });
    await service.markEmailVerified(verified.userId);

    const pendingResult = await service.resendVerification({
      email: 'pending@example.test',
    });
    const verifiedResult = await service.resendVerification({
      email: 'verified@example.test',
    });
    const unknownResult = await service.resendVerification({
      email: 'unknown@example.test',
    });

    expect(verifiedResult).toEqual(pendingResult);
    expect(unknownResult).toEqual(pendingResult);
    expect(resendEmailVerification).toHaveBeenCalledTimes(1);
  });

  it('does not reveal an account or let bad passwords lock out a correct login', async () => {
    const service = createAuthService({ config: buildTestConfig() });
    await service.register({
      email: 'login@example.test',
      password: 'StrongPass123!',
    });
    const registration = await service.register({
      email: 'other@example.test',
      password: 'StrongPass123!',
    });
    await service.markEmailVerified(registration.userId);

    await expect(
      service.login({
        email: 'missing@example.test',
        password: 'WrongPass123!',
      }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.invalidCredentials,
      statusCode: 401,
    });
    await expect(
      service.login({ email: 'other@example.test', password: 'WrongPass123!' }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.invalidCredentials,
      statusCode: 401,
    });

    await Array.from({
      length: buildTestConfig().auth.maxLoginAttempts + 1,
    }).reduce<Promise<void>>(async (previous) => {
      await previous;
      await expect(
        service.login({
          email: 'other@example.test',
          password: 'WrongPass123!',
        }),
      ).rejects.toMatchObject({
        code: AUTH_ERROR_CODES.invalidCredentials,
        statusCode: 401,
      });
    }, Promise.resolve());

    await expect(
      service.login({
        email: 'other@example.test',
        password: 'StrongPass123!',
      }),
    ).resolves.toHaveProperty('accessToken');
  });

  it('keeps register and resend responses enumeration-safe during provider outage', async () => {
    const providerFailure = new AppError(
      AUTH_ERROR_CODES.verificationUnavailable,
      'provider unavailable',
      503,
    );
    const resendEmailVerification = jest
      .fn()
      .mockRejectedValue(providerFailure);
    const service = createAuthService({
      config: buildTestConfig(),
      now: () => new Date('2026-09-25T12:00:00.000Z'),
      emailVerificationGateway: {
        sendEmailVerification: jest
          .fn()
          .mockRejectedValueOnce(providerFailure)
          .mockResolvedValue({ status: 'verification-email-sent' as const }),
        verifyEmailToken: async () => ({ email: 'pending@example.test' }),
        resendEmailVerification,
      },
    });

    const outageRegistration = await service.register({
      email: 'outage@example.test',
      password: 'StrongPass123!',
    });
    const duplicateRegistration = await service.register({
      email: 'outage@example.test',
      password: 'StrongPass123!',
    });
    expect(duplicateRegistration).toMatchObject({
      message: outageRegistration.message,
      verificationStatus: outageRegistration.verificationStatus,
    });

    await service.register({
      email: 'pending@example.test',
      password: 'StrongPass123!',
    });
    const pendingOutage = await service.resendVerification({
      email: 'pending@example.test',
    });
    const unknownDuringOutage = await service.resendVerification({
      email: 'unknown@example.test',
    });
    expect(pendingOutage).toEqual(unknownDuringOutage);
    // Day 126: the duplicate registration of the outage account resends too.
    expect(resendEmailVerification).toHaveBeenCalledTimes(2);
  });
});
