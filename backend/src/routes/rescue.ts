import { type FastifyPluginAsync } from 'fastify';

import { AppError } from '../errors/app-error';
import {
  AUTH_ERROR_CODES,
  RESCUE_ERROR_CODES,
} from '../errors/error-codes';
import { type AppFeatureAvailability } from '../config/env';
import { type AuthService } from '../services/auth/auth-service';
import { type RescueMediaService } from '../services/rescue/rescue-media-service';
import {
  type RescueCaseListQuery,
  type RescueReadService,
} from '../services/rescue/rescue-read-service';
import { type RescueWriteService } from '../services/rescue/rescue-write-service';
import { type ActionQuotaGuard } from '../security/distributed-action-quota';

type RescueRouteOptions = {
  authService: AuthService;
  actionQuotaGuard: ActionQuotaGuard;
  rescueMediaService: RescueMediaService;
  rescueReadService: RescueReadService;
  rescueWriteService: RescueWriteService;
  featureAvailability: AppFeatureAvailability;
};

type DiscussionQuery = { cursor?: unknown; limit?: unknown };

const readOptionalViewerUserId = async (
  authService: AuthService,
  authorization?: string,
) => {
  if (!authorization?.startsWith('Bearer ')) return undefined;
  const accessToken = authorization.slice('Bearer '.length).trim();
  if (!accessToken) return undefined;
  try {
    return (await authService.verifyAccessToken(accessToken)).userId;
  } catch {
    // These endpoints are public. An invalid optional token is anonymous and
    // must never unlock viewer-specific or private fields.
    return undefined;
  }
};

const setPublicReadHeaders = (reply: {
  header: (name: string, value: string) => unknown;
}) => {
  reply.header('Cache-Control', 'no-store');
  reply.header('Vary', 'Authorization');
};

const requireViewerUserId = async (
  authService: AuthService,
  authorization?: string,
) => {
  if (!authorization?.startsWith('Bearer ')) {
    throw new AppError(
      AUTH_ERROR_CODES.unauthorized,
      'Ban can dang nhap de su dung tinh nang Rescue nay.',
      401,
    );
  }
  const accessToken = authorization.slice('Bearer '.length).trim();
  if (!accessToken) {
    throw new AppError(
      AUTH_ERROR_CODES.unauthorized,
      'Bearer access token khong hop le.',
      401,
    );
  }
  return (await authService.verifyAccessToken(accessToken)).userId;
};

const readIdempotencyKey = (value: string | string[] | undefined) =>
  Array.isArray(value) ? undefined : value;

const buildPageInfo = (result: { nextCursor?: string; limit: number }) => ({
  nextCursor: result.nextCursor ?? null,
  hasMore: result.nextCursor !== undefined,
  limit: result.limit,
});

const featureUnavailable = (): never => {
  throw new AppError(
    RESCUE_ERROR_CODES.featureUnavailable,
    'Tinh nang Rescue chua duoc bat.',
    503,
  );
};

