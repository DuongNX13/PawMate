import {
  createPrismaForDatabase,
  ensureVetGeoSchema,
  loadBackendEnv,
  loadVetSeedFiles,
  upsertVetDirectoryEntry,
} from './lib/day3-vet-geo-utils.mjs';

const main = async () => {
  const { databaseUrl } = loadBackendEnv();
  const prisma = createPrismaForDatabase(databaseUrl);

  try {
    await ensureVetGeoSchema(prisma);

    const { clinics } = await loadVetSeedFiles();
    const pilotClinics = clinics.filter(
      (clinic) =>
        clinic.readyForMap === true &&
        typeof clinic.latitude === 'number' &&
        typeof clinic.longitude === 'number',
    );

    const syncedIds = [];
    for (const clinic of pilotClinics) {
      await upsertVetDirectoryEntry(prisma, clinic);
      syncedIds.push(clinic.id);
    }

    console.log(
      JSON.stringify(
        {
          syncedCount: syncedIds.length,
          syncedIds,
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
