import { Prisma, PrismaClient } from '@prisma/client';

import { PrismaHealthRecordStore } from '../src/repositories/prisma-health-record-store';
import { PrismaNotificationStore } from '../src/repositories/prisma-notification-store';
import { PrismaReminderStore } from '../src/repositories/prisma-reminder-store';
import { PrismaPetStore } from '../src/repositories/prisma-pet-store';

// Query/DTO unit contracts, not claimed as native database proof. DB4 runs
// separately on the owned PostGIS instance with all integration flags enabled.
const instant = new Date('2026-10-07T00:00:00.000Z');
const model = () => ({
  findMany: jest.fn().mockResolvedValue([]),
  findUnique: jest.fn().mockResolvedValue(null),
  findFirst: jest.fn().mockResolvedValue(null),
  upsert: jest.fn().mockResolvedValue({}),
  count: jest.fn().mockResolvedValue(2),
  updateMany: jest.fn().mockResolvedValue({ count: 2 }),
});
const asPrisma = (value: object) => value as PrismaClient;
const reminderRow = (populated = false) => ({
  id: 'reminder-a',
  petId: 'pet-a',
  createdByUserId: 'owner-a',
  title: 'Tiêm ngừa',
  note: populated ? 'Ghi chú' : null,
  reminderAt: instant,
  nextTriggerAt: populated ? instant : null,
  lastTriggeredAt: populated ? instant : null,
  repeatRule: populated ? 'weekly' : null,
  timezone: 'Asia/Ho_Chi_Minh',
  status: 'scheduled',
  completedAt: populated ? instant : null,
  cancelledAt: populated ? instant : null,
  snoozedUntil: populated ? instant : null,
  createdAt: instant,
  updatedAt: instant,
  deletedAt: populated ? instant : null,
});

