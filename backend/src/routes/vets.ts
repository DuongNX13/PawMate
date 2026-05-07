import {
  type FastifyPluginAsync,
  type FastifyReply,
  type FastifyRequest,
} from 'fastify';

import { AppError } from '../errors/app-error';
import { type AppConfig } from '../config/env';
import { REVIEW_ERROR_CODES, VET_ERROR_CODES } from '../errors/error-codes';
import {
  readLocalReviewPhoto,
  resolveReviewPhotoContentType,
  type UploadReviewPhotoInput,
  uploadReviewPhoto,
} from '../infrastructure/review-photo-storage';
import { type AuthService } from '../services/auth/auth-service';
import {
  type CreateReviewInput,
  type ReviewListInput,
  type ReviewService,
  type ReviewSort,
} from '../services/reviews/review-service';
import {
  type VetNearbyInput,
  type VetSearchInput,
  type VetService,
} from '../services/vets/vet-service';

type VetRouteOptions = {
  config: AppConfig;
  authService: AuthService;
  vetService: VetService;
  reviewService: ReviewService;
};

type VetSearchQuerystring = {
  q?: string;
  city?: string;
  district?: string;
  limit?: string;
  cursor?: string;
  is24h?: string;
  isOpenNow?: string;
  minRating?: string;
  sort?: string;
};

type VetNearbyQuerystring = {
  lat?: string;
  lng?: string;
  radius?: string;
  limit?: string;
  cursor?: string;
  is24h?: string;
  isOpenNow?: string;
  minRating?: string;
};

type ReviewListQuerystring = {
  limit?: string;
  cursor?: string;
  sort?: string;
};

type ReportReviewBody = {
  reason: string;
  description?: string;
};

type SearchSort = NonNullable<VetSearchInput['sort']>;

const parseInteger = (value: string | undefined, field: string) => {
  if (value === undefined) {
    return undefined;
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed)) {
    throw new AppError(
      VET_ERROR_CODES.invalidQuery,
      `Trường ${field} phải là số nguyên hợp lệ.`,
      400,
      field,
    );
  }

  return parsed;
};

const parseBoolean = (value: string | undefined, field: string) => {
  if (value === undefined) {
    return undefined;
  }

  const normalized = value.trim().toLowerCase();
  if (normalized === 'true' || normalized === '1') {
    return true;
  }
  if (normalized === 'false' || normalized === '0') {
    return false;
  }

  throw new AppError(
    VET_ERROR_CODES.invalidQuery,
    `Trường ${field} chỉ nhận true/false.`,
    400,
    field,
  );
};

const parseMinRating = (value: string | undefined) => {
  if (value === undefined) {
    return undefined;
  }

  const parsed = Number.parseFloat(value);
  if (Number.isNaN(parsed) || parsed < 1 || parsed > 5) {
    throw new AppError(
      VET_ERROR_CODES.invalidQuery,
      'Trường minRating phải nằm trong khoảng 1-5.',
      400,
      'minRating',
    );
  }

  return parsed;
};

const parseSort = (value: string | undefined): SearchSort | undefined => {
  if (value === undefined || value.trim().length === 0) {
    return undefined;
  }

  const normalized = value.trim().toLowerCase();
  const allowed: SearchSort[] = ['curated', 'rating-desc', 'name-asc'];
  if (!allowed.includes(normalized as SearchSort)) {
    throw new AppError(
      VET_ERROR_CODES.invalidQuery,
      'Trường sort chỉ hỗ trợ curated, rating-desc hoặc name-asc.',
      400,
      'sort',
    );
  }

  return normalized as SearchSort;
};

const parseReviewSort = (value: string | undefined): ReviewSort | undefined => {
  if (value === undefined || value.trim().length === 0) {
    return undefined;
  }

  const normalized = value.trim().toLowerCase();
  const allowed: ReviewSort[] = [
    'newest',
    'helpful',
    'rating-desc',
    'rating-asc',
  ];
  if (!allowed.includes(normalized as ReviewSort)) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      'Truong sort chi ho tro newest, helpful, rating-desc hoac rating-asc.',
      400,
      'sort',
    );
  }

  return normalized as ReviewSort;
};

