import { PrismaClient } from '@prisma/client';
import Redis from 'ioredis';

import { buildApp } from '../src/app';
import { loadEnv } from '../src/config/env';

const buildConfig = () => {
  const env = loadEnv();

  return {
    ...env,
    databaseUrl:
      env.databaseUrl ?? 'postgresql://pawmate@127.0.0.1:5432/pawmate',
    redisUrl: env.redisUrl ?? 'redis://127.0.0.1:6379',
  };
};

const smoke = async () => {
  const config = buildConfig();
  const prisma = new PrismaClient({
    datasources: {
      db: {
        url: config.databaseUrl,
      },
    },
  });
  const redis = new Redis(config.redisUrl!, { maxRetriesPerRequest: 1 });
  const smokeEmail = 'runtime-check@pawmate.vn';
  const app = buildApp(
    { logger: false },
    {
      config,
      emailVerificationGateway: {
        sendEmailVerification: async () => ({
          status: 'verification-email-sent' as const,
        }),
        verifyEmailToken: async () => ({ email: smokeEmail }),
        resendEmailVerification: async () => undefined,
      },
    },
  );

  const cleanup = async () => {
    await prisma.pet.deleteMany({ where: { user: { email: smokeEmail } } });
    await prisma.user.deleteMany({ where: { email: smokeEmail } });
    const sessionKeys = await redis.keys('auth:session:*');
    const userSessionKeys = await redis.keys('auth:user-sessions:*');
    if (sessionKeys.length > 0) {
      await redis.del(sessionKeys);
    }
    if (userSessionKeys.length > 0) {
      await redis.del(userSessionKeys);
    }
  };

  try {
    await cleanup();
    await app.ready();

    const registerResponse = await app.inject({
      method: 'POST',
      url: '/auth/register',
      payload: {
        email: smokeEmail,
        password: 'Pawmate123',
      },
    });
    const registerPayload = registerResponse.json();

    await prisma.user.update({
      where: { id: registerPayload.userId },
      data: { emailVerified: true },
    });

    const loginResponse = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: smokeEmail,
        password: 'Pawmate123',
        rememberMe: true,
        deviceId: 'runtime-device-1',
      },
    });
    const loginPayload = loginResponse.json();

    const createPetResponse = await app.inject({
      method: 'POST',
      url: '/pets',
      headers: {
        authorization: `Bearer ${loginPayload.accessToken}`,
      },
      payload: {
        name: 'Runtime Milo',
        species: 'dog',
        gender: 'male',
        weight: 8.2,
        healthStatus: 'healthy',
      },
    });
    const petPayload = createPetResponse.json();

    const user = await prisma.user.findUnique({
      where: { email: smokeEmail },
    });
    const pet = await prisma.pet.findUnique({
      where: { id: petPayload.data.id },
    });
    const redisSessionKeys = await redis.keys('auth:session:*');

    console.log(
      JSON.stringify(
        {
          registerStatus: registerResponse.statusCode,
          loginStatus: loginResponse.statusCode,
          createPetStatus: createPetResponse.statusCode,
          persistedUserId: user?.id,
          persistedPetId: pet?.id,
          persistedPetSpecies: pet?.species,
          redisSessionCount: redisSessionKeys.length,
        },
        null,
        2,
      ),
    );
  } finally {
    await app.close();
    await cleanup();
    await prisma.$disconnect();
    redis.disconnect();
  }
};

smoke().catch((error) => {
  console.error(error);
  process.exit(1);
});
