import { type FastifyPluginAsync } from 'fastify';

import { AppError } from '../errors/app-error';
import { AUTH_ERROR_CODES } from '../errors/error-codes';
import { type AuthService } from '../services/auth/auth-service';
import { type PreferenceService } from '../services/preferences/preference-service';

type PreferenceRouteOptions = {
  authService: AuthService;
  preferenceService: PreferenceService;
};

const requireUserId = async (
  authService: AuthService,
  authorization?: string,
) => {
  if (!authorization?.startsWith('Bearer ')) {
    throw new AppError(
      AUTH_ERROR_CODES.unauthorized,
      'Ban can dang nhap de quan ly cai dat.',
      401,
    );
  }
  const token = authorization.slice('Bearer '.length).trim();
  if (!token) {
    throw new AppError(
      AUTH_ERROR_CODES.unauthorized,
      'Bearer access token khong hop le.',
      401,
    );
  }
  return (await authService.verifyAccessToken(token)).userId;
};

const preferenceRoute: FastifyPluginAsync<PreferenceRouteOptions> = async (
  app,
  options,
) => {
  app.get('/me/notification-preferences', async (request, reply) => {
    const userId = await requireUserId(
      options.authService,
      request.headers.authorization,
    );
    const data =
      await options.preferenceService.getNotificationPreferences(userId);
    reply.header('Cache-Control', 'no-store');
    return { data };
  });

  app.put<{ Body: unknown }>(
    '/me/notification-preferences',
    async (request, reply) => {
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      const data =
        await options.preferenceService.updateNotificationPreferences(
          userId,
          request.body,
        );
      reply.header('Cache-Control', 'no-store');
      return { data };
    },
  );

  app.get('/me/privacy-defaults', async (request, reply) => {
    const userId = await requireUserId(
      options.authService,
      request.headers.authorization,
    );
    const data = await options.preferenceService.getPrivacyDefaults(userId);
    reply.header('Cache-Control', 'no-store');
    return { data };
  });

  app.put<{ Body: unknown }>(
    '/me/privacy-defaults',
    async (request, reply) => {
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      const data = await options.preferenceService.updatePrivacyDefaults(
        userId,
        request.body,
      );
      reply.header('Cache-Control', 'no-store');
      return { data };
    },
  );
};

export default preferenceRoute;
