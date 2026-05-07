import { type PrismaClient } from '@prisma/client';
import { type Redis } from 'ioredis';

import { PrismaAuthUserStore } from '../src/repositories/prisma-auth-user-store';
import { PrismaPetStore } from '../src/repositories/prisma-pet-store';
import { RedisAuthSessionStore } from '../src/repositories/redis-auth-session-store';
import { type SessionRecord, type UserRecord } from '../src/services/auth/auth-service';
import { type PetRecord } from '../src/services/pets/pet-service';

type PrismaUserDelegateMock = {
  findUnique: jest.Mock;
  findFirst: jest.Mock;
  upsert: jest.Mock;
};

type PrismaPetDelegateMock = {
  findMany: jest.Mock;
  findUnique: jest.Mock;
  upsert: jest.Mock;
  findFirst: jest.Mock;
};

type RedisPipelineMock = {
  set: jest.Mock;
  zadd: jest.Mock;
  pexpire: jest.Mock;
  exec: jest.Mock;
};

type RedisMock = {
  zrange: jest.Mock;
  mget: jest.Mock;
  get: jest.Mock;
  multi: jest.Mock<RedisPipelineMock, []>;
};

const createUser = (): UserRecord => ({
  id: 'user-1',
  email: 'user@pawmate.vn',
  passwordHash: 'hash',
  displayName: 'Paw Mate',
  phone: '0909000999',
  authProvider: 'google',
  emailVerified: true,
  failedLoginAttempts: 2,
  lockedUntil: new Date('2026-04-08T10:15:00.000Z'),
  createdAt: new Date('2026-04-08T09:00:00.000Z'),
  updatedAt: new Date('2026-04-08T09:30:00.000Z'),
  providerAccounts: {
    google: 'google-sub',
  },
});

const createPet = (): PetRecord => ({
  id: 'pet-1',
  userId: 'user-1',
  name: 'Milo',
  species: 'dog',
  breed: 'Poodle',
  gender: 'male',
  dob: '2023-01-02',
  weight: 4.2,
  color: 'cream',
  microchip: 'MC-001',
  isNeutered: true,
  avatarUrl: 'http://localhost:3000/assets/pet-photos/pet-1/milo.png',
  healthStatus: 'healthy',
  createdAt: '2026-04-08T09:00:00.000Z',
  updatedAt: '2026-04-08T09:30:00.000Z',
});

describe('PrismaAuthUserStore', () => {
  it('maps user queries and persists provider fields', async () => {
    const user = createUser();
    const prisma = {
      user: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce({
            id: user.id,
            email: user.email,
            passwordHash: user.passwordHash,
            displayName: user.displayName,
            phone: user.phone,
            authProvider: user.authProvider,
            emailVerified: user.emailVerified,
            googleSub: 'google-sub',
            appleSub: null,
            failedLoginAttempts: user.failedLoginAttempts,
            lockedUntil: user.lockedUntil,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
          })
          .mockResolvedValueOnce({
            id: user.id,
            email: user.email,
            passwordHash: user.passwordHash,
            displayName: user.displayName,
            phone: user.phone,
            authProvider: user.authProvider,
            emailVerified: user.emailVerified,
            googleSub: 'google-sub',
            appleSub: null,
            failedLoginAttempts: user.failedLoginAttempts,
            lockedUntil: user.lockedUntil,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
          }),
        findFirst: jest.fn().mockResolvedValue({
          id: user.id,
          email: user.email,
          passwordHash: user.passwordHash,
          displayName: user.displayName,
          phone: user.phone,
          authProvider: user.authProvider,
          emailVerified: user.emailVerified,
          googleSub: 'google-sub',
          appleSub: null,
          failedLoginAttempts: user.failedLoginAttempts,
          lockedUntil: user.lockedUntil,
          createdAt: user.createdAt,
          updatedAt: user.updatedAt,
        }),
        upsert: jest.fn(),
      },
    } as unknown as {
      user: PrismaUserDelegateMock;
    };

    const store = new PrismaAuthUserStore(prisma as unknown as PrismaClient);

    await expect(store.findUserByEmail(user.email)).resolves.toMatchObject({
      email: user.email,
      providerAccounts: { google: 'google-sub' },
    });
    await expect(store.findUserById(user.id)).resolves.toMatchObject({
      id: user.id,
    });
    await expect(
      store.findUserByProviderAccount('google', 'google-sub'),
    ).resolves.toMatchObject({
      email: user.email,
    });

    await store.saveUser(user);

    expect(prisma.user.upsert).toHaveBeenCalledWith({
      where: { id: user.id },
      update: expect.objectContaining({
        email: user.email,
        googleSub: 'google-sub',
        appleSub: undefined,
        failedLoginAttempts: 2,
      }),
      create: expect.objectContaining({
        id: user.id,
        email: user.email,
        googleSub: 'google-sub',
      }),
    });
  });
});

