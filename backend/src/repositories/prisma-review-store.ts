import { randomUUID } from 'node:crypto';
import { Prisma, PrismaClient } from '@prisma/client';

import { AppError } from '../errors/app-error';
import { REVIEW_ERROR_CODES } from '../errors/error-codes';
import {
  type CreateReviewRecordInput,
  type HelpfulResult,
  type ReviewRecord,
  type ReviewReportReason,
  type ReviewReportResult,
  type ReviewSentiment,
  type ReviewSort,
  type ReviewStatus,
  type ReviewStore,
  type ReviewSummary,
} from '../services/reviews/review-service';

type PrismaExecutor = PrismaClient | Prisma.TransactionClient;

type VetIdentityRow = {
  id: string;
  externalId: string | null;
};

type ReviewRow = {
  id: string;
  vetId: string;
  userId: string;
  rating: number;
  title: string | null;
  body: string | null;
  photoUrls: unknown;
  isAnonymous: boolean;
  isVerifiedVisit: boolean;
  helpfulCount: number;
  reportCount: number;
  status: ReviewStatus;
  sentiment: ReviewSentiment;
  isFlagged: boolean;
  createdAt: Date;
  updatedAt: Date;
};

type SummaryRow = {
  averageRating: number | string | null;
  reviewCount: number | bigint;
};

type DistributionRow = {
  rating: number;
  count: number | bigint;
};

const REPORT_AUTO_HIDE_THRESHOLD = 5;

const readStringList = (value: unknown) => {
  if (Array.isArray(value)) {
    return value.map((item) => item?.toString() ?? '').filter(Boolean);
  }

  return [];
};

const readNumber = (value: number | string | null | undefined) => {
  if (typeof value === 'number') {
    return value;
  }

  if (typeof value === 'bigint') {
    return Number(value);
  }

  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number.parseFloat(value);
    return Number.isNaN(parsed) ? undefined : parsed;
  }

  return undefined;
};

const isUniqueViolation = (error: unknown) => {
  const maybeError = error as {
    code?: string;
    meta?: { code?: string; message?: string };
    message?: string;
  };

  return (
    maybeError.code === 'P2002' ||
    maybeError.meta?.code === '23505' ||
    maybeError.message?.includes('23505') ||
    maybeError.message?.toLowerCase().includes('unique') === true
  );
};

const mapRowToReview = (row: ReviewRow): ReviewRecord => ({
  id: row.id,
  vetId: row.vetId,
  userId: row.userId,
  rating: row.rating,
  title: row.title ?? undefined,
  body: row.body ?? undefined,
  photoUrls: readStringList(row.photoUrls),
  isAnonymous: row.isAnonymous,
  isVerifiedVisit: row.isVerifiedVisit,
  helpfulCount: row.helpfulCount,
  reportCount: row.reportCount,
  status: row.status,
  sentiment: row.sentiment,
  isFlagged: row.isFlagged,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
});

const emptyDistribution = (): ReviewSummary['distribution'] => ({
  1: 0,
  2: 0,
  3: 0,
  4: 0,
  5: 0,
});

const parseCursorOffset = (cursor?: string) => {
  if (!cursor) {
    return 0;
  }

  const offset = Number.parseInt(cursor, 10);
  if (!Number.isInteger(offset) || offset < 0) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      'Cursor khong hop le.',
      400,
      'cursor',
    );
  }

  return offset;
};

const resolveSortClause = (sort: ReviewSort) => {
  if (sort === 'helpful') {
    return 'r.helpful_count DESC, r.created_at DESC';
  }

  if (sort === 'rating-desc') {
    return 'r.rating DESC, r.created_at DESC';
  }

  if (sort === 'rating-asc') {
    return 'r.rating ASC, r.created_at DESC';
  }

  return 'r.created_at DESC';
};

