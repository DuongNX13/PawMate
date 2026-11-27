import { createHash, randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import jwt, {
  JsonWebTokenError,
  TokenExpiredError,
  type JwtPayload,
} from 'jsonwebtoken';

import {
  ConfigError,
  resolveAuthJwtConfig,
  type AppConfig,
} from '../../config/env';
import { AppError } from '../../errors/app-error';
import {
  AUTH_ERROR_CODES,
  SECURITY_ERROR_CODES,
} from '../../errors/error-codes';

export type AuthProvider = 'email' | 'google' | 'apple';

export type OAuthProvider = Exclude<AuthProvider, 'email'>;

export type UserRecord = {
  id: string;
  email: string;
  passwordHash?: string;
  displayName?: string;
  phone?: string;
  authProvider: AuthProvider;
  emailVerified: boolean;
  failedLoginAttempts: number;
  lockedUntil?: Date;
  createdAt: Date;
  updatedAt: Date;
  providerAccounts: Partial<Record<OAuthProvider, string>>;
};

export type SessionRecord = {
  id: string;
  userId: string;
  refreshTokenHash: string;
  previousRefreshTokenHash?: string;
  rotatedAt?: Date;
  deviceId?: string;
  userAgent?: string;
  ipAddress?: string;
  expiresAt: Date;
  revokedAt?: Date;
  createdAt: Date;
};

export type AuthUserStore = {
  findUserByEmail: (email: string) => Promise<UserRecord | undefined>;
  findUserById: (userId: string) => Promise<UserRecord | undefined>;
  findUserByProviderAccount: (
    provider: OAuthProvider,
    providerUserId: string,
  ) => Promise<UserRecord | undefined>;
  saveUser: (user: UserRecord) => Promise<void>;
  deleteUserById: (userId: string) => Promise<void>;
};

export type AuthSessionStore = {
  listActiveSessionsByUser: (userId: string) => Promise<SessionRecord[]>;
  findSessionById: (sessionId: string) => Promise<SessionRecord | undefined>;
  createSession: (
    session: SessionRecord,
    maxActiveSessions: number,
    revokedAt: Date,
  ) => Promise<void>;
  rotateSession: (
    session: SessionRecord,
    expectedRefreshTokenHash: string,
  ) => Promise<boolean>;
  revokeSession: (sessionId: string, revokedAt: Date) => Promise<void>;
  revokeAllSessionsForUser: (userId: string, revokedAt: Date) => Promise<void>;
};

type AccessTokenPayload = JwtPayload & {
  typ: 'access';
  sub: string;
  email: string;
  sid: string;
};

type RefreshTokenPayload = JwtPayload & {
  typ: 'refresh';
  sub: string;
  sid: string;
};

export type RegisterInput = {
  email: string;
  password: string;
  phone?: string;
  displayName?: string;
};

export type RegisterResult = {
  userId: string;
  message: string;
  verificationStatus: 'pending' | 'verified';
  verificationExpiresAt?: string;
  resendAvailableAt?: string;
};

export type EmailVerificationDispatchResult = {
  status: 'verification-email-sent' | 'auto-verified';
};

export type LoginInput = {
  email: string;
  password: string;
  rememberMe?: boolean;
  deviceId?: string;
  userAgent?: string;
  ipAddress?: string;
};

export type RefreshInput = {
  refreshToken: string;
  deviceId?: string;
  userAgent?: string;
  ipAddress?: string;
};

export type LogoutInput = {
  refreshToken: string;
};

export type OAuthInput = {
  provider: AuthProvider;
  credential: string;
  accessToken?: string;
  nonce?: string;
  redirectUri?: string;
  displayName?: string;
  deviceId?: string;
  userAgent?: string;
  ipAddress?: string;
};

export type OAuthIdentity = {
  email: string;
  providerUserId: string;
  displayName?: string;
};

export type VerifyEmailInput =
  | {
      tokenHash: string;
    }
  | {
      email: string;
      token: string;
    };

export type ResendVerificationInput = {
  email: string;
};

export type AuthSessionResult = {
  user: {
    id: string;
    email: string;
    authProvider: AuthProvider;
    emailVerified: boolean;
    displayName?: string;
    phone?: string;
  };
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: string;
  refreshTokenExpiresAt: string;
};

export type AuthService = ReturnType<typeof createAuthService>;

export type EmailVerificationGateway = {
  sendEmailVerification: (user: {
    id: string;
    email: string;
    displayName?: string;
    password: string;
  }) => Promise<EmailVerificationDispatchResult>;
  verifyEmailToken: (input: VerifyEmailInput) => Promise<{
    email: string;
  }>;
  resendEmailVerification: (input: ResendVerificationInput) => Promise<void>;
  // Link-based verification confirms the email at the provider only, so login
  // asks the provider before rejecting a locally unverified account. The
  // password is required so a confirmed remote email alone never verifies a
  // local account created by someone else.
  isEmailConfirmed?: (input: {
    email: string;
    password: string;
  }) => Promise<boolean>;
};

export type AuthLogger = {
  warn: (context: Record<string, unknown>, message: string) => void;
};

export type OAuthVerifier = {
  verify: (
    provider: OAuthProvider,
    credential: string,
    context?: {
      accessToken?: string;
      nonce?: string;
      redirectUri?: string;
    },
  ) => Promise<OAuthIdentity>;
};

type AuthServiceDependencies = {
  config: AppConfig;
  now?: () => Date;
  userStore?: AuthUserStore;
  sessionStore?: AuthSessionStore;
  emailVerificationGateway?: EmailVerificationGateway;
  oauthVerifier?: OAuthVerifier;
  logger?: AuthLogger;
};

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const vietnamPhoneRegex = /^0[0-9]{9,10}$/;
const passwordHasLetter = /[A-Za-z]/;
const passwordHasNumber = /[0-9]/;
const verificationOtpTtlMs = 5 * 60 * 1000;
const verificationResendCooldownMs = 60 * 1000;
// A fixed non-user hash keeps unknown-account login work comparable to a real
// bcrypt verification without creating or logging a synthetic credential.
const DUMMY_PASSWORD_HASH =
  '$2b$12$HgrihiU.fGIo279nI1YS2.BZ.mZXHBCWNSQ6OJiQWtaKgfntpSswu';
const GENERIC_VERIFICATION_MESSAGE =
  'Nếu email hợp lệ, hướng dẫn xác minh sẽ được gửi.';

const isQuotaStop = (error: unknown) =>
  error instanceof AppError &&
  (error.code === SECURITY_ERROR_CODES.rateLimited ||
    error.code === SECURITY_ERROR_CODES.quotaUnavailable);

const createInMemoryAuthUserStore = (): AuthUserStore => {
  const users = new Map<string, UserRecord>();
  const usersByEmail = new Map<string, string>();
  const providerLinks = new Map<string, string>();

  return {
    async findUserByEmail(email: string) {
      const userId = usersByEmail.get(email);
      return userId ? users.get(userId) : undefined;
    },

    async findUserById(userId: string) {
      return users.get(userId);
    },

    async findUserByProviderAccount(
      provider: OAuthProvider,
      providerUserId: string,
    ) {
      const userId = providerLinks.get(`${provider}:${providerUserId}`);
      return userId ? users.get(userId) : undefined;
    },

    async saveUser(user: UserRecord) {
      users.set(user.id, user);
      usersByEmail.set(user.email, user.id);
      Object.entries(user.providerAccounts).forEach(
        ([provider, providerUserId]) => {
          if (providerUserId) {
            providerLinks.set(`${provider}:${providerUserId}`, user.id);
          }
        },
      );
    },

    async deleteUserById(userId: string) {
      const existingUser = users.get(userId);
      if (!existingUser) {
        return;
      }

      users.delete(userId);
      usersByEmail.delete(existingUser.email);
      Object.entries(existingUser.providerAccounts).forEach(
        ([provider, providerUserId]) => {
          if (providerUserId) {
            providerLinks.delete(`${provider}:${providerUserId}`);
          }
        },
      );
    },
  };
};

const createInMemoryAuthSessionStore = (): AuthSessionStore => {
  const sessions = new Map<string, SessionRecord>();

  return {
    async listActiveSessionsByUser(userId: string) {
      return [...sessions.values()]
        .filter((session) => session.userId === userId && !session.revokedAt)
        .sort(
          (left, right) => left.createdAt.getTime() - right.createdAt.getTime(),
        );
    },

    async findSessionById(sessionId: string) {
      return sessions.get(sessionId);
    },

    async createSession(session, maxActiveSessions, revokedAt) {
      const activeSessions = [...sessions.values()]
        .filter(
          (candidate) =>
            candidate.userId === session.userId && !candidate.revokedAt,
        )
        .sort(
          (left, right) => left.createdAt.getTime() - right.createdAt.getTime(),
        );
      const sessionsToRevoke = Math.max(
        activeSessions.length - maxActiveSessions + 1,
        0,
      );
      activeSessions.slice(0, sessionsToRevoke).forEach((candidate) => {
        sessions.set(candidate.id, { ...candidate, revokedAt });
      });
      sessions.set(session.id, session);
    },

    async rotateSession(session, expectedRefreshTokenHash) {
      const current = sessions.get(session.id);
      if (
        !current ||
        current.revokedAt ||
        current.userId !== session.userId ||
        current.refreshTokenHash !== expectedRefreshTokenHash
      ) {
        return false;
      }

      sessions.set(session.id, session);
      return true;
    },

    async revokeSession(sessionId: string, revokedAt: Date) {
      const session = sessions.get(sessionId);
      if (!session) {
        return;
      }

      sessions.set(sessionId, {
        ...session,
        revokedAt,
      });
    },

    async revokeAllSessionsForUser(userId: string, revokedAt: Date) {
      [...sessions.values()]
        .filter((session) => session.userId === userId && !session.revokedAt)
        .forEach((session) => {
          sessions.set(session.id, { ...session, revokedAt });
        });
    },
  };
};

const normalizeEmail = (value: string) => value.trim().toLowerCase();
const hashToken = (value: string) =>
  createHash('sha256').update(value).digest('hex');

const CONCURRENT_REFRESH_GRACE_MS = 5_000;

const sanitizeUser = (user: UserRecord) => ({
  id: user.id,
  email: user.email,
  authProvider: user.authProvider,
  emailVerified: user.emailVerified,
  displayName: user.displayName,
  phone: user.phone,
});

const validateProductionAuthDependencies = (
  dependencies: AuthServiceDependencies,
) => {
  if (
    dependencies.config.nodeEnv === 'production' &&
    !dependencies.emailVerificationGateway
  ) {
    throw new ConfigError(
      'CONFIG_EMAIL_VERIFICATION_GATEWAY_REQUIRED',
      'A production email-verification gateway is required.',
    );
  }
  if (
    dependencies.config.nodeEnv === 'production' &&
    dependencies.config.auth.socialLoginEnabled &&
    !dependencies.oauthVerifier
  ) {
    throw new ConfigError(
      'CONFIG_OAUTH_VERIFIER_REQUIRED',
      'A production OAuth verifier is required when social login is enabled.',
    );
  }
  if (
    dependencies.config.nodeEnv === 'production' &&
    (!dependencies.userStore || !dependencies.sessionStore)
  ) {
    throw new ConfigError(
      'CONFIG_AUTH_STORES_REQUIRED',
      'Persistent production user and session stores are required.',
    );
  }
};

const newOAuthUser = (
  provider: OAuthProvider,
  input: OAuthInput,
  identity: OAuthIdentity,
  email: string,
  timestamp: Date,
): UserRecord => ({
  id: randomUUID(),
  email,
  displayName:
    input.displayName?.trim() || identity.displayName?.trim() || undefined,
  phone: undefined,
  authProvider: provider,
  emailVerified: true,
  failedLoginAttempts: 0,
  createdAt: timestamp,
  updatedAt: timestamp,
  providerAccounts: {},
});

const linkOAuthUser = (
  user: UserRecord,
  provider: OAuthProvider,
  input: OAuthInput,
  identity: OAuthIdentity,
  timestamp: Date,
): UserRecord => ({
  ...user,
  authProvider: user.authProvider === 'email' ? provider : user.authProvider,
  emailVerified: true,
  displayName:
    user.displayName ||
    input.displayName?.trim() ||
    identity.displayName?.trim() ||
    undefined,
  providerAccounts: {
    ...user.providerAccounts,
    [provider]: identity.providerUserId,
  },
  updatedAt: timestamp,
});

export const createAuthService = ({
  config,
  now = () => new Date(),
  userStore: suppliedUserStore,
  sessionStore: suppliedSessionStore,
  emailVerificationGateway,
  oauthVerifier,
  logger,
}: AuthServiceDependencies) => {
  const jwtConfig = resolveAuthJwtConfig(config);

  validateProductionAuthDependencies({
    config,
    emailVerificationGateway,
    oauthVerifier,
    userStore: suppliedUserStore,
    sessionStore: suppliedSessionStore,
  });
  const userStore = suppliedUserStore ?? createInMemoryAuthUserStore();
  const sessionStore = suppliedSessionStore ?? createInMemoryAuthSessionStore();

  const verifyApplicationToken = <TPayload extends JwtPayload>(
    token: string,
    tokenType: 'access' | 'refresh',
    ignoreExpiration = false,
  ): TPayload => {
    const decoded = jwt.decode(token, { complete: true });
    if (
      !decoded ||
      typeof decoded === 'string' ||
      decoded.header.alg !== jwtConfig.algorithm ||
      typeof decoded.header.kid !== 'string'
    ) {
      throw new JsonWebTokenError('Token header is not allowed.');
    }

    const currentKey =
      tokenType === 'access'
        ? {
            id: jwtConfig.accessKeyId,
            secret: config.auth.accessTokenSecret,
          }
        : {
            id: jwtConfig.refreshKeyId,
            secret: config.auth.refreshTokenSecret,
          };
    const previousKey =
      tokenType === 'access'
        ? jwtConfig.previousAccessKey
        : jwtConfig.previousRefreshKey;
    let key: { id: string; secret: string } | undefined;
    if (decoded.header.kid === currentKey.id) {
      key = currentKey;
    } else if (previousKey?.id === decoded.header.kid) {
      key = previousKey;
    }

    if (!key) {
      throw new JsonWebTokenError('Token key ID is not active.');
    }

    return jwt.verify(token, key.secret, {
      algorithms: [jwtConfig.algorithm],
      issuer: jwtConfig.issuer,
      audience: jwtConfig.audience,
      clockTolerance: jwtConfig.clockToleranceSeconds,
      ignoreExpiration,
    }) as TPayload;
  };

  const buildVerificationWindow = () => {
    const issuedAt = now().getTime();
    return {
      verificationExpiresAt: new Date(
        issuedAt + verificationOtpTtlMs,
      ).toISOString(),
      resendAvailableAt: new Date(
        issuedAt + verificationResendCooldownMs,
      ).toISOString(),
    };
  };

  const validateEmail = (email: string) => {
    if (email.length > 254 || !emailRegex.test(email)) {
      throw new AppError(
        AUTH_ERROR_CODES.invalidEmail,
        'Email khong dung dinh dang.',
        400,
        'email',
      );
    }
  };

  const validatePassword = (password: string) => {
    const isStrongEnough =
      password.length >= 8 &&
      password.length <= 64 &&
      passwordHasLetter.test(password) &&
      passwordHasNumber.test(password);

    if (!isStrongEnough) {
      throw new AppError(
        AUTH_ERROR_CODES.weakPassword,
        'Mat khau phai co it nhat 8 ky tu, gom chu va so.',
        400,
        'password',
      );
    }
  };

  const validatePhone = (phone?: string) => {
    if (phone != null && !vietnamPhoneRegex.test(phone.trim())) {
      throw new AppError(
        AUTH_ERROR_CODES.invalidPhone,
        'So dien thoai phai co 10-11 chu so va bat dau bang 0.',
        400,
        'phone',
      );
    }
  };

  const buildSessionResult = async (
    user: UserRecord,
    rememberMe: boolean,
    metadata?: Pick<LoginInput, 'deviceId' | 'userAgent' | 'ipAddress'>,
    rotation?: {
      currentSession: SessionRecord;
      expectedRefreshTokenHash: string;
    },
  ): Promise<AuthSessionResult> => {
    const issuedAt = now();
    const sessionId = rotation?.currentSession.id ?? randomUUID();
    const accessTokenExpiresAt = new Date(
      issuedAt.getTime() + config.auth.accessTokenTtlMinutes * 60 * 1000,
    );
    const refreshDays = rememberMe
      ? config.auth.refreshTokenTtlDays
      : Math.min(7, config.auth.refreshTokenTtlDays);
    const refreshTokenExpiresAt = new Date(
      issuedAt.getTime() + refreshDays * 24 * 60 * 60 * 1000,
    );

    const accessToken = jwt.sign(
      {
        typ: 'access',
        email: user.email,
        sid: sessionId,
        jti: randomUUID(),
      },
      config.auth.accessTokenSecret,
      {
        algorithm: jwtConfig.algorithm,
        keyid: jwtConfig.accessKeyId,
        issuer: jwtConfig.issuer,
        audience: jwtConfig.audience,
        subject: user.id,
        expiresIn: `${config.auth.accessTokenTtlMinutes}m`,
      },
    );

    const refreshToken = jwt.sign(
      {
        typ: 'refresh',
        sid: sessionId,
        jti: randomUUID(),
      },
      config.auth.refreshTokenSecret,
      {
        algorithm: jwtConfig.algorithm,
        keyid: jwtConfig.refreshKeyId,
        issuer: jwtConfig.issuer,
        audience: jwtConfig.audience,
        subject: user.id,
        expiresIn: `${refreshDays}d`,
      },
    );

    const nextSession: SessionRecord = {
      id: sessionId,
      userId: user.id,
      refreshTokenHash: hashToken(refreshToken),
      previousRefreshTokenHash: rotation?.expectedRefreshTokenHash,
      rotatedAt: rotation ? issuedAt : undefined,
      deviceId: metadata?.deviceId,
      userAgent: metadata?.userAgent,
      ipAddress: metadata?.ipAddress,
      expiresAt: refreshTokenExpiresAt,
      createdAt: rotation?.currentSession.createdAt ?? issuedAt,
    };
    if (rotation) {
      const rotated = await sessionStore.rotateSession(
        nextSession,
        rotation.expectedRefreshTokenHash,
      );
      if (!rotated) {
        const latest = await sessionStore.findSessionById(nextSession.id);
        if (
          latest?.previousRefreshTokenHash ===
            rotation.expectedRefreshTokenHash &&
          latest.rotatedAt &&
          issuedAt.getTime() - latest.rotatedAt.getTime() <=
            CONCURRENT_REFRESH_GRACE_MS
        ) {
          throw new AppError(
            AUTH_ERROR_CODES.invalidRefreshToken,
            'Refresh token da duoc xu ly boi mot yeu cau dong thoi.',
            401,
          );
        }
        await sessionStore.revokeAllSessionsForUser(user.id, issuedAt);
        throw new AppError(
          AUTH_ERROR_CODES.refreshTokenReuse,
          'Refresh token da bi tai su dung.',
          401,
        );
      }
    } else {
      await sessionStore.createSession(
        nextSession,
        config.auth.maxActiveSessions,
        issuedAt,
      );
    }

    return {
      user: sanitizeUser(user),
      accessToken,
      refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt.toISOString(),
      refreshTokenExpiresAt: refreshTokenExpiresAt.toISOString(),
    };
  };

  const parseRefreshToken = (
    refreshToken: string,
    allowExpired = false,
  ): RefreshTokenPayload => {
    try {
      const payload = verifyApplicationToken<RefreshTokenPayload>(
        refreshToken,
        'refresh',
        allowExpired,
      );

      if (payload.typ !== 'refresh' || !payload.sub || !payload.sid) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidRefreshToken,
          'Refresh token khong hop le.',
          401,
        );
      }

      return payload;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }

      if (error instanceof TokenExpiredError) {
        throw new AppError(
          AUTH_ERROR_CODES.expiredRefreshToken,
          'Refresh token da het han.',
          401,
        );
      }

      if (error instanceof JsonWebTokenError) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidRefreshToken,
          'Refresh token khong hop le.',
          401,
        );
      }

      throw error;
    }
  };

  const dispatchRegistrationVerification = async (
    user: UserRecord,
    password: string,
  ) => {
    let persistedUser = user;
    try {
      const verificationResult =
        (await emailVerificationGateway?.sendEmailVerification({
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          password,
        })) ?? { status: 'verification-email-sent' as const };
      if (verificationResult.status === 'auto-verified') {
        persistedUser = { ...user, emailVerified: true, updatedAt: now() };
        await userStore.saveUser(persistedUser);
      }
    } catch (error) {
      if (isQuotaStop(error)) throw error;
      // Outages retain the pending account; registering again resends.
      logger?.warn(
        { userId: user.id, err: error instanceof Error ? error.message : 'unknown' },
        'auth.register: verification email dispatch failed',
      );
    }
    return persistedUser;
  };

  const resendForPendingDuplicate = async (existing: UserRecord) => {
    if (existing.emailVerified || existing.authProvider !== 'email') return;
    try {
      await emailVerificationGateway?.resendEmailVerification({
        email: existing.email,
      });
    } catch (error) {
      // Quota stops stay silent here so the duplicate response never differs.
      logger?.warn(
        { userId: existing.id, err: error instanceof Error ? error.message : 'unknown' },
        'auth.register: verification resend for pending account failed',
      );
    }
  };

  const syncProviderConfirmation = async (
    user: UserRecord,
    password: string,
  ) => {
    if (!emailVerificationGateway?.isEmailConfirmed) return user;
    try {
      const confirmed = await emailVerificationGateway.isEmailConfirmed({
        email: user.email,
        password,
      });
      if (!confirmed) return user;
      const verifiedUser = { ...user, emailVerified: true, updatedAt: now() };
      await userStore.saveUser(verifiedUser);
      return verifiedUser;
    } catch (error) {
      logger?.warn(
        { userId: user.id, err: error instanceof Error ? error.message : 'unknown' },
        'auth.login: provider confirmation check failed',
      );
      return user;
    }
  };

  const validatePresentedRefresh = async (
    session: SessionRecord,
    tokenHash: string,
  ) => {
    if (session.refreshTokenHash !== tokenHash) {
      if (
        session.previousRefreshTokenHash === tokenHash &&
        session.rotatedAt &&
        now().getTime() - session.rotatedAt.getTime() <=
          CONCURRENT_REFRESH_GRACE_MS
      ) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidRefreshToken,
          'Refresh token da duoc xu ly boi mot yeu cau dong thoi.',
          401,
        );
      }
      await sessionStore.revokeAllSessionsForUser(session.userId, now());
      throw new AppError(
        AUTH_ERROR_CODES.refreshTokenReuse,
        'Refresh token da bi tai su dung.',
        401,
      );
    }
  };

  return {
    async register(input: RegisterInput): Promise<RegisterResult> {
      const email = normalizeEmail(input.email);
      validateEmail(email);
      validatePassword(input.password);
      validatePhone(input.phone);

      // Hash before the existence check so a duplicate and a new registration
      // perform the same dominant CPU work. The duplicate path returns an
      // opaque transaction ID and never exposes the stored user ID.
      const passwordHash = await bcrypt.hash(input.password, 12);
      const existingUser = await userStore.findUserByEmail(email);
      if (existingUser) {
        await resendForPendingDuplicate(existingUser);
        return {
          userId: randomUUID(),
          message: GENERIC_VERIFICATION_MESSAGE,
          verificationStatus: 'pending' as const,
          ...buildVerificationWindow(),
        };
      }

      const timestamp = now();
      const user: UserRecord = {
        id: randomUUID(),
        email,
        passwordHash,
        displayName: input.displayName?.trim() || undefined,
        phone: input.phone?.trim() || undefined,
        authProvider: 'email',
        emailVerified: false,
        failedLoginAttempts: 0,
        createdAt: timestamp,
        updatedAt: timestamp,
        providerAccounts: {},
      };

      await userStore.saveUser(user);
      const persistedUser = await dispatchRegistrationVerification(
        user,
        input.password,
      );

      const verificationStatus = persistedUser.emailVerified
        ? ('verified' as const)
        : ('pending' as const);
      return {
        userId: user.id,
        message: persistedUser.emailVerified
          ? 'Verification temporarily bypassed. You can log in now.'
          : GENERIC_VERIFICATION_MESSAGE,
        verificationStatus,
        ...(verificationStatus === 'pending' ? buildVerificationWindow() : {}),
      };
    },

    async verifyEmail(input: VerifyEmailInput) {
      if (!emailVerificationGateway) {
        throw new AppError(
          AUTH_ERROR_CODES.verificationUnavailable,
          'Email verification gateway chua duoc cau hinh.',
          501,
        );
      }

      const { email } = await emailVerificationGateway.verifyEmailToken(input);
      const user = await userStore.findUserByEmail(email);

      if (!user) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidCredentials,
          'Nguoi dung khong ton tai.',
          404,
        );
      }

      const verifiedUser = {
        ...user,
        emailVerified: true,
        updatedAt: now(),
      };

      await userStore.saveUser(verifiedUser);

      const session = await buildSessionResult(verifiedUser, true);

      return {
        userId: user.id,
        email: user.email,
        message: 'Email verified',
        ...session,
      };
    },

    async resendVerification(input: ResendVerificationInput) {
      if (!emailVerificationGateway) {
        throw new AppError(
          AUTH_ERROR_CODES.verificationUnavailable,
          'Email verification gateway chua duoc cau hinh.',
          501,
        );
      }

      const email = normalizeEmail(input.email);
      validateEmail(email);
      const user = await userStore.findUserByEmail(email);

      if (user && !user.emailVerified) {
        try {
          await emailVerificationGateway.resendEmailVerification({ email });
        } catch (error) {
          if (isQuotaStop(error)) throw error;
          // Return the same generic contract as unknown/verified accounts.
          // The user can retry later without learning account state.
        }
      }

      return {
        message: GENERIC_VERIFICATION_MESSAGE,
        verificationStatus: 'pending' as const,
        ...buildVerificationWindow(),
      };
    },

    async markEmailVerified(userId: string) {
      const user = await userStore.findUserById(userId);
      if (!user) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidCredentials,
          'Nguoi dung khong ton tai.',
          404,
        );
      }

      await userStore.saveUser({
        ...user,
        emailVerified: true,
        updatedAt: now(),
      });
    },

    async login(input: LoginInput): Promise<AuthSessionResult> {
      const email = normalizeEmail(input.email);
      const user = await userStore.findUserByEmail(email);
      const currentTime = now();
      const passwordMatches = await bcrypt.compare(
        input.password,
        user?.passwordHash ?? DUMMY_PASSWORD_HASH,
      );

      if (!user?.passwordHash || !passwordMatches) {
        if (!user) {
          throw new AppError(
            AUTH_ERROR_CODES.invalidCredentials,
            'Email hoac mat khau khong dung.',
            401,
          );
        }
        const failedLoginAttempts = user.failedLoginAttempts + 1;
        const lockedUntil =
          failedLoginAttempts >= config.auth.maxLoginAttempts
            ? new Date(
                currentTime.getTime() + config.auth.lockoutMinutes * 60 * 1000,
              )
            : undefined;

        await userStore.saveUser({
          ...user,
          failedLoginAttempts,
          lockedUntil,
          updatedAt: currentTime,
        });

        throw new AppError(
          AUTH_ERROR_CODES.invalidCredentials,
          'Email hoac mat khau khong dung.',
          401,
        );
      }

      const checkedUser = user.emailVerified
        ? user
        : await syncProviderConfirmation(user, input.password);
      if (!checkedUser.emailVerified) {
        throw new AppError(
          AUTH_ERROR_CODES.emailUnverified,
          'Email chua duoc xac minh.',
          403,
        );
      }

      const updatedUser = {
        ...checkedUser,
        failedLoginAttempts: 0,
        lockedUntil: undefined,
        updatedAt: currentTime,
      };
      await userStore.saveUser(updatedUser);

      return buildSessionResult(updatedUser, Boolean(input.rememberMe), input);
    },

    async refresh(input: RefreshInput): Promise<AuthSessionResult> {
      const payload = parseRefreshToken(input.refreshToken);
      const session = await sessionStore.findSessionById(payload.sid);
      const presentedRefreshTokenHash = hashToken(input.refreshToken);

      if (!session || session.revokedAt || session.userId !== payload.sub) {
        throw new AppError(
          AUTH_ERROR_CODES.refreshTokenReuse,
          'Refresh token da bi thu hoi.',
          401,
        );
      }

      await validatePresentedRefresh(session, presentedRefreshTokenHash);

      if (session.expiresAt <= now()) {
        await sessionStore.revokeSession(session.id, now());
        throw new AppError(
          AUTH_ERROR_CODES.expiredRefreshToken,
          'Refresh token da het han.',
          401,
        );
      }

      const user = await userStore.findUserById(session.userId);

      if (!user) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidCredentials,
          'Nguoi dung khong ton tai.',
          404,
        );
      }

      return buildSessionResult(
        user,
        true,
        {
          deviceId: input.deviceId ?? session.deviceId,
          userAgent: input.userAgent ?? session.userAgent,
          ipAddress: input.ipAddress ?? session.ipAddress,
        },
        {
          currentSession: session,
          expectedRefreshTokenHash: presentedRefreshTokenHash,
        },
      );
    },

    async logout(input: LogoutInput) {
      const payload = parseRefreshToken(input.refreshToken, true);
      const session = await sessionStore.findSessionById(payload.sid);

      if (session) {
        await sessionStore.revokeAllSessionsForUser(session.userId, now());
        return;
      }

      await sessionStore.revokeSession(payload.sid, now());
    },

    async oauth(input: OAuthInput): Promise<AuthSessionResult> {
      if (input.provider !== 'google' && input.provider !== 'apple') {
        throw new AppError(
          AUTH_ERROR_CODES.unsupportedProvider,
          'Nha cung cap OAuth chua duoc ho tro.',
          400,
          'provider',
        );
      }

      if (!config.auth.socialLoginEnabled) {
        throw new AppError(
          AUTH_ERROR_CODES.providerDisabled,
          `Dang nhap bang ${input.provider} dang tam tat trong MVP hien tai.`,
          403,
          'provider',
        );
      }

      if (!oauthVerifier) {
        throw new AppError(
          AUTH_ERROR_CODES.oauthVerificationFailed,
          'OAuth verifier chua duoc cau hinh.',
          501,
        );
      }

      const identity = await oauthVerifier.verify(
        input.provider,
        input.credential,
        {
          accessToken: input.accessToken,
          nonce: input.nonce,
          redirectUri: input.redirectUri,
        },
      );
      const email = normalizeEmail(identity.email);
      validateEmail(email);

      const linkedUser = await userStore.findUserByProviderAccount(
        input.provider,
        identity.providerUserId,
      );
      const existingEmailUser = await userStore.findUserByEmail(email);

      if (
        existingEmailUser &&
        !linkedUser &&
        existingEmailUser.authProvider !== input.provider
      ) {
        throw new AppError(
          AUTH_ERROR_CODES.oauthConflict,
          'Email nay da duoc lien ket voi phuong thuc dang nhap khac.',
          409,
          'email',
        );
      }

      const timestamp = now();
      const nextUser =
        linkedUser ??
        existingEmailUser ??
        newOAuthUser(input.provider, input, identity, email, timestamp);

      const savedUser = linkOAuthUser(
        nextUser,
        input.provider,
        input,
        identity,
        timestamp,
      );

      await userStore.saveUser(savedUser);

      return buildSessionResult(savedUser, true, {
        deviceId: input.deviceId,
        userAgent: input.userAgent,
        ipAddress: input.ipAddress,
      });
    },

    async verifyAccessToken(accessToken: string) {
      try {
        const payload = verifyApplicationToken<AccessTokenPayload>(
          accessToken,
          'access',
        );

        if (payload.typ !== 'access' || !payload.sub || !payload.sid) {
          throw new AppError(
            AUTH_ERROR_CODES.unauthorized,
            'Access token khong hop le.',
            401,
          );
        }

        const session = await sessionStore.findSessionById(payload.sid);
        if (
          !session ||
          session.revokedAt ||
          session.userId !== payload.sub ||
          session.expiresAt <= now()
        ) {
          throw new AppError(
            AUTH_ERROR_CODES.unauthorized,
            'Phien dang nhap da het hieu luc.',
            401,
          );
        }

        return {
          userId: payload.sub,
          email: payload.email,
        };
      } catch (error) {
        if (error instanceof AppError) {
          throw error;
        }

        throw new AppError(
          AUTH_ERROR_CODES.unauthorized,
          'Ban can dang nhap de tiep tuc.',
          401,
        );
      }
    },
  };
};
