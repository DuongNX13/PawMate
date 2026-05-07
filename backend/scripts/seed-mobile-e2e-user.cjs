const path = require('node:path');
const { randomUUID } = require('node:crypto');
const bcrypt = require('bcryptjs');
const dotenv = require('dotenv');
const { PrismaClient } = require('@prisma/client');

const backendRoot = path.resolve(__dirname, '..');

dotenv.config({ path: path.join(backendRoot, '.env'), override: false });
dotenv.config({ path: path.join(backendRoot, '.env.local'), override: true });

const email = process.env.PAWMATE_E2E_EMAIL ?? 'mobile-e2e-owner@pawmate.test';
const password = process.env.PAWMATE_E2E_PASSWORD ?? 'Pawmate123';

const main = async () => {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required to seed the mobile E2E user.');
  }

  const prisma = new PrismaClient({
    datasources: {
      db: {
        url: process.env.DATABASE_URL,
      },
    },
  });

  try {
    const passwordHash = await bcrypt.hash(password, 12);
    const now = new Date();
    const user = await prisma.user.upsert({
      where: { email },
      update: {
        passwordHash,
        displayName: 'Mobile E2E Owner',
        authProvider: 'email',
        emailVerified: true,
        failedLoginAttempts: 0,
        lockedUntil: null,
        deletedAt: null,
        updatedAt: now,
      },
      create: {
        id: randomUUID(),
        email,
        passwordHash,
        displayName: 'Mobile E2E Owner',
        authProvider: 'email',
        emailVerified: true,
        failedLoginAttempts: 0,
        createdAt: now,
        updatedAt: now,
      },
      select: {
        id: true,
        email: true,
        emailVerified: true,
      },
    });

    console.log(
      JSON.stringify({
        status: 'ok',
        userId: user.id,
        email: user.email,
        emailVerified: user.emailVerified,
      }),
    );
  } finally {
    await prisma.$disconnect();
  }
};

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