const findVetIdentity = async (
  executor: PrismaExecutor,
  vetId: string,
): Promise<VetIdentityRow> => {
  const rows = await executor.$queryRawUnsafe<VetIdentityRow[]>(
    `
      SELECT
        id::text AS id,
        external_id AS "externalId"
      FROM public.vets
      WHERE external_id = $1 OR id::text = $1
      LIMIT 1
    `,
    vetId,
  );

  const row = rows[0];
  if (!row) {
    throw new AppError(
      REVIEW_ERROR_CODES.vetNotFound,
      'Khong tim thay phong kham de danh gia.',
      404,
      'vetId',
    );
  }

  return row;
};

const refreshVetAggregate = async (
  executor: PrismaExecutor,
  vetInternalId: string,
) => {
  await executor.$executeRawUnsafe(
    `
      UPDATE public.vets v
      SET
        average_rating = stats.average_rating,
        review_count = stats.review_count,
        updated_at = NOW()
      FROM (
        SELECT
          CASE
            WHEN COUNT(*) = 0 THEN NULL
            ELSE ROUND(AVG(rating)::numeric, 2)
          END AS average_rating,
          COUNT(*)::int AS review_count
        FROM public.reviews
        WHERE vet_id = $1::uuid AND status = 'visible'
      ) stats
      WHERE v.id = $1::uuid
    `,
    vetInternalId,
  );
};

export class PrismaReviewStore implements ReviewStore {
  constructor(private readonly prisma: PrismaClient) {}