const parseLatitude = (value: string | undefined) => {
  if (value === undefined) {
    throw new AppError(
      VET_ERROR_CODES.invalidQuery,
      'Trường lat là bắt buộc.',
      400,
      'lat',
    );
  }

  const parsed = Number.parseFloat(value);
  if (Number.isNaN(parsed) || parsed < 8 || parsed > 24) {
    throw new AppError(
      VET_ERROR_CODES.invalidQuery,
      'Trường lat phải nằm trong khoảng 8-24.',
      400,
      'lat',
    );
  }

  return parsed;
};

const parseLongitude = (value: string | undefined) => {
  if (value === undefined) {
    throw new AppError(
      VET_ERROR_CODES.invalidQuery,
      'Trường lng là bắt buộc.',
      400,
      'lng',
    );
  }

  const parsed = Number.parseFloat(value);
  if (Number.isNaN(parsed) || parsed < 102 || parsed > 110) {
    throw new AppError(
      VET_ERROR_CODES.invalidQuery,
      'Trường lng phải nằm trong khoảng 102-110.',
      400,
      'lng',
    );
  }

  return parsed;
};

const parseRadius = (value: string | undefined) => {
  if (value === undefined) {
    return undefined;
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1000 || parsed > 10000) {
    throw new AppError(
      VET_ERROR_CODES.invalidQuery,
      'Trường radius phải nằm trong khoảng 1000-10000.',
      400,
      'radius',
    );
  }

  return parsed;
};

const parseSearchInput = (query: VetSearchQuerystring): VetSearchInput => ({
  q: query.q,
  city: query.city,
  district: query.district,
  limit: parseInteger(query.limit, 'limit'),
  cursor: query.cursor?.trim() || undefined,
  is24h: parseBoolean(query.is24h, 'is24h'),
  isOpenNow: parseBoolean(query.isOpenNow, 'isOpenNow'),
  minRating: parseMinRating(query.minRating),
  sort: parseSort(query.sort),
});

const parseNearbyInput = (query: VetNearbyQuerystring): VetNearbyInput => ({
  latitude: parseLatitude(query.lat),
  longitude: parseLongitude(query.lng),
  radius: parseRadius(query.radius),
  limit: parseInteger(query.limit, 'limit'),
  cursor: query.cursor?.trim() || undefined,
  is24h: parseBoolean(query.is24h, 'is24h'),
  isOpenNow: parseBoolean(query.isOpenNow, 'isOpenNow'),
  minRating: parseMinRating(query.minRating),
});

const parseReviewListInput = (
  query: ReviewListQuerystring,
): ReviewListInput => ({
  limit: parseInteger(query.limit, 'limit'),
  cursor: query.cursor?.trim() || undefined,
  sort: parseReviewSort(query.sort),
});

const getUserIdFromRequest = (
  authService: AuthService,
  authorization?: string,
) => {
  if (!authorization?.startsWith('Bearer ')) {
    throw new AppError(
      REVIEW_ERROR_CODES.unauthorized,
      'Ban can dang nhap de tiep tuc.',
      401,
    );
  }

  const accessToken = authorization.replace('Bearer ', '').trim();
  return authService.verifyAccessToken(accessToken).userId;
};

type VetSearchRequest = FastifyRequest<{
  Querystring: VetSearchQuerystring;
}> & {
  vetSearchInput?: VetSearchInput;
};

type VetNearbyRequest = FastifyRequest<{
  Querystring: VetNearbyQuerystring;
}> & {
  vetNearbyInput?: VetNearbyInput;
};

const validateSearchQuery = (
  request: VetSearchRequest,
  _reply: FastifyReply,
  done: (error?: Error) => void,
) => {
  try {
    request.vetSearchInput = parseSearchInput(request.query);
    done();
  } catch (error) {
    done(error as Error);
  }
};

