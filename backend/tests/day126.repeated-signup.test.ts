import { createSupabaseEmailVerificationGateway } from '../src/integrations/supabase-auth-gateway';
import { buildTestConfig } from './helpers/rescue-read-fixtures';

const USER = { id: 'local-1', email: 'repeat@pawmate.vn', password: 'Pawmate123' };

// Supabase answers a repeated signUp with a user that has no identities and
// sends no mail (auth event user_repeated_signup).
const repeatedSignup = (emailConfirmedAt: string | null) => ({
  data: {
    user: { id: 'remote-1', identities: [], email_confirmed_at: emailConfirmedAt },
  },
  error: null,
});

const OK_SIGN_IN = { data: { user: { id: 'remote-1' } }, error: null };
const BAD_SIGN_IN = {
  data: { user: null },
  error: { message: 'Invalid login credentials' },
};

const buildGateway = (signUpResponse: unknown, signInResponse: unknown = BAD_SIGN_IN) => {
  const authClient = {
    signUp: jest.fn().mockResolvedValue(signUpResponse),
    verifyOtp: jest.fn(),
    resend: jest.fn().mockResolvedValue({ data: {}, error: null }),
    signInWithPassword: jest.fn().mockResolvedValue(signInResponse),
  };
  const gateway = createSupabaseEmailVerificationGateway(buildTestConfig(), {
    authClient: authClient as never,
    adminClient: undefined,
  });
  return { gateway: gateway!, authClient };
};

describe('Day 126 D126-P2-001 repeated Supabase signup', () => {
  it('resends the confirmation mail when the remote email is unconfirmed', async () => {
    const { gateway, authClient } = buildGateway(repeatedSignup(null));

    await expect(gateway.sendEmailVerification(USER)).resolves.toEqual({
      status: 'verification-email-sent',
    });
    expect(authClient.resend).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'signup', email: USER.email }),
    );
  });

  it('reports auto-verified when the remote email is confirmed with the same password', async () => {
    const { gateway, authClient } = buildGateway(
      repeatedSignup('2026-11-26T04:58:06Z'),
      OK_SIGN_IN,
    );

    await expect(gateway.sendEmailVerification(USER)).resolves.toEqual({
      status: 'auto-verified',
    });
    expect(authClient.resend).not.toHaveBeenCalled();
  });

  it('does not resend after a normal first signup', async () => {
    const { gateway, authClient } = buildGateway({
      data: { user: { id: 'remote-1', identities: [{ id: 'i1' }] } },
      error: null,
    });

    await gateway.sendEmailVerification(USER);
    expect(authClient.resend).not.toHaveBeenCalled();
  });

  it('stays pending when the confirmed remote account has another password', async () => {
    const { gateway, authClient } = buildGateway(
      repeatedSignup('2026-11-26T04:58:06Z'),
      BAD_SIGN_IN,
    );

    await expect(gateway.sendEmailVerification(USER)).resolves.toEqual({
      status: 'verification-email-sent',
    });
    expect(authClient.resend).not.toHaveBeenCalled();
  });
});

describe('Day 126 isEmailConfirmed proves password ownership', () => {
  it('is true only when Supabase accepts the email and password', async () => {
    const ok = buildGateway(null, OK_SIGN_IN);
    const bad = buildGateway(null, BAD_SIGN_IN);

    await expect(
      ok.gateway.isEmailConfirmed!({ email: USER.email, password: USER.password }),
    ).resolves.toBe(true);
    await expect(
      bad.gateway.isEmailConfirmed!({ email: USER.email, password: 'Other123' }),
    ).resolves.toBe(false);
    expect(ok.authClient.signInWithPassword).toHaveBeenCalledWith({
      email: USER.email,
      password: USER.password,
    });
  });
});
