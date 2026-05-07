import { type PrismaClient } from '@prisma/client';

import { REVIEW_ERROR_CODES } from '../src/errors/error-codes';
import { PrismaReviewStore } from '../src/repositories/prisma-review-store';

const vetInternalId = '11111111-1111-1111-1111-111111111111';
const userId = '22222222-2222-2222-2222-222222222222';
const reviewId = '33333333-3333-3333-3333-333333333333';
const now = new Date('2026-04-29T05:00:00.000Z');

const buildReviewRow = () => ({
  id: reviewId,
  vetId: 'hcm-001',
  userId,
  rating: 5,
  title: 'Great visit',
  body: 'The vet explained the treatment plan clearly.',
  photoUrls: ['https://example.com/review.jpg'],
  isAnonymous: false,
  isVerifiedVisit: false,
  helpfulCount: 0,
  reportCount: 0,
  status: 'visible' as const,
  sentiment: 'UNPROCESSED' as const,
  isFlagged: false,
  createdAt: now,
  updatedAt: now,
});

const buildTransactionPrisma = (tx: {
  $queryRawUnsafe: jest.Mock;
  $executeRawUnsafe: jest.Mock;
}) =>
  ({
    $transaction: jest.fn(async (callback: (transaction: typeof tx) => unknown) =>
      callback(tx),
    ),
  }) as unknown as PrismaClient;

describe('PrismaReviewStore', () => {
  it('creates a review inside a transaction and refreshes the vet aggregate', async () => {
    const tx = {
      $queryRawUnsafe: jest
        .fn()
        .mockResolvedValueOnce([{ id: vetInternalId, externalId: 'hcm-001' }])
        .mockResolvedValueOnce([buildReviewRow()]),
      $executeRawUnsafe: jest.fn().mockResolvedValue(undefined),
    };
    const store = new PrismaReviewStore(buildTransactionPrisma(tx));

    const review = await store.createReview({
      vetId: 'hcm-001',
      userId,
      rating: 5,
      title: 'Great visit',
      body: 'The vet explained the treatment plan clearly.',
      photoUrls: ['https://example.com/review.jpg'],
      isAnonymous: false,
      isVerifiedVisit: false,
      createdAt: now,
    });

    expect(review).toMatchObject({
      id: reviewId,
      vetId: 'hcm-001',
      userId,
      rating: 5,
      photoUrls: ['https://example.com/review.jpg'],
    });
    expect(tx.$executeRawUnsafe).toHaveBeenCalledTimes(1);
  });

  it('maps database unique violations to duplicate-review errors', async () => {
    const tx = {
      $queryRawUnsafe: jest
        .fn()
        .mockResolvedValueOnce([{ id: vetInternalId, externalId: 'hcm-001' }])
        .mockRejectedValueOnce({ meta: { code: '23505' } }),
      $executeRawUnsafe: jest.fn(),
    };
    const store = new PrismaReviewStore(buildTransactionPrisma(tx));

    await expect(
      store.createReview({
        vetId: 'hcm-001',
        userId,
        rating: 5,
        photoUrls: [],
        isAnonymous: false,
        isVerifiedVisit: false,
        createdAt: now,
      }),
    ).rejects.toMatchObject({
      code: REVIEW_ERROR_CODES.duplicateReview,
      statusCode: 409,
    });
  });

  it('lists reviews with summary, distribution, and pagination cursor', async () => {
    const prisma = {
      $queryRawUnsafe: jest
        .fn()
        .mockResolvedValueOnce([{ id: vetInternalId, externalId: 'hcm-001' }])
        .mockResolvedValueOnce([buildReviewRow()])
        .mockResolvedValueOnce([{ count: 2 }])
        .mockResolvedValueOnce([{ averageRating: '4.50', reviewCount: 2 }])
        .mockResolvedValueOnce([
          { rating: 4, count: 1 },
          { rating: 5, count: 1 },
        ]),
    } as unknown as PrismaClient;
    const store = new PrismaReviewStore(prisma);

    const result = await store.listReviews('hcm-001', {
      limit: 1,
      sort: 'helpful',
    });

    expect(result.items).toHaveLength(1);
    expect(result.summary).toEqual({
      averageRating: 4.5,
      reviewCount: 2,
      distribution: {
        1: 0,
        2: 0,
        3: 0,
        4: 1,
        5: 1,
      },
    });
    expect(result.nextCursor).toBe('1');
  });

  it('toggles helpful votes on and off through the persistence adapter', async () => {
    const tx = {
      $queryRawUnsafe: jest
        .fn()
        .mockResolvedValueOnce([{ id: reviewId }])
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([{ helpfulCount: 1 }]),
      $executeRawUnsafe: jest.fn().mockResolvedValue(undefined),
    };
    const store = new PrismaReviewStore(buildTransactionPrisma(tx));

    const result = await store.toggleHelpful(reviewId, userId, now);

    expect(result).toEqual({
      reviewId,
      helpfulCount: 1,
      hasVoted: true,
    });
    expect(tx.$executeRawUnsafe).toHaveBeenCalledTimes(1);
  });

  it('auto-hides a review after the report threshold and refreshes aggregate', async () => {
    const tx = {
      $queryRawUnsafe: jest
        .fn()
        .mockResolvedValueOnce([
          { id: reviewId, vetId: vetInternalId, status: 'visible' },
        ])
        .mockResolvedValueOnce([{ reportCount: 5, reviewStatus: 'hidden' }]),
      $executeRawUnsafe: jest.fn().mockResolvedValue(undefined),
    };
    const store = new PrismaReviewStore(buildTransactionPrisma(tx));

    const result = await store.reportReview({
      reviewId,
      reporterId: userId,
      reason: 'spam',
      createdAt: now,
    });

    expect(result).toEqual({
      reportId: expect.any(String),
      reviewId,
      reportCount: 5,
      reviewStatus: 'hidden',
    });
    expect(tx.$executeRawUnsafe).toHaveBeenCalledTimes(2);
  });
});
