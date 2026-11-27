import { createHash } from 'node:crypto';

import { AppError } from '../../errors/app-error';
import {
  ADOPTION_ERROR_CODES,
  IDEMPOTENCY_ERROR_CODES,
} from '../../errors/error-codes';
import {
  AdoptionPersistenceDomainError,
  type AdoptionDecision,
  type AdoptionIdempotencyInput,
  type AdoptionListingCursor,
  type AdoptionReadSort,
  type AdoptionRepository,
} from '../../features/adoption/persistence/adoption-repository';
import {
  toAdoptionListingDetail,
  toAdoptionListingSummary,
} from './adoption-mapper';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type UnknownRecord = Record<string, unknown>;
type CursorEnvelope = {
  version: 1;
  filterFingerprint: string;
  position: AdoptionListingCursor;
};

export type AdoptionListQuery = {
  species?: unknown;
  ageGroup?: unknown;
  lat?: unknown;
  lng?: unknown;
  distanceKm?: unknown;
  sort?: unknown;
  cursor?: unknown;
  limit?: unknown;
};

type NormalizedAdoptionListFilters = {
  species?: 'dog' | 'cat' | 'other';
  ageGroup?: 'under_1' | 'one_to_three' | 'over_three';
  latitude?: number;
  longitude?: number;
  distanceKm?: number;
  sort: AdoptionReadSort;
};

const invalidInput = (field: string, message: string): never => {
  throw new AppError(ADOPTION_ERROR_CODES.invalidInput, message, 400, field);
};

const asObject = (value: unknown): UnknownRecord => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return invalidInput('body', 'Body phai la JSON object.');
  }
  return value as UnknownRecord;
};

const assertKnownKeys = (value: UnknownRecord, allowed: readonly string[]) => {
  const unexpected = Object.keys(value).find((key) => !allowed.includes(key));
  if (unexpected) {
    invalidInput(unexpected, `Truong ${unexpected} khong duoc ho tro.`);
  }
};

const readOptionalString = (value: unknown, field: string) => {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || value.trim().length === 0) {
    return invalidInput(field, `${field} khong hop le.`);
  }
  return value.trim();
};

const readNumber = (value: unknown, field: string) => {
  if (
    value === undefined ||
    (typeof value !== 'string' && typeof value !== 'number')
  ) {
    if (value === undefined) return undefined;
    return invalidInput(field, `${field} phai la mot so hop le.`);
  }
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(parsed)) {
    return invalidInput(field, `${field} phai la mot so hop le.`);
  }
  return parsed;
};

const readInteger = (value: unknown, field: string) => {
  const parsed = readNumber(value, field);
  if (parsed === undefined) return undefined;
  if (!Number.isSafeInteger(parsed)) {
    return invalidInput(field, `${field} phai la so nguyen.`);
  }
  return parsed;
};

const requireUuid = (value: unknown) => {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!UUID_PATTERN.test(normalized)) {
    throw new AppError(
      ADOPTION_ERROR_CODES.notFound,
      'Khong tim thay tin nhan nuoi.',
      404,
    );
  }
  return normalized;
};

const readBoundedString = (
  value: unknown,
  field: string,
  min: number,
  max: number,
) => {
  if (typeof value !== 'string') {
    return invalidInput(field, `${field} phai la chuoi.`);
  }
  const normalized = value.trim();
  if (normalized.length < min || normalized.length > max) {
    return invalidInput(field, `${field} phai dai tu ${min} den ${max} ky tu.`);
  }
  return normalized;
};

const canonicalize = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as UnknownRecord)
        .filter(([, item]) => item !== undefined)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, item]) => [key, canonicalize(item)]),
    );
  }
  return value;
};

const sha256 = (value: string) =>
  createHash('sha256').update(value, 'utf8').digest('hex');

