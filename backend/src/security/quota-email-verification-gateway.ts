import { AppError } from '../errors/app-error';
import { AUTH_ERROR_CODES } from '../errors/error-codes';
import { type EmailVerificationDispatchResult } from '../services/auth/auth-service';
import {
  EXTERNAL_PROVIDER_TIMEOUT_MS,
  withProviderDeadline,
} from './bounded-provider-operation';
import { type ActionQuotaGuard } from './distributed-action-quota';

export type EmailVerificationGateway = {
  sendEmailVerification: (user: {
    id: string;
    email: string;
    displayName?: string;
    password: string;
  }) => Promise<EmailVerificationDispatchResult>;
  verifyEmailToken: (
    input: { tokenHash: string } | { email: string; token: string },
  ) => Promise<{ email: string }>;
  resendEmailVerification: (input: { email: string }) => Promise<void>;
  isEmailConfirmed?: (input: {
    email: string;
    password: string;
  }) => Promise<boolean>;
};

export const createQuotaProtectedEmailVerificationGateway = (
  gateway: EmailVerificationGateway,
  quota: ActionQuotaGuard,
  providerTimeoutMs = EXTERNAL_PROVIDER_TIMEOUT_MS,
): EmailVerificationGateway => ({
  sendEmailVerification: async (user) => {
    await quota.enforce({
      action: 'provider.email',
      dimensions: { account: user.email },
    });
    return withProviderDeadline(
      gateway.sendEmailVerification(user),
      providerTimeoutMs,
      () =>
        new AppError(
          AUTH_ERROR_CODES.verificationUnavailable,
          'Dich vu xac minh dang tam thoi khong phan hoi.',
          503,
        ),
    );
  },
  verifyEmailToken: (input) =>
    withProviderDeadline(
      gateway.verifyEmailToken(input),
      providerTimeoutMs,
      () =>
        new AppError(
          AUTH_ERROR_CODES.verificationUnavailable,
          'Dich vu xac minh dang tam thoi khong phan hoi.',
          503,
        ),
    ),
  ...(gateway.isEmailConfirmed
    ? {
        isEmailConfirmed: (input: { email: string; password: string }) =>
          withProviderDeadline(
            gateway.isEmailConfirmed!(input),
            providerTimeoutMs,
            () =>
              new AppError(
                AUTH_ERROR_CODES.verificationUnavailable,
                'Dich vu xac minh dang tam thoi khong phan hoi.',
                503,
              ),
          ),
      }
    : {}),
  resendEmailVerification: async (input) => {
    await quota.enforce({
      action: 'provider.email',
      dimensions: { account: input.email },
    });
    return withProviderDeadline(
      gateway.resendEmailVerification(input),
      providerTimeoutMs,
      () =>
        new AppError(
          AUTH_ERROR_CODES.verificationUnavailable,
          'Dich vu xac minh dang tam thoi khong phan hoi.',
          503,
        ),
    );
  },
});
