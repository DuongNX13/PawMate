import { AUTH_ERROR_CODES } from '../src/errors/error-codes';
import {
  createSupabaseEmailVerificationGateway,
  createSupabaseOAuthVerifier,
} from '../src/integrations/supabase-auth-gateway';
import { buildTestConfig } from './helpers/rescue-read-fixtures';
import { createPetService } from '../src/services/pets/pet-service';
import { createHealthRecordService } from '../src/services/health/health-record-service';
import { createReminderService } from '../src/services/reminders/reminder-service';
import {
  createVetService,
  type VetClinic,
} from '../src/services/vets/vet-service';

// Provider boundary unit tests: every SDK method is a fake, never cloud proof.
const user = {
  id: 'local-a',
  email: 'owner@example.test',
  password: 'Test-only123!',
};
const client = () => ({
  signUp: jest.fn().mockResolvedValue({ data: { user: null }, error: null }),
  verifyOtp: jest.fn().mockResolvedValue({
    data: { user: { email: ' OWNER@EXAMPLE.TEST ' } },
    error: null,
  }),
  resend: jest.fn().mockResolvedValue({ error: null }),
  signInWithIdToken: jest.fn(),
});
const admin = () => ({
  auth: {
    admin: {
      generateLink: jest
        .fn()
        .mockResolvedValue({ data: { user: null }, error: null }),
      updateUserById: jest
        .fn()
        .mockResolvedValue({ data: { user: { id: 'remote-a' } }, error: null }),
      listUsers: jest
        .fn()
        .mockResolvedValue({ data: { users: [] }, error: null }),
    },
  },
});
const fallback = () => {
  const config = buildTestConfig();
  config.auth.emailRateLimitAutoVerifyFallback = true;
  return config;
};