describe('Day137 persistence projection and query boundary unit contracts', () => {
  it.each([false, true])(
    'round-trips nullable reminder fields (populated=%s)',
    async (populated) => {
      const reminder = model();
      reminder.findUnique.mockResolvedValue(reminderRow(populated));
      const store = new PrismaReminderStore(asPrisma({ reminder }));
      const result = await store.findById('reminder-a');
      expect(result).toMatchObject({
        id: 'reminder-a',
        note: populated ? 'Ghi chú' : undefined,
        repeatRule: populated ? 'weekly' : 'none',
        nextTriggerAt: populated ? instant.toISOString() : undefined,
        completedAt: populated ? instant.toISOString() : undefined,
        deletedAt: populated ? instant.toISOString() : undefined,
      });
      await store.save(result!);
      expect(reminder.upsert).toHaveBeenCalledWith({
        where: { id: 'reminder-a' },
        update: {
          petId: 'pet-a',
          createdByUserId: 'owner-a',
          title: 'Tiêm ngừa',
          note: populated ? 'Ghi chú' : null,
          reminderAt: instant,
          nextTriggerAt: populated ? instant : null,
          lastTriggeredAt: populated ? instant : null,
          repeatRule: populated ? 'weekly' : 'none',
          timezone: 'Asia/Ho_Chi_Minh',
          status: 'scheduled',
          completedAt: populated ? instant : null,
          cancelledAt: populated ? instant : null,
          snoozedUntil: populated ? instant : null,
          updatedAt: instant,
          deletedAt: populated ? instant : null,
        },
        create: expect.objectContaining({
          id: 'reminder-a',
          createdAt: instant,
        }),
      });
    },
  );

  it.each([
    { includeDone: false },
    { includeDone: true, cursor: 'cursor-a', from: instant.toISOString() },
    { to: instant.toISOString() },
    { from: instant.toISOString(), to: instant.toISOString() },
  ])('preserves reminder date/status/cursor filters %j', async (filters) => {
    const reminder = model();
    reminder.findMany.mockResolvedValue([
      reminderRow(),
      { ...reminderRow(), id: 'reminder-b' },
    ]);
    const store = new PrismaReminderStore(asPrisma({ reminder }));
    const result = await store.listByPet('pet-a', { limit: 1, ...filters });
    const where = {
      petId: 'pet-a',
      deletedAt: null,
      ...('includeDone' in filters && filters.includeDone
        ? {}
        : { status: { notIn: ['done', 'cancelled'] } }),
      ...('from' in filters || 'to' in filters
        ? {
            nextTriggerAt: {
              ...('from' in filters ? { gte: instant } : {}),
              ...('to' in filters ? { lte: instant } : {}),
            },
          }
        : {}),
    };
    expect(reminder.findMany).toHaveBeenCalledWith({
      where,
      orderBy: [{ nextTriggerAt: 'asc' }, { createdAt: 'asc' }],
      take: 2,
      ...('cursor' in filters ? { cursor: { id: 'cursor-a' }, skip: 1 } : {}),
    });
    expect(reminder.count).toHaveBeenCalledWith({ where });
    expect(result).toMatchObject({
      total: 2,
      nextCursor: 'reminder-a',
      limit: 1,
      items: [{ id: 'reminder-a' }],
    });
  });

  it('returns missing/empty reminder state and keeps the due-owner filter optional', async () => {
    const reminder = model();
    const store = new PrismaReminderStore(asPrisma({ reminder }));
    await expect(store.findById('missing')).resolves.toBeUndefined();
    await expect(
      store.listByPet('pet-a', { limit: 10 }),
    ).resolves.toMatchObject({ items: [], nextCursor: undefined });
    await store.listDue(instant.toISOString(), 5);
    expect(reminder.findMany).toHaveBeenLastCalledWith({
      where: {
        status: 'scheduled',
        deletedAt: null,
        nextTriggerAt: { lte: instant },
        OR: [{ snoozedUntil: null }, { snoozedUntil: { lte: instant } }],
      },
      orderBy: { nextTriggerAt: 'asc' },
      take: 5,
    });
    reminder.findMany.mockResolvedValue([reminderRow(true)]);
    await expect(
      store.listDue(instant.toISOString(), 5, { createdByUserId: 'owner-a' }),
    ).resolves.toMatchObject([{ id: 'reminder-a' }]);
    expect(reminder.findMany.mock.lastCall![0].where.createdByUserId).toBe(
      'owner-a',
    );
  });

  it.each([false, true])(
    'projects health optional/JSON fields and date-only value (%s)',
    async (populated) => {
      const healthRecord = model();
      const row = {
        id: 'health-a',
        petId: 'pet-a',
        createdByUserId: 'owner-a',
        recordType: 'vaccination',
        recordDate: instant,
        eventTime: populated ? '09:30' : null,
        title: populated ? 'Dại' : null,
        notes: populated ? 'Liều 1' : null,
        vetId: populated ? 'vet-a' : null,
        attachments: populated ? [123, 'photo-a'] : null,
        createdAt: instant,
        updatedAt: instant,
        deletedAt: populated ? instant : null,
      };
      healthRecord.findUnique.mockResolvedValue(row);
      const store = new PrismaHealthRecordStore(asPrisma({ healthRecord }));
      const result = await store.findById('health-a');
      expect(result).toMatchObject({
        date: '2026-10-07',
        time: populated ? '09:30' : undefined,
        attachments: populated ? ['123', 'photo-a'] : [],
        deletedAt: populated ? instant.toISOString() : undefined,
      });
      await store.save(result!);
      expect(healthRecord.upsert).toHaveBeenCalledWith({
        where: { id: 'health-a' },
        update: expect.objectContaining({
          recordType: 'vaccination',
          recordDate: instant,
          attachments: populated ? ['123', 'photo-a'] : [],
          deletedAt: populated ? instant : null,
        }),
        create: expect.objectContaining({ id: 'health-a', createdAt: instant }),
      });
      healthRecord.findMany.mockResolvedValue([
        row,
        { ...row, id: 'health-b' },
      ]);
      const page = await store.listByPet('pet-a', {
        limit: 1,
        cursor: 'cursor-a',
        type: 'vaccination',
      });
      expect(page.nextCursor).toBe('health-a');
      expect(healthRecord.findMany).toHaveBeenCalledWith({
        where: { petId: 'pet-a', deletedAt: null, recordType: 'vaccination' },
        orderBy: [{ recordDate: 'desc' }, { createdAt: 'desc' }],
        take: 2,
        cursor: { id: 'cursor-a' },
        skip: 1,
      });
    },
  );

  it('handles missing health rows and an empty unfiltered page', async () => {
    const healthRecord = model();
    const store = new PrismaHealthRecordStore(asPrisma({ healthRecord }));
    await expect(store.findById('missing')).resolves.toBeUndefined();
    await expect(store.listByPet('pet-a', { limit: 1 })).resolves.toMatchObject(
      { items: [], nextCursor: undefined },
    );
    expect(healthRecord.findMany.mock.lastCall![0]).toEqual({
      where: { petId: 'pet-a', deletedAt: null },
      orderBy: [{ recordDate: 'desc' }, { createdAt: 'desc' }],
      take: 2,
    });
  });

  it.each([false, true])(
    'round-trips notification relationships and lifecycle dates (%s)',
    async (populated) => {
      const notification = model();
      const row = {
        id: 'notification-a',
        userId: 'owner-a',
        petId: populated ? 'pet-a' : null,
        reminderId: populated ? 'reminder-a' : null,
        type: 'reminder',
        title: 'Đến giờ',
        body: 'Tiêm ngừa',
        readAt: populated ? instant : null,
        deliveredAt: populated ? instant : null,
        dismissedAt: populated ? instant : null,
        createdAt: instant,
      };
      notification.findUnique.mockResolvedValue(row);
      const store = new PrismaNotificationStore(asPrisma({ notification }));
      const result = await store.findById('notification-a');
      expect(result).toMatchObject({
        petId: populated ? 'pet-a' : undefined,
        readAt: populated ? instant.toISOString() : undefined,
        createdAt: instant.toISOString(),
      });
      await store.save(result!);
      expect(notification.upsert).toHaveBeenCalledWith({
        where: { id: 'notification-a' },
        update: expect.objectContaining({
          userId: 'owner-a',
          petId: populated ? 'pet-a' : null,
          reminderId: populated ? 'reminder-a' : null,
          readAt: populated ? instant : null,
          deliveredAt: populated ? instant : null,
          dismissedAt: populated ? instant : null,
        }),
        create: expect.objectContaining({
          id: 'notification-a',
          createdAt: instant,
        }),
      });
      notification.findMany.mockResolvedValue([
        row,
        { ...row, id: 'notification-b' },
      ]);
      const page = await store.listByUser('owner-a', {
        limit: 1,
        cursor: 'cursor-a',
        unreadOnly: true,
      });
      expect(page).toMatchObject({
        nextCursor: 'notification-a',
        total: 2,
        unreadCount: 2,
      });
      expect(notification.findMany).toHaveBeenCalledWith({
        where: { userId: 'owner-a', dismissedAt: null, readAt: null },
        orderBy: { createdAt: 'desc' },
        take: 2,
        cursor: { id: 'cursor-a' },
        skip: 1,
      });
    },
  );

  it('keeps unread count independent of filters and scopes mark-all-read to the owner', async () => {
    const notification = model();
    const store = new PrismaNotificationStore(asPrisma({ notification }));
    await expect(store.findById('missing')).resolves.toBeUndefined();
    await expect(
      store.listByUser('owner-a', { limit: 2 }),
    ).resolves.toMatchObject({ items: [], nextCursor: undefined });
    expect(notification.count.mock.calls).toEqual([
      [{ where: { userId: 'owner-a', dismissedAt: null } }],
      [{ where: { userId: 'owner-a', dismissedAt: null, readAt: null } }],
    ]);
    await expect(
      store.markAllRead('owner-a', instant.toISOString()),
    ).resolves.toBe(2);
    expect(notification.updateMany).toHaveBeenCalledWith({
      where: { userId: 'owner-a', dismissedAt: null, readAt: null },
      data: { readAt: instant },
    });
  });

  it.each(['dog', 'cat', 'bird'])(
    'normalizes pet species without dropping decimal/nullable values (%s)',
    async (species) => {
      const pet = model();
      const populated = species !== 'bird';
      const row = {
        id: 'pet-a',
        userId: 'owner-a',
        name: 'Mochi',
        species,
        gender: 'unknown',
        breed: populated ? 'Poodle' : null,
        dob: populated ? instant : null,
        weightKg: populated ? new Prisma.Decimal('12.4') : null,
        color: populated ? 'Nâu' : null,
        microchipNumber: populated ? 'MC123' : null,
        isNeutered: false,
        avatarUrl: populated ? 'https://example.invalid/pet.png' : null,
        healthStatus: 'healthy',
        createdAt: instant,
        updatedAt: instant,
        deletedAt: populated ? instant : null,
      };
      pet.findUnique.mockResolvedValue(row);
      pet.findMany.mockResolvedValue([row]);
      const store = new PrismaPetStore(asPrisma({ pet }));
      const result = await store.findById('pet-a');
      expect(result).toMatchObject({
        species: populated ? species : 'other',
        weight: populated ? 12.4 : undefined,
        dob: populated ? '2026-10-07' : undefined,
      });
      await expect(store.listByUser('owner-a')).resolves.toEqual([result]);
      expect(pet.findMany).toHaveBeenCalledWith({
        where: { userId: 'owner-a', deletedAt: null },
        orderBy: { createdAt: 'desc' },
      });
      await store.save(result!);
      expect(pet.upsert.mock.lastCall![0].update).toMatchObject({
        dob: populated ? instant : null,
        weightKg: populated ? 12.4 : undefined,
        deletedAt: populated ? instant : null,
      });
    },
  );

  it('finds microchip conflicts excluding only a requested pet and never includes deleted records', async () => {
    const pet = model();
    const store = new PrismaPetStore(asPrisma({ pet }));
    await expect(store.findById('missing')).resolves.toBeUndefined();
    await expect(store.hasMicrochipConflict('MC123')).resolves.toBe(false);
    expect(pet.findFirst).toHaveBeenCalledWith({
      where: { microchipNumber: 'MC123', deletedAt: null },
      select: { id: true },
    });
    pet.findFirst.mockResolvedValue({ id: 'other-pet' });
    await expect(store.hasMicrochipConflict('MC123', 'pet-a')).resolves.toBe(
      true,
    );
    expect(pet.findFirst).toHaveBeenLastCalledWith({
      where: {
        microchipNumber: 'MC123',
        deletedAt: null,
        id: { not: 'pet-a' },
      },
      select: { id: true },
    });
  });
});
