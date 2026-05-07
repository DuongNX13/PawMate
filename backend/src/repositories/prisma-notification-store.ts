import { PrismaClient } from '@prisma/client';

import {
  type NotificationListResult,
  type NotificationRecord,
  type NotificationStore,
} from '../services/notifications/notification-service';

const mapNotification = (notification: {
  id: string;
  userId: string;
  petId: string | null;
  reminderId: string | null;
  type: string;
  title: string;
  body: string;
  readAt: Date | null;
  deliveredAt: Date | null;
  dismissedAt: Date | null;
  createdAt: Date;
}): NotificationRecord => ({
  id: notification.id,
  userId: notification.userId,
  petId: notification.petId ?? undefined,
  reminderId: notification.reminderId ?? undefined,
  type: notification.type,
  title: notification.title,
  body: notification.body,
  readAt: notification.readAt?.toISOString(),
  deliveredAt: notification.deliveredAt?.toISOString(),
  dismissedAt: notification.dismissedAt?.toISOString(),
  createdAt: notification.createdAt.toISOString(),
});

export class PrismaNotificationStore implements NotificationStore {
  constructor(private readonly prisma: PrismaClient) {}

  async listByUser(
    userId: string,
    input: {
      limit: number;
      cursor?: string;
      unreadOnly?: boolean;
    },
  ): Promise<NotificationListResult> {
    const where = {
      userId,
      dismissedAt: null,
      ...(input.unreadOnly ? { readAt: null } : {}),
    };
    const [notifications, total, unreadCount] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: input.limit + 1,
        ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
      }),
      this.prisma.notification.count({ where }),
      this.prisma.notification.count({
        where: { userId, dismissedAt: null, readAt: null },
      }),
    ]);
    const page = notifications.slice(0, input.limit);

    return {
      items: page.map(mapNotification),
      nextCursor:
        notifications.length > input.limit ? page.at(-1)?.id : undefined,
      total,
      unreadCount,
      limit: input.limit,
    };
  }

  async findById(notificationId: string) {
    const notification = await this.prisma.notification.findUnique({
      where: { id: notificationId },
    });

    return notification ? mapNotification(notification) : undefined;
  }

  async save(notification: NotificationRecord) {
    await this.prisma.notification.upsert({
      where: { id: notification.id },
      update: {
        userId: notification.userId,
        petId: notification.petId ?? null,
        reminderId: notification.reminderId ?? null,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        readAt: notification.readAt ? new Date(notification.readAt) : null,
        deliveredAt: notification.deliveredAt
          ? new Date(notification.deliveredAt)
          : null,
        dismissedAt: notification.dismissedAt
          ? new Date(notification.dismissedAt)
          : null,
      },
      create: {
        id: notification.id,
        userId: notification.userId,
        petId: notification.petId,
        reminderId: notification.reminderId,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        readAt: notification.readAt ? new Date(notification.readAt) : null,
        deliveredAt: notification.deliveredAt
          ? new Date(notification.deliveredAt)
          : null,
        dismissedAt: notification.dismissedAt
          ? new Date(notification.dismissedAt)
          : null,
        createdAt: new Date(notification.createdAt),
      },
    });
  }

  async markAllRead(userId: string, readAt: string) {
    const result = await this.prisma.notification.updateMany({
      where: {
        userId,
        dismissedAt: null,
        readAt: null,
      },
      data: {
        readAt: new Date(readAt),
      },
    });

    return result.count;
  }
}