describe('Day137 Supabase boundary/error unit contracts', () => {
  it('returns no gateway when Supabase is not configured', () => {
    expect(
      createSupabaseEmailVerificationGateway(buildTestConfig()),
    ).toBeUndefined();
    expect(createSupabaseOAuthVerifier(buildTestConfig())).toBeUndefined();
  });
  it.each([false, true])(
    'preserves the configured mobile/web redirect (mobile=%s)',
    async (mobile) => {
      const config = buildTestConfig();
      config.supabaseAuthRedirectUrl = 'https://example.invalid/auth';
      if (mobile) config.supabaseAuthMobileRedirectUrl = 'pawmate://auth';
      const authClient = client();
      const gateway = createSupabaseEmailVerificationGateway(config, {
        authClient: authClient as never,
      })!;
      await gateway.sendEmailVerification(user);
      await gateway.resendEmailVerification({ email: user.email });
      expect(authClient.signUp).toHaveBeenCalledWith({
        email: user.email,
        password: user.password,
        options: {
          emailRedirectTo: mobile
            ? 'pawmate://auth'
            : 'https://example.invalid/auth',
          data: { local_user_id: user.id, display_name: undefined },
        },
      });
      expect(authClient.resend.mock.lastCall![0].options.emailRedirectTo).toBe(
        mobile ? 'pawmate://auth' : 'https://example.invalid/auth',
      );
    },
  );
  it('maps non-rate-limit dispatch and resend errors without invoking admin fallback', async () => {
    const authClient = client();
    const adminClient = admin();
    authClient.signUp.mockResolvedValue({
      data: { user: null },
      error: { message: 'provider failed' },
    });
    authClient.resend.mockResolvedValue({
      error: { message: 'resend failed' },
    });
    const gateway = createSupabaseEmailVerificationGateway(fallback(), {
      authClient: authClient as never,
      adminClient,
    })!;
    await expect(gateway.sendEmailVerification(user)).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.verificationUnavailable,
      statusCode: 502,
      field: 'email',
    });
    await expect(
      gateway.resendEmailVerification({ email: user.email }),
    ).rejects.toMatchObject({
      code: AUTH_ERROR_CODES.verificationUnavailable,
      message: 'resend failed',
    });
    expect(adminClient.auth.admin.generateLink).not.toHaveBeenCalled();
  });
  it.each(['production', 'disabled', 'no-admin'])(
    'never auto-confirms when fallback is forbidden (%s)',
    async (reason) => {
      const config = fallback();
      if (reason === 'production') config.nodeEnv = 'production';
      if (reason === 'disabled')
        config.auth.emailRateLimitAutoVerifyFallback = false;
      const authClient = client();
      const adminClient = admin();
      authClient.signUp.mockResolvedValue({
        data: { user: null },
        error: { message: 'email rate limit exceeded' },
      });
      const gateway = createSupabaseEmailVerificationGateway(config, {
        authClient: authClient as never,
        ...(reason === 'no-admin' ? {} : { adminClient }),
      })!;
      await expect(gateway.sendEmailVerification(user)).rejects.toMatchObject({
        code: AUTH_ERROR_CODES.verificationUnavailable,
        statusCode: 502,
      });
      expect(adminClient.auth.admin.generateLink).not.toHaveBeenCalled();
    },
  );
  it('finds a normalized matching email on the next admin page and confirms only its ID', async () => {
    const config = fallback();
    config.supabaseAuthRedirectUrl = 'https://example.invalid/auth';
    const authClient = client();
    const adminClient = admin();
    authClient.signUp.mockResolvedValue({
      data: { user: null },
      error: { message: 'EMAIL RATE LIMIT EXCEEDED' },
    });
    adminClient.auth.admin.listUsers.mockResolvedValueOnce({
      data: {
        users: Array.from({ length: 200 }, (_, i) => ({
          id: `other-${i}`,
          email: i ? null : 'other@example.test',
        })),
      },
      error: null,
    });
    adminClient.auth.admin.listUsers.mockResolvedValueOnce({
      data: { users: [{ id: 'remote-a', email: ' OWNER@EXAMPLE.TEST ' }] },
      error: null,
    });
    const gateway = createSupabaseEmailVerificationGateway(config, {
      authClient: authClient as never,
      adminClient,
    })!;
    await expect(gateway.sendEmailVerification(user)).resolves.toEqual({
      status: 'auto-verified',
    });
    expect(adminClient.auth.admin.listUsers.mock.calls).toEqual([
      [{ page: 1, perPage: 200 }],
      [{ page: 2, perPage: 200 }],
    ]);
    expect(adminClient.auth.admin.generateLink).toHaveBeenCalledWith({
      type: 'signup',
      email: user.email,
      password: user.password,
      options: { redirectTo: 'https://example.invalid/auth' },
    });
    expect(adminClient.auth.admin.updateUserById).toHaveBeenCalledWith(
      'remote-a',
      { email_confirm: true },
    );
  });
  it.each([
    'list-error',
    'generate-error',
    'missing-user',
    'five-pages',
    'confirm-error',
  ])(
    'retains fallback failure %s without inventing a verified user',
    async (kind) => {
      const authClient = client();
      const adminClient = admin();
      authClient.signUp.mockResolvedValue({
        data: { user: null },
        error: { message: 'email rate limit exceeded' },
      });
      if (kind === 'list-error')
        adminClient.auth.admin.listUsers.mockResolvedValue({
          data: { users: [] },
          error: { message: 'list failure' },
        });
      if (kind === 'generate-error')
        adminClient.auth.admin.generateLink.mockResolvedValue({
          data: { user: null },
          error: { message: 'generate failure' },
        });
      if (kind === 'five-pages')
        adminClient.auth.admin.listUsers.mockResolvedValue({
          data: {
            users: Array.from({ length: 200 }, (_, i) => ({
              id: `other-${i}`,
              email: undefined,
            })),
          },
          error: null,
        });
      if (kind === 'confirm-error') {
        adminClient.auth.admin.generateLink.mockResolvedValue({
          data: { user: { id: 'remote-a' } },
          error: null,
        });
        adminClient.auth.admin.updateUserById.mockResolvedValue({
          data: { user: null },
          error: { message: 'confirm failure' },
        });
      }
      const gateway = createSupabaseEmailVerificationGateway(fallback(), {
        authClient: authClient as never,
        adminClient,
      })!;
      await expect(gateway.sendEmailVerification(user)).rejects.toMatchObject({
        code: AUTH_ERROR_CODES.verificationUnavailable,
        statusCode: 502,
        field: 'email',
      });
      if (kind === 'five-pages')
        expect(adminClient.auth.admin.listUsers).toHaveBeenCalledTimes(5);
      if (kind !== 'confirm-error')
        expect(adminClient.auth.admin.updateUserById).not.toHaveBeenCalled();
    },
  );
  it.each([true, false])(
    'verifies hash/email OTP through the correct SDK payload (%s)',
    async (hash) => {
      const authClient = client();
      const gateway = createSupabaseEmailVerificationGateway(
        buildTestConfig(),
        { authClient: authClient as never },
      )!;
      const input = hash
        ? { tokenHash: 'fixture-hash' }
        : { email: user.email, token: '123456' };
      await expect(gateway.verifyEmailToken(input)).resolves.toEqual({
        email: user.email,
      });
      expect(authClient.verifyOtp).toHaveBeenCalledWith(
        hash
          ? { token_hash: 'fixture-hash', type: 'signup' }
          : { email: user.email, token: '123456', type: 'signup' },
      );
      authClient.verifyOtp.mockResolvedValue({
        data: { user: null },
        error: { message: hash ? 'otp_expired' : 'bad token' },
      });
      await expect(gateway.verifyEmailToken(input)).rejects.toMatchObject({
        code: hash
          ? AUTH_ERROR_CODES.expiredVerificationToken
          : AUTH_ERROR_CODES.invalidVerificationToken,
        statusCode: 400,
        field: hash ? 'tokenHash' : 'token',
      });
    },
  );
  it.each([null, { email: '' }])(
    'rejects an OTP response without usable email (%j)',
    async (remoteUser) => {
      const authClient = client();
      authClient.verifyOtp.mockResolvedValue({
        data: { user: remoteUser },
        error: null,
      });
      const gateway = createSupabaseEmailVerificationGateway(
        buildTestConfig(),
        { authClient: authClient as never },
      )!;
      await expect(
        gateway.verifyEmailToken({ tokenHash: 'fixture' }),
      ).rejects.toMatchObject({
        code: AUTH_ERROR_CODES.invalidVerificationToken,
      });
    },
  );
  it.each([
    {
      identities: undefined,
      metadata: undefined,
      expected: 'remote-a',
      name: undefined,
    },
    {
      identities: [
        { provider: 'google', identity_data: { sub: '  provider-sub  ' } },
      ],
      metadata: { full_name: 'Full Name' },
      expected: 'provider-sub',
      name: 'Full Name',
    },
    {
      identities: [
        { provider: 'google', id: 'identity-id', identity_data: { sub: ' ' } },
      ],
      metadata: { name: 'Nickname' },
      expected: 'identity-id',
      name: 'Nickname',
    },
    {
      identities: [
        {
          provider: 'google',
          identity_id: 'old-identity-id',
          identity_data: { sub: 123 },
        },
      ],
      metadata: { full_name: 123 },
      expected: 'old-identity-id',
      name: undefined,
    },
    {
      identities: [{ provider: 'apple', id: 'wrong-provider' }],
      metadata: {},
      expected: 'remote-a',
      name: undefined,
    },
  ])(
    'uses the native OAuth identity fallbacks without accepting another provider (%j)',
    async (row) => {
      const authClient = client();
      authClient.signInWithIdToken.mockResolvedValue({
        error: null,
        data: {
          user: {
            id: 'remote-a',
            email: ' OWNER@EXAMPLE.TEST ',
            identities: row.identities,
            user_metadata: row.metadata,
          },
        },
      });
      const verifier = createSupabaseOAuthVerifier(buildTestConfig(), {
        authClient: authClient as never,
      })!;
      await expect(verifier.verify('google', 'fixture-token')).resolves.toEqual(
        {
          email: user.email,
          providerUserId: row.expected,
          displayName: row.name,
        },
      );
      expect(authClient.signInWithIdToken).toHaveBeenCalledWith({
        provider: 'google',
        token: 'fixture-token',
      });
      await verifier.verify('google', 'fixture-token', {
        accessToken: 'fixture-access',
        nonce: 'fixture-nonce',
      });
      expect(authClient.signInWithIdToken).toHaveBeenLastCalledWith({
        provider: 'google',
        token: 'fixture-token',
        access_token: 'fixture-access',
        nonce: 'fixture-nonce',
      });
    },
  );
  it.each(['error', 'no-user', 'no-email'])(
    'rejects unusable OAuth responses (%s)',
    async (kind) => {
      const authClient = client();
      authClient.signInWithIdToken.mockResolvedValue({
        error: kind === 'error' ? { message: 'provider denied' } : null,
        data: {
          user: kind === 'no-user' ? null : { id: 'remote-a', email: '' },
        },
      });
      const verifier = createSupabaseOAuthVerifier(buildTestConfig(), {
        authClient: authClient as never,
      })!;
      await expect(
        verifier.verify('apple', 'fixture-token'),
      ).rejects.toMatchObject({
        code: AUTH_ERROR_CODES.oauthVerificationFailed,
        statusCode: 401,
        field: 'credential',
      });
    },
  );
});

