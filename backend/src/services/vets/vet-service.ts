import { readFile } from 'node:fs/promises';
import path from 'node:path';

import { AppError } from '../../errors/app-error';
import { VET_ERROR_CODES } from '../../errors/error-codes';

export type VetClinic = {
  id: string;
  name: string;
  city: string;
  district: string;
  address: string;
  phone: string;
  latitude: number | null;
  longitude: number | null;
  website: string | null;
  is24h: boolean | null;
  openHours: string[];
  services: string[];
  photoUrls: string[];
  averageRating: number | null;
  reviewCount: number;
  sourceUrl: string;
  sourceList: string;
  sourceRank: number;
  priorityTier: string;
  selectionReason: string;
  enrichmentStatus: string;
  readyForMap: boolean;
};

type VetSeedFile = {
  clinics: VetClinic[];
};

type VetPilotOverlayClinic = Partial<Omit<VetClinic, 'id'>> & {
  id: string;
};

type VetPilotOverlayFile = {
  clinics: VetPilotOverlayClinic[];
};

type VetSummaryShape = Pick<
  VetClinic,
  | 'id'
  | 'name'
  | 'city'
  | 'district'
  | 'address'
  | 'phone'
  | 'latitude'
  | 'longitude'
  | 'services'
  | 'sourceRank'
  | 'averageRating'
  | 'reviewCount'
  | 'is24h'
  | 'openHours'
  | 'readyForMap'
> & {
  distanceMeters?: number;
};

export type VetNearbyCandidate = VetSummaryShape;

export type VetNearbyStore = {
  listNearby: (input: {
    latitude: number;
    longitude: number;
    radiusMeters: number;
    is24h?: boolean;
    minRating?: number;
  }) => Promise<VetNearbyCandidate[]>;
  getDetailById?: (vetId: string) => Promise<VetClinic | undefined>;
};

export type VetSummary = {
  id: string;
  name: string;
  city: string;
  district: string;
  address: string;
  phone: string;
  summary?: string;
  services: string[];
  seedRank: number;
  averageRating?: number;
  reviewCount: number;
  is24h?: boolean;
  isOpen?: boolean;
  readyForMap: boolean;
  latitude?: number;
  longitude?: number;
  distanceMeters?: number;
};

export type VetDetail = VetSummary & {
  website?: string;
  openHours: string[];
  photoUrls: string[];
  source: {
    url: string;
    list: string;
    priorityTier: string;
    enrichmentStatus: string;
    selectionReason: string;
  };
};

export type VetSearchInput = {
  q?: string;
  city?: string;
  district?: string;
  limit?: number;
  cursor?: string;
  is24h?: boolean;
  isOpenNow?: boolean;
  minRating?: number;
  sort?: 'curated' | 'rating-desc' | 'name-asc';
};

export type VetNearbyInput = {
  latitude: number;
  longitude: number;
  radius?: number;
  limit?: number;
  cursor?: string;
  is24h?: boolean;
  isOpenNow?: boolean;
  minRating?: number;
};

export type VetSearchResult = {
  items: VetSummary[];
  nextCursor?: string;
  total: number;
  limit: number;
};

export type VetNearbyResult = VetSearchResult;

export type VetService = ReturnType<typeof createVetService>;

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const DEFAULT_NEARBY_RADIUS_METERS = 3000;
const MIN_NEARBY_RADIUS_METERS = 1000;
const MAX_NEARBY_RADIUS_METERS = 10000;
const HO_CHI_MINH_TIMEZONE = 'Asia/Ho_Chi_Minh';
const EARTH_RADIUS_METERS = 6371000;

const normalizeForSearch = (value?: string) =>
  (value ?? '')
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .trim();

const toRadians = (degrees: number) => (degrees * Math.PI) / 180;

const haversineDistanceMeters = (
  fromLatitude: number,
  fromLongitude: number,
  toLatitude: number,
  toLongitude: number,
) => {
  const latitudeDelta = toRadians(toLatitude - fromLatitude);
  const longitudeDelta = toRadians(toLongitude - fromLongitude);
  const fromLatitudeRadians = toRadians(fromLatitude);
  const toLatitudeRadians = toRadians(toLatitude);

  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(fromLatitudeRadians) *
      Math.cos(toLatitudeRadians) *
      Math.sin(longitudeDelta / 2) ** 2;

  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(a));
};

