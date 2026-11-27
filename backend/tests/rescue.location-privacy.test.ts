import {
  projectRescueCoordinateCell,
  projectRescueLocationPrivacy,
  RESCUE_DEFAULT_PRIVACY_RADIUS_METERS,
  RESCUE_FALLBACK_AREA_LABEL,
  validateRescueLocationCoordinates,
} from '../src/services/rescue/rescue-location-privacy';

const haversineMeters = (
  from: { latitude: number; longitude: number },
  to: { latitude: number; longitude: number },
) => {
  const earthRadiusMeters = 6_371_000;
  const toRadians = (value: number) => (value * Math.PI) / 180;
  const deltaLatitude = toRadians(to.latitude - from.latitude);
  let shortestDeltaLongitude = to.longitude - from.longitude;
  if (shortestDeltaLongitude > 180) shortestDeltaLongitude -= 360;
  if (shortestDeltaLongitude < -180) shortestDeltaLongitude += 360;
  const deltaLongitude = toRadians(shortestDeltaLongitude);
  const fromLatitude = toRadians(from.latitude);
  const toLatitude = toRadians(to.latitude);
  const a =
    Math.sin(deltaLatitude / 2) ** 2 +
    Math.cos(fromLatitude) *
      Math.cos(toLatitude) *
      Math.sin(deltaLongitude / 2) ** 2;
  return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

describe('Day 38 rescue location privacy projector', () => {
  it('drops the first street segment and keeps at most three trailing administrative segments', () => {
    const result = projectRescueLocationPrivacy({
      latitude: 10.7769,
      longitude: 106.7009,
      formattedAddress:
        '12/3 Đường Lê Lợi, Phường Bến Nghé, Quận 1, Thành phố Hồ Chí Minh, Việt Nam',
    });

    expect(result).toMatchObject({
      areaLabel: 'Quận 1, Thành phố Hồ Chí Minh, Việt Nam',
      privacyRadiusMeters: RESCUE_DEFAULT_PRIVACY_RADIUS_METERS,
    });
    const projection = projectRescueCoordinateCell({
      latitude: 10.7769,
      longitude: 106.7009,
    });
    expect(projection.approximateLatitude).toBe(10.7775);
    expect(projection.approximateLongitude).toBe(106.6995);
    expect(result.areaLabel).not.toMatch(/12\/3|Đường Lê Lợi/u);
    expect(
      haversineMeters(
        { latitude: 10.7769, longitude: 106.7009 },
        {
          latitude: projection.approximateLatitude,
          longitude: projection.approximateLongitude,
        },
      ),
    ).toBeLessThanOrEqual(RESCUE_DEFAULT_PRIVACY_RADIUS_METERS);
  });

  it('removes unsafe road, alley, hamlet and premise segments after the first segment', () => {
    const result = projectRescueLocationPrivacy({
      latitude: 10.75,
      longitude: 106.67,
      formattedAddress:
        'Điểm ghim riêng tư, Hẻm 8, Ấp 4, Chung cư Hoa Sen, Phường 5, Quận 3, Thành phố Hồ Chí Minh',
    });

    expect(result.areaLabel).toBe('Phường 5, Quận 3, Thành phố Hồ Chí Minh');
    expect(result.privacyRadiusMeters).toBe(500);
    expect(result.areaLabel).not.toMatch(/Hẻm|Ấp|Chung cư/u);
  });

  it.each([
    'Điểm ghim, 10.776889, 106.700806, Quận 1, Thành phố Hồ Chí Minh',
    'Điểm ghim, lat: 10.776889 lng: 106.700806, Quận 1, Thành phố Hồ Chí Minh',
    'Điểm ghim, 10.776889 N, 106.700806 E, Quận 1, Thành phố Hồ Chí Minh',
    'Điểm ghim, coordinates 10.776889, 106.700806, Quận 1, Thành phố Hồ Chí Minh',
    'Điểm ghim, 10.776889° N, 106.700806° E, Quận 1, Thành phố Hồ Chí Minh',
  ])(
    'removes coordinate-like address segments before producing the public label: %s',
    (formattedAddress) => {
      const result = projectRescueLocationPrivacy({
        latitude: 10.7769,
        longitude: 106.7009,
        formattedAddress,
      });

      expect(result.areaLabel).toBe('Quận 1, Thành phố Hồ Chí Minh');
      expect(result.areaLabel).not.toMatch(
        /lat|lng|coordinates|10\.776889|106\.700806/iu,
      );
    },
  );

  it('never reuses the first segment even when it looks administrative', () => {
    const result = projectRescueLocationPrivacy({
      latitude: 10.78,
      longitude: 106.69,
      formattedAddress: 'Phường 5, Quận 3, Thành phố Hồ Chí Minh',
    });

    expect(result.areaLabel).toBe('Quận 3, Thành phố Hồ Chí Minh');
    expect(result.areaLabel).not.toContain('Phường 5');
  });

  it.each([undefined, '', '12 Đường Lê Lợi', 'Điểm ghim, Hẻm 4, Thôn 2, Ấp 3'])(
    'uses a privacy-safe fallback for an unusable address: %p',
    (formattedAddress) => {
      expect(
        projectRescueLocationPrivacy({
          latitude: 21.0285,
          longitude: 105.8542,
          formattedAddress,
        }),
      ).toMatchObject({
        areaLabel: RESCUE_FALLBACK_AREA_LABEL,
        privacyRadiusMeters: 500,
      });
    },
  );

  it('maps nearby coordinates in one quantization cell to one deterministic center', () => {
    const first = projectRescueCoordinateCell({
      latitude: 10.776889,
      longitude: 106.700806,
    });
    const nearby = projectRescueCoordinateCell({
      latitude: 10.7771,
      longitude: 106.7005,
    });

    expect(first).toEqual(
      projectRescueCoordinateCell({
        latitude: 10.776889,
        longitude: 106.700806,
      }),
    );
    expect(nearby).toMatchObject({
      approximateLatitude: first.approximateLatitude,
      approximateLongitude: first.approximateLongitude,
      privacyRadiusMeters: RESCUE_DEFAULT_PRIVACY_RADIUS_METERS,
    });
    expect(first.approximateLatitude).not.toBe(10.776889);
    expect(first.approximateLongitude).not.toBe(106.700806);
  });

  it('does not claim minimum displacement for an exact cell-center input', () => {
    const input = { latitude: 10.7775, longitude: 106.6995 };
    const projection = projectRescueCoordinateCell(input);

    expect(projection).toMatchObject({
      approximateLatitude: input.latitude,
      approximateLongitude: input.longitude,
      privacyRadiusMeters: RESCUE_DEFAULT_PRIVACY_RADIUS_METERS,
    });
    expect(
      haversineMeters(input, {
        latitude: projection.approximateLatitude,
        longitude: projection.approximateLongitude,
      }),
    ).toBeLessThanOrEqual(RESCUE_DEFAULT_PRIVACY_RADIUS_METERS);
  });

  it.each([
    { latitude: 0.000001, longitude: 0.000001 },
    { latitude: 85.123456, longitude: 135.987654 },
    { latitude: -12.345678, longitude: 179.9999 },
    { latitude: 0, longitude: 179.997 },
    { latitude: 0, longitude: 179.9971 },
    { latitude: 0, longitude: 179.9969 },
    { latitude: 12.345678, longitude: -179.9999 },
    { latitude: 0, longitude: -179.997 },
    { latitude: 0, longitude: -179.9969 },
    { latitude: 89.99, longitude: 0 },
    { latitude: -89.99, longitude: 0 },
  ])(
    'keeps the projected center within the 500 m uncertainty bound: %p',
    (input) => {
      const projection = projectRescueCoordinateCell(input);
      expect(
        haversineMeters(input, {
          latitude: projection.approximateLatitude,
          longitude: projection.approximateLongitude,
        }),
      ).toBeLessThanOrEqual(500);
      expect(Number.isFinite(projection.approximateLatitude)).toBe(true);
      expect(Number.isFinite(projection.approximateLongitude)).toBe(true);
    },
  );

  it.each([
    { latitude: 10, longitude: 180 },
    { latitude: 0, longitude: 180 },
    { latitude: -90, longitude: 180 },
    { latitude: 90, longitude: 180 },
  ])(
    'normalizes the dateline projection into the persisted longitude range: %p',
    (input) => {
      const projection = projectRescueCoordinateCell(input);
      expect(projection.approximateLongitude).toBeGreaterThanOrEqual(-180);
      expect(projection.approximateLongitude).toBeLessThanOrEqual(180);
    },
  );

  it('uses one canonical seam cell for adjacent dateline inputs', () => {
    const east = projectRescueCoordinateCell({
      latitude: 10,
      longitude: 179.9999,
    });
    const eastBoundary = projectRescueCoordinateCell({
      latitude: 10,
      longitude: 180,
    });
    const westBoundary = projectRescueCoordinateCell({
      latitude: 10,
      longitude: -180,
    });

    expect(east.approximateLongitude).toBe(-180);
    expect(eastBoundary.approximateLongitude).toBe(-180);
    expect(westBoundary.approximateLongitude).toBe(-180);
    expect(
      haversineMeters(
        { latitude: 10, longitude: 179.9999 },
        {
          latitude: east.approximateLatitude,
          longitude: east.approximateLongitude,
        },
      ),
    ).toBeLessThanOrEqual(RESCUE_DEFAULT_PRIVACY_RADIUS_METERS);
  });

  it('does not merge the first cell outside the dateline seam', () => {
    expect(
      projectRescueCoordinateCell({ latitude: 0, longitude: 179.9969 })
        .approximateLongitude,
    ).toBe(179.9955);
    expect(
      projectRescueCoordinateCell({ latitude: 0, longitude: -179.9969 })
        .approximateLongitude,
    ).toBe(-179.9955);
  });

  it.each([
    { latitude: -90, longitude: -180 },
    { latitude: 0, longitude: 0 },
    { latitude: 90, longitude: 180 },
  ])('accepts finite boundary coordinates: %p', (input) => {
    expect(() => validateRescueLocationCoordinates(input)).not.toThrow();
  });

  it.each([
    { latitude: Number.NaN, longitude: 0, field: 'latitude' },
    { latitude: Number.POSITIVE_INFINITY, longitude: 0, field: 'latitude' },
    { latitude: -90.000001, longitude: 0, field: 'latitude' },
    { latitude: 90.000001, longitude: 0, field: 'latitude' },
    { latitude: 0, longitude: Number.NEGATIVE_INFINITY, field: 'longitude' },
    { latitude: 0, longitude: -180.000001, field: 'longitude' },
    { latitude: 0, longitude: 180.000001, field: 'longitude' },
  ])('rejects invalid coordinate input: $field', ({ field, ...input }) => {
    expect(() => validateRescueLocationCoordinates(input)).toThrow(field);
    expect(() => projectRescueLocationPrivacy(input)).toThrow(field);
  });
});
