import { createHash } from 'node:crypto';

import { AppError } from '../../errors/app-error';
import { RESCUE_ERROR_CODES } from '../../errors/error-codes';
import {
  type RescueCaseReadCursor,
  type RescueReadSort,
  type RescueRepository,
} from '../../features/rescue/persistence/rescue-repository';
import {
  toRescueCaseDetail,
  toRescueCaseSummary,
  type RescueCaseDetail,
  type RescueCaseSummary,
} from './rescue-read-mapper';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const DEFAULT_RADIUS_METERS = 1_000;
const MIN_RADIUS_METERS = 100;
const MAX_RADIUS_METERS = 20_000;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_DATE_TIME_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,9})?)?(?:Z|[+-]\d{2}:\d{2})$/;

type RescueReadRepository = Pick<
  RescueRepository,
  'listPublicCases' | 'findPublicCase'
>;

export type RescueCaseListQuery = {
  status?: unknown;
  species?: unknown;
  lostFrom?: unknown;
  lostTo?: unknown;
  lat?: unknown;
  lng?: unknown;
  radiusMeters?: unknown;
  sort?: unknown;
  cursor?: unknown;
  limit?: unknown;
};

export type RescueCaseListResult = {
  items: RescueCaseSummary[];
  nextCursor?: string;
  limit: number;
};

type CursorEnvelope = {
  version: 1;
  filterFingerprint: string;
  position: RescueCaseReadCursor;
};

const invalidInput = (field: string, message: string): never => {
  throw new AppError(RESCUE_ERROR_CODES.invalidInput, message, 400, field);
};

const readOptionalString = (value: unknown, field: string) => {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || value.trim().length === 0) {
    return invalidInput(field, `${field} khong hop le.`);
  }
  return value.trim();
};

const readNumber = (value: unknown, field: string) => {
  if (value === undefined) return undefined;
  if (
    (typeof value !== 'string' && typeof value !== 'number') ||
    (typeof value === 'string' && value.trim().length === 0)
  ) {
    return invalidInput(field, `${field} phai la mot so hop le.`);
  }
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(parsed)) {
    return invalidInput(field, `${field} phai la mot so hop le.`);
  }
  return parsed;
};

const readInteger = (value: unknown, field: string) => {
  if (typeof value === 'string' && !/^-?\d+$/.test(value.trim())) {
    return invalidInput(field, `${field} phai la so nguyen hop le.`);
  }
  const parsed = readNumber(value, field);
  if (parsed === undefined) return undefined;
  if (!Number.isSafeInteger(parsed)) {
    return invalidInput(field, `${field} phai la so nguyen hop le.`);
  }
  return parsed;
};

const readDate = (value: unknown, field: string) => {
  const raw = readOptionalString(value, field);
  if (raw === undefined) return undefined;
  if (!ISO_DATE_TIME_PATTERN.test(raw)) {
    return invalidInput(field, `${field} phai la thoi gian ISO-8601.`);
  }
  const date = new Date(raw);
  if (!Number.isFinite(date.getTime())) {
    return invalidInput(field, `${field} phai la thoi gian ISO-8601.`);
  }
  return date;
};

const requireUuid = (value: unknown, field: string, notFound = false) => {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (!UUID_PATTERN.test(raw)) {
    if (notFound) {
      throw new AppError(
        RESCUE_ERROR_CODES.notFound,
        'Khong tim thay tin tim thu cung.',
        404,
      );
    }
    return invalidInput(field, `${field} khong hop le.`);
  }
  return raw;
};

const buildFilterFingerprint = (value: {
  status?: 'missing' | 'found';
  species?: 'dog' | 'cat' | 'other';
  lostFrom?: Date;
  lostTo?: Date;
  latitude?: number;
  longitude?: number;
  radiusMeters?: number;
  sort: RescueReadSort;
}) =>
  createHash('sha256')
    .update(
      JSON.stringify({
        status: value.status ?? null,
        species: value.species ?? null,
        lostFrom: value.lostFrom?.toISOString() ?? null,
        lostTo: value.lostTo?.toISOString() ?? null,
        latitude: value.latitude ?? null,
        longitude: value.longitude ?? null,
        radiusMeters: value.radiusMeters ?? null,
        sort: value.sort,
      }),
    )
    .digest('hex');