const readHoChiMinhTimeParts = (now: Date) => {
  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: HO_CHI_MINH_TIMEZONE,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  });

  const parts = formatter.formatToParts(now);
  const partMap = Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value]),
  );

  return {
    weekday: (partMap.weekday ?? '').toLowerCase(),
    hour: Number.parseInt(partMap.hour ?? '0', 10),
    minute: Number.parseInt(partMap.minute ?? '0', 10),
  };
};

const pickOpenHoursEntry = (openHours: string[], weekday: string) => {
  if (openHours.length === 0) {
    return undefined;
  }

  const weekdayAliases: Record<string, string[]> = {
    mon: ['mon', 't2', 'thứ 2', 'thu 2'],
    tue: ['tue', 't3', 'thứ 3', 'thu 3'],
    wed: ['wed', 't4', 'thứ 4', 'thu 4'],
    thu: ['thu', 't5', 'thứ 5', 'thu 5'],
    fri: ['fri', 't6', 'thứ 6', 'thu 6'],
    sat: ['sat', 't7', 'thứ 7', 'thu 7'],
    sun: ['sun', 'cn', 'chủ nhật', 'chu nhat'],
  };

  const aliases = weekdayAliases[weekday] ?? [];
  const exactMatch = openHours.find((entry) => {
    const normalizedEntry = normalizeForSearch(entry);
    return aliases.some((alias) => normalizedEntry.includes(normalizeForSearch(alias)));
  });

  if (exactMatch) {
    return exactMatch.trim();
  }

  return openHours.find((entry) => entry.trim().length > 0)?.trim();
};

const computeIsOpen = (
  clinic: Pick<VetSummaryShape, 'is24h' | 'openHours'>,
  now: Date,
) => {
  if (clinic.is24h === true) {
    return true;
  }

  const normalizedEntries = clinic.openHours.map((entry) => normalizeForSearch(entry));
  if (
    normalizedEntries.some(
      (entry) => entry.includes('24/7') || entry.includes('24h'),
    )
  ) {
    return true;
  }

  const { weekday, hour, minute } = readHoChiMinhTimeParts(now);
  const entry = pickOpenHoursEntry(clinic.openHours, weekday);
  if (!entry) {
    return undefined;
  }

  const match = entry.match(/(\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})/);
  if (!match) {
    return undefined;
  }

  const openMinutes =
    Number.parseInt(match[1] ?? '0', 10) * 60 +
    Number.parseInt(match[2] ?? '0', 10);
  const closeMinutes =
    Number.parseInt(match[3] ?? '0', 10) * 60 +
    Number.parseInt(match[4] ?? '0', 10);
  const currentMinutes = hour * 60 + minute;

  if (closeMinutes < openMinutes) {
    return currentMinutes >= openMinutes || currentMinutes <= closeMinutes;
  }

  return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
};

const buildSummary = (clinic: VetSummaryShape) => {
  if (clinic.services.length > 0) {
    return clinic.services.slice(0, 3).join(' • ');
  }

  return `Phòng khám được đưa vào danh sách ưu tiên tại ${clinic.district}, ${clinic.city}.`;
};

const mapToSummary = (clinic: VetSummaryShape, now: Date): VetSummary => ({
  id: clinic.id,
  name: clinic.name,
  city: clinic.city,
  district: clinic.district,
  address: clinic.address,
  phone: clinic.phone,
  summary: buildSummary(clinic),
  services: clinic.services,
  seedRank: clinic.sourceRank,
  averageRating:
    typeof clinic.averageRating === 'number' ? clinic.averageRating : undefined,
  reviewCount: clinic.reviewCount,
  is24h: clinic.is24h ?? undefined,
  isOpen: computeIsOpen(clinic, now),
  readyForMap: clinic.readyForMap,
  latitude:
    typeof clinic.latitude === 'number' ? clinic.latitude : undefined,
  longitude:
    typeof clinic.longitude === 'number' ? clinic.longitude : undefined,
  distanceMeters:
    typeof clinic.distanceMeters === 'number'
      ? Number(clinic.distanceMeters.toFixed(1))
      : undefined,
});

const mapToDetail = (clinic: VetClinic, now: Date): VetDetail => ({
  ...mapToSummary(clinic, now),
  website: clinic.website ?? undefined,
  openHours: clinic.openHours,
  photoUrls: clinic.photoUrls,
  source: {
    url: clinic.sourceUrl,
    list: clinic.sourceList,
    priorityTier: clinic.priorityTier,
    enrichmentStatus: clinic.enrichmentStatus,
    selectionReason: clinic.selectionReason,
  },
});

