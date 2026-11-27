import { Prisma, type PrismaClient } from '@prisma/client';

import {
  AdoptionPersistenceDomainError,
  type AdoptionIdempotencyInput,
  type AdoptionListingCursor,
  type AdoptionListingPage,
  type AdoptionListingRecord,
  type AdoptionRepository,
  type AdoptionRequestListingAvailability,
  type AdoptionRequestSummaryRecord,
} from './adoption-repository';

type TransactionClient = Omit<
  PrismaClient,
  '$connect' | '$disconnect' | '$on' | '$transaction' | '$use' | '$extends'
>;

type ListingRow = Prisma.AdoptionListingGetPayload<{
  include: { heroMedia: true };
}>;

type ListingOrderRow = {
  listingId: string;
  createdAt: Date | string;
  distanceMeters: number | string | null;
};

type ListListingsInput = Parameters<AdoptionRepository['listListings']>[0];

const ACTIVE_REQUEST_STATUSES = ['submitted', 'reviewing', 'approved'] as const;

const toIso = (value: Date | string) =>
  value instanceof Date ? value.toISOString() : new Date(value).toISOString();

const toRequestListingAvailability = (listing: {
  status: string;
  deletedAt: Date | null;
}): AdoptionRequestListingAvailability => {
  if (listing.deletedAt !== null) return 'deleted';
  if (listing.status === 'closed') return 'expired';
  if (listing.status === 'available') return 'available';
  return 'unavailable';
};

const toListingRecord = (
  row: ListingRow,
  distanceMeters?: number,
): AdoptionListingRecord => {
  if (row.heroMedia.purpose !== 'adoption_listing') {
    throw new Error('Adoption listing hero media has an invalid purpose.');
  }
  return {
    listingId: row.id,
    shelterId: row.shelterId,
    petName: row.petName,
    species: row.species,
    ...(row.breed ? { breed: row.breed } : {}),
    ageLabel: row.ageLabel,
    ...(row.description ? { description: row.description } : {}),
    traits: row.traits,
    healthBadges: row.healthBadges,
    verificationBadges: row.verificationBadges,
    heroMedia: {
      mediaId: row.heroMedia.id,
      ownerUserId: row.heroMedia.ownerUserId,
      purpose: row.heroMedia.purpose,
      mimeType: row.heroMedia.mimeType,
      sizeBytes: Number(row.heroMedia.sizeBytes),
      sha256: row.heroMedia.sha256,
      status: row.heroMedia.status,
      ...(row.heroMedia.publicUrl
        ? { publicUrl: row.heroMedia.publicUrl }
        : {}),
      ...(row.heroMedia.width !== null ? { width: row.heroMedia.width } : {}),
      ...(row.heroMedia.height !== null
        ? { height: row.heroMedia.height }
        : {}),
      ...(row.heroMedia.durationSeconds !== null
        ? { durationSeconds: Number(row.heroMedia.durationSeconds) }
        : {}),
      createdAt: row.heroMedia.createdAt.toISOString(),
    },
    status: row.status,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    ...(distanceMeters !== undefined ? { distanceMeters } : {}),
  };
};

const speciesSql = (species: 'dog' | 'cat' | 'other' | undefined) => {
  if (!species) return Prisma.empty;
  if (species === 'other') {
    return Prisma.sql`AND l.species IN ('bird', 'rabbit', 'other')`;
  }
  return Prisma.sql`AND l.species::text = ${species}`;
};

const ageGroupSql = (ageGroup: ListListingsInput['ageGroup']) => {
  switch (ageGroup) {
    case 'under_1':
      return Prisma.sql`AND l.age_months < 12`;
    case 'one_to_three':
      return Prisma.sql`AND l.age_months BETWEEN 12 AND 35`;
    case 'over_three':
      return Prisma.sql`AND l.age_months >= 36`;
    default:
      return Prisma.empty;
  }
};

const ageMonthsWhere = (
  ageGroup: ListListingsInput['ageGroup'],
): Prisma.AdoptionListingWhereInput['ageMonths'] => {
  switch (ageGroup) {
    case 'under_1':
      return { lt: 12 };
    case 'one_to_three':
      return { gte: 12, lt: 36 };
    case 'over_three':
      return { gte: 36 };
    default:
      return undefined;
  }
};

const buildDistanceSql = (latitude: number, longitude: number) => Prisma.sql`
  ROUND((
    6371000 * 2 * ASIN(
      SQRT(
        POWER(SIN(RADIANS(l.latitude::double precision - ${latitude}) / 2), 2)
        + COS(RADIANS(${latitude}))
          * COS(RADIANS(l.latitude::double precision))
          * POWER(
              SIN(RADIANS(l.longitude::double precision - ${longitude}) / 2),
              2
            )
      )
    )
  ))::integer
`;

