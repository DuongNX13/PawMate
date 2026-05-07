import { randomUUID } from 'node:crypto';

import { AppError } from '../../errors/app-error';
import { REMINDER_ERROR_CODES } from '../../errors/error-codes';
import { type NotificationService } from '../notifications/notification-service';
import { type PetRecord } from '../pets/pet-service';

export type ReminderRepeatRule = 'none' | 'daily' | 'weekly' | 'monthly';

export type ReminderStatus = 'scheduled' | 'sent' | 'cancelled' | 'done';

export type ReminderRecord = {
  id: string;
  petId: string;
  createdByUserId: string;
  title: string;
  note?: string;
  reminderAt: string;
  nextTriggerAt?: string;
  lastTriggeredAt?: string;
  repeatRule: ReminderRepeatRule;
  timezone: string;
  status: ReminderStatus;
  completedAt?: string;
  cancelledAt?: string;
  snoozedUntil?: string;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
};

export type ReminderListInput = {
  limit?: number;
  cursor?: string;
  from?: string;
  to?: string;
  includeDone?: boolean;
};

export type ReminderListResult = {
  items: ReminderRecord[];
  nextCursor?: string;
  total: number;
  limit: number;
};

export type CreateReminderInput = {
  title?: string;
  note?: string;
  reminderAt?: string;
  repeatRule?: string;
  timezone?: string;
};

export type UpdateReminderInput = Partial<CreateReminderInput>;

export type SnoozeReminderInput = {
  snoozedUntil?: string;
};

export type ReminderStore = {
  listByPet: (
    petId: string,
    input: {
      limit: number;
      cursor?: string;
      from?: string;
      to?: string;
      includeDone?: boolean;
    },
  ) => Promise<ReminderListResult>;
  findById: (reminderId: string) => Promise<ReminderRecord | undefined>;
  save: (reminder: ReminderRecord) => Promise<void>;
  listDue: (now: string, limit: number) => Promise<ReminderRecord[]>;
};

export type ReminderService = ReturnType<typeof createReminderService>;

type PetReader = {
  get: (userId: string, petId: string) => Promise<PetRecord>;
};

class InMemoryReminderStore implements ReminderStore {
  private readonly reminders = new Map<string, ReminderRecord>();

  async listByPet(
    petId: string,
    input: {
      limit: number;
      cursor?: string;
      from?: string;
      to?: string;
      includeDone?: boolean;
    },
  ): Promise<ReminderListResult> {
    const sorted = [...this.reminders.values()]
      .filter((reminder) => {
        const triggerAt = reminder.nextTriggerAt ?? reminder.reminderAt;
        return (
          reminder.petId === petId &&
          !reminder.deletedAt &&
          (input.includeDone || !['done', 'cancelled'].includes(reminder.status)) &&
          (!input.from || triggerAt >= input.from) &&
          (!input.to || triggerAt <= input.to)
        );
      })
      .sort((left, right) => {
        const leftTrigger = left.nextTriggerAt ?? left.reminderAt;
        const rightTrigger = right.nextTriggerAt ?? right.reminderAt;
        return leftTrigger.localeCompare(rightTrigger) || left.createdAt.localeCompare(right.createdAt);
      });
    const startIndex = input.cursor
      ? sorted.findIndex((reminder) => reminder.id === input.cursor) + 1
      : 0;
    const safeStartIndex = Math.max(startIndex, 0);
    const page = sorted.slice(safeStartIndex, safeStartIndex + input.limit);

    return {
      items: page,
      nextCursor:
        safeStartIndex + input.limit < sorted.length ? page.at(-1)?.id : undefined,
      total: sorted.length,
      limit: input.limit,
    };
  }

  async findById(reminderId: string) {
    return this.reminders.get(reminderId);
  }

  async save(reminder: ReminderRecord) {
    this.reminders.set(reminder.id, reminder);
  }

  async listDue(now: string, limit: number) {
    return [...this.reminders.values()]
      .filter((reminder) => {
        const triggerAt = reminder.nextTriggerAt ?? reminder.reminderAt;
        return (
          reminder.status === 'scheduled' &&
          !reminder.deletedAt &&
          triggerAt <= now &&
          (!reminder.snoozedUntil || reminder.snoozedUntil <= now)
        );
      })
      .sort((left, right) => {
        const leftTrigger = left.nextTriggerAt ?? left.reminderAt;
        const rightTrigger = right.nextTriggerAt ?? right.reminderAt;
        return leftTrigger.localeCompare(rightTrigger);
      })
      .slice(0, limit);
  }
}

