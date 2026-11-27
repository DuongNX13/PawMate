export const RESCUE_DEFAULT_PRIVACY_RADIUS_METERS = 500 as const;

// Public Rescue coordinates are the center of a deterministic fixed-degree
// grid. The 500 m value is a policy uncertainty radius, not the cell side
// length or a promise of minimum displacement. The grid is conservative at
// the equator (~334 m per side), becomes smaller in meters toward the poles,
// and avoids longitude-singularity math while keeping every cell safely
// inside the 500 m policy radius.
export const RESCUE_PRIVACY_CELL_SIZE_DEGREES = 0.003 as const;

export const RESCUE_FALLBACK_AREA_LABEL = 'Khu vực lân cận' as const;

export type RescueExactLocationInput = {
  latitude: number;
  longitude: number;
  formattedAddress?: string;
};

export type RescueLocationPrivacyProjection = {
  areaLabel: string;
  privacyRadiusMeters: typeof RESCUE_DEFAULT_PRIVACY_RADIUS_METERS;
};

/**
 * Wire shape used when publishing a public rescue coordinate. Keep this
 * separate from `RescueLocationPrivacyProjection`: the latter intentionally
 * contains only the redacted area label/radius used by draft metadata.
 */
export type RescueCoordinatePrivacyProjection = {
  approximateLatitude: number;
  approximateLongitude: number;
  privacyRadiusMeters: typeof RESCUE_DEFAULT_PRIVACY_RADIUS_METERS;
};

const MAX_AREA_LABEL_LENGTH = 160;

const collapseWhitespace = (value: string) =>
  value.trim().replace(/\s+/gu, ' ');

const foldForComparison = (value: string) =>
  collapseWhitespace(value)
    .toLocaleLowerCase('vi')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/gu, '')
    .replace(/đ/gu, 'd');

const VIETNAMESE_SENSITIVE_SEGMENT =
  /(^|[\s./-])(?:đường|hẻm|ngõ|ngách|kiệt|ấp|thôn|xóm|số nhà|quốc lộ|tỉnh lộ|đại lộ|xa lộ|tổ dân phố|khu phố|khu đô thị|chung cư|tòa nhà|lô)(?=$|[\s./-])/iu;

const ENGLISH_SENSITIVE_SEGMENT =
  /\b(?:street|road|lane|alley|avenue|building|apartment|block|lot)\b/iu;

// Geocoders and hand-entered drafts sometimes append GPS values to an
// otherwise administrative address. Treat both labelled coordinates and
// decimal pairs as sensitive so they cannot survive into areaLabel.
const COORDINATE_LABEL_SEGMENT =
  /\b(?:lat(?:itude)?|lng|lon(?:gitude)?|gps)\s*[:=]?\s*[-+]?\d{1,3}(?:\.\d+)?/iu;
const COORDINATE_PAIR_SEGMENT =
  /(?:^|[^\d])[-+]?\d{1,3}\.\d+\s*(?:[,;|/]\s*|\s+)[-+]?\d{1,3}\.\d+(?=$|[^\d])/u;
const COORDINATE_PREFIX_SEGMENT = /\b(?:coordinates?|coords?|gps|tọa\s*độ)\b/iu;
const STANDALONE_COORDINATE_SEGMENT =
  /^[-+]?\d{1,3}(?:\.\d+)?\s*°?\s*[NSEW]?$/iu;
// Six-decimal GPS values are often split into separate comma segments (and
// may carry N/E/S/W or a degree symbol), so detect the high-precision token
// even when no pair remains in the individual segment.
const HIGH_PRECISION_COORDINATE_SEGMENT = /[-+]?\d{1,3}\.\d{4,}/u;

const LEADING_HOUSE_NUMBER =
  /^(?:so(?:\s+nha)?\s+)?\d+[a-z]?(?:[/-]\d+[a-z]?)*(?:\s|$)/u;

const hasCoordinateAnnotation = (segment: string) =>
  COORDINATE_LABEL_SEGMENT.test(segment) ||
  COORDINATE_PAIR_SEGMENT.test(segment) ||
  COORDINATE_PREFIX_SEGMENT.test(segment) ||
  STANDALONE_COORDINATE_SEGMENT.test(collapseWhitespace(segment)) ||
  HIGH_PRECISION_COORDINATE_SEGMENT.test(segment);