const validateNearbyQuery = (
  request: VetNearbyRequest,
  _reply: FastifyReply,
  done: (error?: Error) => void,
) => {
  try {
    request.vetNearbyInput = parseNearbyInput(request.query);
    done();
  } catch (error) {
    done(error as Error);
  }
};

const vetRoute: FastifyPluginAsync<VetRouteOptions> = async (app, options) => {
  app.get<{
    Params: { vetId: string; userId: string; fileName: string };
  }>(
    '/assets/review-photos/:vetId/:userId/:fileName',
    async (request, reply) => {
      try {
        const fileContent = await readLocalReviewPhoto(
          request.params.vetId,
          request.params.userId,
          request.params.fileName,
        );
        reply.type(resolveReviewPhotoContentType(request.params.fileName));
        return await reply.send(fileContent);
      } catch {
        throw new AppError(
          REVIEW_ERROR_CODES.notFound,
          'Khong tim thay anh review.',
          404,
        );
      }
    },
  );

  app.get<{ Querystring: VetSearchQuerystring }>(
    '/vets/search',
    {
      preHandler: validateSearchQuery,
    },
    async (request) => {
      const parsedRequest = request as VetSearchRequest;
      const result = await options.vetService.search(
        parsedRequest.vetSearchInput ?? parseSearchInput(request.query),
      );

      return {
        data: result.items,
        pagination: {
          total: result.total,
          limit: result.limit,
          nextCursor: result.nextCursor,
        },
      };
    },
  );

  app.get<{ Querystring: VetNearbyQuerystring }>(
    '/vets/nearby',
    {
      preHandler: validateNearbyQuery,
    },
    async (request) => {
      const parsedRequest = request as VetNearbyRequest;
      const result = await options.vetService.nearby(
        parsedRequest.vetNearbyInput ?? parseNearbyInput(request.query),
      );

      return {
        data: result.items,
        pagination: {
          total: result.total,
          limit: result.limit,
          nextCursor: result.nextCursor,
        },
      };
    },
  );

  app.get<{
    Params: { vetId: string };
    Querystring: ReviewListQuerystring;
  }>('/vets/:vetId/reviews', async (request) => {
    const result = await options.reviewService.list(
      request.params.vetId,
      parseReviewListInput(request.query),
    );

    return {
      data: result.items,
      summary: result.summary,
      pagination: result.pagination,
    };
  });

  app.post<{ Params: { vetId: string }; Body: CreateReviewInput }>(
    '/vets/:vetId/reviews',
    async (request, reply) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      const review = await options.reviewService.create(
        request.params.vetId,
        userId,
        request.body,
      );
      reply.code(201).send({ data: review });
    },
  );

  app.post<{
    Params: { vetId: string };
    Body: UploadReviewPhotoInput;
  }>('/vets/:vetId/reviews/photos', async (request, reply) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    await options.vetService.get(request.params.vetId);
    const result = await uploadReviewPhoto(
      options.config,
      request.params.vetId,
      userId,
      request.body,
    );
    reply.code(201).send({ data: result });
  });

  app.get<{ Params: { vetId: string } }>('/vets/:vetId', async (request) => ({
    data: await options.vetService.get(request.params.vetId),
  }));

  app.put<{ Params: { reviewId: string } }>(
    '/reviews/:reviewId/helpful',
    async (request) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      return {
        data: await options.reviewService.toggleHelpful(
          request.params.reviewId,
          userId,
        ),
      };
    },
  );

  app.post<{ Params: { reviewId: string }; Body: ReportReviewBody }>(
    '/reviews/:reviewId/report',
    async (request, reply) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      const result = await options.reviewService.report(
        request.params.reviewId,
        userId,
        request.body,
      );
      reply.code(201).send({ data: result });
    },
  );
};

export default vetRoute;