const buildIdempotencyInput = (input: {
  userId: string;
  normalizedPath: string;
  idempotencyKey: unknown;
  payload: unknown;
  now: Date;
}): AdoptionIdempotencyInput => {
  if (typeof input.idempotencyKey !== 'string') {
    return invalidInput('Idempotency-Key', 'Thieu header Idempotency-Key.');
  }
  const key = input.idempotencyKey.trim();
  if (key.length < 1 || key.length > 128) {
    return invalidInput(
      'Idempotency-Key',
      'Idempotency-Key phai dai tu 1 den 128 ky tu.',
    );
  }
  return {
    userId: input.userId,
    method: 'POST',
    normalizedPath: input.normalizedPath,
    keyHash: sha256(key),
    requestHash: sha256(JSON.stringify(canonicalize(input.payload))),
    now: input.now,
  };
};

const buildFilterFingerprint = (value: {
  species?: 'dog' | 'cat' | 'other';
  ageGroup?: 'under_1' | 'one_to_three' | 'over_three';
  latitude?: number;
  longitude?: number;
  distanceKm?: number;
  sort: AdoptionReadSort;
}) =>
  sha256(
    JSON.stringify({
      species: value.species ?? null,
      ageGroup: value.ageGroup ?? null,
      latitude: value.latitude ?? null,
      longitude: value.longitude ?? null,
      distanceKm: value.distanceKm ?? null,
      sort: value.sort,
    }),
  );

const encodeCursor = (
  position: AdoptionListingCursor,
  filterFingerprint: string,
) =>
  Buffer.from(
    JSON.stringify({ version: 1, filterFingerprint, position }),
    'utf8',
  ).toString('base64url');

const parseCursorEnvelope = (value: string): Partial<CursorEnvelope> => {
  if (value.length > 2_048 || !/^[A-Za-z0-9_-]+$/.test(value)) {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
  } catch {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }
  if (!parsed || typeof parsed !== 'object') {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }
  return parsed as Partial<CursorEnvelope>;
};

const requireMatchingCursorPosition = (
  candidate: Partial<CursorEnvelope>,
  expectedSort: AdoptionReadSort,
  expectedFilterFingerprint: string,
): AdoptionListingCursor => {
  if (
    candidate.version !== 1 ||
    candidate.filterFingerprint !== expectedFilterFingerprint
  ) {
    return invalidInput(
      'cursor',
      'Cursor khong khop voi bo loc hoac cach sap xep.',
    );
  }
  const { position } = candidate;
  if (
    !position ||
    position.sort !== expectedSort ||
    !UUID_PATTERN.test(position.listingId)
  ) {
    return invalidInput(
      'cursor',
      'Cursor khong khop voi bo loc hoac cach sap xep.',
    );
  }
  return position;
};

const validateCursorPosition = (
  position: AdoptionListingCursor,
): AdoptionListingCursor => {
  if (position.sort === 'curated') {
    const date = new Date(position.createdAt);
    if (
      !Number.isFinite(date.getTime()) ||
      date.toISOString() !== position.createdAt
    ) {
      return invalidInput('cursor', 'Cursor khong hop le.');
    }
    return position;
  }
  if (
    !Number.isSafeInteger(position.distanceMeters) ||
    position.distanceMeters < 0
  ) {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }
  return position;
};

const decodeCursor = (
  value: string,
  expectedSort: AdoptionReadSort,
  expectedFilterFingerprint: string,
): AdoptionListingCursor => {
  const candidate = parseCursorEnvelope(value);
  const position = requireMatchingCursorPosition(
    candidate,
    expectedSort,
    expectedFilterFingerprint,
  );
  return validateCursorPosition(position);
};

const parseSpecies = (
  value: unknown,
): NormalizedAdoptionListFilters['species'] => {
  const species = readOptionalString(value, 'species');
  if (
    species &&
    species !== 'dog' &&
    species !== 'cat' &&
    species !== 'other'
  ) {
    return invalidInput('species', 'species chi nhan dog, cat hoac other.');
  }
  return species as NormalizedAdoptionListFilters['species'];
};

const parseAgeGroup = (
  value: unknown,
): NormalizedAdoptionListFilters['ageGroup'] => {
  const ageGroup = readOptionalString(value, 'ageGroup');
  if (
    ageGroup &&
    ageGroup !== 'under_1' &&
    ageGroup !== 'one_to_three' &&
    ageGroup !== 'over_three'
  ) {
    return invalidInput(
      'ageGroup',
      'ageGroup chi nhan under_1, one_to_three hoac over_three.',
    );
  }
  return ageGroup as NormalizedAdoptionListFilters['ageGroup'];
};