  async createReview(input: CreateReviewRecordInput): Promise<ReviewRecord> {
    try {
      return await this.prisma.$transaction(async (tx) => {
        const vet = await findVetIdentity(tx, input.vetId);
        const rows = await tx.$queryRawUnsafe<ReviewRow[]>(
          `
            INSERT INTO public.reviews (
              id,
              vet_id,
              user_id,
              rating,
              title,
              body,
              photo_urls,
              is_anonymous,
              is_verified_visit,
              helpful_count,
              report_count,
              status,
              sentiment,
              is_flagged,
              created_at,
              updated_at
            )
            VALUES (
              $1::uuid,
              $2::uuid,
              $3::uuid,
              $4,
              $5,
              $6,
              $7::jsonb,
              $8,
              $9,
              0,
              0,
              'visible',
              'UNPROCESSED',
              false,
              $10,
              $10
            )
            RETURNING
              id::text AS id,
              COALESCE((SELECT external_id FROM public.vets WHERE id = vet_id), vet_id::text) AS "vetId",
              user_id::text AS "userId",
              rating,
              title,
              body,
              COALESCE(photo_urls, '[]'::jsonb) AS "photoUrls",
              is_anonymous AS "isAnonymous",
              is_verified_visit AS "isVerifiedVisit",
              helpful_count AS "helpfulCount",
              report_count AS "reportCount",
              status,
              sentiment,
              is_flagged AS "isFlagged",
              created_at AS "createdAt",
              updated_at AS "updatedAt"
          `,
          randomUUID(),
          vet.id,
          input.userId,
          input.rating,
          input.title ?? null,
          input.body ?? null,
          JSON.stringify(input.photoUrls),
          input.isAnonymous,
          input.isVerifiedVisit,
          input.createdAt,
        );

        await refreshVetAggregate(tx, vet.id);
        const review = rows[0];
        if (!review) {
          throw new AppError(
            REVIEW_ERROR_CODES.invalidInput,
            'Khong tao duoc review.',
            500,
          );
        }

        return mapRowToReview(review);
      });
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new AppError(
          REVIEW_ERROR_CODES.duplicateReview,
          'Ban da danh gia phong kham nay.',
          409,
          'vetId',
        );
      }

      throw error;
    }
  }

  async listReviews(
    vetId: string,
    input: { limit: number; cursor?: string; sort: ReviewSort },
  ) {
    const vet = await findVetIdentity(this.prisma, vetId);
    const offset = parseCursorOffset(input.cursor);
    const sortClause = resolveSortClause(input.sort);

    const [items, totalRows, summaryRows, distributionRows] = await Promise.all([
      this.prisma.$queryRawUnsafe<ReviewRow[]>(
        `
          SELECT
            r.id::text AS id,
            COALESCE(v.external_id, v.id::text) AS "vetId",
            r.user_id::text AS "userId",
            r.rating,
            r.title,
            r.body,
            COALESCE(r.photo_urls, '[]'::jsonb) AS "photoUrls",
            r.is_anonymous AS "isAnonymous",
            r.is_verified_visit AS "isVerifiedVisit",
            r.helpful_count AS "helpfulCount",
            r.report_count AS "reportCount",
            r.status,
            r.sentiment,
            r.is_flagged AS "isFlagged",
            r.created_at AS "createdAt",
            r.updated_at AS "updatedAt"
          FROM public.reviews r
          INNER JOIN public.vets v ON v.id = r.vet_id
          WHERE r.vet_id = $1::uuid AND r.status = 'visible'
          ORDER BY ${sortClause}
          LIMIT $2 OFFSET $3
        `,
        vet.id,
        input.limit,
        offset,
      ),
      this.prisma.$queryRawUnsafe<{ count: number | bigint }[]>(
        `
          SELECT COUNT(*) AS count
          FROM public.reviews
          WHERE vet_id = $1::uuid AND status = 'visible'
        `,
        vet.id,
      ),
      this.prisma.$queryRawUnsafe<SummaryRow[]>(
        `
          SELECT
            CASE
              WHEN COUNT(*) = 0 THEN NULL
              ELSE ROUND(AVG(rating)::numeric, 2)
            END AS "averageRating",
            COUNT(*) AS "reviewCount"
          FROM public.reviews
          WHERE vet_id = $1::uuid AND status = 'visible'
        `,
        vet.id,
      ),
      this.prisma.$queryRawUnsafe<DistributionRow[]>(
        `
          SELECT rating, COUNT(*) AS count
          FROM public.reviews
          WHERE vet_id = $1::uuid AND status = 'visible'
          GROUP BY rating
        `,
        vet.id,
      ),
    ]);

    const distribution = emptyDistribution();
    distributionRows.forEach((row) => {
      distribution[row.rating as 1 | 2 | 3 | 4 | 5] = Number(row.count);
    });
    const total = Number(totalRows[0]?.count ?? 0);
    const nextOffset = offset + items.length;
    const summaryRow = summaryRows[0];

    return {
      items: items.map(mapRowToReview),
      summary: {
        averageRating: readNumber(summaryRow?.averageRating) ?? null,
        reviewCount: Number(summaryRow?.reviewCount ?? 0),
        distribution,
      },
      total,
      nextCursor: nextOffset < total ? `${nextOffset}` : undefined,
    };
  }

  async toggleHelpful(
    reviewId: string,
    userId: string,
    toggledAt: Date,
  ): Promise<HelpfulResult> {
    return this.prisma.$transaction(async (tx) => {
      const reviewRows = await tx.$queryRawUnsafe<{ id: string }[]>(
        `
          SELECT id::text AS id
          FROM public.reviews
          WHERE id = $1::uuid AND status = 'visible'
          LIMIT 1
        `,
        reviewId,
      );
      if (!reviewRows[0]) {
        throw new AppError(
          REVIEW_ERROR_CODES.notFound,
          'Khong tim thay review.',
          404,
        );
      }

      const voteRows = await tx.$queryRawUnsafe<{ id: string }[]>(
        `
          SELECT id::text AS id
          FROM public.review_helpful_votes
          WHERE review_id = $1::uuid AND user_id = $2::uuid
          LIMIT 1
        `,
        reviewId,
        userId,
      );
      const hasVoted = Boolean(voteRows[0]);

      if (hasVoted) {
        await tx.$executeRawUnsafe(
          `
            DELETE FROM public.review_helpful_votes
            WHERE review_id = $1::uuid AND user_id = $2::uuid
          `,
          reviewId,
          userId,
        );
      } else {
        await tx.$executeRawUnsafe(
          `
            INSERT INTO public.review_helpful_votes (id, review_id, user_id, created_at)
            VALUES ($1::uuid, $2::uuid, $3::uuid, $4)
          `,
          randomUUID(),
          reviewId,
          userId,
          toggledAt,
        );
      }

      const rows = await tx.$queryRawUnsafe<{ helpfulCount: number }[]>(
        `
          UPDATE public.reviews
          SET
            helpful_count = GREATEST(
              helpful_count + CASE WHEN $2::boolean THEN -1 ELSE 1 END,
              0
            ),
            updated_at = $3
          WHERE id = $1::uuid
          RETURNING helpful_count AS "helpfulCount"
        `,
        reviewId,
        hasVoted,
        toggledAt,
      );

      return {
        reviewId,
        helpfulCount: rows[0]?.helpfulCount ?? 0,
        hasVoted: !hasVoted,
      };
    });
  }

  async reportReview(input: {
    reviewId: string;
    reporterId: string;
    reason: ReviewReportReason;
    description?: string;
    createdAt: Date;
  }): Promise<ReviewReportResult> {
    try {
      return await this.prisma.$transaction(async (tx) => {
        const reviewRows = await tx.$queryRawUnsafe<
          { id: string; vetId: string; status: ReviewStatus }[]
        >(
          `
            SELECT
              id::text AS id,
              vet_id::text AS "vetId",
              status
            FROM public.reviews
            WHERE id = $1::uuid
            LIMIT 1
          `,
          input.reviewId,
        );
        const review = reviewRows[0];
        if (!review) {
          throw new AppError(
            REVIEW_ERROR_CODES.notFound,
            'Khong tim thay review.',
            404,
          );
        }

        const reportId = randomUUID();
        await tx.$executeRawUnsafe(
          `
            INSERT INTO public.review_reports (
              id,
              review_id,
              reporter_id,
              reason,
              description,
              status,
              created_at,
              updated_at
            )
            VALUES (
              $1::uuid,
              $2::uuid,
              $3::uuid,
              $4::"ReviewReportReason",
              $5,
              'pending',
              $6,
              $6
            )
          `,
          reportId,
          input.reviewId,
          input.reporterId,
          input.reason,
          input.description ?? null,
          input.createdAt,
        );

        const rows = await tx.$queryRawUnsafe<
          { reportCount: number; reviewStatus: ReviewStatus }[]
        >(
          `
            UPDATE public.reviews
            SET
              report_count = (
                SELECT COUNT(*)::int
                FROM public.review_reports
                WHERE review_id = $1::uuid
              ),
              status = CASE
                WHEN (
                  SELECT COUNT(*)
                  FROM public.review_reports
                  WHERE review_id = $1::uuid
                ) >= $2 THEN 'hidden'::"ReviewStatus"
                ELSE status
              END,
              updated_at = $3
            WHERE id = $1::uuid
            RETURNING report_count AS "reportCount", status AS "reviewStatus"
          `,
          input.reviewId,
          REPORT_AUTO_HIDE_THRESHOLD,
          input.createdAt,
        );

        const result = rows[0];
        if (result?.reviewStatus === 'hidden' && review.status !== 'hidden') {
          await refreshVetAggregate(tx, review.vetId);
        }

        return {
          reportId,
          reviewId: input.reviewId,
          reportCount: result?.reportCount ?? 0,
          reviewStatus: result?.reviewStatus ?? review.status,
        };
      });
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new AppError(
          REVIEW_ERROR_CODES.duplicateReport,
          'Ban da bao cao review nay.',
          409,
          'reviewId',
        );
      }

      throw error;
    }
  }
}