const buildCursorSql = (
  cursor: AdoptionListingCursor | undefined,
  distanceSql: Prisma.Sql,
) => {
  if (cursor?.sort === 'curated') {
    return Prisma.sql`
      AND (
        l.created_at < ${new Date(cursor.createdAt)}
        OR (
          l.created_at = ${new Date(cursor.createdAt)}
          AND l.id < ${cursor.listingId}::uuid
        )
      )
    `;
  }
  if (cursor?.sort === 'distance') {
    return Prisma.sql`
      AND (
        ${distanceSql} > ${cursor.distanceMeters}
        OR (
          ${distanceSql} = ${cursor.distanceMeters}
          AND l.id > ${cursor.listingId}::uuid
        )
      )
    `;
  }
  return Prisma.empty;
};

const buildOrderSql = (sort: ListListingsInput['sort']) =>
  sort === 'distance'
    ? Prisma.sql`ORDER BY "distanceMeters" ASC, l.id ASC`
    : Prisma.sql`ORDER BY l.created_at DESC, l.id DESC`;

const buildLocationNextCursor = (
  hasMore: boolean,
  last: ListingOrderRow | undefined,
  sort: ListListingsInput['sort'],
): AdoptionListingCursor | undefined => {
  if (!hasMore || !last) return undefined;
  return sort === 'distance'
    ? {
        sort: 'distance',
        distanceMeters: Number(last.distanceMeters ?? 0),
        listingId: last.listingId,
      }
    : {
        sort: 'curated',
        createdAt: toIso(last.createdAt),
        listingId: last.listingId,
      };
};

export class PrismaAdoptionRepository implements AdoptionRepository {
  constructor(private readonly prisma: PrismaClient) {}

  private async executeCommand<T>(
    idempotency: AdoptionIdempotencyInput,
    execute: (transaction: TransactionClient) => Promise<T>,
  ): Promise<T> {
    return this.prisma.$transaction(async (transaction) => {
      const now = idempotency.now ?? new Date();
      const lockScope = [
        idempotency.userId,
        idempotency.method,
        idempotency.normalizedPath,
        idempotency.keyHash,
      ].join(':');
      await transaction.$queryRaw<Array<{ locked: boolean }>>`
        SELECT true AS locked
        FROM pg_advisory_xact_lock(hashtextextended(${lockScope}, 0))
      `;
      const identity = {
        userId: idempotency.userId,
        method: idempotency.method,
        normalizedPath: idempotency.normalizedPath,
        keyHash: idempotency.keyHash,
      };
      const existing = await transaction.idempotencyRecord.findUnique({
        where: { userId_method_normalizedPath_keyHash: identity },
      });
      if (existing && existing.expiresAt > now) {
        if (existing.requestHash !== idempotency.requestHash) {
          throw new AdoptionPersistenceDomainError(
            'idempotency_conflict',
            'Idempotency key was already used with a different payload.',
          );
        }
        return existing.responseBody as unknown as T;
      }
      if (existing) {
        await transaction.idempotencyRecord.delete({
          where: { id: existing.id },
        });
      }
      const result = await execute(transaction);
      await transaction.idempotencyRecord.create({
        data: {
          ...identity,
          requestHash: idempotency.requestHash,
          responseStatus: 201,
          responseBody: JSON.parse(
            JSON.stringify(result),
          ) as Prisma.InputJsonValue,
          createdAt: now,
          expiresAt: new Date(now.getTime() + 24 * 60 * 60 * 1_000),
        },
      });
      return result;
    });
  }

  async listListings(input: ListListingsInput): Promise<AdoptionListingPage> {
    if (input.latitude === undefined || input.longitude === undefined) {
      return this.listCuratedListings(input);
    }
    return this.listLocationListings({
      ...input,
      latitude: input.latitude,
      longitude: input.longitude,
    });
  }

  private async listCuratedListings(
    input: ListListingsInput,
  ): Promise<AdoptionListingPage> {
    const speciesWhere: Prisma.AdoptionListingWhereInput['species'] =
      input.species === 'other'
        ? { in: ['bird', 'rabbit', 'other'] }
        : input.species;
    const ageWhere = ageMonthsWhere(input.ageGroup);
    const rows = await this.prisma.adoptionListing.findMany({
      where: {
        deletedAt: null,
        status: 'available',
        shelterId: { not: input.viewerUserId },
        decisions: { none: { adopterUserId: input.viewerUserId } },
        ...(speciesWhere ? { species: speciesWhere } : {}),
        ...(ageWhere ? { ageMonths: ageWhere } : {}),
      },
      include: { heroMedia: true },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: input.limit + 1,
      ...(input.cursor
        ? { cursor: { id: input.cursor.listingId }, skip: 1 }
        : {}),
    });
    const hasMore = rows.length > input.limit;
    const visibleRows = rows.slice(0, input.limit);
    const last = visibleRows.at(-1);
    return {
      items: visibleRows.map((row) => toListingRecord(row)),
      ...(hasMore && last
        ? {
            nextCursor: {
              sort: 'curated' as const,
              createdAt: last.createdAt.toISOString(),
              listingId: last.id,
            },
          }
        : {}),
      limit: input.limit,
    };
  }

