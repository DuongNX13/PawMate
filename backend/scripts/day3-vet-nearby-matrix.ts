import assert from 'node:assert/strict';
import path from 'node:path';

import dotenv from 'dotenv';

import { buildApp } from '../src/app';
import { loadEnv } from '../src/config/env';

type Scenario = {
  name: string;
  latitude: number;
  longitude: number;
  radius: number;
  is24h?: boolean;
  minRating?: number;
  expectEmpty?: boolean;
};

const scenarios: Scenario[] = [
  { name: 'hn-1km', latitude: 21.060822, longitude: 105.8359417, radius: 1000 },
  { name: 'hn-3km', latitude: 21.0430646, longitude: 105.8218397, radius: 3000 },
  {
    name: 'dn-3km-24h',
    latitude: 16.0646984,
    longitude: 108.1967615,
    radius: 3000,
    is24h: true,
  },
  { name: 'hcm-1km', latitude: 10.792682, longitude: 106.6904944, radius: 1000 },
  {
    name: 'hcm-3km-rating',
    latitude: 10.7769,
    longitude: 106.7009,
    radius: 3000,
    minRating: 4.5,
  },
  { name: 'hcm-10km', latitude: 10.7769, longitude: 106.7009, radius: 10000 },
  { name: 'hp-3km', latitude: 20.8449, longitude: 106.6881, radius: 3000 },
  { name: 'dn-3km', latitude: 16.0544, longitude: 108.2022, radius: 3000 },
  {
    name: 'no-result-small-radius',
    latitude: 11.0,
    longitude: 107.5,
    radius: 1000,
    expectEmpty: true,
  },
  {
    name: 'mixed-open-24h',
    latitude: 16.0646984,
    longitude: 108.1967615,
    radius: 5000,
    is24h: true,
    minRating: 4.0,
  },
];

const loadRuntimeEnv = () => {
  dotenv.config({
    path: [
      path.join(process.cwd(), '.env.local'),
      path.join(process.cwd(), '.env'),
    ],
    override: true,
  });
};

const assertSortedByDistance = (items: Array<{ distanceMeters?: number }>) => {
  for (let index = 1; index < items.length; index += 1) {
    const previous = items[index - 1]?.distanceMeters ?? Number.MAX_SAFE_INTEGER;
    const current = items[index]?.distanceMeters ?? Number.MAX_SAFE_INTEGER;
    assert.ok(previous <= current, 'Distance must be sorted ascending.');
  }
};

const main = async () => {
  loadRuntimeEnv();
  const app = buildApp({ logger: false }, { config: loadEnv(process.env) });
  await app.ready();

  try {
    const results = [];

    for (const scenario of scenarios) {
      const query = new URLSearchParams({
        lat: scenario.latitude.toString(),
        lng: scenario.longitude.toString(),
        radius: scenario.radius.toString(),
        limit: '20',
      });
      if (scenario.is24h === true) {
        query.set('is24h', 'true');
      }
      if (typeof scenario.minRating === 'number') {
        query.set('minRating', scenario.minRating.toString());
      }

      const response = await app.inject({
        method: 'GET',
        url: `/vets/nearby?${query.toString()}`,
      });

      assert.equal(response.statusCode, 200, `${scenario.name} should return 200.`);
      const payload = response.json();
      const items = Array.isArray(payload.data) ? payload.data : [];

      if (scenario.expectEmpty) {
        assert.equal(items.length, 0, `${scenario.name} should return empty result.`);
      } else {
        assert.ok(items.length > 0, `${scenario.name} should return at least one clinic.`);
      }

      for (const item of items) {
        if (typeof item.distanceMeters === 'number') {
          assert.ok(
            item.distanceMeters <= scenario.radius + 1,
            `${scenario.name} returned a clinic outside the requested radius.`,
          );
        }
        if (scenario.is24h === true) {
          assert.equal(item.is24h, true, `${scenario.name} must only return 24h clinics.`);
        }
        if (typeof scenario.minRating === 'number' && item.averageRating != null) {
          assert.ok(
            Number(item.averageRating) >= scenario.minRating,
            `${scenario.name} returned a clinic below minRating.`,
          );
        }
      }

      assertSortedByDistance(items);
      results.push({
        scenario: scenario.name,
        count: items.length,
        firstId: items[0]?.id ?? null,
      });
    }

    console.log(JSON.stringify({ checked: scenarios.length, results }, null, 2));
  } finally {
    await app.close();
  }
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
