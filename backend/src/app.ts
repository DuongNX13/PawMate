import Fastify, { type FastifyServerOptions } from 'fastify';
import {
  loadEnv,
  resolveAppFeatureAvailability,
  validateAppConfig,
  type AppConfig,
} from './config/env';
import { AppError } from './errors/app-error';
import { getPrismaClient } from './infrastructure/prisma';
import { getRedisClient } from './infrastructure/redis';
import {
  createSupabaseRescueMediaStorage,
  type RescueMediaStorage,
} from './infrastructure/rescue-media-storage';
import { PrismaAdoptionRepository } from './features/adoption/persistence/prisma-adoption-repository';
import { PrismaChatRepository } from './features/chat/persistence/prisma-chat-repository';
import { PrismaRescueRepository } from './features/rescue/persistence/prisma-rescue-repository';
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
import {
  createActionQuotaGuard,
  createNoopActionQuotaGuard,
  type ActionQuotaGuard,
} from './security/distributed-action-quota';
import { createBoundedOAuthVerifier } from './security/bounded-provider-operation';
import { createQuotaProtectedEmailVerificationGateway } from './security/quota-email-verification-gateway';
import { RedisActionQuotaStore } from './security/redis-action-quota-store';
import adoptionChatRoute from './routes/adoption-chat';
import adoptionRoute from './routes/adoption';
import authRoute from './routes/auth';
import healthRoute, { type ReadinessCheck } from './routes/health';
import notificationRoute from './routes/notifications';
import petRoute from './routes/pets';
import preferenceRoute from './routes/preferences';
import rescueRoute from './routes/rescue';
import vetRoute from './routes/vets';
import webRoute from './routes/web';
import {
  createAdoptionChatService,
  type AdoptionChatService,
} from './services/adoption/adoption-chat-service';
import {
  createAdoptionService,
  type AdoptionService,
} from './services/adoption/adoption-service';
import {
  createAuthService,
  type AuthService,
  type EmailVerificationDispatchResult,
  type OAuthIdentity,
} from './services/auth/auth-service';
import { createPetService, type PetService } from './services/pets/pet-service';
import {
  createPreferenceService,
  type PreferenceService,
} from './services/preferences/preference-service';
import { PrismaPreferenceRepository } from './features/preferences/persistence/prisma-preference-repository';
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
import {
  createRescueMediaService,
  type RescueMediaService,
} from './services/rescue/rescue-media-service';
import {
  createRescueReadService,
  type RescueReadService,
} from './services/rescue/rescue-read-service';
import {
  createRescueWriteService,
  type RescueWriteService,
} from './services/rescue/rescue-write-service';
import { createVetService, type VetService } from './services/vets/vet-service';

export type AppDependencies = {
  config?: AppConfig;
  authService?: AuthService;
  adoptionChatService?: AdoptionChatService;
  adoptionService?: AdoptionService;
  healthRecordService?: HealthRecordService;
  reminderService?: ReminderService;
  notificationService?: NotificationService;
  petService?: PetService;
  preferenceService?: PreferenceService;
  rescueMediaStorage?: RescueMediaStorage;
  rescueMediaService?: RescueMediaService;
  rescueReadService?: RescueReadService;
  rescueWriteService?: RescueWriteService;
  vetService?: VetService;
  reviewService?: ReviewService;
  readinessChecks?: ReadinessCheck[];
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
  actionQuotaGuard?: ActionQuotaGuard;
};

const needsPrimaryPersistence = (dependencies: AppDependencies) =>
  !dependencies.authService ||
  !dependencies.petService ||
  !dependencies.healthRecordService ||
  !dependencies.reminderService ||
  !dependencies.notificationService ||
  !dependencies.vetService ||
  !dependencies.reviewService;

const needsFeaturePersistence = (dependencies: AppDependencies) =>
  !dependencies.rescueReadService ||
  !dependencies.rescueWriteService ||
  !dependencies.rescueMediaService ||
  !dependencies.adoptionService ||
  !dependencies.adoptionChatService ||
  !dependencies.preferenceService;