const parseCoordinates = (query: AdoptionListQuery) => {
  const latitude = readNumber(query.lat, 'lat');
  const longitude = readNumber(query.lng, 'lng');
  if ((latitude === undefined) !== (longitude === undefined)) {
    invalidInput('lat', 'lat va lng phai duoc gui cung nhau.');
  }
  if (latitude !== undefined && (latitude < -90 || latitude > 90)) {
    invalidInput('lat', 'lat phai tu -90 den 90.');
  }
  if (longitude !== undefined && (longitude < -180 || longitude > 180)) {
    invalidInput('lng', 'lng phai tu -180 den 180.');
  }
  return { latitude, longitude };
};

const parseDistanceKm = (value: unknown, latitude: number | undefined) => {
  const distanceKm = readNumber(value, 'distanceKm');
  if (distanceKm !== undefined && (distanceKm < 1 || distanceKm > 100)) {
    invalidInput('distanceKm', 'distanceKm phai tu 1 den 100.');
  }
  if (distanceKm !== undefined && latitude === undefined) {
    invalidInput('distanceKm', 'distanceKm can lat va lng.');
  }
  return distanceKm;
};

const parseSort = (
  value: unknown,
  latitude: number | undefined,
): AdoptionReadSort => {
  const sort = readOptionalString(value, 'sort') ?? 'curated';
  if (sort !== 'curated' && sort !== 'distance') {
    return invalidInput('sort', 'sort chi nhan curated hoac distance.');
  }
  if (sort === 'distance' && latitude === undefined) {
    invalidInput('sort', 'sort=distance can lat va lng.');
  }
  return sort;
};

const parseLimit = (value: unknown) => {
  const limit = readInteger(value, 'limit') ?? DEFAULT_LIMIT;
  if (limit < 1 || limit > MAX_LIMIT) {
    invalidInput('limit', `limit phai tu 1 den ${MAX_LIMIT}.`);
  }
  return limit;
};

const normalizeListFilters = (
  query: AdoptionListQuery,
): NormalizedAdoptionListFilters => {
  const species = parseSpecies(query.species);
  const ageGroup = parseAgeGroup(query.ageGroup);
  const { latitude, longitude } = parseCoordinates(query);
  const distanceKm = parseDistanceKm(query.distanceKm, latitude);
  const sort = parseSort(query.sort, latitude);
  return { species, ageGroup, latitude, longitude, distanceKm, sort };
};

const requireRepository = (repository?: AdoptionRepository) => {
  if (!repository) throw new Error('Adoption persistence is unavailable.');
  return repository;
};

const mapPersistenceError = (error: unknown): never => {
  if (!(error instanceof AdoptionPersistenceDomainError)) throw error;
  switch (error.reason) {
    case 'not_found':
      throw new AppError(
        ADOPTION_ERROR_CODES.notFound,
        'Khong tim thay tin nhan nuoi.',
        404,
      );
    case 'self_listing':
      throw new AppError(
        ADOPTION_ERROR_CODES.selfListing,
        'Ban khong the tu gui yeu cau cho tin cua minh.',
        403,
      );
    case 'listing_unavailable':
      throw new AppError(
        ADOPTION_ERROR_CODES.invalidInput,
        'Tin nhan nuoi khong con mo.',
        409,
      );
    case 'duplicate_active_request':
      throw new AppError(
        ADOPTION_ERROR_CODES.duplicateActiveRequest,
        'Ban da co mot yeu cau dang hoat dong cho tin nay.',
        409,
      );
    case 'idempotency_conflict':
      throw new AppError(
        IDEMPOTENCY_ERROR_CODES.payloadConflict,
        'Idempotency-Key da duoc dung voi payload khac.',
        409,
      );
    default:
      throw error;
  }
};

const callRepository = async <T>(work: () => Promise<T>) => {
  try {
    return await work();
  } catch (error) {
    return mapPersistenceError(error);
  }
};

