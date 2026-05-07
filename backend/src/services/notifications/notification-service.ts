import { randomUUID } from 'node:crypto';

import { AppError } from '../../errors/app-error';
import { NOTIFICATION_ERROR_CODES } from '../../errors/error-codes';

export type NotificationRecord = {
  id: string;
  userId: string;
  petId?: string;
  reminderId?: string;
  type: string;
  title: string;
  body: string;
  readAt?: string;
  deliveredAt?: string;
  dismissedAt?: string;
  createdAt: string;
};

export type NotificationListInput = {
  limit?: number;
  cursor?: string;
  unreadOnly?: boolean;
};

export type NotificationListResult = {
  items: NotificationRecord[];
  nextCursor?: string;
  total: number;
  unreadCount: number;
  limit: number;
};

export type CreateReminderNotificationInput = {
  userId: string;
  petId: string;
  reminderId: string;
  title: string;
  body: string;
  now?: Date;
};

export type NotificationStore = {
  listByUser: (
    userId: string,
    input: {
      limit: number;
      cursor?: string;
      unreadOnly?: boolean;
    },
  ) => Promise<NotificationListResult>;
  findById: (notificationId: string) => Promise<NotificationRecord | undefined>;
  save: (notification: NotificationRecord) => Promise<void>;
  markAllRead: (userId: string, readAt: string) => Promise<number>;
};

export type NotificationService = ReturnType<typeof createNotificationService>;

class InMemoryNotificationStore implements NotificationStore {
  private readonly notifications = new Map<string, NotificationRecord>();

  async listByUser(
    userId: string,
    input: {
      limit: number;
      cursor?: string;
      unreadOnly?: boolean;
    },
  ): Promise<NotificationListResult> {
    const sorted = [...this.notifications.values()]
      .filter(
        (notification) =>
          notification.userId === userId &&
          !notification.dismissedAt &&
          (!input.unreadOnly || !notification.readAt),
      )
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));
    const unreadCount = [...this.notifications.values()].filter(
      (notification) =>
        notification.userId === userId &&
        !notification.dismissedAt &&
        !notification.readAt,
    ).length;
    const startIndex = input.cursor
      ? sorted.findIndex((notification) => notification.id === input.cursor) + 1
      : 0;
    const safeStartIndex = Math.max(startIndex, 0);
    const page = sorted.slice(safeStartIndex, safeStartIndex + input.limit);

    return {
      items: page,
      nextCursor:
        safeStartIndex + input.limit < sorted.length ? page.at(-1)?.id : undefined,
      total: sorted.length,
      unreadCount,
      limit: input.limit,
    };
  }

  async findById(notificationId: string) {
    return this.notifications.get(notificationId);
  }

  async save(notification: NotificationRecord) {
    this.notifications.set(notification.id, notification);
  }

  async markAllRead(userId: string, readAt: string) {
    const unreadNotifications = [...this.notifications.values()].filter(
      (notification) =>
        notification.userId === userId &&
        !notification.dismissedAt &&
        !notification.readAt,
    );
    unreadNotifications.forEach((notification) => {
        this.notifications.set(notification.id, {
          ...notification,
          readAt,
        });
    });

    return unreadNotifications.length;
  }
}

const validateLimit = (value?: number) => {
  const limit = value ?? 20;
  if (!Number.isInteger(limit) || limit < 1 || limit > 50) {
    throw new AppError(
      NOTIFICATION_ERROR_CODES.invalidInput,
      'Limit must be in the 1-50 range.',
      400,
      'limit',
    );
  }

  return limit;
};

const requireOwnedNotification = async (
  store: NotificationStore,
  userId: string,
  notificationId: string,
) => {
  const notification = await store.findById(notificationId);
  if (
    !notification ||
    notification.userId !== userId ||
    notification.dismissedAt
  ) {
    throw new AppError(
      NOTIFICATION_ERROR_CODES.notFound,
      'Notification not found.',
      404,
    );
  }

  return notification;
};

export const createNotificationService = (dependencies: {
  store?: NotificationStore;
} = {}) => {
  const store = dependencies.store ?? new InMemoryNotificationStore();

  return {
    async list(userId: string, input: NotificationListInput = {}) {
      return store.listByUser(userId, {
        limit: validateLimit(input.limit),
        cursor: input.cursor?.trim() || undefined,
        unreadOnly: Boolean(input.unreadOnly),
      });
    },

    async createReminderNotification(input: CreateReminderNotificationInput) {
      const now = input.now ?? new Date();
      const timestamp = now.toISOString();
      const notification: NotificationRecord = {
        id: randomUUID(),
        userId: input.userId,
        petId: input.petId,
        reminderId: input.reminderId,
        type: 'reminder_due',
        title: input.title.trim(),
        body: input.body.trim(),
        deliveredAt: timestamp,
        createdAt: timestamp,
      };

      await store.save(notification);
      return notification;
    },

    async markRead(userId: string, notificationId: string) {
      const notification = await requireOwnedNotification(
        store,
        userId,
        notificationId,
      );
      if (notification.readAt) {
        return notification;
      }

      const nextNotification = {
        ...notification,
        readAt: new Date().toISOString(),
      };
      await store.save(nextNotification);
      return nextNotification;
    },

    async markAllRead(userId: string) {
      return {
        updatedCount: await store.markAllRead(userId, new Date().toISOString()),
      };
    },

    async dismiss(userId: string, notificationId: string) {
      const notification = await requireOwnedNotification(
        store,
        userId,
        notificationId,
      );
      const nextNotification = {
        ...notification,
        dismissedAt: new Date().toISOString(),
      };
      await store.save(nextNotification);
      return nextNotification;
    },
  };
};