const resolvePrisma = (config: AppConfig, dependencies: AppDependencies) =>
  config.databaseUrl &&
  (config.nodeEnv === 'production' ||
    needsPrimaryPersistence(dependencies) ||
    needsFeaturePersistence(dependencies))
    ? getPrismaClient(config.databaseUrl)
    : undefined;

const createServer = (config: AppConfig, options: FastifyServerOptions) =>
  Fastify({
    ...options,
    logger: options.logger ?? true,
    bodyLimit: options.bodyLimit ?? 1024 * 1024,
    requestTimeout: options.requestTimeout ?? 15_000,
    trustProxy:
      config.trustedProxyCidrs && config.trustedProxyCidrs.length > 0
        ? config.trustedProxyCidrs
        : false,
  });

const appErrorResponse = (error: AppError, requestId: string) => ({
  success: false,
  error: {
    code: error.code,
    message: error.message,
    ...(error.field ? { field: error.field } : {}),
  },
  requestId,
});

export const buildApp = (
  options: FastifyServerOptions = {},
  dependencies: AppDependencies = {},
) => {
  const config = validateAppConfig(dependencies.config ?? loadEnv());
  const featureAvailability = resolveAppFeatureAvailability(config);
  const app = createServer(config, options);
  const prisma = resolvePrisma(config, dependencies);
  const redis =
    config.redisUrl &&
    (config.nodeEnv === 'production' || !dependencies.authService)
      ? getRedisClient(config.redisUrl)
      : undefined;
  const resolveActionQuotaGuard = () => {
    const actionQuotaGuard =
      dependencies.actionQuotaGuard ??
      (redis
        ? createActionQuotaGuard({
            store: new RedisActionQuotaStore(redis),
            secret: config.auth.accessTokenSecret,
            onBudgetWarning: ({ action, thresholdPercent }) => {
              app.log.warn({
                event: 'quota_budget_threshold_crossed',
                action,
                thresholdPercent,
              });
            },
          })
        : createNoopActionQuotaGuard());
    return actionQuotaGuard;
  };
  const actionQuotaGuard = resolveActionQuotaGuard();
  const resolveAuthService = () => {
    const rawEmailVerificationGateway =
      dependencies.emailVerificationGateway ??
      createSupabaseEmailVerificationGateway(config);
    const emailVerificationGateway = rawEmailVerificationGateway
      ? createQuotaProtectedEmailVerificationGateway(
          rawEmailVerificationGateway,
          actionQuotaGuard,
        )
      : undefined;
    const rawOAuthVerifier =
      dependencies.oauthVerifier ?? createOAuthVerifier(config);
    const oauthVerifier = rawOAuthVerifier
      ? createBoundedOAuthVerifier(rawOAuthVerifier)
      : undefined;

    const authService =
      dependencies.authService ??
      createAuthService({
        config,
        userStore: prisma ? new PrismaAuthUserStore(prisma) : undefined,
        sessionStore: redis ? new RedisAuthSessionStore(redis) : undefined,
        oauthVerifier,
        emailVerificationGateway,
        logger: app.log,
      });
    return authService;
  };
  const authService = resolveAuthService();
  const resolvePetAndHealth = () => {
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
    return { petService, healthRecordService };
  };
  const { petService, healthRecordService } = resolvePetAndHealth();
  const resolveCareServices = () => {
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
    return { notificationService, reminderService, vetService, reviewService };
  };
  const { notificationService, reminderService, vetService, reviewService } =
    resolveCareServices();
  const resolveRescueServices = () => {
    const rescueRepository = prisma
      ? new PrismaRescueRepository(prisma)
      : undefined;
    const rescueReadService =
      dependencies.rescueReadService ??
      createRescueReadService({
        repository: rescueRepository,
      });
    const rescueWriteService =
      dependencies.rescueWriteService ??
      createRescueWriteService({ repository: rescueRepository });
    const mediaStorage =
      dependencies.rescueMediaStorage ??
      createSupabaseRescueMediaStorage(config);
    const chatRepository = prisma
      ? new PrismaChatRepository(prisma)
      : undefined;
    const rescueMediaService =
      dependencies.rescueMediaService ??
      createRescueMediaService({
        repository: rescueRepository,
        chatRepository,
        storage: mediaStorage,
        featureAvailability,
      });
    return {
      rescueReadService,
      rescueWriteService,
      rescueMediaService,
      mediaStorage,
      chatRepository,
    };
  };
  const {
    rescueReadService,
    rescueWriteService,
    rescueMediaService,
    mediaStorage,
    chatRepository,
  } = resolveRescueServices();
  const resolveAdoptionAndPreferences = () => {
    const adoptionService =
      dependencies.adoptionService ??
      createAdoptionService({
        repository: prisma ? new PrismaAdoptionRepository(prisma) : undefined,
      });
    const adoptionChatService =
      dependencies.adoptionChatService ??
      createAdoptionChatService({
        repository: chatRepository,
        storage: mediaStorage,
      });
    const preferenceService =
      dependencies.preferenceService ??
      createPreferenceService({
        repository: prisma ? new PrismaPreferenceRepository(prisma) : undefined,
      });
    return { adoptionService, adoptionChatService, preferenceService };
  };
  const { adoptionService, adoptionChatService, preferenceService } =
    resolveAdoptionAndPreferences();
  const resolveReadinessChecks = () => {
    const readinessChecks: ReadinessCheck[] = dependencies.readinessChecks ?? [
      ...(prisma
        ? [
            {
              name: 'database',
              check: async () => {
                await prisma.$queryRawUnsafe('SELECT 1');
                return true;
              },
            },
          ]
        : []),
      ...(redis
        ? [
            {
              name: 'redis',
              check: async () => {
                if (redis.status === 'wait') await redis.connect();
                return (await redis.ping()) === 'PONG';
              },
            },
          ]
        : []),
    ];
    return readinessChecks;
  };
  const readinessChecks = resolveReadinessChecks();

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
      if (error.retryAfterSeconds !== undefined) {
        reply.header('Retry-After', String(error.retryAfterSeconds));
      }
      reply.status(error.statusCode).send(appErrorResponse(error, request.id));
      return;
    }

    const fastifyError = error as {
      code?: string;
      message?: string;
      statusCode?: number;
    };
    const statusCode =
      typeof fastifyError.statusCode === 'number'
        ? fastifyError.statusCode
        : 500;

    if (statusCode >= 400 && statusCode < 500) {
      reply.status(statusCode).send({
        success: false,
        error: {
          code: fastifyError.code ?? 'REQ_001',
          message: fastifyError.message ?? 'Invalid request.',
        },
        requestId: request.id,
      });
      return;
    }

    if (config.nodeEnv === 'production') {
      request.log.error(
        {
          code: 'SYS_001',
          errorName: error instanceof Error ? error.name : 'UnknownError',
        },
        'Unhandled request error',
      );
    } else {
      request.log.error(error);
    }
    reply.status(500).send({
      success: false,
      error: {
        code: 'SYS_001',
        message: 'Da co loi he thong. Vui long thu lai.',
      },
      requestId: request.id,
    });
  });

  app.register(healthRoute, { readinessChecks });
  app.register(authRoute, { authService, actionQuotaGuard });
  app.register(petRoute, {
    authService,
    petService,
    healthRecordService,
    reminderService,
  });
  app.register(preferenceRoute, {
    authService,
    preferenceService,
  });
  app.register(notificationRoute, {
    authService,
    notificationService,
    reminderService,
  });
  app.register(rescueRoute, {
    authService,
    actionQuotaGuard,
    rescueMediaService,
    rescueReadService,
    rescueWriteService,
    featureAvailability,
  });
  app.register(adoptionRoute, {
    authService,
    adoptionService,
    actionQuotaGuard,
  });
  app.register(adoptionChatRoute, {
    authService,
    adoptionChatService,
    actionQuotaGuard,
  });
  app.register(vetRoute, {
    config,
    authService,
    vetService,
    reviewService,
    actionQuotaGuard,
  });
  app.register(webRoute, { appName: config.appName });

  return app;
};
