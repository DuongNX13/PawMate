import { AppError } from '../src/errors/app-error';
import { RESCUE_ERROR_CODES } from '../src/errors/error-codes';
import {
  type RescueRepository,
  type RescueSpecies,
} from '../src/features/rescue/persistence/rescue-repository';
import {
  toRescueCaseDetail,
  toRescueCaseSummary,
} from '../src/services/rescue/rescue-read-mapper';
import { createRescueReadService } from '../src/services/rescue/rescue-read-service';
import {
  CASE_ID,
  makeRescueCase,
  makeRescueMedia,
  OWNER_USER_ID,
} from './helpers/rescue-read-fixtures';

type ReadRepository = Pick<
  RescueRepository,
  'listPublicCases' | 'findPublicCase'
>;

const buildRepository = () => {
  const listPublicCases = jest.fn().mockResolvedValue({
    items: [],
    limit: 20,
  });
  const findPublicCase = jest.fn().mockResolvedValue(undefined);
  const repository: ReadRepository = {
    listPublicCases,
    findPublicCase,
  };
  return { repository, listPublicCases, findPublicCase };
};

describe('Day 35 rescue read mapper', () => {
  it.each<RescueSpecies>(['bird', 'rabbit', 'other'])(
    'normalizes persistence species %s to the public other value',
    (species) => {
      const summary = toRescueCaseSummary({
        rescueCase: makeRescueCase({ species }),
      });

      expect(summary.species).toBe('other');
    },
  );

  it('publishes only the DTO allowlist and attached public media', () => {
    const rescueCase = makeRescueCase({
      species: 'rabbit',
      media: [
        makeRescueMedia(),
        makeRescueMedia({
          mediaId: '55555555-5555-4555-8555-555555555555',
          status: 'verified',
          publicUrl: 'https://cdn.example.test/rescue/not-attached.jpg',
        }),
        makeRescueMedia({
          mediaId: '66666666-6666-4666-8666-666666666666',
          publicUrl: undefined,
        }),
      ],
    });

    const summary = toRescueCaseSummary({
      rescueCase,
      distanceMeters: 234,
    });

    expect(Object.keys(summary).sort()).toEqual(
      [
        'ageLabel',
        'breedOrColor',
        'caseId',
        'commentCount',
        'createdAt',
        'distanceMeters',
        'lostAt',
        'media',
        'petName',
        'publicLocation',
        'species',
        'status',
        'updatedAt',
      ].sort(),
    );
    expect(summary.media).toEqual([
      {
        mediaId: rescueCase.media[0].mediaId,
        mimeType: 'image/jpeg',
        publicUrl: 'https://cdn.example.test/rescue/golden.jpg',
        createdAt: '2026-07-20T08:00:00.000Z',
        width: 1_200,
        height: 800,
      },
    ]);
    expect(summary.publicLocation).toEqual({
      areaLabel: 'Thao Dien, Thu Duc',
      approximateLatitude: 10.8021,
      approximateLongitude: 106.7339,
      privacyRadiusMeters: 500,
    });
    expect(summary.species).toBe('other');
    expect(JSON.stringify(summary)).not.toMatch(
      /ownerUserId|sourceDraftId|privateLocation|contactPreference|storageKey|sha256|sizeBytes|formattedAddress/,
    );
  });

  it('applies anonymous, authenticated non-owner, and owner permissions without private contact disclosure', () => {
    const rescueCase = makeRescueCase();

    const anonymous = toRescueCaseDetail(rescueCase);
    const nonOwner = toRescueCaseSummary(
      { rescueCase },
      '77777777-7777-4777-8777-777777777777',
    );
    const owner = toRescueCaseDetail(rescueCase, OWNER_USER_ID);

    expect(anonymous.viewerPermissions).toEqual({
      canComment: false,
      canUpdateStatus: false,
      canViewPrivateContact: false,
    });
    expect(nonOwner.viewerPermissions).toEqual({
      canComment: true,
      canUpdateStatus: false,
      canViewPrivateContact: false,
    });
    expect(owner.viewerPermissions).toEqual({
      canComment: true,
      canUpdateStatus: true,
      canViewPrivateContact: false,
    });
    expect(owner.version).toBe(rescueCase.version);
    expect(owner).not.toHaveProperty('contactChannel');
    expect(JSON.stringify(owner)).not.toMatch(
      /ownerUserId|privateLocation|contactPreference|formattedAddress/,
    );
  });
});

