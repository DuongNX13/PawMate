import {
  $Enums,
  PrismaClient,
} from '@prisma/client';

import {
  type AuthUserStore,
  type OAuthProvider,
  type UserRecord,
} from '../services/auth/auth-service';

const mapAuthProvider = (provider: $Enums.AuthProvider): UserRecord['authProvider'] =>
  provider;

const mapProviderAccounts = (user: {
  googleSub: string | null;
  appleSub: string | null;
}): UserRecord['providerAccounts'] => ({
  ...(user.googleSub ? { google: user.googleSub } : {}),
  ...(user.appleSub ? { apple: user.appleSub } : {}),
});

const mapUser = (user: {
  id: string;
  email: string;
  passwordHash: string | null;
  displayName: string | null;
  phone: string | null;
  authProvider: $Enums.AuthProvider;
  emailVerified: boolean;
  googleSub: string | null;
  appleSub: string | null;
  failedLoginAttempts: number;
  lockedUntil: Date | null;
  createdAt: Date;
  updatedAt: Date;
}) => ({
  id: user.id,
  email: user.email,
  passwordHash: user.passwordHash ?? undefined,
  displayName: user.displayName ?? undefined,
  phone: user.phone ?? undefined,
  authProvider: mapAuthProvider(user.authProvider),
  emailVerified: user.emailVerified,
  failedLoginAttempts: user.failedLoginAttempts,
  lockedUntil: user.lockedUntil ?? undefined,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
  providerAccounts: mapProviderAccounts(user),
});

export class PrismaAuthUserStore implements AuthUserStore {
  constructor(private readonly prisma: PrismaClient) {}

  async findUserByEmail(email: string) {
    const user = await this.prisma.user.findUnique({
      where: { email },
    });
    return user ? mapUser(user) : undefined;
  }

  async findUserById(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });
    return user ? mapUser(user) : undefined;
  }

  async findUserByProviderAccount(
    provider: OAuthProvider,
    providerUserId: string,
  ) {
    const user = await this.prisma.user.findFirst({
      where:
        provider === 'google'
          ? { googleSub: providerUserId }
          : { appleSub: providerUserId },
    });

    return user ? mapUser(user) : undefined;
  }

  async saveUser(user: UserRecord) {
    await this.prisma.user.upsert({
      where: { id: user.id },
      update: {
        email: user.email,
        passwordHash: user.passwordHash,
        displayName: user.displayName,
        phone: user.phone,
        authProvider: user.authProvider as $Enums.AuthProvider,
        emailVerified: user.emailVerified,
        googleSub: user.providerAccounts.google,
        appleSub: user.providerAccounts.apple,
        failedLoginAttempts: user.failedLoginAttempts,
        lockedUntil: user.lockedUntil,
      },
      create: {
        id: user.id,
        email: user.email,
        passwordHash: user.passwordHash,
        displayName: user.displayName,
        phone: user.phone,
        authProvider: user.authProvider as $Enums.AuthProvider,
        emailVerified: user.emailVerified,
        googleSub: user.providerAccounts.google,
        appleSub: user.providerAccounts.apple,
        failedLoginAttempts: user.failedLoginAttempts,
        lockedUntil: user.lockedUntil,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
    });
  }

  async deleteUserById(userId: string) {
    await this.prisma.user.deleteMany({
      where: { id: userId },
    });
  }
}
