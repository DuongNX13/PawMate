import {
  createPrismaForDatabase,
  ensureVetGeoSchema,
  loadBackendEnv,
  removePerfEntries,
  upsertVetDirectoryEntry,
} from './lib/day3-vet-geo-utils.mjs';

const CITY_CENTERS = [
  { prefix: 'hn', city: 'Hà Nội', district: 'Tây Hồ', latitude: 21.0285, longitude: 105.8542 },
  { prefix: 'hcm', city: 'TP Hồ Chí Minh', district: 'Quận 1', latitude: 10.7769, longitude: 106.7009 },
  { prefix: 'hp', city: 'Hải Phòng', district: 'Lê Chân', latitude: 20.8449, longitude: 106.6881 },
  { prefix: 'dn', city: 'Đà Nẵng', district: 'Hải Châu', latitude: 16.0544, longitude: 108.2022 },
];

const PER_CITY = 250;

const serviceSets = [
  ['Khám tổng quát', 'Tiêm phòng'],
  ['Cấp cứu 24/7', 'Siêu âm'],
  ['Tẩy giun', 'Xét nghiệm máu'],
  ['Khám tổng quát', 'Phẫu thuật mềm'],
];

const pad = (value) => value.toString().padStart(4, '0');

const buildSyntheticClinic = (center, index) => {
  const ring = index % 25;
  const spoke = index % 8;
  const latitudeOffset = (Math.sin(index * 1.7) * 0.008) + ring * 0.00042;
  const longitudeOffset = (Math.cos(index * 1.3) * 0.008) + spoke * 0.00037;
  const services = serviceSets[index % serviceSets.length];
  const is24h = index % 5 === 0;

  return {
    id: `perf-${center.prefix}-${pad(index + 1)}`,
    name: `Perf Vet ${center.prefix.toUpperCase()} ${pad(index + 1)}`,
    city: center.city,
    district: center.district,
    address: `${100 + index} ${center.district}, ${center.city}`,
    phone: `090${(1000000 + index).toString().slice(0, 7)}`,
    latitude: Number((center.latitude + latitudeOffset).toFixed(7)),
    longitude: Number((center.longitude + longitudeOffset).toFixed(7)),
    is24h,
    openHours: is24h ? ['00:00-23:59'] : ['Mon-Sun 08:00-20:00'],
    services,
    photoUrls: [],
    averageRating: Number((3.8 + ((index % 12) * 0.1)).toFixed(1)),
    reviewCount: 5 + (index % 80),
    sourceRank: 5000 + index,
    readyForMap: true,
  };
};

const main = async () => {
  const { databaseUrl } = loadBackendEnv();
  const prisma = createPrismaForDatabase(databaseUrl);

  try {
    await ensureVetGeoSchema(prisma);
    await removePerfEntries(prisma);

    let inserted = 0;
    for (const center of CITY_CENTERS) {
      for (let index = 0; index < PER_CITY; index += 1) {
        await upsertVetDirectoryEntry(prisma, buildSyntheticClinic(center, index));
        inserted += 1;
      }
    }

    console.log(
      JSON.stringify(
        {
          inserted,
          perCity: PER_CITY,
          sources: CITY_CENTERS.map((center) => center.city),
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
