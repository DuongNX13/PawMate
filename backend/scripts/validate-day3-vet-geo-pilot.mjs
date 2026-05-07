import { loadVetSeedFiles } from './lib/day3-vet-geo-utils.mjs';

const VIETNAM_BOUNDS = {
  minLatitude: 8,
  maxLatitude: 24,
  minLongitude: 102,
  maxLongitude: 110,
};

const errors = [];
const warnings = [];

const isValidLatitude = (value) =>
  typeof value === 'number' &&
  value >= VIETNAM_BOUNDS.minLatitude &&
  value <= VIETNAM_BOUNDS.maxLatitude;

const isValidLongitude = (value) =>
  typeof value === 'number' &&
  value >= VIETNAM_BOUNDS.minLongitude &&
  value <= VIETNAM_BOUNDS.maxLongitude;

const main = async () => {
  const { seedPath, overlayPath, seedFile, overlayFile } = await loadVetSeedFiles();
  const baseIds = new Set((seedFile?.clinics ?? []).map((clinic) => clinic.id));
  const seenOverlayIds = new Set();

  for (const clinic of overlayFile?.clinics ?? []) {
    if (!clinic.id?.trim()) {
      errors.push('Overlay record thiếu id.');
      continue;
    }

    if (!baseIds.has(clinic.id)) {
      errors.push(`Overlay id ${clinic.id} không tồn tại trong seed gốc.`);
    }

    if (seenOverlayIds.has(clinic.id)) {
      errors.push(`Overlay id ${clinic.id} bị trùng.`);
    }
    seenOverlayIds.add(clinic.id);

    if (!isValidLatitude(clinic.latitude)) {
      errors.push(`Clinic ${clinic.id} có latitude không hợp lệ: ${clinic.latitude}`);
    }
    if (!isValidLongitude(clinic.longitude)) {
      errors.push(`Clinic ${clinic.id} có longitude không hợp lệ: ${clinic.longitude}`);
    }
    if (clinic.readyForMap !== true) {
      errors.push(`Clinic ${clinic.id} phải có readyForMap=true trong pilot overlay.`);
    }
    if (
      clinic.is24h === true &&
      (!Array.isArray(clinic.openHours) || clinic.openHours.length === 0)
    ) {
      errors.push(`Clinic ${clinic.id} bật is24h nhưng chưa có openHours.`);
    }

    if (!Array.isArray(clinic.services) || clinic.services.length === 0) {
      warnings.push(`Clinic ${clinic.id} chưa có services, map preview sẽ dùng fallback.`);
    }
    if (!Array.isArray(clinic.openHours) || clinic.openHours.length === 0) {
      warnings.push(`Clinic ${clinic.id} chưa có openHours, trạng thái mở cửa sẽ phụ thuộc fallback.`);
    }
  }

  const summary = {
    seedPath,
    overlayPath,
    overlayCount: overlayFile?.clinics?.length ?? 0,
    errorCount: errors.length,
    warningCount: warnings.length,
  };

  console.log(JSON.stringify(summary, null, 2));

  if (warnings.length > 0) {
    console.log('\nWarnings:');
    for (const warning of warnings) {
      console.log(`- ${warning}`);
    }
  }

  if (errors.length > 0) {
    console.error('\nErrors:');
    for (const error of errors) {
      console.error(`- ${error}`);
    }
    process.exitCode = 1;
    return;
  }

  console.log('\nDay 3 geo pilot overlay hợp lệ.');
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