const allowedRepeatRules: ReminderRepeatRule[] = [
  'none',
  'daily',
  'weekly',
  'monthly',
];

const validateLimit = (value?: number) => {
  const limit = value ?? 20;
  if (!Number.isInteger(limit) || limit < 1 || limit > 50) {
    throw new AppError(
      REMINDER_ERROR_CODES.invalidInput,
      'Limit must be in the 1-50 range.',
      400,
      'limit',
    );
  }

  return limit;
};

const trimLimited = (
  value: string | undefined,
  field: string,
  maxLength: number,
  options: { required?: boolean } = {},
) => {
  const trimmed = value?.trim();
  if (!trimmed) {
    if (options.required) {
      throw new AppError(
        REMINDER_ERROR_CODES.invalidInput,
        `${field} is required.`,
        400,
        field,
      );
    }
    return undefined;
  }

  if (trimmed.length > maxLength) {
    throw new AppError(
      REMINDER_ERROR_CODES.invalidInput,
      `${field} must not exceed ${maxLength} characters.`,
      400,
      field,
    );
  }

  return trimmed;
};

const validateIsoDate = (
  value: string | undefined,
  field: string,
  options: { required?: boolean } = {},
) => {
  if (!value?.trim()) {
    if (options.required) {
      throw new AppError(
        REMINDER_ERROR_CODES.invalidInput,
        `${field} is required.`,
        400,
        field,
      );
    }
    return undefined;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new AppError(
      REMINDER_ERROR_CODES.invalidInput,
      `${field} must be a valid date-time.`,
      400,
      field,
    );
  }

  return parsed.toISOString();
};

const validateRepeatRule = (value?: string): ReminderRepeatRule => {
  const normalized = value?.trim().toLowerCase() || 'none';
  if (!allowedRepeatRules.includes(normalized as ReminderRepeatRule)) {
    throw new AppError(
      REMINDER_ERROR_CODES.invalidInput,
      'repeatRule must be none, daily, weekly, or monthly.',
      400,
      'repeatRule',
    );
  }

  return normalized as ReminderRepeatRule;
};

const validateTimezone = (value?: string) => {
  const timezone = value?.trim() || 'Asia/Bangkok';
  if (timezone.length > 64 || !/^[A-Za-z0-9_+\-/]+$/.test(timezone)) {
    throw new AppError(
      REMINDER_ERROR_CODES.invalidInput,
      'timezone is not valid.',
      400,
      'timezone',
    );
  }

  return timezone;
};

const addRepeatInterval = (
  currentIso: string,
  repeatRule: ReminderRepeatRule,
  now: Date,
) => {
  if (repeatRule === 'none') {
    return undefined;
  }

  const next = new Date(currentIso);
  do {
    switch (repeatRule) {
      case 'daily':
        next.setUTCDate(next.getUTCDate() + 1);
        break;
      case 'weekly':
        next.setUTCDate(next.getUTCDate() + 7);
        break;
      case 'monthly':
        next.setUTCMonth(next.getUTCMonth() + 1);
        break;
      default:
        break;
    }
  } while (next <= now);

  return next.toISOString();
};

