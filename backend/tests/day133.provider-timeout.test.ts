import { AppError } from '../src/errors/app-error';
import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import {
  createBoundedOAuthVerifier,
  withProviderDeadline,
} from '../src/security/bounded-provider-operation';

describe('Day 133 external provider deadline', () => {
  it('fails a provider operation after the configured deadline', async () => {
    const neverSettles = new Promise<never>(() => {
      // Intentionally pending to exercise the deadline.
    });

    await expect(
      withProviderDeadline(
        neverSettles,
        5,
        () =>
          new AppError(
            AUTH_ERROR_CODES.verificationUnavailable,
            'Provider tam thoi khong phan hoi.',
            503,
          ),
      ),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.verificationUnavailable,
      statusCode: 503,
    });
  });

  it('clears the deadline when the provider resolves in time', async () => {
    await expect(
      withProviderDeadline(Promise.resolve('ok'), 50, () => new Error('late')),
    ).resolves.toBe('ok');
  });

  it('bounds OAuth verification without retrying the provider', async () => {
    const verify = jest.fn(
      () =>
        new Promise<never>(() => {
          // Intentionally pending to exercise the deadline.
        }),
    );
    const verifier = createBoundedOAuthVerifier({ verify }, 5);

    await expect(
      verifier.verify('google', 'opaque-provider-credential'),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.oauthVerificationFailed,
      statusCode: 503,
    });
    expect(verify).toHaveBeenCalledTimes(1);
  });
});
