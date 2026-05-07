import { randomUUID } from 'node:crypto';

import { AppError } from '../../errors/app-error';
import { REVIEW_ERROR_CODES } from '../../errors/error-codes';
import { type VetService } from '../vets/vet-service';

export type ReviewStatus = 'visible' | 'hidden';
export type ReviewSentiment = 'UNPROCESSED' | 'POSITIVE' | 'NEGATIVE' | 'NEUTRAL';
export type ReviewReportReason =
  | 'spam'
  | 'false_information'
  | 'abusive'
  | 'off_topic'
  | 'other';
export type ReviewReportStatus = 'pending' | 'approved' | 'rejected';
export type ReviewSort = 'newest' | 'helpful' | 'rating-desc' | 'rating-asc';

export type CreateReviewInput = {
  rating: number;
  title?: string;
  body?: string;
  photoUrls?: string[];
  isAnonymous?: boolean;
  isVerifiedVisit?: boolean;
};

export type CreateReviewRecordInput = {
  vetId: string;
  userId: string;
  rating: number;
  title?: string;
  body?: string;
  photoUrls: string[];
  isAnonymous: boolean;
  isVerifiedVisit: boolean;
  createdAt: Date;
};

export type ReviewRecord = {
  id: string;
  vetId: string;
  userId: string;
  rating: number;
  title?: string;
  body?: string;
  photoUrls: string[];
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

export type PublicReview = Omit<ReviewRecord, 'userId'> & {
  reviewer: {
    id: string;
    displayName: string;
  };
};

export type ReviewSummary = {
  averageRating: number | null;
  reviewCount: number;
  distribution: Record<1 | 2 | 3 | 4 | 5, number>;
};

export type ReviewListInput = {
  limit?: number;
  cursor?: string;
  sort?: ReviewSort;
};

export type ReviewListResult = {
  items: PublicReview[];
  summary: ReviewSummary;
  pagination: {
    total: number;
    limit: number;
    nextCursor?: string;
  };
};

export type HelpfulResult = {
  reviewId: string;
  helpfulCount: number;
  hasVoted: boolean;
};

export type ReviewReportResult = {
  reportId: string;
  reviewId: string;
  reportCount: number;
  reviewStatus: ReviewStatus;
};

export type ReviewStore = {
  createReview: (input: CreateReviewRecordInput) => Promise<ReviewRecord>;
  listReviews: (
    vetId: string,
    input: { limit: number; cursor?: string; sort: ReviewSort },
  ) => Promise<{
    items: ReviewRecord[];
    summary: ReviewSummary;
    total: number;
    nextCursor?: string;
  }>;
  toggleHelpful: (
    reviewId: string,
    userId: string,
    toggledAt: Date,
  ) => Promise<HelpfulResult>;
  reportReview: (
    input: {
      reviewId: string;
      reporterId: string;
      reason: ReviewReportReason;
      description?: string;
      createdAt: Date;
    },
  ) => Promise<ReviewReportResult>;
};

type ReviewServiceOptions = {
  vetReader: Pick<VetService, 'get'>;
  store?: ReviewStore;
  now?: () => Date;
};

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const REPORT_AUTO_HIDE_THRESHOLD = 5;

const emptyDistribution = (): ReviewSummary['distribution'] => ({
  1: 0,
  2: 0,
  3: 0,
  4: 0,
  5: 0,
});

const sanitizeOptionalText = (value: string | undefined) => {
  const trimmed = value?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : undefined;
};

const validateLimit = (limit?: number) => {
  if (limit === undefined) {
    return DEFAULT_LIMIT;
  }

  if (!Number.isInteger(limit) || limit <= 0 || limit > MAX_LIMIT) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      `Limit phai nam trong khoang 1-${MAX_LIMIT}.`,
      400,
      'limit',
    );
  }

  return limit;
};

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