const rescueRoute: FastifyPluginAsync<RescueRouteOptions> = async (
  app,
  options,
) => {
  app.get<{ Querystring: RescueCaseListQuery }>(
    '/rescue/cases',
    async (request, reply) => {
      if (!options.featureAvailability.rescueBrowse) featureUnavailable();
      const viewerUserId = await readOptionalViewerUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'discovery.read',
        dimensions: { ip: request.ip },
      });
      const result = await options.rescueReadService.listCases(
        request.query,
        viewerUserId,
      );
      setPublicReadHeaders(reply);
      return {
        data: result.items,
        pageInfo: buildPageInfo(result),
      };
    },
  );

  app.get<{ Params: { caseId: string } }>(
    '/rescue/cases/:caseId',
    async (request, reply) => {
      if (!options.featureAvailability.rescueBrowse) featureUnavailable();
      const viewerUserId = await readOptionalViewerUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'discovery.read',
        dimensions: { ip: request.ip },
      });
      const rescueCase = await options.rescueReadService.getCase(
        request.params.caseId,
        viewerUserId,
      );
      setPublicReadHeaders(reply);
      return { data: rescueCase };
    },
  );

  app.post<{ Body: unknown }>('/rescue/case-drafts', async (request, reply) => {
    if (!options.featureAvailability.rescueCreate) featureUnavailable();
    const userId = await requireViewerUserId(
      options.authService,
      request.headers.authorization,
    );
    await options.actionQuotaGuard.enforce({
      action: 'rescue.write',
      dimensions: { ip: request.ip, account: userId },
      idempotencyKey: readIdempotencyKey(request.headers['idempotency-key']),
    });
    const draft = await options.rescueWriteService.createDraft(
      userId,
      request.body,
      readIdempotencyKey(request.headers['idempotency-key']),
    );
    reply.header('Cache-Control', 'no-store');
    return reply.code(201).send({ data: draft });
  });

  app.patch<{ Params: { draftId: string }; Body: unknown }>(
    '/rescue/case-drafts/:draftId',
    async (request, reply) => {
      if (!options.featureAvailability.rescueCreate) featureUnavailable();
      const userId = await requireViewerUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'rescue.write',
        dimensions: {
          ip: request.ip,
          account: userId,
          resource: request.params.draftId,
        },
      });
      const draft = await options.rescueWriteService.updateDraft(
        userId,
        request.params.draftId,
        request.body,
      );
      reply.header('Cache-Control', 'no-store');
      return { data: draft };
    },
  );

  app.post<{ Params: { draftId: string }; Body: unknown }>(
    '/rescue/case-drafts/:draftId/publish',
    async (request, reply) => {
      if (!options.featureAvailability.rescueCreate) featureUnavailable();
      const userId = await requireViewerUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'rescue.write',
        dimensions: {
          ip: request.ip,
          account: userId,
          resource: request.params.draftId,
        },
        idempotencyKey: readIdempotencyKey(request.headers['idempotency-key']),
      });
      const rescueCase = await options.rescueWriteService.publishDraft(
        userId,
        request.params.draftId,
        request.body,
        readIdempotencyKey(request.headers['idempotency-key']),
      );
      reply.header('Cache-Control', 'no-store');
      return reply.code(201).send({ data: rescueCase });
    },
  );

  app.post<{ Params: { caseId: string }; Body: unknown }>(
    '/rescue/cases/:caseId/comments',
    async (request, reply) => {
      if (!options.featureAvailability.rescueBrowse) featureUnavailable();
      const userId = await requireViewerUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'rescue.comment',
        dimensions: {
          ip: request.ip,
          account: userId,
          resource: request.params.caseId,
        },
        idempotencyKey: readIdempotencyKey(request.headers['idempotency-key']),
      });
      const comment = await options.rescueWriteService.createComment(
        userId,
        request.params.caseId,
        request.body,
        readIdempotencyKey(request.headers['idempotency-key']),
      );
      reply.header('Cache-Control', 'no-store');
      return reply.code(201).send({ data: comment });
    },
  );

  app.get<{ Params: { caseId: string }; Querystring: DiscussionQuery }>(
    '/rescue/cases/:caseId/discussion',
    async (request, reply) => {
      if (!options.featureAvailability.rescueBrowse) featureUnavailable();
      await requireViewerUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'discovery.read',
        dimensions: { ip: request.ip },
      });
      const result = await options.rescueWriteService.listDiscussion(
        request.params.caseId,
        request.query,
      );
      reply.header('Cache-Control', 'no-store');
      return {
        data: result.items,
        pageInfo: buildPageInfo(result),
      };
    },
  );

  app.patch<{ Params: { caseId: string }; Body: unknown }>(
    '/rescue/cases/:caseId/status',
    async (request, reply) => {
      if (!options.featureAvailability.rescueBrowse) featureUnavailable();
      const userId = await requireViewerUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'rescue.write',
        dimensions: {
          ip: request.ip,
          account: userId,
          resource: request.params.caseId,
        },
        idempotencyKey: readIdempotencyKey(request.headers['idempotency-key']),
      });
      const rescueCase = await options.rescueWriteService.updateStatus(
        userId,
        request.params.caseId,
        request.body,
        readIdempotencyKey(request.headers['idempotency-key']),
      );
      reply.header('Cache-Control', 'no-store');
      return { data: rescueCase };
    },
  );

  app.post<{ Body: unknown }>('/media/uploads', async (request, reply) => {
    const mediaPurpose = (request.body as { purpose?: unknown } | undefined)
      ?.purpose;
    if (
      (mediaPurpose === 'rescue_case' &&
        !options.featureAvailability.rescueCreate) ||
      (mediaPurpose === 'rescue_comment' &&
        !options.featureAvailability.rescueBrowse)
    ) {
      featureUnavailable();
    }
    const userId = await requireViewerUserId(
      options.authService,
      request.headers.authorization,
    );
    const uploadBody = request.body as { sizeBytes?: unknown };
    const quotaDecision = await options.actionQuotaGuard.enforce({
      action: 'upload.ticket',
      dimensions: { ip: request.ip, account: userId },
      units: {
        bytes:
          typeof uploadBody?.sizeBytes === 'number'
            ? uploadBody.sizeBytes
            : Number.NaN,
      },
      idempotencyKey: readIdempotencyKey(request.headers['idempotency-key']),
    });
    let ticket;
    try {
      ticket = await options.rescueMediaService.requestUpload(
        userId,
        request.body,
        readIdempotencyKey(request.headers['idempotency-key']),
      );
      if (quotaDecision.lease) {
        await options.actionQuotaGuard.bindLease(
          quotaDecision.lease,
          ticket.mediaId,
        );
      }
    } catch (error) {
      if (quotaDecision.lease) {
        try {
          await options.actionQuotaGuard.cancelLease(quotaDecision.lease);
        } catch {
          request.log.warn({
            event: 'quota_lease_cleanup_deferred',
            action: 'upload.ticket',
            requestId: request.id,
          });
        }
      }
      throw error;
    }
    reply.header('Cache-Control', 'no-store');
    return reply.code(201).send({ data: ticket });
  });

  app.post<{ Params: { mediaId: string }; Body: unknown }>(
    '/media/uploads/:mediaId/complete',
    async (request, reply) => {
      const userId = await requireViewerUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'rescue.write',
        dimensions: {
          ip: request.ip,
          account: userId,
          resource: request.params.mediaId,
        },
        idempotencyKey: readIdempotencyKey(request.headers['idempotency-key']),
      });
      const media = await options.rescueMediaService.completeUpload(
        userId,
        request.params.mediaId,
        request.body,
        readIdempotencyKey(request.headers['idempotency-key']),
      );
      try {
        await options.actionQuotaGuard.releaseLease({
          action: 'upload.ticket',
          dimensions: { account: userId },
          resourceId: request.params.mediaId,
        });
      } catch {
        request.log.warn({
          event: 'quota_lease_cleanup_deferred',
          action: 'upload.ticket',
          requestId: request.id,
        });
      }
      reply.header('Cache-Control', 'no-store');
      return { data: media };
    },
  );
};

export default rescueRoute;
