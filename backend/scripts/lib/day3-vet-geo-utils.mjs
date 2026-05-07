import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(__dirname, '..', '..');
const seedRoot = path.join(backendRoot, 'prisma', 'data');

export const loadBackendEnv = () => {
  dotenv.config({
    path: [
      path.join(backendRoot, '.env.local'),
      path.join(backendRoot, '.env'),
    ],
    override: true,
  });

  const databaseUrl = process.env.DATABASE_URL?.trim();
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required for Day 3 vet geo scripts.');
  }

  return {
    backendRoot,
    databaseUrl,
  };
};

export const createPrismaForDatabase = (databaseUrl) =>
  new PrismaClient({
    datasources: {
      db: {
        url: databaseUrl,
      },
    },
  });

const schemaStatements = [
  'CREATE EXTENSION IF NOT EXISTS postgis',
  `ALTER TABLE public.vets
    ADD COLUMN IF NOT EXISTS external_id text,
    ADD COLUMN IF NOT EXISTS source_rank integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS ready_for_map boolean NOT NULL DEFAULT false`,
  `DO $$
    BEGIN
      IF to_regclass('public.vets_external_id_uidx') IS NULL THEN
        EXECUTE 'CREATE UNIQUE INDEX vets_external_id_uidx ON public.vets (external_id)';
      END IF;
    END $$`,
  `DO $$
    BEGIN
      IF to_regclass('public.vets_ready_for_map_source_rank_idx') IS NULL THEN
        EXECUTE 'CREATE INDEX vets_ready_for_map_source_rank_idx ON public.vets (ready_for_map, source_rank)';
      END IF;
    END $$`,
  `DO $$
    BEGIN
      IF to_regclass('public.vets_location_gist_idx') IS NULL THEN
        EXECUTE 'CREATE INDEX vets_location_gist_idx ON public.vets USING GIST (location)';
      END IF;
    END $$`,
];

export const readJsonFile = async (filePath) => {
  const raw = await import('node:fs/promises').then(({ readFile }) =>
    readFile(filePath, 'utf8'),
  );
  return JSON.parse(raw);
};

export const mergeVetSeedWithOverlay = (seedFile, overlayFile) => {
  const overlayById = new Map(
    (overlayFile?.clinics ?? []).map((clinic) => [clinic.id, clinic]),
  );

  return (seedFile?.clinics ?? []).map((clinic) => {
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

export const loadVetSeedFiles = async ({
  seedPath = path.join(seedRoot, 'day2_vet_seed_candidates.json'),
  overlayPath = path.join(seedRoot, 'day3_vet_geo_pilot.json'),
} = {}) => {
  const [seedFile, overlayFile] = await Promise.all([
    readJsonFile(seedPath),
    readJsonFile(overlayPath),
  ]);

  return {
    seedPath,
    overlayPath,
    seedFile,
    overlayFile,
    clinics: mergeVetSeedWithOverlay(seedFile, overlayFile),
  };
};

export const ensureVetGeoSchema = async (prisma) => {
  for (const statement of schemaStatements) {
    await prisma.$executeRawUnsafe(statement);
  }
};

export const upsertVetDirectoryEntry = async (prisma, clinic) => {
  if (
    typeof clinic.latitude !== 'number' ||
    typeof clinic.longitude !== 'number'
  ) {
    throw new Error(`Clinic ${clinic.id} is missing latitude/longitude.`);
  }

  const existing = await prisma.$queryRawUnsafe(
    'SELECT id FROM public.vets WHERE external_id = $1 LIMIT 1',
    clinic.id,
  );
  const vetId = existing[0]?.id ?? randomUUID();

  await prisma.$executeRawUnsafe(
    `
      INSERT INTO public.vets (
        id,
        external_id,
        name,
        phone,
        email,
        address,
        ward,
        district,
        city,
        location,
        opening_hours,
        is_24h,
        average_rating,
        review_count,
        source_rank,
        ready_for_map,
        created_at,
        updated_at
      )
      VALUES (
        $1::uuid,
        $2,
        $3,
        $4,
        NULL,
        $5,
        NULL,
        $6,
        $7,
        ST_SetSRID(ST_MakePoint($8, $9), 4326)::geography,
        $10::jsonb,
        $11,
        $12::numeric,
        $13,
        $14,
        $15,
        NOW(),
        NOW()
      )
      ON CONFLICT (external_id) DO UPDATE SET
        name = EXCLUDED.name,
        phone = EXCLUDED.phone,
        address = EXCLUDED.address,
        district = EXCLUDED.district,
        city = EXCLUDED.city,
        location = EXCLUDED.location,
        opening_hours = EXCLUDED.opening_hours,
        is_24h = EXCLUDED.is_24h,
        average_rating = EXCLUDED.average_rating,
        review_count = EXCLUDED.review_count,
        source_rank = EXCLUDED.source_rank,
        ready_for_map = EXCLUDED.ready_for_map,
        updated_at = NOW()
    `,
    vetId,
    clinic.id,
    clinic.name,
    clinic.phone?.trim() || null,
    clinic.address,
    clinic.district?.trim() || null,
    clinic.city?.trim() || null,
    clinic.longitude,
    clinic.latitude,
    JSON.stringify(clinic.openHours ?? []),
    clinic.is24h === true,
    clinic.averageRating ?? null,
    clinic.reviewCount ?? 0,
    clinic.sourceRank ?? 0,
    clinic.readyForMap === true,
  );

  await prisma.$executeRawUnsafe(
    'DELETE FROM public.vet_services WHERE vet_id = $1::uuid',
    vetId,
  );

  const services = Array.isArray(clinic.services) ? clinic.services : [];
  for (const serviceName of services) {
    if (!serviceName || !serviceName.trim()) {
      // eslint-disable-next-line no-continue
      continue;
    }

    await prisma.$executeRawUnsafe(
      `
        INSERT INTO public.vet_services (
          id,
          vet_id,
          service_name,
          is_emergency,
          created_at
        )
        VALUES ($1::uuid, $2::uuid, $3, $4, NOW())
      `,
      randomUUID(),
      vetId,
      serviceName.trim(),
      /24\/7|cấp cứu/i.test(serviceName),
    );
  }

  return vetId;
};

export const removePerfEntries = async (prisma) => {
  await prisma.$executeRawUnsafe(
    `
      DELETE FROM public.vet_services
      WHERE vet_id IN (
        SELECT id FROM public.vets WHERE external_id LIKE 'perf-%'
      )
    `,
  );
  await prisma.$executeRawUnsafe(
    "DELETE FROM public.vets WHERE external_id LIKE 'perf-%'",
  );
};
