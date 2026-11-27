import { type FastifyPluginAsync } from 'fastify';

import { AppError } from '../errors/app-error';
import { AUTH_ERROR_CODES } from '../errors/error-codes';
import {
  type AdoptionChatService,
  type ChatQuery,
} from '../services/adoption/adoption-chat-service';
import { type AuthService } from '../services/auth/auth-service';
import { type ActionQuotaGuard } from '../security/distributed-action-quota';

type AdoptionChatRouteOptions = {
  authService: AuthService;
  adoptionChatService: AdoptionChatService;
  actionQuotaGuard: ActionQuotaGuard;
};

const requireUserId = async (
  authService: AuthService,
  authorization?: string,
) => {
  if (!authorization?.startsWith('Bearer ')) {
    throw new AppError(
      AUTH_ERROR_CODES.unauthorized,
      'Ban can dang nhap de su dung tinh nang tro chuyen.',
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

const readIdempotencyKey = (value: string | string[] | undefined) =>
  Array.isArray(value) ? undefined : value;

const buildPageInfo = (result: { nextCursor?: string; limit: number }) => ({
  nextCursor: result.nextCursor ?? null,
  hasMore: result.nextCursor !== undefined,
  limit: result.limit,
});

const adoptionChatRoute: FastifyPluginAsync<AdoptionChatRouteOptions> = async (
  app,
  options,
) => {
  app.get<{ Params: { threadId: string; mediaId: string } }>(
    '/adoption/chat/:threadId/media/:mediaId',
    async (request, reply) => {
      reply.header('Cache-Control', 'private, no-store, max-age=0');
      reply.header('Pragma', 'no-cache');
      reply.header('Vary', 'Authorization');
      reply.header('X-Content-Type-Options', 'nosniff');
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'discovery.read',
        dimensions: { ip: request.ip },
      });
      const media = await options.adoptionChatService.readMedia(
        userId,
        request.params.threadId,
        request.params.mediaId,
      );
      reply.header('Content-Type', media.mimeType);
      return reply.send(media.bytes);
    },
  );

  app.get<{ Params: { threadId: string }; Querystring: ChatQuery }>(
    '/adoption/chat/:threadId',
    async (request, reply) => {
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'discovery.read',
        dimensions: { ip: request.ip },
      });
      const result = await options.adoptionChatService.readThread(
        userId,
        request.params.threadId,
        request.query,
      );
      reply.header('Cache-Control', 'no-store');
      return {
        data: result.items,
        thread: result.thread,
        pageInfo: buildPageInfo(result),
      };
    },
  );

  app.post<{ Params: { threadId: string }; Body: unknown }>(
    '/adoption/chat/:threadId/messages',
    async (request, reply) => {
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'chat.message',
        dimensions: {
          ip: request.ip,
          account: userId,
          resource: request.params.threadId,
        },
        idempotencyKey: readIdempotencyKey(request.headers['idempotency-key']),
      });
      const message = await options.adoptionChatService.sendMessage(
        userId,
        request.params.threadId,
        request.body,
        readIdempotencyKey(request.headers['idempotency-key']),
      );
      reply.header('Cache-Control', 'no-store');
      return reply.code(201).send({ data: message });
    },
  );

  app.put<{ Params: { threadId: string }; Body: unknown }>(
    '/adoption/chat/:threadId/read',
    async (request, reply) => {
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'chat.read-state',
        dimensions: {
          ip: request.ip,
          account: userId,
          resource: request.params.threadId,
        },
      });
      const readState = await options.adoptionChatService.markRead(
        userId,
        request.params.threadId,
        request.body,
      );
      reply.header('Cache-Control', 'no-store');
      return reply.send({ data: readState });
    },
  );
};

export default adoptionChatRoute;
