import { $Enums, PrismaClient } from '@prisma/client';

import {
  type ReminderListResult,
  type ReminderRecord,
  type ReminderRepeatRule,
  type ReminderStatus,
  type ReminderStore,
} from '../services/reminders/reminder-service';

const mapReminder = (reminder: {
  id: string;
  petId: string;
  createdByUserId: string;
  title: string;
  note: string | null;
  reminderAt: Date;
  nextTriggerAt: Date | null;
  lastTriggeredAt: Date | null;
  repeatRule: string | null;
  timezone: string;
  status: $Enums.ReminderStatus;
  completedAt: Date | null;
  cancelledAt: Date | null;
  snoozedUntil: Date | null;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}): ReminderRecord => ({
  id: reminder.id,
  petId: reminder.petId,
  createdByUserId: reminder.createdByUserId,
  title: reminder.title,
  note: reminder.note ?? undefined,
  reminderAt: reminder.reminderAt.toISOString(),
  nextTriggerAt: reminder.nextTriggerAt?.toISOString(),
  lastTriggeredAt: reminder.lastTriggeredAt?.toISOString(),
  repeatRule: (reminder.repeatRule ?? 'none') as ReminderRepeatRule,
  timezone: reminder.timezone,
  status: reminder.status as ReminderStatus,
  completedAt: reminder.completedAt?.toISOString(),
  cancelledAt: reminder.cancelledAt?.toISOString(),
  snoozedUntil: reminder.snoozedUntil?.toISOString(),
  createdAt: reminder.createdAt.toISOString(),
  updatedAt: reminder.updatedAt.toISOString(),
  deletedAt: reminder.deletedAt?.toISOString(),
});

export class PrismaReminderStore implements ReminderStore {
  constructor(private readonly prisma: PrismaClient) {}

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
    const where = {
      petId,
      deletedAt: null,
      ...(input.includeDone
        ? {}
        : { status: { notIn: ['done', 'cancelled'] as $Enums.ReminderStatus[] } }),
      ...(input.from || input.to
        ? {
            nextTriggerAt: {
              ...(input.from ? { gte: new Date(input.from) } : {}),
              ...(input.to ? { lte: new Date(input.to) } : {}),
            },
          }
        : {}),
    };
    const [reminders, total] = await Promise.all([
      this.prisma.reminder.findMany({
        where,
        orderBy: [{ nextTriggerAt: 'asc' }, { createdAt: 'asc' }],
        take: input.limit + 1,
        ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
      }),
      this.prisma.reminder.count({ where }),
    ]);
    const page = reminders.slice(0, input.limit);

    return {
      items: page.map(mapReminder),
      nextCursor: reminders.length > input.limit ? page.at(-1)?.id : undefined,
      total,
      limit: input.limit,
    };
  }

  async findById(reminderId: string) {
    const reminder = await this.prisma.reminder.findUnique({
      where: { id: reminderId },
    });

    return reminder ? mapReminder(reminder) : undefined;
  }

  async save(reminder: ReminderRecord) {
    const data = {
      petId: reminder.petId,
      createdByUserId: reminder.createdByUserId,
      title: reminder.title,
      note: reminder.note ?? null,
      reminderAt: new Date(reminder.reminderAt),
      nextTriggerAt: reminder.nextTriggerAt
        ? new Date(reminder.nextTriggerAt)
        : null,
      lastTriggeredAt: reminder.lastTriggeredAt
        ? new Date(reminder.lastTriggeredAt)
        : null,
      repeatRule: reminder.repeatRule,
      timezone: reminder.timezone,
      status: reminder.status as $Enums.ReminderStatus,
      completedAt: reminder.completedAt
        ? new Date(reminder.completedAt)
        : null,
      cancelledAt: reminder.cancelledAt
        ? new Date(reminder.cancelledAt)
        : null,
      snoozedUntil: reminder.snoozedUntil
        ? new Date(reminder.snoozedUntil)
        : null,
      updatedAt: new Date(reminder.updatedAt),
      deletedAt: reminder.deletedAt ? new Date(reminder.deletedAt) : null,
    };

    await this.prisma.reminder.upsert({
      where: { id: reminder.id },
      update: data,
      create: {
        id: reminder.id,
        ...data,
        createdAt: new Date(reminder.createdAt),
      },
    });
  }

  async listDue(now: string, limit: number) {
    const reminders = await this.prisma.reminder.findMany({
      where: {
        status: 'scheduled',
        deletedAt: null,
        nextTriggerAt: { lte: new Date(now) },
        OR: [{ snoozedUntil: null }, { snoozedUntil: { lte: new Date(now) } }],
      },
      orderBy: { nextTriggerAt: 'asc' },
      take: limit,
    });

    return reminders.map(mapReminder);
  }
}
