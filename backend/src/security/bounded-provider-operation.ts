import { AppError } from '../errors/app-error';
import { AUTH_ERROR_CODES } from '../errors/error-codes';
import { type OAuthVerifier } from '../services/auth/auth-service';

export const EXTERNAL_PROVIDER_TIMEOUT_MS = 10_000;

/**
 * Bounds how long an API request waits for an already-started provider call.
 *
 * This helper deliberately does not retry. Provider-specific transports may
 * still complete after the caller has timed out when they do not expose an
 * abort signal, so every metered side effect must be idempotent before it is
 * passed here.
 */
export const withProviderDeadline = async <T>(
  operation: Promise<T>,
  timeoutMs: number,
  createTimeoutError: () => Error,
): Promise<T> => {
  let timeout: NodeJS.Timeout | undefined;
  const deadline = new Promise<never>((_resolve, reject) => {
    timeout = setTimeout(() => reject(createTimeoutError()), timeoutMs);
  });

  try {
    return await Promise.race([operation, deadline]);
  } finally {
    if (timeout) clearTimeout(timeout);
  }
};

export const createBoundedOAuthVerifier = (
  verifier: OAuthVerifier,
  timeoutMs = EXTERNAL_PROVIDER_TIMEOUT_MS,
): OAuthVerifier => ({
  verify: (provider, credential, context) =>
    withProviderDeadline(
      verifier.verify(provider, credential, context),
      timeoutMs,
      () =>
        new AppError(
          AUTH_ERROR_CODES.oauthVerificationFailed,
          'Nha cung cap dang tam thoi khong phan hoi. Vui long thu lai sau.',
          503,
          'credential',
        ),
    ),
});