const encodeCursor = (
  position: RescueCaseReadCursor,
  filterFingerprint: string,
) =>
  Buffer.from(
    JSON.stringify({ version: 1, filterFingerprint, position }),
    'utf8',
  ).toString('base64url');

const parseCursorEnvelope = (cursor: string): Partial<CursorEnvelope> => {
  if (cursor.length > 2_048 || !/^[A-Za-z0-9_-]+$/.test(cursor)) {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }

  let envelope: unknown;
  try {
    envelope = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
  } catch {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }
  if (!envelope || typeof envelope !== 'object') {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }

  return envelope as Partial<CursorEnvelope>;
};

const validateCursorPosition = (position: RescueCaseReadCursor) => {
  requireUuid(position.caseId, 'cursor');
  if (position.sort === 'recent') {
    const date = new Date(position.lostAt);
    if (
      !Number.isFinite(date.getTime()) ||
      date.toISOString() !== position.lostAt
    ) {
      return invalidInput('cursor', 'Cursor khong hop le.');
    }
  } else if (
    !Number.isSafeInteger(position.distanceMeters) ||
    position.distanceMeters < 0
  ) {
    return invalidInput('cursor', 'Cursor khong hop le.');
  }
  return position;
};

const decodeCursor = (
  cursor: string,
  expectedSort: RescueReadSort,
  expectedFilterFingerprint: string,
): RescueCaseReadCursor => {
  const candidate = parseCursorEnvelope(cursor);
  if (
    candidate.version !== 1 ||
    candidate.filterFingerprint !== expectedFilterFingerprint ||
    !candidate.position ||
    candidate.position.sort !== expectedSort
  ) {
    return invalidInput(
      'cursor',
      'Cursor khong khop voi bo loc hoac cach sap xep.',
    );
  }

  return validateCursorPosition(candidate.position);
};

const requireRepository = (
  repository?: RescueReadRepository,
): RescueReadRepository => {
  if (!repository) {
    throw new Error('Rescue persistence is unavailable.');
  }
  return repository;
};

const readCaseStatus = (value: unknown) => {
  const statusRaw = readOptionalString(value, 'status');
  if (statusRaw && statusRaw !== 'missing' && statusRaw !== 'found') {
    return invalidInput('status', 'status chi nhan missing hoac found.');
  }
  return statusRaw as 'missing' | 'found' | undefined;
};

const readCaseSpecies = (value: unknown) => {
  const speciesRaw = readOptionalString(value, 'species');
  if (
    speciesRaw &&
    speciesRaw !== 'dog' &&
    speciesRaw !== 'cat' &&
    speciesRaw !== 'other'
  ) {
    return invalidInput('species', 'species chi nhan dog, cat hoac other.');
  }
  return speciesRaw as 'dog' | 'cat' | 'other' | undefined;
};

const readLostRange = (query: RescueCaseListQuery) => {
  const lostFrom = readDate(query.lostFrom, 'lostFrom');
  const lostTo = readDate(query.lostTo, 'lostTo');
  if (lostFrom && lostTo && lostFrom.getTime() > lostTo.getTime()) {
    return invalidInput('lostFrom', 'lostFrom phai som hon hoac bang lostTo.');
  }
  return { lostFrom, lostTo };
};

const readCaseCenter = (query: RescueCaseListQuery) => {
  const latitude = readNumber(query.lat, 'lat');
  const longitude = readNumber(query.lng, 'lng');
  if ((latitude === undefined) !== (longitude === undefined)) {
    return invalidInput('lat', 'lat va lng phai duoc gui cung nhau.');
  }
  if (latitude !== undefined && (latitude < -90 || latitude > 90)) {
    return invalidInput('lat', 'lat phai nam trong khoang -90 den 90.');
  }
  if (longitude !== undefined && (longitude < -180 || longitude > 180)) {
    return invalidInput('lng', 'lng phai nam trong khoang -180 den 180.');
  }
  return { latitude, longitude };
};