describe('Day 35 rescue read service', () => {
  it.each([
    ['status enum', { status: 'open' }, 'status'],
    ['species enum', { species: 'bird' }, 'species'],
    ['ISO date-time', { lostFrom: '2026-07-20' }, 'lostFrom'],
    [
      'date ordering',
      {
        lostFrom: '2026-07-21T00:00:00.000Z',
        lostTo: '2026-07-20T00:00:00.000Z',
      },
      'lostFrom',
    ],
    ['coordinate pairing', { lat: '10.8' }, 'lat'],
    ['latitude range', { lat: '91', lng: '106.7' }, 'lat'],
    ['longitude range', { lat: '10.8', lng: '-181' }, 'lng'],
    ['radius without coordinates', { radiusMeters: '1000' }, 'radiusMeters'],
    [
      'radius range',
      { lat: '10.8', lng: '106.7', radiusMeters: '99' },
      'radiusMeters',
    ],
    ['sort enum', { sort: 'nearest' }, 'sort'],
    ['distance sort coordinates', { sort: 'distance' }, 'sort'],
    ['limit range', { limit: '0' }, 'limit'],
    ['integer limit', { limit: '1.5' }, 'limit'],
  ])('rejects invalid %s input', async (_name, query, field) => {
    const { repository, listPublicCases } = buildRepository();
    const service = createRescueReadService({ repository });

    await expect(service.listCases(query)).rejects.toMatchObject({
      name: 'AppError',
      code: RESCUE_ERROR_CODES.invalidInput,
      statusCode: 400,
      field,
    });
    expect(listPublicCases).not.toHaveBeenCalled();
  });

  it('normalizes valid filters, defaults, dates, geo radius, and limit for persistence', async () => {
    const { repository, listPublicCases } = buildRepository();
    listPublicCases.mockResolvedValueOnce({ items: [], limit: 7 });
    const service = createRescueReadService({ repository });

    const result = await service.listCases({
      status: 'missing',
      species: 'other',
      lostFrom: '2026-07-01T00:00:00+07:00',
      lostTo: '2026-07-21T12:30:00.000Z',
      lat: '10.8021',
      lng: '106.7339',
      sort: 'distance',
      limit: '7',
    });

    expect(result).toEqual({ items: [], limit: 7 });
    expect(listPublicCases).toHaveBeenCalledWith({
      status: 'missing',
      species: 'other',
      lostFrom: new Date('2026-07-01T00:00:00+07:00'),
      lostTo: new Date('2026-07-21T12:30:00.000Z'),
      latitude: 10.8021,
      longitude: 106.7339,
      radiusMeters: 1_000,
      sort: 'distance',
      cursor: undefined,
      limit: 7,
    });
  });

  it('binds an opaque cursor to its exact filter fingerprint', async () => {
    const { repository, listPublicCases } = buildRepository();
    listPublicCases
      .mockResolvedValueOnce({
        items: [],
        nextCursor: {
          sort: 'distance',
          distanceMeters: 321,
          caseId: CASE_ID,
        },
        limit: 2,
      })
      .mockResolvedValueOnce({ items: [], limit: 2 });
    const service = createRescueReadService({ repository });
    const filters = {
      status: 'missing',
      species: 'dog',
      lat: '10.8',
      lng: '106.7',
      radiusMeters: '2500',
      sort: 'distance',
      limit: '2',
    };

    const firstPage = await service.listCases(filters);
    expect(firstPage.nextCursor).toEqual(expect.any(String));

    await service.listCases({ ...filters, cursor: firstPage.nextCursor });
    expect(listPublicCases).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        cursor: {
          sort: 'distance',
          distanceMeters: 321,
          caseId: CASE_ID,
        },
      }),
    );

    await expect(
      service.listCases({
        ...filters,
        status: 'found',
        cursor: firstPage.nextCursor,
      }),
    ).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.invalidInput,
      statusCode: 400,
      field: 'cursor',
    });
    expect(listPublicCases).toHaveBeenCalledTimes(2);
  });

  it('rejects malformed and structurally invalid cursors before persistence', async () => {
    const { repository, listPublicCases } = buildRepository();
    const service = createRescueReadService({ repository });
    const structurallyInvalid = Buffer.from(
      JSON.stringify({
        version: 1,
        filterFingerprint: 'wrong',
        position: { sort: 'recent', lostAt: 'not-a-date', caseId: CASE_ID },
      }),
      'utf8',
    ).toString('base64url');

    await expect(
      service.listCases({ cursor: 'not+base64' }),
    ).rejects.toBeInstanceOf(AppError);
    await expect(
      service.listCases({ cursor: structurallyInvalid }),
    ).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.invalidInput,
      field: 'cursor',
    });
    expect(listPublicCases).not.toHaveBeenCalled();
  });

  it('maps list and detail records while preserving public not-found semantics', async () => {
    const { repository, listPublicCases, findPublicCase } = buildRepository();
    const rescueCase = makeRescueCase({ species: 'bird' });
    listPublicCases.mockResolvedValueOnce({
      items: [{ rescueCase, distanceMeters: 125 }],
      limit: 20,
    });
    findPublicCase
      .mockResolvedValueOnce(rescueCase)
      .mockResolvedValueOnce(undefined);
    const service = createRescueReadService({ repository });

    const list = await service.listCases({}, OWNER_USER_ID);
    const detail = await service.getCase(CASE_ID, OWNER_USER_ID);

    expect(list.items[0]).toMatchObject({
      caseId: CASE_ID,
      species: 'other',
      distanceMeters: 125,
      viewerPermissions: {
        canComment: true,
        canUpdateStatus: true,
        canViewPrivateContact: false,
      },
    });
    expect(detail).toMatchObject({
      caseId: CASE_ID,
      version: rescueCase.version,
      identifyingFeatures: 'Deo vong co mau xanh mint.',
    });
    expect(JSON.stringify({ list, detail })).not.toMatch(
      /ownerUserId|privateLocation|storageKey|sha256/,
    );

    await expect(service.getCase(CASE_ID)).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.notFound,
      statusCode: 404,
    });
    await expect(service.getCase('invalid-id')).rejects.toMatchObject({
      code: RESCUE_ERROR_CODES.notFound,
      statusCode: 404,
    });
  });
});
