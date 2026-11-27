import { AppError } from '../src/errors/app-error';
import { AUTH_ERROR_CODES, SECURITY_ERROR_CODES } from '../src/errors/error-codes';
import {
  createAuthService,
  type EmailVerificationGateway,
} from '../src/services/auth/auth-service';
import { buildTestConfig } from './helpers/rescue-read-fixtures';

const EMAIL = 'owner@example.test';
const PASSWORD = 'StrongPass123!';

const buildGateway = (
  overrides: Partial<EmailVerificationGateway> = {},
): EmailVerificationGateway => ({
  sendEmailVerification: jest
    .fn()
    .mockResolvedValue({ status: 'verification-email-sent' as const }),
  verifyEmailToken: async () => ({ email: EMAIL }),
  resendEmailVerification: jest.fn().mockResolvedValue(undefined),
  ...overrides,
});

const expectAppError = async (promise: Promise<unknown>, code: string) => {
  await expect(promise).rejects.toBeInstanceOf(AppError);
  await expect(promise).rejects.toMatchObject({ code });
};

describe('Day 126 D125-P2-002 registration retry after a failed send', () => {
  it('resends the verification email when a pending email is registered again', async () => {
    const gateway = buildGateway({
      sendEmailVerification: jest
        .fn()
        .mockRejectedValue(new Error('provider down')),
    });
    const logger = { warn: jest.fn() };
    const service = createAuthService({
      config: buildTestConfig(),
      emailVerificationGateway: gateway,
      logger,
    });

    const first = await service.register({ email: EMAIL, password: PASSWORD });
    const retry = await service.register({ email: EMAIL, password: PASSWORD });

    expect(gateway.resendEmailVerification).toHaveBeenCalledTimes(1);
    expect(gateway.resendEmailVerification).toHaveBeenCalledWith({
      email: EMAIL,
    });
    expect(retry).toMatchObject({
      message: first.message,
      verificationStatus: 'pending',
    });
    expect(logger.warn).toHaveBeenCalledWith(
      expect.objectContaining({ userId: first.userId }),
      expect.any(String),
    );
    expect(JSON.stringify(logger.warn.mock.calls)).not.toContain(EMAIL);
  });

  it('sends nothing when a verified email is registered again', async () => {
    const gateway = buildGateway();
    const service = createAuthService({
      config: buildTestConfig(),
      emailVerificationGateway: gateway,
    });
    const first = await service.register({ email: EMAIL, password: PASSWORD });
    await service.markEmailVerified(first.userId);

    const retry = await service.register({ email: EMAIL, password: PASSWORD });

    expect(gateway.resendEmailVerification).not.toHaveBeenCalled();
    expect(retry).toMatchObject({
      message: first.message,
      verificationStatus: 'pending',
    });
  });

  it('keeps the generic response when the resend quota is exhausted', async () => {
    const gateway = buildGateway({
      resendEmailVerification: jest
        .fn()
        .mockRejectedValue(
          new AppError(SECURITY_ERROR_CODES.rateLimited, 'limited', 429),
        ),
    });
    const service = createAuthService({
      config: buildTestConfig(),
      emailVerificationGateway: gateway,
    });
    const first = await service.register({ email: EMAIL, password: PASSWORD });

    const retry = await service.register({ email: EMAIL, password: PASSWORD });

    expect(retry).toMatchObject({
      message: first.message,
      verificationStatus: 'pending',
    });
  });
});

describe('Day 126 D125-P2-003 login after the email link was clicked', () => {
  it('logs in and stores the flag when the provider reports the email confirmed', async () => {
    const isEmailConfirmed = jest.fn().mockResolvedValue(true);
    const service = createAuthService({
      config: buildTestConfig(),
      emailVerificationGateway: buildGateway({ isEmailConfirmed }),
    });
    await service.register({ email: EMAIL, password: PASSWORD });

    const session = await service.login({ email: EMAIL, password: PASSWORD });
    const second = await service.login({ email: EMAIL, password: PASSWORD });

    expect(session.accessToken).toEqual(expect.any(String));
    expect(second.accessToken).toEqual(expect.any(String));
    expect(isEmailConfirmed).toHaveBeenCalledTimes(1);
    expect(isEmailConfirmed).toHaveBeenCalledWith({
      email: EMAIL,
      password: PASSWORD,
    });
  });

  it('still rejects login when the provider reports the email unconfirmed', async () => {
    const service = createAuthService({
      config: buildTestConfig(),
      emailVerificationGateway: buildGateway({
        isEmailConfirmed: jest.fn().mockResolvedValue(false),
      }),
    });
    await service.register({ email: EMAIL, password: PASSWORD });

    await expectAppError(
      service.login({ email: EMAIL, password: PASSWORD }),
      AUTH_ERROR_CODES.emailUnverified,
    );
  });

  it('rejects login without crashing when the provider check fails', async () => {
    const service = createAuthService({
      config: buildTestConfig(),
      emailVerificationGateway: buildGateway({
        isEmailConfirmed: jest.fn().mockRejectedValue(new Error('network')),
      }),
    });
    await service.register({ email: EMAIL, password: PASSWORD });

    await expectAppError(
      service.login({ email: EMAIL, password: PASSWORD }),
      AUTH_ERROR_CODES.emailUnverified,
    );
  });

  it('does not ask the provider when the password is wrong', async () => {
    const isEmailConfirmed = jest.fn().mockResolvedValue(true);
    const service = createAuthService({
      config: buildTestConfig(),
      emailVerificationGateway: buildGateway({ isEmailConfirmed }),
    });
    await service.register({ email: EMAIL, password: PASSWORD });

    await expectAppError(
      service.login({ email: EMAIL, password: 'WrongPass999!' }),
      AUTH_ERROR_CODES.invalidCredentials,
    );
    expect(isEmailConfirmed).not.toHaveBeenCalled();
  });
});
