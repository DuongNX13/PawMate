import { projectRescueLocationPrivacy } from '../src/services/rescue/rescue-location-privacy';
import { toRescueCaseDetail } from '../src/services/rescue/rescue-read-mapper';
import {
  makeRescueCase,
  OWNER_USER_ID,
} from './helpers/rescue-read-fixtures';

describe('Day103 public location contact redaction', () => {
  it.each(['Gọi 0901234567', 'Liên hệ +84 901 234 567', 'Email owner@example.test'])(
    'never publishes private contact embedded in an address: %s',
    (contact) => {
      const result = projectRescueLocationPrivacy({
        latitude: 21.0321, longitude: 105.8422,
        formattedAddress: `120 Đường riêng tư, ${contact}, Quận 7`,
      });
      expect(result.areaLabel).toBe('Quận 7');
    },
  );

  it('keeps exact owner storage outside both anonymous and owner public API shapes', () => {
    const rescueCase = makeRescueCase({
      privateLocation: {
        latitude: 10.801234,
        longitude: 106.734567,
        formattedAddress: '12 Đường bí mật, gọi 0901234567',
      },
    });

    [
      toRescueCaseDetail(rescueCase),
      toRescueCaseDetail(rescueCase, OWNER_USER_ID),
    ].forEach((response) => {
      const json = JSON.stringify(response);
      expect(response.publicLocation).toEqual({
        areaLabel: rescueCase.areaLabel,
        approximateLatitude: rescueCase.approximateLatitude,
        approximateLongitude: rescueCase.approximateLongitude,
        privacyRadiusMeters: 500,
      });
      expect(json).not.toContain('privateLocation');
      expect(json).not.toContain('formattedAddress');
      expect(json).not.toContain('10.801234');
      expect(json).not.toContain('106.734567');
      expect(json).not.toContain('0901234567');
    });
  });
});
