import { createHash, randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import jwt, {
  JsonWebTokenError,
  TokenExpiredError,
  type JwtPayload,
} from 'jsonwebtoken';

import { type AppConfig } from '../../config/env';
import { AppError } from '../../errors/app-error';
import { AUTH_ERROR_CODES } from '../../errors/error-codes';

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
  saveSession: (session: SessionRecord) => Promise<void>;
  revokeSession: (sessionId: string, revokedAt: Date) => Promise<void>;
  revokeAllSessionsForUser: (userId: string, revokedAt: Date) => Promise<void>;
};

type AccessTokenPayload = JwtPayload & {
  typ: 'access';
  sub: string;
  email: string;
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
};

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const passwordHasLetter = /[A-Za-z]/;
const passwordHasNumber = /[0-9]/;

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

    async saveSession(session: SessionRecord) {
      sessions.set(session.id, session);
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
      const activeSessions = [...sessions.values()].filter(
        (session) => session.userId === userId && !session.revokedAt,
      );

      await Promise.all(
        activeSessions.map((session) =>
          Promise.resolve(
            sessions.set(session.id, {
              ...session,
              revokedAt,
            }),
          ),
        ),
      );
    },
  };
};

const normalizeEmail = (value: string) => value.trim().toLowerCase();
const hashToken = (value: string) =>
  createHash('sha256').update(value).digest('hex');

const sanitizeUser = (user: UserRecord) => ({
  id: user.id,
  email: user.email,
  authProvider: user.authProvider,
  emailVerified: user.emailVerified,
  displayName: user.displayName,
  phone: user.phone,
});