export const createReminderService = (dependencies: {
  petReader: PetReader;
  notificationService: Pick<
    NotificationService,
    'createReminderNotification'
  >;
  store?: ReminderStore;
}) => {
  const store = dependencies.store ?? new InMemoryReminderStore();

  const requireOwnedPet = (userId: string, petId: string) =>
    dependencies.petReader.get(userId, petId);

  const requireOwnedReminder = async (
    userId: string,
    petId: string,
    reminderId: string,
  ) => {
    await requireOwnedPet(userId, petId);
    const reminder = await store.findById(reminderId);
    if (!reminder || reminder.deletedAt || reminder.petId !== petId) {
      throw new AppError(
        REMINDER_ERROR_CODES.notFound,
        'Reminder not found.',
        404,
      );
    }

    return reminder;
  };

  return {
    async list(
      userId: string,
      petId: string,
      input: ReminderListInput = {},
    ) {
      await requireOwnedPet(userId, petId);
      return store.listByPet(petId, {
        limit: validateLimit(input.limit),
        cursor: input.cursor?.trim() || undefined,
        from: validateIsoDate(input.from, 'from'),
        to: validateIsoDate(input.to, 'to'),
        includeDone: Boolean(input.includeDone),
      });
    },

    async create(userId: string, petId: string, input: CreateReminderInput) {
      await requireOwnedPet(userId, petId);
      const timestamp = new Date().toISOString();
      const reminderAt = validateIsoDate(input.reminderAt, 'reminderAt', {
        required: true,
      })!;
      const reminder: ReminderRecord = {
        id: randomUUID(),
        petId,
        createdByUserId: userId,
        title: trimLimited(input.title, 'title', 120, { required: true })!,
        note: trimLimited(input.note, 'note', 1000),
        reminderAt,
        nextTriggerAt: reminderAt,
        repeatRule: validateRepeatRule(input.repeatRule),
        timezone: validateTimezone(input.timezone),
        status: 'scheduled',
        createdAt: timestamp,
        updatedAt: timestamp,
      };

      await store.save(reminder);
      return reminder;
    },

    async update(
      userId: string,
      petId: string,
      reminderId: string,
      input: UpdateReminderInput,
    ) {
      const existingReminder = await requireOwnedReminder(
        userId,
        petId,
        reminderId,
      );
      const reminderAt =
        input.reminderAt === undefined
          ? existingReminder.reminderAt
          : validateIsoDate(input.reminderAt, 'reminderAt', { required: true })!;
      const nextReminder: ReminderRecord = {
        ...existingReminder,
        title:
          input.title === undefined
            ? existingReminder.title
            : trimLimited(input.title, 'title', 120, { required: true })!,
        note:
          input.note === undefined
            ? existingReminder.note
            : trimLimited(input.note, 'note', 1000),
        reminderAt,
        nextTriggerAt:
          input.reminderAt === undefined
            ? existingReminder.nextTriggerAt
            : reminderAt,
        repeatRule:
          input.repeatRule === undefined
            ? existingReminder.repeatRule
            : validateRepeatRule(input.repeatRule),
        timezone:
          input.timezone === undefined
            ? existingReminder.timezone
            : validateTimezone(input.timezone),
        updatedAt: new Date().toISOString(),
      };

      await store.save(nextReminder);
      return nextReminder;
    },

    async remove(userId: string, petId: string, reminderId: string) {
      const existingReminder = await requireOwnedReminder(
        userId,
        petId,
        reminderId,
      );
      const timestamp = new Date().toISOString();
      await store.save({
        ...existingReminder,
        status: 'cancelled',
        cancelledAt: timestamp,
        deletedAt: timestamp,
        updatedAt: timestamp,
      });
    },

    async snooze(
      userId: string,
      petId: string,
      reminderId: string,
      input: SnoozeReminderInput,
    ) {
      const existingReminder = await requireOwnedReminder(
        userId,
        petId,
        reminderId,
      );
      const snoozedUntil = validateIsoDate(
        input.snoozedUntil,
        'snoozedUntil',
        { required: true },
      )!;
      const nextReminder = {
        ...existingReminder,
        status: 'scheduled' as ReminderStatus,
        nextTriggerAt: snoozedUntil,
        snoozedUntil,
        updatedAt: new Date().toISOString(),
      };
      await store.save(nextReminder);
      return nextReminder;
    },

    async markDone(userId: string, petId: string, reminderId: string) {
      const existingReminder = await requireOwnedReminder(
        userId,
        petId,
        reminderId,
      );
      const timestamp = new Date().toISOString();
      const nextReminder = {
        ...existingReminder,
        status: 'done' as ReminderStatus,
        completedAt: timestamp,
        nextTriggerAt: undefined,
        updatedAt: timestamp,
      };
      await store.save(nextReminder);
      return nextReminder;
    },

    async processDueReminders(now: Date = new Date(), limit = 100) {
      const dueReminders = await store.listDue(now.toISOString(), limit);
      const processed = await Promise.all(
        dueReminders.map(async (reminder) => {
        const triggeredAt = reminder.nextTriggerAt ?? reminder.reminderAt;
        await dependencies.notificationService.createReminderNotification({
          userId: reminder.createdByUserId,
          petId: reminder.petId,
          reminderId: reminder.id,
          title: reminder.title,
          body: reminder.note || `Reminder due at ${triggeredAt}.`,
          now,
        });
        const nextTriggerAt = addRepeatInterval(
          triggeredAt,
          reminder.repeatRule,
          now,
        );
        const nextReminder: ReminderRecord = {
          ...reminder,
          status: nextTriggerAt ? 'scheduled' : 'sent',
          lastTriggeredAt: now.toISOString(),
          nextTriggerAt,
          snoozedUntil: undefined,
          updatedAt: now.toISOString(),
        };
        await store.save(nextReminder);
          return nextReminder;
        }),
      );

      return {
        processedCount: processed.length,
        items: processed,
      };
    },
  };
};