const validateCreateReviewInput = (input: CreateReviewInput) => {
  if (!Number.isInteger(input.rating) || input.rating < 1 || input.rating > 5) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidRating,
      'Rating phai la so nguyen tu 1 den 5.',
      400,
      'rating',
    );
  }

  const body = sanitizeOptionalText(input.body);
  if (body && body.length < 10) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      'Noi dung review phai co it nhat 10 ky tu neu duoc nhap.',
      400,
      'body',
    );
  }

  const photoUrls = input.photoUrls ?? [];
  if (!Array.isArray(photoUrls) || photoUrls.length > 3) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      'Moi review chi duoc dinh kem toi da 3 anh.',
      400,
      'photoUrls',
    );
  }

  const invalidPhotoUrl = photoUrls.find(
    (url) => typeof url !== 'string' || url.trim().length === 0,
  );
  if (invalidPhotoUrl !== undefined) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidInput,
      'Duong dan anh review khong hop le.',
      400,
      'photoUrls',
    );
  }

  return {
    rating: input.rating,
    title: sanitizeOptionalText(input.title),
    body,
    photoUrls: photoUrls.map((url) => url.trim()),
    isAnonymous: Boolean(input.isAnonymous),
    isVerifiedVisit: Boolean(input.isVerifiedVisit),
  };
};

const validateReason = (reason: string): ReviewReportReason => {
  const allowed: ReviewReportReason[] = [
    'spam',
    'false_information',
    'abusive',
    'off_topic',
    'other',
  ];

  if (!allowed.includes(reason as ReviewReportReason)) {
    throw new AppError(
      REVIEW_ERROR_CODES.invalidReportReason,
      'Ly do bao cao review khong hop le.',
      400,
      'reason',
    );
  }

  return reason as ReviewReportReason;
};

const mapToPublicReview = (review: ReviewRecord): PublicReview => {
  const { userId, ...publicFields } = review;

  return {
    ...publicFields,
    reviewer: {
      id: review.isAnonymous ? 'anonymous' : userId,
      displayName: review.isAnonymous ? 'Nguoi dung PawMate' : 'Thanh vien PawMate',
    },
  };
};

