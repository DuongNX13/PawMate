import { performance } from 'node:perf_hooks';

import {
  createPrismaForDatabase,
  ensureVetGeoSchema,
  loadBackendEnv,
} from './lib/day3-vet-geo-utils.mjs';

const nearbySql = `
  SELECT
    v.external_id,
    ST_Distance(
      v.location,
      ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
    ) AS distance_meters
  FROM public.vets v
  WHERE v.ready_for_map = TRUE
    AND v.external_id IS NOT NULL
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
  ORDER BY distance_meters ASC, v.source_rank ASC, v.name ASC
  LIMIT $6
`;

const scenarios = [
  { name: 'hn-1km', latitude: 21.0285, longitude: 105.8542, radius: 1000, is24h: null, minRating: null },
  { name: 'hn-3km', latitude: 21.0285, longitude: 105.8542, radius: 3000, is24h: null, minRating: null },
  { name: 'hn-5km-24h', latitude: 21.0285, longitude: 105.8542, radius: 5000, is24h: true, minRating: null },
  { name: 'hcm-1km', latitude: 10.7769, longitude: 106.7009, radius: 1000, is24h: null, minRating: null },
  { name: 'hcm-3km-rating', latitude: 10.7769, longitude: 106.7009, radius: 3000, is24h: null, minRating: 4.5 },
  { name: 'hcm-10km', latitude: 10.7769, longitude: 106.7009, radius: 10000, is24h: null, minRating: null },
  { name: 'hp-3km', latitude: 20.8449, longitude: 106.6881, radius: 3000, is24h: null, minRating: null },
  { name: 'dn-3km', latitude: 16.0544, longitude: 108.2022, radius: 3000, is24h: null, minRating: null },
  { name: 'no-result-small-radius', latitude: 11.0000, longitude: 107.5000, radius: 1000, is24h: null, minRating: null },
  { name: 'mixed-open-24h', latitude: 10.7769, longitude: 106.7009, radius: 5000, is24h: true, minRating: 4.0 },
];
const iterationsPerScenario = 5;

const percentile = (values, point) => {
  if (values.length === 0) {
    return 0;
  }

  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(
    sorted.length - 1,
    Math.max(0, Math.ceil((point / 100) * sorted.length) - 1),
  );
  return Number(sorted[index].toFixed(2));
};

const main = async () => {
  const { databaseUrl } = loadBackendEnv();
  const prisma = createPrismaForDatabase(databaseUrl);

  try {
    await ensureVetGeoSchema(prisma);

    await prisma.$queryRawUnsafe(
      nearbySql,
      106.7009,
      10.7769,
      3000,
      null,
      null,
      20,
    );

    const samples = [];

    for (const scenario of scenarios) {
      for (let iteration = 1; iteration <= iterationsPerScenario; iteration += 1) {
        const started = performance.now();
        const rows = await prisma.$queryRawUnsafe(
          nearbySql,
          scenario.longitude,
          scenario.latitude,
          scenario.radius,
          scenario.is24h,
          scenario.minRating,
          20,
        );
        const durationMs = performance.now() - started;

        samples.push({
          scenario: scenario.name,
          iteration,
          durationMs: Number(durationMs.toFixed(2)),
          resultCount: rows.length,
        });
      }
    }

    const durations = samples.map((measurement) => measurement.durationMs);
    const scenarioStats = scenarios.map((scenario) => {
      const scenarioDurations = samples
        .filter((sample) => sample.scenario == scenario.name)
        .map((sample) => sample.durationMs);
      const resultCount = samples.find((sample) => sample.scenario == scenario.name)?.resultCount ?? 0;

      return {
        scenario: scenario.name,
        resultCount,
        p50: percentile(scenarioDurations, 50),
        p95: percentile(scenarioDurations, 95),
        max: Number(Math.max(...scenarioDurations).toFixed(2)),
      };
    });
    const explain = await prisma.$queryRawUnsafe(
      `
        EXPLAIN ANALYZE
        ${nearbySql}
      `,
      106.7009,
      10.7769,
      3000,
      null,
      null,
      20,
    );

    console.log(
      JSON.stringify(
        {
          scenarioStats,
          samples,
          stats: {
            p50: percentile(durations, 50),
            p95: percentile(durations, 95),
            p99: percentile(durations, 99),
            max: Math.max(...durations),
          },
          explain,
        },
        null,
        2,
      ),
    );
  } finally {
    await prisma.$disconnect();
  }
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