  private async listLocationListings(
    input: ListListingsInput & { latitude: number; longitude: number },
  ): Promise<AdoptionListingPage> {
    const distanceSql = buildDistanceSql(input.latitude, input.longitude);
    const distanceLimitSql =
      input.distanceKm === undefined
        ? Prisma.empty
        : Prisma.sql`AND ${distanceSql} <= ${Math.round(input.distanceKm * 1_000)}`;
    const cursorSql = buildCursorSql(input.cursor, distanceSql);
    const orderSql = buildOrderSql(input.sort);
    const orderRows = await this.prisma.$queryRaw<ListingOrderRow[]>(Prisma.sql`
      SELECT
        l.id AS "listingId",
        l.created_at AS "createdAt",
        ${distanceSql} AS "distanceMeters"
      FROM public.adoption_listings l
      LEFT JOIN public.adoption_decisions d
        ON d.listing_id = l.id
       AND d.adopter_user_id = ${input.viewerUserId}::uuid
      WHERE l.deleted_at IS NULL
        AND l.status = 'available'
        AND l.shelter_id <> ${input.viewerUserId}::uuid
        AND d.id IS NULL
        AND l.latitude IS NOT NULL
        AND l.longitude IS NOT NULL
        ${speciesSql(input.species)}
        ${ageGroupSql(input.ageGroup)}
        ${distanceLimitSql}
        ${cursorSql}
      ${orderSql}
      LIMIT ${input.limit + 1}
    `);
    const hasMore = orderRows.length > input.limit;
    const visibleOrder = orderRows.slice(0, input.limit);
    const ids = visibleOrder.map((row) => row.listingId);
    const listings = ids.length
      ? await this.prisma.adoptionListing.findMany({
          where: { id: { in: ids } },
          include: { heroMedia: true },
        })
      : [];
    const byId = new Map(listings.map((row) => [row.id, row]));
    const items = visibleOrder.flatMap((orderRow) => {
      const listing = byId.get(orderRow.listingId);
      if (!listing) return [];
      return [toListingRecord(listing, Number(orderRow.distanceMeters ?? 0))];
    });
    const last = visibleOrder.at(-1);
    const nextCursor = buildLocationNextCursor(hasMore, last, input.sort);
    return {
      items,
      ...(nextCursor ? { nextCursor } : {}),
      limit: input.limit,
    };
  }

  async findListing(
    listingId: string,
  ): Promise<AdoptionListingRecord | undefined> {
    const listing = await this.prisma.adoptionListing.findFirst({
      where: { id: listingId, deletedAt: null },
      include: { heroMedia: true },
    });
    return listing ? toListingRecord(listing) : undefined;
  }

  async listRequestsByAdopter(
    adopterUserId: string,
  ): Promise<AdoptionRequestSummaryRecord[]> {
    const requests = await this.prisma.adoptionRequest.findMany({
      where: { adopterUserId },
      select: {
        id: true,
        listingId: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        listing: {
          select: { petName: true, status: true, deletedAt: true },
        },
        chatThread: { select: { id: true } },
      },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
    });
    return requests.map((request) => ({
      requestId: request.id,
      listingId: request.listingId,
      petName: request.listing.petName,
      status: request.status,
      listingAvailability: toRequestListingAvailability(request.listing),
      ...(request.chatThread ? { threadId: request.chatThread.id } : {}),
      createdAt: request.createdAt.toISOString(),
      updatedAt: request.updatedAt.toISOString(),
    }));
  }

