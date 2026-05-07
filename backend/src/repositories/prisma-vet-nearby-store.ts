import { PrismaClient } from '@prisma/client';

import {
  type VetClinic,
  type VetNearbyCandidate,
  type VetNearbyStore,
} from '../services/vets/vet-service';

type VetDirectoryRow = {
  id: string;
  name: string;
  city: string | null;
  district: string | null;
  address: string;
  phone: string | null;
  latitude: number;
  longitude: number;
  services: unknown;
  sourceRank: number | null;
  averageRating: number | string | null;
  reviewCount: number | null;
  is24h: boolean | null;
  openHours: unknown;
  readyForMap: boolean;
  distanceMeters?: number;
};

type VetNearbyRow = VetDirectoryRow & {
  distanceMeters: number;
};

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

  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number.parseFloat(value);
    return Number.isNaN(parsed) ? undefined : parsed;
  }

  return undefined;
};

const mapRowToCandidate = (row: VetDirectoryRow): VetNearbyCandidate => ({
  id: row.id,
  name: row.name,
  city: row.city ?? '',
  district: row.district ?? '',
  address: row.address,
  phone: row.phone ?? '',
  latitude: row.latitude,
  longitude: row.longitude,
  services: readStringList(row.services),
  sourceRank: row.sourceRank ?? 0,
  averageRating: readNumber(row.averageRating) ?? null,
  reviewCount: row.reviewCount ?? 0,
  is24h: row.is24h,
  openHours: readStringList(row.openHours),
  readyForMap: row.readyForMap,
  distanceMeters: row.distanceMeters,
});

const mapRowToClinic = (row: VetDirectoryRow): VetClinic => ({
  ...mapRowToCandidate(row),
  website: null,
  photoUrls: [],
  sourceUrl: '',
  sourceList: 'runtime-vet-directory',
  priorityTier: 'map-ready',
  selectionReason: 'Matched from the Day 3 map-ready vet directory.',
  enrichmentStatus: 'runtime-db-ready',
});

export class PrismaVetNearbyStore implements VetNearbyStore {
  constructor(private readonly prisma: PrismaClient) {}

  async listNearby(input: {
    latitude: number;
    longitude: number;
    radiusMeters: number;
    is24h?: boolean;
    minRating?: number;
  }): Promise<VetNearbyCandidate[]> {
    const rows = await this.prisma.$queryRawUnsafe<VetNearbyRow[]>(
      `
        SELECT
          v.external_id AS id,
          v.name,
          v.city,
          v.district,
          v.address,
          v.phone,
          ST_Y(v.location::geometry) AS latitude,
          ST_X(v.location::geometry) AS longitude,
          COALESCE(
            jsonb_agg(vs.service_name) FILTER (WHERE vs.service_name IS NOT NULL),
            '[]'::jsonb
          ) AS services,
          v.source_rank AS "sourceRank",
          v.average_rating AS "averageRating",
          v.review_count AS "reviewCount",
          v.is_24h AS "is24h",
          COALESCE(v.opening_hours, '[]'::jsonb) AS "openHours",
          v.ready_for_map AS "readyForMap",
          ST_Distance(
            v.location,
            ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
          ) AS "distanceMeters"
        FROM public.vets v
        LEFT JOIN public.vet_services vs ON vs.vet_id = v.id
        WHERE v.ready_for_map = TRUE
          AND v.external_id IS NOT NULL
          AND v.external_id NOT LIKE 'perf-%'
          AND ST_DWithin(
            v.location,
            ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
            $3
          )
          AND ($4::boolean IS NULL OR v.is_24h = $4::boolean)
          AND (
            $5::numeric IS NULL OR
            (v.average_rating IS NOT NULL AND v.average_rating >= $5::numeric)
          )
        GROUP BY v.id
        ORDER BY "distanceMeters" ASC, v.source_rank ASC, v.name ASC
      `,
      input.longitude,
      input.latitude,
      input.radiusMeters,
      input.is24h ?? null,
      input.minRating ?? null,
    );

    return rows.map(mapRowToCandidate);
  }

  async getDetailById(vetId: string): Promise<VetClinic | undefined> {
    const rows = await this.prisma.$queryRawUnsafe<VetDirectoryRow[]>(
      `
        SELECT
          v.external_id AS id,
          v.name,
          v.city,
          v.district,
          v.address,
          v.phone,
          ST_Y(v.location::geometry) AS latitude,
          ST_X(v.location::geometry) AS longitude,
          COALESCE(
            jsonb_agg(vs.service_name) FILTER (WHERE vs.service_name IS NOT NULL),
            '[]'::jsonb
          ) AS services,
          v.source_rank AS "sourceRank",
          v.average_rating AS "averageRating",
          v.review_count AS "reviewCount",
          v.is_24h AS "is24h",
          COALESCE(v.opening_hours, '[]'::jsonb) AS "openHours",
          v.ready_for_map AS "readyForMap"
        FROM public.vets v
        LEFT JOIN public.vet_services vs ON vs.vet_id = v.id
        WHERE v.ready_for_map = TRUE
          AND v.external_id = $1
          AND v.external_id NOT LIKE 'perf-%'
        GROUP BY v.id
        LIMIT 1
      `,
      vetId,
    );

    const row = rows[0];
    return row ? mapRowToClinic(row) : undefined;
  }
}