const mergeClinics = (
  baseClinics: VetClinic[],
  overlayClinics: VetPilotOverlayClinic[],
): VetClinic[] => {
  if (overlayClinics.length === 0) {
    return baseClinics;
  }

  const overlayById = new Map(
    overlayClinics.map((clinic) => [clinic.id, clinic]),
  );

  return baseClinics.map((clinic) => {
    const overlay = overlayById.get(clinic.id);
    if (!overlay) {
      return clinic;
    }

    return {
      ...clinic,
      ...overlay,
      id: clinic.id,
      openHours: overlay.openHours ?? clinic.openHours,
      services: overlay.services ?? clinic.services,
      photoUrls: overlay.photoUrls ?? clinic.photoUrls,
    };
  });
};

const readJsonFile = async <T>(filePath: string) => {
  const raw = await readFile(filePath, 'utf8');
  return JSON.parse(raw) as T;
};

export const createVetService = (
  options: {
    seedPath?: string;
    pilotSeedPath?: string;
    seedData?: VetSeedFile;
    pilotSeedData?: VetPilotOverlayFile;
    nearbyStore?: VetNearbyStore;
    now?: () => Date;
  } = {},
) => {
  let cachedClinicsPromise: Promise<VetClinic[]> | undefined;
  const nowProvider = options.now ?? (() => new Date());

  const loadClinics = async () => {
    if (options.seedData) {
      return mergeClinics(
        options.seedData.clinics,
        options.pilotSeedData?.clinics ?? [],
      );
    }

    if (!cachedClinicsPromise) {
      const seedPath =
        options.seedPath ??
        path.resolve(process.cwd(), 'prisma', 'data', 'day2_vet_seed_candidates.json');
      const pilotSeedPath =
        options.pilotSeedPath ??
        path.resolve(process.cwd(), 'prisma', 'data', 'day3_vet_geo_pilot.json');
      cachedClinicsPromise = Promise.all([
        readJsonFile<VetSeedFile>(seedPath),
        readJsonFile<VetPilotOverlayFile>(pilotSeedPath).catch(() => ({
          clinics: [],
        })),
      ]).then(([seedFile, pilotFile]) =>
        mergeClinics(seedFile.clinics ?? [], pilotFile.clinics ?? []),
      );
    }

    return cachedClinicsPromise;
  };

  const validateLimit = (limit?: number) => {
    if (limit === undefined) {
      return DEFAULT_LIMIT;
    }

    if (!Number.isInteger(limit) || limit <= 0 || limit > MAX_LIMIT) {
      throw new AppError(
        VET_ERROR_CODES.invalidQuery,
        `Limit phải nằm trong khoảng 1-${MAX_LIMIT}.`,
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
        VET_ERROR_CODES.invalidQuery,
        'Cursor không hợp lệ.',
        400,
        'cursor',
      );
    }

    return offset;
  };

  const validateRadius = (radius?: number) => {
    if (radius === undefined) {
      return DEFAULT_NEARBY_RADIUS_METERS;
    }

    if (
      !Number.isFinite(radius) ||
      radius < MIN_NEARBY_RADIUS_METERS ||
      radius > MAX_NEARBY_RADIUS_METERS
    ) {
      throw new AppError(
        VET_ERROR_CODES.invalidQuery,
        `Bán kính phải nằm trong khoảng ${MIN_NEARBY_RADIUS_METERS}-${MAX_NEARBY_RADIUS_METERS} mét.`,
        400,
        'radius',
      );
    }

    return Math.round(radius);
  };

  const listNearbyInMemory = async (input: {
    latitude: number;
    longitude: number;
    radiusMeters: number;
    is24h?: boolean;
    minRating?: number;
  }) => {
    const clinics = await loadClinics();

    return clinics
      .filter(
        (clinic) =>
          clinic.readyForMap &&
          typeof clinic.latitude === 'number' &&
          typeof clinic.longitude === 'number',
      )
      .map((clinic) => ({
        ...clinic,
        distanceMeters: haversineDistanceMeters(
          input.latitude,
          input.longitude,
          clinic.latitude as number,
          clinic.longitude as number,
        ),
      }))
      .filter((clinic) => clinic.distanceMeters <= input.radiusMeters)
      .filter((clinic) =>
        input.is24h === true ? clinic.is24h === true : true,
      )
      .filter((clinic) =>
        typeof input.minRating === 'number'
          ? typeof clinic.averageRating === 'number' &&
            clinic.averageRating >= input.minRating
          : true,
      );
  };

  return {
    async search(input: VetSearchInput): Promise<VetSearchResult> {
      const limit = validateLimit(input.limit);
      const offset = parseCursorOffset(input.cursor);
      const query = normalizeForSearch(input.q);
      const city = normalizeForSearch(input.city);
      const district = normalizeForSearch(input.district);
      const { minRating } = input;
      const sort = input.sort ?? 'curated';
      const now = nowProvider();

      const clinics = await loadClinics();
      const filtered = clinics
        .filter((clinic) => {
          const matchesCity =
            !city || normalizeForSearch(clinic.city) === city;
          const matchesDistrict =
            !district || normalizeForSearch(clinic.district) === district;
          const haystack = normalizeForSearch(
            [
              clinic.name,
              clinic.city,
              clinic.district,
              clinic.address,
              clinic.phone,
              ...clinic.services,
            ].join(' '),
          );
          const matchesQuery = !query || haystack.includes(query);
          const matches24h =
            input.is24h === true ? clinic.is24h === true : true;
          const isOpen = computeIsOpen(clinic, now);
          const matchesOpenNow =
            input.isOpenNow === true ? isOpen === true : true;
          const matchesRating =
            typeof minRating === 'number'
              ? typeof clinic.averageRating === 'number' &&
                clinic.averageRating >= minRating
              : true;

          return (
            matchesCity &&
            matchesDistrict &&
            matchesQuery &&
            matches24h &&
            matchesOpenNow &&
            matchesRating
          );
        })
        .sort((left, right) => {
          if (sort === 'rating-desc') {
            const leftRating =
              typeof left.averageRating === 'number' ? left.averageRating : -1;
            const rightRating =
              typeof right.averageRating === 'number' ? right.averageRating : -1;
            const ratingCompare = rightRating - leftRating;
            if (ratingCompare !== 0) {
              return ratingCompare;
            }
          }

          if (sort === 'name-asc') {
            return left.name.localeCompare(right.name, 'vi');
          }

          const priorityCompare = left.sourceRank - right.sourceRank;
          if (priorityCompare !== 0) {
            return priorityCompare;
          }

          return left.name.localeCompare(right.name, 'vi');
        });

      const slice = filtered.slice(offset, offset + limit);
      const nextOffset = offset + slice.length;
      const nextCursor = nextOffset < filtered.length ? `${nextOffset}` : undefined;

      return {
        items: slice.map((clinic) => mapToSummary(clinic, now)),
        nextCursor,
        total: filtered.length,
        limit,
      };
    },

    async nearby(input: VetNearbyInput): Promise<VetNearbyResult> {
      const limit = validateLimit(input.limit);
      const offset = parseCursorOffset(input.cursor);
      const radiusMeters = validateRadius(input.radius);
      const now = nowProvider();

      const nearbyCandidates = options.nearbyStore
        ? await options.nearbyStore.listNearby({
            latitude: input.latitude,
            longitude: input.longitude,
            radiusMeters,
            is24h: input.is24h,
            minRating: input.minRating,
          })
        : await listNearbyInMemory({
            latitude: input.latitude,
            longitude: input.longitude,
            radiusMeters,
            is24h: input.is24h,
            minRating: input.minRating,
          });

      const filtered = nearbyCandidates
        .filter((clinic) =>
          input.isOpenNow === true ? computeIsOpen(clinic, now) === true : true,
        )
        .sort((left, right) => {
          const distanceCompare = (left.distanceMeters ?? 0) - (right.distanceMeters ?? 0);
          if (distanceCompare !== 0) {
            return distanceCompare;
          }

          const rankCompare = left.sourceRank - right.sourceRank;
          if (rankCompare !== 0) {
            return rankCompare;
          }

          return left.name.localeCompare(right.name, 'vi');
        });

      const slice = filtered.slice(offset, offset + limit);
      const nextOffset = offset + slice.length;
      const nextCursor = nextOffset < filtered.length ? `${nextOffset}` : undefined;

      return {
        items: slice.map((clinic) => mapToSummary(clinic, now)),
        nextCursor,
        total: filtered.length,
        limit,
      };
    },

    async get(vetId: string): Promise<VetDetail> {
      const clinics = await loadClinics();
      let clinic = clinics.find((item) => item.id === vetId);
      if (!clinic && options.nearbyStore?.getDetailById) {
        clinic = await options.nearbyStore.getDetailById(vetId);
      }

      if (!clinic) {
        throw new AppError(
          VET_ERROR_CODES.notFound,
          'Không tìm thấy phòng khám thú y.',
          404,
        );
      }

      return mapToDetail(clinic, nowProvider());
    },
  };
};