const vetFixture = (id: string, patch: Partial<VetClinic> = {}): VetClinic => ({
  id,
  name: id,
  city: 'Hồ Chí Minh',
  district: 'Quận 7',
  address: 'Địa chỉ fixture',
  phone: 'fixture',
  latitude: 10.7769,
  longitude: 106.7009,
  website: null,
  is24h: false,
  openHours: ['mon 08:00-17:00'],
  services: [],
  photoUrls: [],
  averageRating: 4,
  reviewCount: 0,
  sourceUrl: 'https://example.invalid',
  sourceList: 'fixture',
  sourceRank: 1,
  priorityTier: 'fixture',
  selectionReason: 'unit',
  enrichmentStatus: 'unit',
  readyForMap: true,
  ...patch,
});
describe('Day137 Vet availability and query contracts', () => {
  it('keeps nullable rating/location, opening-hours and overnight states separate', async () => {
    const clinics = [
      vetFixture('A'),
      vetFixture('B', {
        averageRating: null,
        longitude: null,
        openHours: ['unknown'],
        sourceRank: 2,
      }),
      vetFixture('C', { is24h: true, services: ['Khám'], averageRating: 5 }),
      vetFixture('D', { openHours: ['20:00-06:00'], latitude: 11.2 }),
      vetFixture('E', { openHours: [], readyForMap: false }),
      vetFixture('F', { openHours: ['24/7'], averageRating: null }),
    ];
    const service = createVetService({
      seedData: { clinics },
      now: () => new Date('2026-10-05T14:30:00Z'),
    });
    // NFD removes combining accents, not the distinct Vietnamese letter đ.
    const found = await service.search({
      q: 'địa chỉ',
      city: 'ho chi minh',
      district: 'quan 7',
      sort: 'rating-desc',
      limit: 2,
    });
    expect(found.items.map((v) => v.id)).toEqual(['C', 'A']);
    expect(found.nextCursor).toBe('2');
    expect(
      (await service.search({ isOpenNow: true, sort: 'name-asc' })).items.map(
        (v) => v.id,
      ),
    ).toEqual(['C', 'D', 'F']);
    expect(
      (await service.search({ is24h: true })).items.map((v) => v.id),
    ).toEqual(['C']);
    expect(
      (await service.search({ minRating: 4.5 })).items.map((v) => v.id),
    ).toEqual(['C']);
    expect(await service.get('B')).toMatchObject({
      averageRating: undefined,
      longitude: undefined,
      isOpen: undefined,
      website: undefined,
    });
    expect(
      (
        await service.nearby({
          latitude: 10.7769,
          longitude: 106.7009,
          radius: 1000,
          minRating: 4.5,
        })
      ).items.map((v) => v.id),
    ).toEqual(['C']);
    expect(
      (
        await service.nearby({
          latitude: 10.7769,
          longitude: 106.7009,
          is24h: true,
        })
      ).items.map((v) => v.id),
    ).toEqual(['C']);
    expect((await service.search({ city: 'Hà Nội' })).items).toEqual([]);
    expect((await service.search({ district: 'Quận 1' })).items).toEqual([]);
    expect((await service.search({ q: 'không có' })).items).toEqual([]);
  });
  it.each([
    { limit: 0 },
    { limit: 51 },
    { limit: 1.5 },
    { cursor: '-1' },
    { cursor: 'bad' },
  ])('rejects invalid search pagination %j', async (input) => {
    const service = createVetService({ seedData: { clinics: [] } });
    await expect(service.search(input)).rejects.toMatchObject({
      statusCode: 400,
      field: 'limit' in input ? 'limit' : 'cursor',
    });
  });
  it.each([NaN, 999, 10001])(
    'rejects an invalid nearby radius before invoking persistence (%s)',
    async (radius) => {
      const listNearby = jest.fn();
      const service = createVetService({
        seedData: { clinics: [] },
        nearbyStore: { listNearby },
      });
      await expect(
        service.nearby({ latitude: 10.7769, longitude: 106.7009, radius }),
      ).rejects.toMatchObject({ statusCode: 400, field: 'radius' });
      expect(listNearby).not.toHaveBeenCalled();
    },
  );
  it('sorts equal nearby distances by rank/name and uses persistent detail fallback', async () => {
    const clinics = [
      vetFixture('B'),
      vetFixture('A'),
      vetFixture('Z', { sourceRank: 2 }),
    ];
    const listNearby = jest.fn().mockResolvedValue(clinics);
    const getDetailById = jest.fn().mockResolvedValue(vetFixture('stored'));
    const service = createVetService({
      seedData: { clinics: [] },
      nearbyStore: { listNearby, getDetailById },
    });
    expect(
      (
        await service.nearby({ latitude: 10.7769, longitude: 106.7009 })
      ).items.map((v) => v.id),
    ).toEqual(['A', 'B', 'Z']);
    expect((await service.get('stored')).id).toBe('stored');
    getDetailById.mockResolvedValue(undefined);
    await expect(service.get('missing')).rejects.toMatchObject({
      statusCode: 404,
    });
  });
});