const looksSensitive = (segment: string) => {
  const lower = collapseWhitespace(segment).toLocaleLowerCase('vi');
  const withoutCityPhrase = lower.replace(/thành\s+phố/giu, 'thành_phố');
  const folded = foldForComparison(segment);

  // Address annotations are user input too: never expose contact details in
  // public area labels, even when prefixed with a name or "Liên hệ".
  const compactContact = segment.replace(/[\s().-]/gu, '');
  if (/(?:\+?84|0)\d{9,10}(?!\d)/u.test(compactContact)) return true;
  if (/[^\s@]+@[^\s@]+\.[^\s@]+/u.test(segment)) return true;

  if (LEADING_HOUSE_NUMBER.test(folded)) return true;
  if (hasCoordinateAnnotation(segment)) {
    return true;
  }
  if (VIETNAMESE_SENSITIVE_SEGMENT.test(withoutCityPhrase)) return true;
  if (ENGLISH_SENSITIVE_SEGMENT.test(folded)) return true;

  return /(^|[\s./-])phố(?=$|[\s./-])/iu.test(withoutCityPhrase);
};

export const validateRescueLocationCoordinates = (
  input: Pick<RescueExactLocationInput, 'latitude' | 'longitude'>,
) => {
  if (
    !Number.isFinite(input.latitude) ||
    input.latitude < -90 ||
    input.latitude > 90
  ) {
    throw new RangeError(
      'latitude must be a finite number between -90 and 90.',
    );
  }
  if (
    !Number.isFinite(input.longitude) ||
    input.longitude < -180 ||
    input.longitude > 180
  ) {
    throw new RangeError(
      'longitude must be a finite number between -180 and 180.',
    );
  }
};

const normalizeLongitude = (longitude: number) => {
  const normalized = ((((longitude + 180) % 360) + 360) % 360) - 180;
  return normalized === -180 && longitude > 0 ? 180 : normalized;
};

const roundCoordinate = (value: number) => Number(value.toFixed(6));

/**
 * Projects an exact WGS-84 coordinate into a deterministic quantization grid.
 * The fixed 0.003° square has a maximum center distance below 500 m even at
 * the equator and only gets smaller toward the poles. This avoids pretending
 * that decimal rounding itself provides a 500 m displacement.
 */
export const projectRescueCoordinateCell = (
  input: Pick<RescueExactLocationInput, 'latitude' | 'longitude'>,
): RescueCoordinatePrivacyProjection => {
  validateRescueLocationCoordinates(input);

  // Use a half-open longitude domain for cell indexing; +180 and -180 are
  // the same meridian and are canonicalized to -180 below.
  const normalizedLongitude =
    normalizeLongitude(input.longitude) === 180
      ? -180
      : normalizeLongitude(input.longitude);
  const latitudeCell = Math.floor(
    input.latitude / RESCUE_PRIVACY_CELL_SIZE_DEGREES,
  );
  const projectedLatitude = Math.min(
    90,
    Math.max(
      -90,
      roundCoordinate((latitudeCell + 0.5) * RESCUE_PRIVACY_CELL_SIZE_DEGREES),
    ),
  );
  const isDatelineCell =
    normalizedLongitude >= 180 - RESCUE_PRIVACY_CELL_SIZE_DEGREES ||
    normalizedLongitude <= -180 + RESCUE_PRIVACY_CELL_SIZE_DEGREES;
  const longitudeCell = Math.floor(
    (normalizedLongitude + 180) / RESCUE_PRIVACY_CELL_SIZE_DEGREES,
  );
  const rawProjectedLongitude = isDatelineCell
    ? -180
    : -180 + (longitudeCell + 0.5) * RESCUE_PRIVACY_CELL_SIZE_DEGREES;
  const projectedLongitude = roundCoordinate(rawProjectedLongitude);

  return {
    approximateLatitude: projectedLatitude,
    approximateLongitude: projectedLongitude,
    privacyRadiusMeters: RESCUE_DEFAULT_PRIVACY_RADIUS_METERS,
  };
};

const projectAreaLabel = (formattedAddress: string | undefined) => {
  if (!formattedAddress) return RESCUE_FALLBACK_AREA_LABEL;

  const segments = formattedAddress
    .split(',')
    .map(collapseWhitespace)
    .filter(Boolean);
  if (segments.length < 2) return RESCUE_FALLBACK_AREA_LABEL;

  const firstSegment = foldForComparison(segments[0]);
  const selected = segments
    .slice(1)
    .filter((segment) => foldForComparison(segment) !== firstSegment)
    .filter((segment) => !looksSensitive(segment))
    .slice(-3);

  while (
    selected.length > 1 &&
    selected.join(', ').length > MAX_AREA_LABEL_LENGTH
  ) {
    selected.shift();
  }

  const areaLabel = selected.join(', ');
  if (!areaLabel || areaLabel.length > MAX_AREA_LABEL_LENGTH) {
    return RESCUE_FALLBACK_AREA_LABEL;
  }

  return areaLabel;
};

export const projectRescueLocationPrivacy = (
  input: RescueExactLocationInput,
): RescueLocationPrivacyProjection => {
  validateRescueLocationCoordinates(input);

  return {
    areaLabel: projectAreaLabel(input.formattedAddress),
    privacyRadiusMeters: RESCUE_DEFAULT_PRIVACY_RADIUS_METERS,
  };
};