const readCaseRadius = (value: unknown, latitude: number | undefined) => {
  const radiusInput = readInteger(value, 'radiusMeters');
  if (radiusInput !== undefined && latitude === undefined) {
    return invalidInput(
      'radiusMeters',
      'radiusMeters chi hop le khi co lat va lng.',
    );
  }
  if (
    radiusInput !== undefined &&
    (radiusInput < MIN_RADIUS_METERS || radiusInput > MAX_RADIUS_METERS)
  ) {
    return invalidInput(
      'radiusMeters',
      `radiusMeters phai tu ${MIN_RADIUS_METERS} den ${MAX_RADIUS_METERS}.`,
    );
  }
  return latitude === undefined
    ? undefined
    : (radiusInput ?? DEFAULT_RADIUS_METERS);
};

const readCaseSort = (value: unknown, latitude: number | undefined) => {
  const sortRaw = readOptionalString(value, 'sort') ?? 'recent';
  if (sortRaw !== 'recent' && sortRaw !== 'distance') {
    return invalidInput('sort', 'sort chi nhan recent hoac distance.');
  }
  const sort: RescueReadSort = sortRaw;
  if (sort === 'distance' && latitude === undefined) {
    return invalidInput('sort', 'sort=distance can lat va lng.');
  }
  return sort;
};

const readCaseLimit = (value: unknown) => {
  const limit = readInteger(value, 'limit') ?? DEFAULT_LIMIT;
  if (limit < 1 || limit > MAX_LIMIT) {
    return invalidInput('limit', `limit phai tu 1 den ${MAX_LIMIT}.`);
  }
  return limit;
};

export const createRescueReadService = (options: {
  repository?: RescueReadRepository;
}) => ({
  async listCases(
    query: RescueCaseListQuery = {},
    viewerUserId?: string,
  ): Promise<RescueCaseListResult> {
    const status = readCaseStatus(query.status);
    const species = readCaseSpecies(query.species);
    const { lostFrom, lostTo } = readLostRange(query);
    const { latitude, longitude } = readCaseCenter(query);
    const radiusMeters = readCaseRadius(query.radiusMeters, latitude);
    const sort = readCaseSort(query.sort, latitude);
    const limit = readCaseLimit(query.limit);
    const normalizedFilters = {
      status,
      species,
      lostFrom,
      lostTo,
      latitude,
      longitude,
      radiusMeters,
      sort,
    };
    const filterFingerprint = buildFilterFingerprint(normalizedFilters);
    const cursorRaw = readOptionalString(query.cursor, 'cursor');
    const cursor = cursorRaw
      ? decodeCursor(cursorRaw, sort, filterFingerprint)
      : undefined;

    const page = await requireRepository(options.repository).listPublicCases({
      ...normalizedFilters,
      cursor,
      limit,
    });
    return {
      items: page.items.map((item) => toRescueCaseSummary(item, viewerUserId)),
      ...(page.nextCursor
        ? { nextCursor: encodeCursor(page.nextCursor, filterFingerprint) }
        : {}),
      limit: page.limit,
    };
  },

  async getCase(
    caseId: unknown,
    viewerUserId?: string,
  ): Promise<RescueCaseDetail> {
    const normalizedCaseId = requireUuid(caseId, 'caseId', true);
    const rescueCase = await requireRepository(
      options.repository,
    ).findPublicCase(normalizedCaseId);
    if (!rescueCase) {
      throw new AppError(
        RESCUE_ERROR_CODES.notFound,
        'Khong tim thay tin tim thu cung.',
        404,
      );
    }
    return toRescueCaseDetail(rescueCase, viewerUserId);
  },
});

export type RescueReadService = ReturnType<typeof createRescueReadService>;