describe('PrismaPetStore', () => {
  it('maps pet records and persists date or decimal fields', async () => {
    const pet = createPet();
    const prisma = {
      pet: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: pet.id,
            userId: pet.userId,
            name: pet.name,
            species: pet.species,
            breed: pet.breed,
            gender: pet.gender,
            dob: new Date(`${pet.dob}T00:00:00.000Z`),
            weightKg: { toNumber: () => 4.2 },
            color: pet.color,
            microchipNumber: pet.microchip,
            isNeutered: pet.isNeutered,
            avatarUrl: pet.avatarUrl,
            healthStatus: pet.healthStatus,
            createdAt: new Date(pet.createdAt),
            updatedAt: new Date(pet.updatedAt),
            deletedAt: null,
          },
        ]),
        findUnique: jest.fn().mockResolvedValue({
          id: pet.id,
          userId: pet.userId,
          name: pet.name,
          species: pet.species,
          breed: pet.breed,
          gender: pet.gender,
          dob: new Date(`${pet.dob}T00:00:00.000Z`),
          weightKg: { toNumber: () => 4.2 },
          color: pet.color,
          microchipNumber: pet.microchip,
          isNeutered: pet.isNeutered,
          avatarUrl: pet.avatarUrl,
          healthStatus: pet.healthStatus,
          createdAt: new Date(pet.createdAt),
          updatedAt: new Date(pet.updatedAt),
          deletedAt: null,
        }),
        upsert: jest.fn(),
        findFirst: jest.fn().mockResolvedValue({ id: pet.id }),
      },
    } as unknown as {
      pet: PrismaPetDelegateMock;
    };

    const store = new PrismaPetStore(prisma as unknown as PrismaClient);

    await expect(store.listByUser(pet.userId)).resolves.toEqual([pet]);
    await expect(store.findById(pet.id)).resolves.toEqual(pet);
    await expect(
      store.hasMicrochipConflict(pet.userId, pet.microchip ?? ''),
    ).resolves.toBe(true);

    prisma.pet.findFirst.mockResolvedValueOnce(null);
    await expect(
      store.hasMicrochipConflict(pet.userId, pet.microchip ?? '', pet.id),
    ).resolves.toBe(false);

    await store.save(pet);

    expect(prisma.pet.upsert).toHaveBeenCalledWith({
      where: { id: pet.id },
      update: expect.objectContaining({
        userId: pet.userId,
        dob: new Date(`${pet.dob}T00:00:00.000Z`),
        weightKg: pet.weight,
      }),
      create: expect.objectContaining({
        id: pet.id,
        createdAt: new Date(pet.createdAt),
        updatedAt: new Date(pet.updatedAt),
      }),
    });
  });
});

describe('RedisAuthSessionStore', () => {
  it('serializes sessions, lists active ones, and revokes them', async () => {
    const storedValues = new Map<string, string>();
    const orderedSessionIds = ['session-2', 'session-1'];
    const redis: RedisMock = {
      zrange: jest.fn().mockResolvedValue(orderedSessionIds),
      mget: jest.fn().mockImplementation(async (keys: string[]) =>
        keys.map((key) => storedValues.get(key) ?? null),
      ),
      get: jest.fn().mockImplementation(async (key: string) => storedValues.get(key) ?? null),
      multi: jest.fn().mockImplementation(() => {
        const pipeline: RedisPipelineMock = {
          set: jest.fn().mockImplementation((key: string, value: string) => {
            storedValues.set(key, value);
            return pipeline;
          }),
          zadd: jest.fn().mockImplementation(() => pipeline),
          pexpire: jest.fn().mockImplementation(() => pipeline),
          exec: jest.fn().mockResolvedValue([]),
        };
        return pipeline;
      }),
    };

    const store = new RedisAuthSessionStore(redis as unknown as Redis);
    const sessionA: SessionRecord = {
      id: 'session-1',
      userId: 'user-1',
      refreshTokenHash: 'hash-a',
      expiresAt: new Date(Date.now() + 60_000),
      createdAt: new Date('2026-04-08T10:00:00.000Z'),
    };
    const sessionB: SessionRecord = {
      id: 'session-2',
      userId: 'user-1',
      refreshTokenHash: 'hash-b',
      expiresAt: new Date(Date.now() + 60_000),
      createdAt: new Date('2026-04-08T09:00:00.000Z'),
      revokedAt: new Date('2026-04-08T09:30:00.000Z'),
    };

    await store.saveSession(sessionA);
    await store.saveSession(sessionB);

    await expect(store.findSessionById(sessionA.id)).resolves.toMatchObject({
      id: sessionA.id,
      userId: sessionA.userId,
    });
    await expect(store.listActiveSessionsByUser('user-1')).resolves.toEqual([
      expect.objectContaining({ id: 'session-1' }),
    ]);

    await store.revokeSession('session-1', new Date('2026-04-08T10:30:00.000Z'));
    await expect(store.findSessionById('session-1')).resolves.toMatchObject({
      revokedAt: new Date('2026-04-08T10:30:00.000Z'),
    });

    await store.revokeAllSessionsForUser(
      'user-1',
      new Date('2026-04-08T11:00:00.000Z'),
    );

    expect(redis.multi).toHaveBeenCalled();
  });
});