  async recordDecision(
    input: Parameters<AdoptionRepository['recordDecision']>[0],
  ) {
    return this.executeCommand(input.idempotency, async (transaction) => {
      const listing = await transaction.adoptionListing.findFirst({
        where: { id: input.listingId, deletedAt: null },
        select: { id: true, shelterId: true, status: true },
      });
      if (!listing) {
        throw new AdoptionPersistenceDomainError(
          'not_found',
          'Adoption listing was not found.',
        );
      }
      if (listing.shelterId === input.adopterUserId) {
        throw new AdoptionPersistenceDomainError(
          'self_listing',
          'Listing owner cannot decide their own listing.',
        );
      }
      if (listing.status !== 'available') {
        throw new AdoptionPersistenceDomainError(
          'listing_unavailable',
          'Adoption listing is not available.',
        );
      }
      const decision = await transaction.adoptionDecisionRecord.upsert({
        where: {
          listingId_adopterUserId: {
            listingId: input.listingId,
            adopterUserId: input.adopterUserId,
          },
        },
        create: {
          listingId: input.listingId,
          adopterUserId: input.adopterUserId,
          decision: input.decision,
          createdAt: input.now,
          updatedAt: input.now,
        },
        update: {
          decision: input.decision,
          updatedAt: input.now,
        },
      });
      return {
        listingId: decision.listingId,
        adopterUserId: decision.adopterUserId,
        decision: decision.decision,
        createdAt: decision.createdAt.toISOString(),
      };
    });
  }

  async createRequest(
    input: Parameters<AdoptionRepository['createRequest']>[0],
  ) {
    try {
      return await this.executeCommand(
        input.idempotency,
        async (transaction) => {
          const listing = await transaction.adoptionListing.findFirst({
            where: { id: input.listingId, deletedAt: null },
            select: { id: true, shelterId: true, status: true },
          });
          if (!listing) {
            throw new AdoptionPersistenceDomainError(
              'not_found',
              'Adoption listing was not found.',
            );
          }
          if (listing.shelterId === input.adopterUserId) {
            throw new AdoptionPersistenceDomainError(
              'self_listing',
              'Listing owner cannot request their own listing.',
            );
          }
          if (listing.status !== 'available') {
            throw new AdoptionPersistenceDomainError(
              'listing_unavailable',
              'Adoption listing is not available.',
            );
          }
          const existing = await transaction.adoptionRequest.findFirst({
            where: {
              listingId: input.listingId,
              adopterUserId: input.adopterUserId,
              status: { in: [...ACTIVE_REQUEST_STATUSES] },
            },
            select: { id: true },
          });
          if (existing) {
            throw new AdoptionPersistenceDomainError(
              'duplicate_active_request',
              'An active request already exists.',
            );
          }
          const request = await transaction.adoptionRequest.create({
            data: {
              listingId: input.listingId,
              adopterUserId: input.adopterUserId,
              shelterId: listing.shelterId,
              livingCondition: input.livingCondition,
              petExperience: input.petExperience,
              carePlan: input.carePlan,
              commitmentAccepted: input.commitmentAccepted,
              note: input.note,
              status: 'submitted',
              createdAt: input.now,
              updatedAt: input.now,
              chatThread: {
                create: {
                  adopterUserId: input.adopterUserId,
                  shelterId: listing.shelterId,
                  createdAt: input.now,
                  updatedAt: input.now,
                  participants: {
                    create: [
                      {
                        userId: input.adopterUserId,
                        role: 'adopter',
                        lastReadAt: input.now,
                        createdAt: input.now,
                        updatedAt: input.now,
                      },
                      {
                        userId: listing.shelterId,
                        role: 'shelter',
                        lastReadAt: input.now,
                        createdAt: input.now,
                        updatedAt: input.now,
                      },
                    ],
                  },
                },
              },
            },
            include: { chatThread: true },
          });
          if (!request.chatThread) {
            throw new Error('Adoption request chat thread was not created.');
          }
          await transaction.outboxEvent.create({
            data: {
              topic: 'adoption',
              eventType: 'adoption.request_submitted.v1',
              aggregateType: 'adoption_request',
              aggregateId: request.id,
              actorUserId: input.adopterUserId,
              payload: {
                requestId: request.id,
                listingId: request.listingId,
                adopterUserId: request.adopterUserId,
                shelterId: request.shelterId,
                threadId: request.chatThread.id,
              },
              dedupeKey: `adoption.request_submitted.v1:${request.id}`,
              occurredAt: input.now,
              availableAt: input.now,
            },
          });
          return {
            requestId: request.id,
            listingId: request.listingId,
            adopterUserId: request.adopterUserId,
            shelterId: request.shelterId,
            livingCondition: request.livingCondition,
            petExperience: request.petExperience,
            carePlan: request.carePlan,
            commitmentAccepted: true as const,
            status: request.status,
            threadId: request.chatThread.id,
            createdAt: request.createdAt.toISOString(),
            updatedAt: request.updatedAt.toISOString(),
            ...(request.note ? { note: request.note } : {}),
          };
        },
      );
    } catch (error) {
      if (
        error &&
        typeof error === 'object' &&
        'code' in error &&
        error.code === 'P2002'
      ) {
        throw new AdoptionPersistenceDomainError(
          'duplicate_active_request',
          'An active request already exists.',
        );
      }
      throw error;
    }
  }
}
