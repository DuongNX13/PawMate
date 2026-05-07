import { type AppConfig } from '../config/env';
import { getPrismaClient } from '../infrastructure/prisma';
import { PrismaNotificationStore } from '../repositories/prisma-notification-store';
import { PrismaPetStore } from '../repositories/prisma-pet-store';
import { PrismaReminderStore } from '../repositories/prisma-reminder-store';
import { createNotificationService } from '../services/notifications/notification-service';
import { createPetService } from '../services/pets/pet-service';
import { type ReminderService, createReminderService } from '../services/reminders/reminder-service';

const DEFAULT_LIMIT = 100;
const MAX_LIMIT = 500;

export type DueReminderProcessingSummary = {
  processedCount: number;
  reminderIds: string[];
  ranAt: string;
  limit: number;
};

export type DueReminderJobResources = {
  reminderService: Pick<ReminderService, 'processDueReminders'>;
  close: () => Promise<void>;
};

const validateLimit = (limit?: number) => {
  const nextLimit = limit ?? DEFAULT_LIMIT;
  if (!Number.isInteger(nextLimit) || nextLimit < 1 || nextLimit > MAX_LIMIT) {
    throw new Error(`Reminder processing limit must be an integer from 1 to ${MAX_LIMIT}.`);
  }

  return nextLimit;
};

export const createDueReminderJobResources = (config: AppConfig): DueReminderJobResources => {
  if (!config.databaseUrl) {
    throw new Error(
      'DATABASE_URL is required for production reminder processing.',
    );
  }

  const prisma = getPrismaClient(config.databaseUrl);
  const petService = createPetService(config, { store: new PrismaPetStore(prisma) });
  const notificationService = createNotificationService({
    store: new PrismaNotificationStore(prisma),
  });
  const reminderService = createReminderService({
    petReader: petService,
    notificationService,
    store: new PrismaReminderStore(prisma),
  });

  return {
    reminderService,
    close: () => prisma.$disconnect(),
  };
};

export const processDueRemindersOnce = async (
  reminderService: Pick<ReminderService, 'processDueReminders'>,
  options: {
    now?: Date;
    limit?: number;
  } = {},
): Promise<DueReminderProcessingSummary> => {
  const now = options.now ?? new Date();
  const limit = validateLimit(options.limit);
  const result = await reminderService.processDueReminders(now, limit);

  return {
    processedCount: result.processedCount,
    reminderIds: result.items.map((reminder) => reminder.id),
    ranAt: now.toISOString(),
    limit,
  };
};

export const parseProcessDueReminderArgs = (argv: string[]) => {
  const nextArgs: { now?: Date; limit?: number } = {};

  let index = 0;
  while (index < argv.length) {
    const arg = argv[index];
    if (arg === '--limit') {
      const rawLimit = argv[index + 1];
      if (!rawLimit) {
        throw new Error('--limit requires a value.');
      }
      nextArgs.limit = Number(rawLimit);
      index += 2;
    } else if (arg === '--now') {
      const rawNow = argv[index + 1];
      if (!rawNow) {
        throw new Error('--now requires an ISO datetime value.');
      }
      const parsedNow = new Date(rawNow);
      if (Number.isNaN(parsedNow.getTime())) {
        throw new Error('--now must be a valid ISO datetime value.');
      }
      nextArgs.now = parsedNow;
      index += 2;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (nextArgs.limit !== undefined) {
    validateLimit(nextArgs.limit);
  }

  return nextArgs;
};
