import { type FastifyPluginAsync } from 'fastify';

import { AppError } from '../errors/app-error';
import { AUTH_ERROR_CODES } from '../errors/error-codes';
import {
  type AdoptionListQuery,
  type AdoptionService,
} from '../services/adoption/adoption-service';
import { type AuthService } from '../services/auth/auth-service';
import { type ActionQuotaGuard } from '../security/distributed-action-quota';

type AdoptionRouteOptions = {
  authService: AuthService;
  adoptionService: AdoptionService;
  actionQuotaGuard: ActionQuotaGuard;
};

const requireUserId = async (
  authService: AuthService,
  authorization?: string,
) => {
  if (!authorization?.startsWith('Bearer ')) {
    throw new AppError(
      AUTH_ERROR_CODES.unauthorized,
      'Ban can dang nhap de su dung tinh nang nhan nuoi.',
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

const adoptionRoute: FastifyPluginAsync<AdoptionRouteOptions> = async (
  app,
  options,
) => {
  app.get('/adoption/requests', async (request, reply) => {
    const userId = await requireUserId(
      options.authService,
      request.headers.authorization,
    );
    await options.actionQuotaGuard.enforce({
      action: 'discovery.read',
      dimensions: { ip: request.ip },
    });
    const requests = await options.adoptionService.listRequests(userId);
    reply.header('Cache-Control', 'no-store');
    return { data: requests };
  });

  app.get<{ Querystring: AdoptionListQuery }>(
    '/adoption/listings',
    async (request, reply) => {
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'discovery.read',
        dimensions: { ip: request.ip },
      });
      const result = await options.adoptionService.listListings(
        userId,
        request.query,
      );
      reply.header('Cache-Control', 'no-store');
      return {
        data: result.items,
        pageInfo: buildPageInfo(result),
      };
    },
  );

  app.get<{ Params: { listingId: string } }>(
    '/adoption/listings/:listingId',
    async (request, reply) => {
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'discovery.read',
        dimensions: { ip: request.ip },
      });
      const listing = await options.adoptionService.getListing(
        userId,
        request.params.listingId,
      );
      reply.header('Cache-Control', 'no-store');
      return { data: listing };
    },
  );

  app.post<{ Params: { listingId: string }; Body: unknown }>(
    '/adoption/listings/:listingId/decisions',
    async (request, reply) => {
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'adoption.decision',
        dimensions: {
          ip: request.ip,
          account: userId,
          resource: request.params.listingId,
        },
        idempotencyKey: readIdempotencyKey(request.headers['idempotency-key']),
      });
      const decision = await options.adoptionService.recordDecision(
        userId,
        request.params.listingId,
        request.body,
        readIdempotencyKey(request.headers['idempotency-key']),
      );
      reply.header('Cache-Control', 'no-store');
      return reply.code(201).send({ data: decision });
    },
  );

  app.post<{ Params: { listingId: string }; Body: unknown }>(
    '/adoption/listings/:listingId/requests',
    async (request, reply) => {
      const userId = await requireUserId(
        options.authService,
        request.headers.authorization,
      );
      await options.actionQuotaGuard.enforce({
        action: 'adoption.request',
        dimensions: {
          ip: request.ip,
          account: userId,
          resource: request.params.listingId,
        },
        idempotencyKey: readIdempotencyKey(request.headers['idempotency-key']),
      });
      const adoptionRequest = await options.adoptionService.createRequest(
        userId,
        request.params.listingId,
        request.body,
        readIdempotencyKey(request.headers['idempotency-key']),
      );
      reply.header('Cache-Control', 'no-store');
      return reply.code(201).send({ data: adoptionRequest });
    },
  );
};

export default adoptionRoute;
