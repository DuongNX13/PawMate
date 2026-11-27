import { Prisma, type PrismaClient } from '@prisma/client';

import { PrismaReviewStore } from '../src/repositories/prisma-review-store';

const vetInternalId = '11111111-1111-1111-1111-111111111111';

describe('PrismaReviewStore numeric average boundary', () => {
  it.each([
    ['Decimal4', new Prisma.Decimal('4.00'), 4],
    ['DecimalFraction', new Prisma.Decimal('4.75'), 4.75],
    ['DecimalZero', new Prisma.Decimal('0'), 0],
    ['number', 4, 4],
    ['string', '4.00', 4],
    ['bigint', 4n, 4],
    ['null', null, null],
    ['undefined', undefined, null],
    ['blank', ' ', null],
    ['invalid', 'not-a-number', null],
    ['DecimalNaN', new Prisma.Decimal(NaN), null],
    ['DecimalInfinity', new Prisma.Decimal(Infinity), null],
  ])(
    'preserves %s without altering count/distribution',
    async (_, value, expected) => {
      const query = jest
        .fn()
        .mockResolvedValueOnce([{ id: vetInternalId, externalId: 'hn-001' }])
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([{ count: 2n }])
        .mockResolvedValueOnce([{ averageRating: value, reviewCount: 2n }])
        .mockResolvedValueOnce([
          { rating: 3, count: 1n },
          { rating: 5, count: 1n },
        ]);
      const prisma = { $queryRawUnsafe: query } as unknown as PrismaClient;
      const result = await new PrismaReviewStore(prisma).listReviews('hn-001', {
        limit: 20,
        sort: 'newest',
      });
      expect(result.summary).toEqual({
        averageRating: expected,
        reviewCount: 2,
        distribution: { 1: 0, 2: 0, 3: 1, 4: 0, 5: 1 },
      });
      expect(query).toHaveBeenCalledTimes(5);
      expect(query.mock.calls[3][0]).toContain(
        'ROUND(AVG(rating)::numeric, 2)',
      );
      expect(query.mock.calls[3][0]).toContain("status = 'visible'");
      expect(query.mock.calls[3].slice(1)).toEqual([vetInternalId]);
    },
  );

  it('keeps empty collections at null average and zero count', async () => {
    const query = jest
      .fn()
      .mockResolvedValueOnce([{ id: vetInternalId, externalId: 'hn-001' }])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ count: 0n }])
      .mockResolvedValueOnce([{ averageRating: null, reviewCount: 0n }])
      .mockResolvedValueOnce([]);
    const result = await new PrismaReviewStore({
      $queryRawUnsafe: query,
    } as unknown as PrismaClient).listReviews('hn-001', {
      limit: 20,
      sort: 'newest',
    });
    expect(result.summary).toEqual({
      averageRating: null,
      reviewCount: 0,
      distribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
    });
    expect(result.total).toBe(0);
    expect(result.nextCursor).toBeUndefined();
  });
});
