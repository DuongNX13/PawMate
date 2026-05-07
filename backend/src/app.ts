import Fastify, { type FastifyServerOptions } from 'fastify';
import { loadEnv, type AppConfig } from './config/env';
import { AppError } from './errors/app-error';
import { getPrismaClient } from './infrastructure/prisma';
import { getRedisClient } from './infrastructure/redis';
import { createSupabaseEmailVerificationGateway } from './integrations/supabase-auth-gateway';
import { createOAuthVerifier } from './integrations/oauth-verifier';
import { PrismaAuthUserStore } from './repositories/prisma-auth-user-store';
import { PrismaHealthRecordStore } from './repositories/prisma-health-record-store';
import { PrismaNotificationStore } from './repositories/prisma-notification-store';
import { PrismaPetStore } from './repositories/prisma-pet-store';
import { PrismaReminderStore } from './repositories/prisma-reminder-store';
import { PrismaReviewStore } from './repositories/prisma-review-store';
import { PrismaVetNearbyStore } from './repositories/prisma-vet-nearby-store';
import { RedisAuthSessionStore } from './repositories/redis-auth-session-store';
import authRoute from './routes/auth';
import healthRoute from './routes/health';
import notificationRoute from './routes/notifications';
import petRoute from './routes/pets';
import vetRoute from './routes/vets';
import webRoute from './routes/web';
import {
  createAuthService,
  type AuthService,
  type EmailVerificationDispatchResult,
  type OAuthIdentity,
} from './services/auth/auth-service';
import { createPetService, type PetService } from './services/pets/pet-service';
import {
  createHealthRecordService,
  type HealthRecordService,
} from './services/health/health-record-service';
import {
  createNotificationService,
  type NotificationService,
} from './services/notifications/notification-service';
import {
  createReminderService,
  type ReminderService,
} from './services/reminders/reminder-service';
import {
  createReviewService,
  type ReviewService,
} from './services/reviews/review-service';
import { createVetService, type VetService } from './services/vets/vet-service';

type AppDependencies = {
  config?: AppConfig;
  authService?: AuthService;
  healthRecordService?: HealthRecordService;
  reminderService?: ReminderService;
  notificationService?: NotificationService;
  petService?: PetService;
  vetService?: VetService;
  reviewService?: ReviewService;
  oauthVerifier?: {
    verify: (
      provider: 'google' | 'apple',
      credential: string,
      context?: {
        accessToken?: string;
        nonce?: string;
        redirectUri?: string;
      },
    ) => Promise<OAuthIdentity>;
  };
  emailVerificationGateway?: {
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
  };
};

export const buildApp = (
  options: FastifyServerOptions = {},
  dependencies: AppDependencies = {},
) => {
  const config = dependencies.config ?? loadEnv();
  const app = Fastify({
    logger: true,
    ...options,
  });
  const prisma =
    config.databaseUrl && !dependencies.authService && !dependencies.petService
      ? getPrismaClient(config.databaseUrl)
      : undefined;
  const redis =
    config.redisUrl && !dependencies.authService
      ? getRedisClient(config.redisUrl)
      : undefined;
  const emailVerificationGateway =
    dependencies.emailVerificationGateway ??
    createSupabaseEmailVerificationGateway(config);
  const oauthVerifier =
    dependencies.oauthVerifier ?? createOAuthVerifier(config);

  const authService =
    dependencies.authService ??
    createAuthService({
      config,
      userStore: prisma ? new PrismaAuthUserStore(prisma) : undefined,
      sessionStore: redis ? new RedisAuthSessionStore(redis) : undefined,
      oauthVerifier,
      emailVerificationGateway,
    });
  const petService =
    dependencies.petService ??
    createPetService(config, {
      store: prisma ? new PrismaPetStore(prisma) : undefined,
    });
  const healthRecordService =
    dependencies.healthRecordService ??
    createHealthRecordService({
      petReader: petService,
      store: prisma ? new PrismaHealthRecordStore(prisma) : undefined,
    });
  const notificationService =
    dependencies.notificationService ??
    createNotificationService({
      store: prisma ? new PrismaNotificationStore(prisma) : undefined,
    });
  const reminderService =
    dependencies.reminderService ??
    createReminderService({
      petReader: petService,
      notificationService,
      store: prisma ? new PrismaReminderStore(prisma) : undefined,
    });
  const vetService =
    dependencies.vetService ??
    createVetService({
      nearbyStore: prisma ? new PrismaVetNearbyStore(prisma) : undefined,
    });
  const reviewService =
    dependencies.reviewService ??
    createReviewService({
      vetReader: vetService,
      store: prisma ? new PrismaReviewStore(prisma) : undefined,
    });

  if (prisma) {
    app.addHook('onClose', async () => {
      await prisma.$disconnect();
    });
  }

  if (redis) {
    app.addHook('onClose', async () => {
      redis.disconnect();
    });
  }

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof AppError) {
      reply.status(error.statusCode).send({
        success: false,
        error: {
          code: error.code,
          message: error.message,
          ...(error.field ? { field: error.field } : {}),
        },
        requestId: request.id,
      });
      return;
    }

    request.log.error(error);
    reply.status(500).send({
      success: false,
      error: {
        code: 'SYS_001',
        message: 'Da co loi he thong. Vui long thu lai.',
      },
      requestId: request.id,
    });
  });

  app.register(healthRoute);
  app.register(authRoute, { authService });
  app.register(petRoute, {
    authService,
    petService,
    healthRecordService,
    reminderService,
  });
  app.register(notificationRoute, {
    authService,
    notificationService,
    reminderService,
  });
  app.register(vetRoute, { config, authService, vetService, reviewService });
  app.register(webRoute, { appName: config.appName });

  return app;
};