export const createAdoptionService = (options: {
  repository?: AdoptionRepository;
  now?: () => Date;
}) => {
  const repository = () => requireRepository(options.repository);
  const now = options.now ?? (() => new Date());

  return {
    async listRequests(adopterUserId: string) {
      return callRepository(() =>
        repository().listRequestsByAdopter(adopterUserId),
      );
    },

    async listListings(viewerUserId: string, query: AdoptionListQuery = {}) {
      const normalizedFilters = normalizeListFilters(query);
      const limit = parseLimit(query.limit);
      const fingerprint = buildFilterFingerprint(normalizedFilters);
      const cursorRaw = readOptionalString(query.cursor, 'cursor');
      const cursor = cursorRaw
        ? decodeCursor(cursorRaw, normalizedFilters.sort, fingerprint)
        : undefined;
      const page = await repository().listListings({
        viewerUserId,
        ...normalizedFilters,
        cursor,
        limit,
      });
      return {
        items: page.items.map(toAdoptionListingSummary),
        ...(page.nextCursor
          ? { nextCursor: encodeCursor(page.nextCursor, fingerprint) }
          : {}),
        limit: page.limit,
      };
    },

    async getListing(viewerUserId: string, listingId: unknown) {
      const normalizedListingId = requireUuid(listingId);
      const listing = await repository().findListing(normalizedListingId);
      if (!listing) {
        throw new AppError(
          ADOPTION_ERROR_CODES.notFound,
          'Khong tim thay tin nhan nuoi.',
          404,
        );
      }
      return toAdoptionListingDetail(listing, viewerUserId);
    },

    async recordDecision(
      adopterUserId: string,
      listingId: unknown,
      payload: unknown,
      idempotencyKey: unknown,
    ) {
      const normalizedListingId = requireUuid(listingId);
      const body = asObject(payload);
      assertKnownKeys(body, ['decision']);
      if (body.decision !== 'skip' && body.decision !== 'like') {
        invalidInput('decision', 'decision chi nhap skip hoac like.');
      }
      const decision = body.decision as AdoptionDecision;
      const commandNow = now();
      return callRepository(() =>
        repository().recordDecision({
          listingId: normalizedListingId,
          adopterUserId,
          decision,
          now: commandNow,
          idempotency: buildIdempotencyInput({
            userId: adopterUserId,
            normalizedPath: `/adoption/listings/${normalizedListingId}/decisions`,
            idempotencyKey,
            payload: body,
            now: commandNow,
          }),
        }),
      );
    },

    async createRequest(
      adopterUserId: string,
      listingId: unknown,
      payload: unknown,
      idempotencyKey: unknown,
    ) {
      const normalizedListingId = requireUuid(listingId);
      const body = asObject(payload);
      assertKnownKeys(body, [
        'livingCondition',
        'petExperience',
        'carePlan',
        'commitmentAccepted',
        'note',
      ]);
      const livingCondition = readBoundedString(
        body.livingCondition,
        'livingCondition',
        1,
        500,
      );
      const petExperience = readBoundedString(
        body.petExperience,
        'petExperience',
        1,
        500,
      );
      const carePlan = readBoundedString(body.carePlan, 'carePlan', 1, 500);
      if (body.commitmentAccepted !== true) {
        invalidInput('commitmentAccepted', 'commitmentAccepted phai la true.');
      }
      const note =
        body.note === undefined
          ? undefined
          : readBoundedString(body.note, 'note', 0, 1_000);
      const normalizedBody = {
        livingCondition,
        petExperience,
        carePlan,
        commitmentAccepted: true as const,
        ...(note !== undefined ? { note } : {}),
      };
      const commandNow = now();
      return callRepository(() =>
        repository().createRequest({
          listingId: normalizedListingId,
          adopterUserId,
          ...normalizedBody,
          now: commandNow,
          idempotency: buildIdempotencyInput({
            userId: adopterUserId,
            normalizedPath: `/adoption/listings/${normalizedListingId}/requests`,
            idempotencyKey,
            payload: normalizedBody,
            now: commandNow,
          }),
        }),
      );
    },
  };
};

export type AdoptionService = ReturnType<typeof createAdoptionService>;
