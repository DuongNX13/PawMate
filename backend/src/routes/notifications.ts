import { type FastifyPluginAsync } from 'fastify';

import { AppError } from '../errors/app-error';
import {
  NOTIFICATION_ERROR_CODES,
  PET_ERROR_CODES,
} from '../errors/error-codes';
import { type AuthService } from '../services/auth/auth-service';
import { type NotificationService } from '../services/notifications/notification-service';
import { type ReminderService } from '../services/reminders/reminder-service';

type NotificationRouteOptions = {
  authService: AuthService;
  notificationService: NotificationService;
  reminderService: Pick<ReminderService, 'processDueReminders'>;
};

type NotificationListQuerystring = {
  limit?: string;
  cursor?: string;
  unreadOnly?: string;
};

const getUserIdFromRequest = (
  authService: AuthService,
  authorization?: string,
) => {
  if (!authorization?.startsWith('Bearer ')) {
    throw new AppError(
      PET_ERROR_CODES.unauthorized,
      'Ban can dang nhap de xem thong bao.',
      401,
    );
  }

  const accessToken = authorization.replace('Bearer ', '').trim();
  return authService.verifyAccessToken(accessToken).userId;
};

const parseLimit = (value: string | undefined) => {
  if (value === undefined) {
    return undefined;
  }

  const trimmed = value.trim();
  if (!/^\d+$/.test(trimmed)) {
    throw new AppError(
      NOTIFICATION_ERROR_CODES.invalidInput,
      'Truong limit phai la so nguyen hop le.',
      400,
      'limit',
    );
  }

  return Number(trimmed);
};

const parseUnreadOnly = (value: string | undefined) => {
  if (value === undefined) {
    return undefined;
  }

  const normalized = value.trim().toLowerCase();
  if (['1', 'true', 'yes'].includes(normalized)) {
    return true;
  }
  if (['0', 'false', 'no'].includes(normalized)) {
    return false;
  }

  throw new AppError(
    NOTIFICATION_ERROR_CODES.invalidInput,
    'Truong unreadOnly khong hop le.',
    400,
    'unreadOnly',
  );
};

const notificationRoute: FastifyPluginAsync<NotificationRouteOptions> = async (
  app,
  options,
) => {
  app.get<{ Querystring: NotificationListQuerystring }>(
    '/notifications',
    async (request) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      return {
        data: await options.notificationService.list(userId, {
          limit: parseLimit(request.query.limit),
          cursor: request.query.cursor?.trim() || undefined,
          unreadOnly: parseUnreadOnly(request.query.unreadOnly),
        }),
      };
    },
  );

  app.post('/notifications/process-due-reminders', async (request) => {
    getUserIdFromRequest(options.authService, request.headers.authorization);

    return {
      data: await options.reminderService.processDueReminders(new Date()),
    };
  });

  app.patch<{ Params: { notificationId: string } }>(
    '/notifications/:notificationId/read',
    async (request) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      return {
        data: await options.notificationService.markRead(
          userId,
          request.params.notificationId,
        ),
      };
    },
  );

  app.post('/notifications/read-all', async (request) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    return {
      data: await options.notificationService.markAllRead(userId),
    };
  });

  app.patch<{ Params: { notificationId: string } }>(
    '/notifications/:notificationId/dismiss',
    async (request) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      return {
        data: await options.notificationService.dismiss(
          userId,
          request.params.notificationId,
        ),
      };
    },
  );
};

export default notificationRoute;