const createInMemoryReviewStore = (): ReviewStore => {
  const reviews = new Map<string, ReviewRecord>();
  const reviewByVetAndUser = new Map<string, string>();
  const helpfulVotes = new Set<string>();
  const reportByReviewAndUser = new Map<string, string>();

  const summarize = (vetId: string): ReviewSummary => {
    const visibleReviews = [...reviews.values()].filter(
      (review) => review.vetId === vetId && review.status === 'visible',
    );
    const distribution = emptyDistribution();
    visibleReviews.forEach((review) => {
      distribution[review.rating as 1 | 2 | 3 | 4 | 5] += 1;
    });

    const ratingSum = visibleReviews.reduce(
      (total, review) => total + review.rating,
      0,
    );

    return {
      averageRating:
        visibleReviews.length > 0
          ? Number((ratingSum / visibleReviews.length).toFixed(2))
          : null,
      reviewCount: visibleReviews.length,
      distribution,
    };
  };

  return {
    async createReview(input) {
      const duplicateKey = `${input.vetId}:${input.userId}`;
      if (reviewByVetAndUser.has(duplicateKey)) {
        throw new AppError(
          REVIEW_ERROR_CODES.duplicateReview,
          'Ban da danh gia phong kham nay.',
          409,
          'vetId',
        );
      }

      const review: ReviewRecord = {
        id: randomUUID(),
        vetId: input.vetId,
        userId: input.userId,
        rating: input.rating,
        title: input.title,
        body: input.body,
        photoUrls: input.photoUrls,
        isAnonymous: input.isAnonymous,
        isVerifiedVisit: input.isVerifiedVisit,
        helpfulCount: 0,
        reportCount: 0,
        status: 'visible',
        sentiment: 'UNPROCESSED',
        isFlagged: false,
        createdAt: input.createdAt,
        updatedAt: input.createdAt,
      };

      reviews.set(review.id, review);
      reviewByVetAndUser.set(duplicateKey, review.id);
      return review;
    },

    async listReviews(vetId, input) {
      const offset = parseCursorOffset(input.cursor);
      const filtered = [...reviews.values()]
        .filter((review) => review.vetId === vetId && review.status === 'visible')
        .sort((left, right) => {
          if (input.sort === 'helpful') {
            const helpfulCompare = right.helpfulCount - left.helpfulCount;
            if (helpfulCompare !== 0) {
              return helpfulCompare;
            }
          }

          if (input.sort === 'rating-desc') {
            const ratingCompare = right.rating - left.rating;
            if (ratingCompare !== 0) {
              return ratingCompare;
            }
          }

          if (input.sort === 'rating-asc') {
            const ratingCompare = left.rating - right.rating;
            if (ratingCompare !== 0) {
              return ratingCompare;
            }
          }

          return right.createdAt.getTime() - left.createdAt.getTime();
        });
      const slice = filtered.slice(offset, offset + input.limit);
      const nextOffset = offset + slice.length;

      return {
        items: slice,
        summary: summarize(vetId),
        total: filtered.length,
        nextCursor: nextOffset < filtered.length ? `${nextOffset}` : undefined,
      };
    },

    async toggleHelpful(reviewId, userId, toggledAt) {
      const review = reviews.get(reviewId);
      if (!review || review.status !== 'visible') {
        throw new AppError(
          REVIEW_ERROR_CODES.notFound,
          'Khong tim thay review.',
          404,
        );
      }

      const voteKey = `${reviewId}:${userId}`;
      const hasVoted = helpfulVotes.has(voteKey);
      const nextHelpfulCount = hasVoted
        ? Math.max(0, review.helpfulCount - 1)
        : review.helpfulCount + 1;

      if (hasVoted) {
        helpfulVotes.delete(voteKey);
      } else {
        helpfulVotes.add(voteKey);
      }

      reviews.set(reviewId, {
        ...review,
        helpfulCount: nextHelpfulCount,
        updatedAt: toggledAt,
      });

      return {
        reviewId,
        helpfulCount: nextHelpfulCount,
        hasVoted: !hasVoted,
      };
    },

    async reportReview(input) {
      const review = reviews.get(input.reviewId);
      if (!review) {
        throw new AppError(
          REVIEW_ERROR_CODES.notFound,
          'Khong tim thay review.',
          404,
        );
      }

      const reportKey = `${input.reviewId}:${input.reporterId}`;
      if (reportByReviewAndUser.has(reportKey)) {
        throw new AppError(
          REVIEW_ERROR_CODES.duplicateReport,
          'Ban da bao cao review nay.',
          409,
          'reviewId',
        );
      }

      const reportId = randomUUID();
      const reportCount = review.reportCount + 1;
      const reviewStatus =
        reportCount >= REPORT_AUTO_HIDE_THRESHOLD ? 'hidden' : review.status;
      reportByReviewAndUser.set(reportKey, reportId);
      reviews.set(input.reviewId, {
        ...review,
        reportCount,
        status: reviewStatus,
        updatedAt: input.createdAt,
      });

      return {
        reportId,
        reviewId: input.reviewId,
        reportCount,
        reviewStatus,
      };
    },
  };
};

export const createReviewService = ({
  vetReader,
  store = createInMemoryReviewStore(),
  now = () => new Date(),
}: ReviewServiceOptions) => {
  const assertVetExists = async (vetId: string) => {
    await vetReader.get(vetId);
  };

  return {
    async create(
      vetId: string,
      userId: string,
      input: CreateReviewInput,
    ): Promise<PublicReview> {
      await assertVetExists(vetId);
      const normalizedInput = validateCreateReviewInput(input);
      const review = await store.createReview({
        vetId,
        userId,
        ...normalizedInput,
        createdAt: now(),
      });

      return mapToPublicReview(review);
    },

    async list(vetId: string, input: ReviewListInput = {}): Promise<ReviewListResult> {
      await assertVetExists(vetId);
      const limit = validateLimit(input.limit);
      const sort = input.sort ?? 'newest';
      const result = await store.listReviews(vetId, {
        limit,
        cursor: input.cursor,
        sort,
      });

      return {
        items: result.items.map(mapToPublicReview),
        summary: result.summary,
        pagination: {
          total: result.total,
          limit,
          nextCursor: result.nextCursor,
        },
      };
    },

    async toggleHelpful(reviewId: string, userId: string) {
      return store.toggleHelpful(reviewId, userId, now());
    },

    async report(
      reviewId: string,
      reporterId: string,
      input: { reason: string; description?: string },
    ) {
      return store.reportReview({
        reviewId,
        reporterId,
        reason: validateReason(input.reason),
        description: sanitizeOptionalText(input.description),
        createdAt: now(),
      });
    },
  };
};

export type ReviewService = ReturnType<typeof createReviewService>;