const validPet = {
  name: 'Mochi',
  species: 'dog',
  breed: 'Golden',
  color: 'Kem',
};
describe('Day137 pet/health/reminder validation and effects', () => {
  it.each([
    [{ name: '' }, 'name'],
    [{ name: 'n'.repeat(51) }, 'name'],
    [{ species: '' }, 'species'],
    [{ species: 'fish' }, 'species'],
    [{ breed: '' }, 'breed'],
    [{ breed: 'b'.repeat(81) }, 'breed'],
    [{ color: '' }, 'color'],
    [{ color: 'c'.repeat(81) }, 'color'],
    [{ gender: 'invalid' }, 'gender'],
    [{ healthStatus: 'invalid' }, 'healthStatus'],
    [{ weight: NaN }, 'weight'],
    [{ weight: 0 }, 'weight'],
    [{ dob: 'bad' }, 'dob'],
    [{ dob: '2025-13-01' }, 'dob'],
    [{ dob: '2025-02-30' }, 'dob'],
    [{ dob: '2030-01-01' }, 'dob'],
    [{ microchip: 'm'.repeat(33) }, 'microchip'],
    [{ microchip: 'not a chip' }, 'microchip'],
  ])('rejects invalid pet %j before saving (%s)', async (patch, field) => {
    const pets = createPetService(buildTestConfig());
    await expect(
      pets.create('owner-a', { ...validPet, ...patch }),
    ).rejects.toMatchObject({ statusCode: 400, field });
    await expect(pets.list('owner-a')).resolves.toEqual([]);
  });
  it('preserves identity and unchanged fields while clearing only nullable pet values', async () => {
    const pets = createPetService(buildTestConfig());
    const pet = await pets.create('owner-a', {
      ...validPet,
      dob: '2024-01-02',
      weight: 1.234,
      microchip: 'MC-1',
    });
    expect(pet).toMatchObject({ dob: '2024-01-02', weight: 1.23 });
    await pets.update('owner-a', pet.id, {
      name: 'Bắp',
      species: 'cat',
      breed: 'Tam thể',
      gender: 'female',
      color: 'Trắng',
      isNeutered: true,
      healthStatus: 'monitoring',
      microchip: 'MC-2',
    });
    const updated = await pets.update('owner-a', pet.id, {
      dob: null,
      weight: null,
      microchip: null,
      isNeutered: null,
      healthStatus: null,
      species: null,
      gender: null,
    });
    expect(updated).toMatchObject({
      id: pet.id,
      userId: 'owner-a',
      name: 'Bắp',
      species: 'cat',
      dob: undefined,
      weight: undefined,
      microchip: undefined,
      isNeutered: true,
      healthStatus: 'monitoring',
    });
    await expect(pets.get('other-owner', pet.id)).rejects.toMatchObject({
      statusCode: 403,
    });
    await pets.remove('owner-a', pet.id);
    await expect(pets.get('owner-a', pet.id)).rejects.toMatchObject({
      statusCode: 404,
    });
    await expect(pets.list('owner-a')).resolves.toEqual([]);
  });
  it('rejects both create/update microchip conflicts without corrupting either owner', async () => {
    const pets = createPetService(buildTestConfig());
    await pets.create('owner-b', { ...validPet, microchip: 'MC-1' });
    const pet = await pets.create('owner-a', validPet);
    await expect(
      pets.create('owner-a', { ...validPet, microchip: 'MC-1' }),
    ).rejects.toMatchObject({ statusCode: 409, field: 'microchip' });
    await expect(
      pets.update('owner-a', pet.id, { microchip: 'MC-1' }),
    ).rejects.toMatchObject({ statusCode: 409, field: 'microchip' });
    expect((await pets.get('owner-a', pet.id)).microchip).toBeUndefined();
    expect(await pets.list('owner-a')).toHaveLength(1);
  });
  it.each([
    [{ base64Data: undefined }, 'base64Data'],
    [{ base64Data: ' ' }, 'base64Data'],
    [{ base64Data: 'data:image/png;base64,' }, 'base64Data'],
    [{ base64Data: 'abc' }, 'base64Data'],
    [{ base64Data: '????' }, 'base64Data'],
    [{ fileName: ' ' }, 'fileName'],
    [{ contentType: undefined }, 'contentType'],
    [{ contentType: 'application/pdf' }, 'contentType'],
    [
      { base64Data: Buffer.alloc(5 * 1024 * 1024 + 1).toString('base64') },
      'base64Data',
    ],
  ])(
    'rejects invalid photo metadata before storage (case %#)',
    async (patch, field) => {
      const savePhoto = jest.fn();
      const pets = createPetService(buildTestConfig(), { savePhoto });
      const pet = await pets.create('owner-a', validPet);
      await expect(
        pets.attachPhoto('owner-a', pet.id, {
          fileName: 'm.png',
          contentType: 'image/png',
          base64Data: 'YWJj',
          ...patch,
        }),
      ).rejects.toMatchObject({ statusCode: 400, field });
      expect(savePhoto).not.toHaveBeenCalled();
      expect((await pets.get('owner-a', pet.id)).avatarUrl).toBeUndefined();
    },
  );
  it.each([
    [{ type: '' }, 'type'],
    [{ type: 'unknown' }, 'type'],
    [{ date: '' }, 'date'],
    [{ date: 'bad' }, 'date'],
    [{ date: '2025-13-01' }, 'date'],
    [{ date: '2025-02-30' }, 'date'],
    [{ time: '25:00' }, 'time'],
    [{ title: 't'.repeat(121) }, 'title'],
    [{ note: 'n'.repeat(1001) }, 'note'],
    [{ vetId: 'bad-id' }, 'vetId'],
    [{ attachments: {} }, 'attachments'],
    [
      { attachments: Array(6).fill('https://example.invalid/p.png') },
      'attachments',
    ],
    [{ attachments: [null] }, 'attachments.0'],
    [{ attachments: ['file://private'] }, 'attachments.0'],
  ])('rejects invalid health field %s without saving', async (patch, field) => {
    const pets = createPetService(buildTestConfig());
    const pet = await pets.create('owner-a', validPet);
    const health = createHealthRecordService({ petReader: pets });
    await expect(
      health.create('owner-a', pet.id, {
        type: 'vaccination',
        date: '2026-01-01',
        ...patch,
      }),
    ).rejects.toMatchObject({ statusCode: 400, field });
    expect((await health.list('owner-a', pet.id)).items).toEqual([]);
  });
  it('supports health aliases, natural pagination, clears optional details and excludes deleted records', async () => {
    const pets = createPetService(buildTestConfig());
    const pet = await pets.create('owner-a', validPet);
    const health = createHealthRecordService({ petReader: pets });
    const record = await health.create('owner-a', pet.id, {
      recordType: 'checkup',
      recordDate: '2026-01-01',
      eventTime: '09:30',
      notes: 'Note',
      attachments: ['https://example.invalid/a.png'],
    });
    const b = await health.create('owner-a', pet.id, {
      type: 'vaccination',
      date: '2026-02-01',
    });
    const page = await health.list('owner-a', pet.id, { limit: 1 });
    expect(page.nextCursor).toBe(b.id);
    expect(
      (
        await health.list('owner-a', pet.id, {
          limit: 1,
          cursor: page.nextCursor,
        })
      ).items[0].id,
    ).toBe(record.id);
    const updated = await health.update('owner-a', pet.id, record.id, {
      recordType: 'note',
      recordDate: '2026-03-01',
      eventTime: '10:40',
      title: ' ',
      notes: ' ',
      vetId: ' ',
      attachments: [],
    });
    expect(updated).toMatchObject({
      id: record.id,
      type: 'note',
      date: '2026-03-01',
      time: '10:40',
      title: undefined,
      note: undefined,
      vetId: undefined,
      attachments: [],
    });
    await health.remove('owner-a', pet.id, record.id);
    await expect(
      health.update('owner-a', pet.id, record.id, {}),
    ).rejects.toMatchObject({ statusCode: 404 });
    expect(
      (await health.list('owner-a', pet.id, { type: 'note' })).items,
    ).toEqual([]);
    await Promise.all(
      [0, 51, 1.5].map(async (limit) => {
        await expect(
          health.list('owner-a', pet.id, { limit }),
        ).rejects.toMatchObject({ statusCode: 400, field: 'limit' });
      }),
    );
  });
  it.each([
    [{ title: '' }, 'title'],
    [{ title: 't'.repeat(121) }, 'title'],
    [{ note: 'n'.repeat(1001) }, 'note'],
    [{ reminderAt: '' }, 'reminderAt'],
    [{ reminderAt: 'bad' }, 'reminderAt'],
    [{ repeatRule: 'yearly' }, 'repeatRule'],
    [{ timezone: 'bad time zone' }, 'timezone'],
    [{ timezone: 'a'.repeat(65) }, 'timezone'],
  ])(
    'rejects reminder %s without notification/draft effects',
    async (patch, field) => {
      const pets = createPetService(buildTestConfig());
      const pet = await pets.create('owner-a', validPet);
      const createReminderNotification = jest.fn();
      const reminders = createReminderService({
        petReader: pets,
        notificationService: { createReminderNotification },
      });
      await expect(
        reminders.create('owner-a', pet.id, {
          title: 'Nhắc',
          reminderAt: '2026-01-01T00:00:00Z',
          ...patch,
        }),
      ).rejects.toMatchObject({ statusCode: 400, field });
      expect((await reminders.list('owner-a', pet.id)).items).toEqual([]);
      expect(createReminderNotification).not.toHaveBeenCalled();
    },
  );
  it.each(['none', 'daily', 'weekly', 'monthly'])(
    'processes recurrence %s after due time without retrying notification',
    async (repeatRule) => {
      const pets = createPetService(buildTestConfig());
      const pet = await pets.create('owner-a', validPet);
      const notify = jest.fn().mockResolvedValue({});
      const reminders = createReminderService({
        petReader: pets,
        notificationService: { createReminderNotification: notify },
      });
      const reminder = await reminders.create('owner-a', pet.id, {
        title: 'Nhắc',
        reminderAt: '2026-01-01T00:00:00Z',
        repeatRule,
        note: ' ',
      });
      const next = await reminders.update('owner-a', pet.id, reminder.id, {
        title: 'Nhắc mới',
        note: 'Note',
        reminderAt: '2026-01-02T00:00:00Z',
        repeatRule,
        timezone: 'UTC',
      });
      expect(next).toMatchObject({
        title: 'Nhắc mới',
        note: 'Note',
        timezone: 'UTC',
      });
      const now = new Date('2026-04-01T00:00:00Z');
      const result = await reminders.processDueRemindersForUser('owner-a', now);
      expect(result.processedCount).toBe(1);
      expect(notify).toHaveBeenCalledTimes(1);
      expect(notify.mock.lastCall![0]).toMatchObject({
        userId: 'owner-a',
        body: 'Note',
        reminderId: reminder.id,
      });
      if (repeatRule === 'none')
        expect(result.items[0]).toMatchObject({
          status: 'sent',
          nextTriggerAt: undefined,
        });
      else {
        expect(result.items[0].status).toBe('scheduled');
        expect(Date.parse(result.items[0].nextTriggerAt!)).toBeGreaterThan(
          now.getTime(),
        );
      }
      await reminders.remove('owner-a', pet.id, reminder.id);
      await expect(
        reminders.update('owner-a', pet.id, reminder.id, {}),
      ).rejects.toMatchObject({ statusCode: 404 });
    },
  );
  it('filters reminder dates/done state, scopes due processing, and paginates stably', async () => {
    const pets = createPetService(buildTestConfig());
    const pet = await pets.create('owner-a', validPet);
    const notify = jest.fn().mockResolvedValue({});
    const reminders = createReminderService({
      petReader: pets,
      notificationService: { createReminderNotification: notify },
    });
    const a = await reminders.create('owner-a', pet.id, {
      title: 'A',
      reminderAt: '2026-01-01T00:00:00Z',
    });
    const b = await reminders.create('owner-a', pet.id, {
      title: 'B',
      reminderAt: '2026-01-01T00:00:00Z',
    });
    expect(
      (await reminders.list('owner-a', pet.id, { limit: 1 })).nextCursor,
    ).toBe(a.id);
    expect(
      (await reminders.list('owner-a', pet.id, { limit: 1, cursor: a.id }))
        .items[0].id,
    ).toBe(b.id);
    await reminders.markDone('owner-a', pet.id, a.id);
    expect(
      (await reminders.list('owner-a', pet.id)).items.map((r) => r.id),
    ).toEqual([b.id]);
    expect(
      (await reminders.list('owner-a', pet.id, { includeDone: true })).items,
    ).toHaveLength(2);
    expect(
      (
        await reminders.list('owner-a', pet.id, {
          from: '2026-02-01T00:00:00Z',
        })
      ).items,
    ).toEqual([]);
    expect(
      (await reminders.list('owner-a', pet.id, { to: '2025-12-31T00:00:00Z' }))
        .items,
    ).toEqual([]);
    await expect(
      reminders.snooze('owner-a', pet.id, b.id, {}),
    ).rejects.toMatchObject({ statusCode: 400, field: 'snoozedUntil' });
    await reminders.snooze('owner-a', pet.id, b.id, {
      snoozedUntil: '2026-02-01T00:00:00Z',
    });
    expect(
      (
        await reminders.processDueRemindersForUser(
          'owner-b',
          new Date('2026-03-01T00:00:00Z'),
        )
      ).processedCount,
    ).toBe(0);
    expect(
      (await reminders.processDueReminders(new Date('2026-03-01T00:00:00Z')))
        .processedCount,
    ).toBe(1);
    expect(notify.mock.lastCall![0].body).toContain('Reminder due at');
    await Promise.all(
      [0, 51, 1.5].map(async (limit) => {
        await expect(
          reminders.list('owner-a', pet.id, { limit }),
        ).rejects.toMatchObject({ statusCode: 400, field: 'limit' });
      }),
    );
  });
});
