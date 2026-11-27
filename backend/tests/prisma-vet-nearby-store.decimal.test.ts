import { Prisma, type PrismaClient } from '@prisma/client';

import { PrismaVetNearbyStore } from '../src/repositories/prisma-vet-nearby-store';

const buildRow = (averageRating: unknown) => ({
  id: 'd137-fixture-near',
  name: 'Fixture nearby',
  city: 'Fixture city',
  district: 'Fixture district',
  address: 'Fixture address',
  phone: null,
  latitude: 10.7769,
  longitude: 106.7009,
  services: [],
  sourceRank: 1,
  averageRating,
  reviewCount: 0,
  is24h: true,
  openHours: [],
  readyForMap: true,
  distanceMeters: 0,
});

const buildStore = (averageRating: unknown) => {
  const query = jest.fn().mockResolvedValue([buildRow(averageRating)]);
  const prisma = { $queryRawUnsafe: query } as unknown as PrismaClient;
  return { store: new PrismaVetNearbyStore(prisma), query };
};

describe('PrismaVetNearbyStore Decimal boundary regression', () => {
  it.each([
    ['Decimal integer', new Prisma.Decimal('5.00'), 5],
    ['Decimal fractional', new Prisma.Decimal('4.75'), 4.75],
    ['Decimal zero', new Prisma.Decimal('0'), 0],
    ['native number', 5, 5],
    ['numeric string', '4.50', 4.5],
    ['null', null, null],
    ['undefined', undefined, null],
    ['invalid string', 'invalid', null],
    ['blank string', '   ', null],
    ['Decimal NaN', new Prisma.Decimal('NaN'), null],
    ['Decimal infinity', new Prisma.Decimal('Infinity'), null],
  ])(
    'preserves %s rating in both nearby and DB-backed detail',
    async (_, input, expected) => {
      const { store, query } = buildStore(input);
      const nearby = await store.listNearby({
        latitude: 10.7769,
        longitude: 106.7009,
        radiusMeters: 1000,
        minRating: 4,
      });
      const detail = await store.getDetailById('d137-fixture-near');

      expect(nearby[0].averageRating).toBe(expected);
      expect(detail?.averageRating).toBe(expected);
      expect(query).toHaveBeenCalledTimes(2);
      expect(query.mock.calls[0].slice(1)).toEqual([
        106.7009,
        10.7769,
        1000,
        null,
        4,
      ]);
      expect(query.mock.calls[1].slice(1)).toEqual(['d137-fixture-near']);
    },
  );

  it('does not invent a detail when the database returns no row', async () => {
    const { store, query } = buildStore(null);
    query.mockResolvedValue([]);

    await expect(store.getDetailById('missing')).resolves.toBeUndefined();
  });
});