export const createAuthService = ({
  config,
  now = () => new Date(),
  userStore = createInMemoryAuthUserStore(),
  sessionStore = createInMemoryAuthSessionStore(),
  emailVerificationGateway,
  oauthVerifier,
}: AuthServiceDependencies) => {
  const validateEmail = (email: string) => {
    if (!emailRegex.test(email)) {
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

  const enforceSessionLimit = async (userId: string, issuedAt: Date) => {
    const activeSessions = await sessionStore.listActiveSessionsByUser(userId);
    if (activeSessions.length < config.auth.maxActiveSessions) {
      return;
    }

    const sessionsToRevoke =
      activeSessions.length - config.auth.maxActiveSessions + 1;

    await Promise.all(
      activeSessions
        .slice(0, sessionsToRevoke)
        .map((session) => sessionStore.revokeSession(session.id, issuedAt)),
    );
  };

  const buildSessionResult = async (
    user: UserRecord,
    rememberMe: boolean,
    metadata?: Pick<LoginInput, 'deviceId' | 'userAgent' | 'ipAddress'>,
    sessionId: string = randomUUID(),
  ): Promise<AuthSessionResult> => {
    const issuedAt = now();
    const accessTokenExpiresAt = new Date(
      issuedAt.getTime() + config.auth.accessTokenTtlMinutes * 60 * 1000,
    );
    const refreshDays = rememberMe
      ? config.auth.refreshTokenTtlDays
      : Math.min(7, config.auth.refreshTokenTtlDays);
    const refreshTokenExpiresAt = new Date(
      issuedAt.getTime() + refreshDays * 24 * 60 * 60 * 1000,
    );

    await enforceSessionLimit(user.id, issuedAt);

    const accessToken = jwt.sign(
      {
        typ: 'access',
        email: user.email,
        jti: randomUUID(),
      },
      config.auth.accessTokenSecret,
      {
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
        subject: user.id,
        expiresIn: `${refreshDays}d`,
      },
    );

    await sessionStore.saveSession({
      id: sessionId,
      userId: user.id,
      refreshTokenHash: hashToken(refreshToken),
      deviceId: metadata?.deviceId,
      userAgent: metadata?.userAgent,
      ipAddress: metadata?.ipAddress,
      expiresAt: refreshTokenExpiresAt,
      createdAt: issuedAt,
    });

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
      const payload = jwt.verify(refreshToken, config.auth.refreshTokenSecret, {
        ignoreExpiration: allowExpired,
      }) as RefreshTokenPayload;

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

  return {
    async register(input: RegisterInput): Promise<RegisterResult> {
      const email = normalizeEmail(input.email);
      validateEmail(email);
      validatePassword(input.password);

      if (await userStore.findUserByEmail(email)) {
        throw new AppError(
          AUTH_ERROR_CODES.duplicateEmail,
          'Email nay da duoc dang ky.',
          409,
          'email',
        );
      }

      const timestamp = now();
      const user: UserRecord = {
        id: randomUUID(),
        email,
        passwordHash: await bcrypt.hash(input.password, 12),
        displayName: input.displayName?.trim() || undefined,
        phone: input.phone?.trim() || undefined,
        authProvider: 'email',
        emailVerified: false,
        failedLoginAttempts: 0,
        createdAt: timestamp,
        updatedAt: timestamp,
        providerAccounts: {},
      };

      let persistedUser = user;
      await userStore.saveUser(persistedUser);
      try {
        const verificationResult =
          (await emailVerificationGateway?.sendEmailVerification({
            id: user.id,
            email: user.email,
            displayName: user.displayName,
            password: input.password,
          })) ?? {
            status: 'verification-email-sent' as const,
          };

        if (verificationResult.status === 'auto-verified') {
          persistedUser = {
            ...user,
            emailVerified: true,
            updatedAt: now(),
          };
          await userStore.saveUser(persistedUser);
        }
      } catch (error) {
        await userStore.deleteUserById(user.id);
        throw error;
      }

      return {
        userId: user.id,
        message:
          persistedUser.emailVerified
            ? 'Verification temporarily bypassed. You can log in now.'
            : 'Check your email',
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

      await userStore.saveUser({
        ...user,
        emailVerified: true,
        updatedAt: now(),
      });

      return {
        userId: user.id,
        email: user.email,
        message: 'Email verified',
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

      if (!user) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidCredentials,
          'Nguoi dung khong ton tai.',
          404,
          'email',
        );
      }

      if (user.emailVerified) {
        return {
          message: 'Email already verified',
        };
      }

      await emailVerificationGateway.resendEmailVerification({ email });

      return {
        message: 'Verification email resent',
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

      if (!user?.passwordHash) {
        throw new AppError(
          AUTH_ERROR_CODES.invalidCredentials,
          'Email hoac mat khau khong dung.',
          401,
        );
      }

      const currentTime = now();

      if (user.lockedUntil && user.lockedUntil > currentTime) {
        throw new AppError(
          AUTH_ERROR_CODES.accountLocked,
          'Tai khoan tam thoi bi khoa. Vui long thu lai sau.',
          423,
        );
      }

      if (!user.emailVerified) {
        throw new AppError(
          AUTH_ERROR_CODES.emailUnverified,
          'Email chua duoc xac minh.',
          403,
        );
      }

      const passwordMatches = await bcrypt.compare(
        input.password,
        user.passwordHash,
      );

      if (!passwordMatches) {
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

        if (lockedUntil) {
          throw new AppError(
            AUTH_ERROR_CODES.accountLocked,
            'Tai khoan tam thoi bi khoa. Vui long thu lai sau.',
            423,
          );
        }

        throw new AppError(
          AUTH_ERROR_CODES.invalidCredentials,
          'Email hoac mat khau khong dung.',
          401,
        );
      }

      const updatedUser = {
        ...user,
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

      if (!session || session.revokedAt) {
        throw new AppError(
          AUTH_ERROR_CODES.refreshTokenReuse,
          'Refresh token da bi thu hoi.',
          401,
        );
      }

      if (session.refreshTokenHash !== hashToken(input.refreshToken)) {
        await sessionStore.revokeAllSessionsForUser(session.userId, now());
        throw new AppError(
          AUTH_ERROR_CODES.refreshTokenReuse,
          'Refresh token da bi tai su dung.',
          401,
        );
      }

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
        session.id,
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
        existingEmailUser ?? {
          id: randomUUID(),
          email,
          displayName:
            input.displayName?.trim() ||
            identity.displayName?.trim() ||
            undefined,
          phone: undefined,
          authProvider: input.provider,
          emailVerified: true,
          failedLoginAttempts: 0,
          createdAt: timestamp,
          updatedAt: timestamp,
          providerAccounts: {},
        };

      const savedUser: UserRecord = {
        ...nextUser,
        authProvider:
          nextUser.authProvider === 'email'
            ? input.provider
            : nextUser.authProvider,
        emailVerified: true,
        displayName:
          nextUser.displayName ||
          input.displayName?.trim() ||
          identity.displayName?.trim() ||
          undefined,
        providerAccounts: {
          ...nextUser.providerAccounts,
          [input.provider]: identity.providerUserId,
        },
        updatedAt: timestamp,
      };

      await userStore.saveUser(savedUser);

      return buildSessionResult(savedUser, true, {
        deviceId: input.deviceId,
        userAgent: input.userAgent,
        ipAddress: input.ipAddress,
      });
    },

    verifyAccessToken(accessToken: string) {
      try {
        const payload = jwt.verify(
          accessToken,
          config.auth.accessTokenSecret,
        ) as AccessTokenPayload;

        if (payload.typ !== 'access' || !payload.sub) {
          throw new AppError(
            AUTH_ERROR_CODES.unauthorized,
            'Access token khong hop le.',
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
