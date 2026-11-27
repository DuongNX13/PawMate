import { readFileSync } from 'node:fs';
import path from 'node:path';

import {
  RESCUE_IMAGE_MAX_BYTES,
  RESCUE_VIDEO_MAX_BYTES,
} from '../src/features/rescue/rescue-media-policy';

type RouteContract = {
  path: string;
  screen: string;
  permission?: string;
  bottomNavVisible?: boolean;
  bottomNavActive?: string;
};

type EndpointContract = {
  contractId: string;
  implementation?: string;
  method: string;
  path: string;
  auth: string;
  states?: string[];
};

type ModuleContract = {
  status?: string;
  routes: RouteContract[];
  backendEndpoints: EndpointContract[];
  domainModels?: {
    lostCase?: {
      requiredFields: string[];
      statusValues: string[];
      statusUiMap: Record<string, string>;
      persistenceSpeciesValues: string[];
      publicSpeciesValues: string[];
      publicSpeciesProjection: Record<string, string>;
    };
    adoptionListing?: { requiredFields: string[] };
    adoptionRequest?: { requiredFields: string[] };
    shelterChatMessage?: { requiredFields: string[] };
  };
  entryRule?: string;
};

type Phase2Contract = {
  guardrails: {
    bottomNavLabels: string[];
    adoptionDoesNotReplaceNav: boolean;
    rescueStatusUi: string[];
    forbiddenRescueStatusUi: string[];
    ownerOnlyActions: string[];
  };
  modules: {
    rescue: ModuleContract;
    adoption: ModuleContract;
    settingsAndPrivacy: Pick<ModuleContract, 'routes' | 'backendEndpoints'>;
  };
  impactCoverage: {
    rescue: string[];
    adoption: string[];
    settingsAndPrivacy: string[];
  };
  implementationOrder: string[];
};

type DtoDefinition = {
  required: string[];
  optional: Record<string, string> | string[];
  types?: Record<string, string>;
  rules?: string[];
};

type ModelDefinition = {
  required: string[];
  optional?: string[];
  types: Record<string, string>;
  forbidden?: string[];
};

type ContractExample = {
  dto: string;
  value: Record<string, unknown>;
};

type ApiEndpoint = {
  id: string;
  module: string;
  implementation: string;
  method: string;
  path: string;
  auth: string;
  requestDto: string;
  responseDto: string;
  successStatus: number;
  errors: string[];
  sideEffects: string[];
  invalidates: string[];
  idempotencyMode: string;
};

type ApiContract = {
  status: string;
  conventions: {
    errorEnvelope: {
      required: string[];
      errorRequired: string[];
    };
    identifiers: {
      canonicalFields: string[];
    };
    idempotency: {
      header: string;
      requiredForEndpointModes: string[];
    };
    media: {
      directBase64InJson: boolean;
      allowedMimeTypes: string[];
      imageMaxBytes: number;
      videoMaxBytes: number;
      maxAttachmentsPerEntity: number;
    };
    locationPrivacy: {
      publicFields: string[];
      publicRule: string;
      seamRule?: string;
      decisionSource?: string;
    };
    outbox: {
      producer: string;
      consumer: string;
      deliveryGuarantee: string;
      events: string[];
      decisionSource?: string;
    };
    rescuePublicRead: {
      defaultSort: string;
      defaultLimit: number;
      radiusDefaultMeters: number;
      radiusRequiresCoordinates: boolean;
      cursorBindingFields: string[];
      publicSpeciesValues: string[];
      persistenceSpeciesProjection: Record<string, string>;
      otherSpeciesFilterMatchesPersistenceValues: string[];
    };
  };
  dtos: Record<string, DtoDefinition>;
  models: Record<string, ModelDefinition>;
  examples: Record<string, ContractExample>;
  endpoints: ApiEndpoint[];
  compatibilityRisks: Array<{ id: string; mitigation: string }>;
};

const readJson = <T>(relativePath: string): T => {
  const contractPath = path.resolve(__dirname, relativePath);
  return JSON.parse(readFileSync(contractPath, 'utf8')) as T;
};

const readText = (relativePath: string): string =>
  readFileSync(path.resolve(__dirname, relativePath), 'utf8');

const readPhase2Contract = (): Phase2Contract =>
  readJson<Phase2Contract>(
    '../../docs/engineering/phase2_route_data_contract.json',
  );

const readApiContract = (): ApiContract =>
  readJson<ApiContract>('../../docs/architecture/pawmate_api_contract_v1.json');

const expectRoute = (
  routes: RouteContract[],
  routePath: string,
): RouteContract => {
  const route = routes.find((candidate) => candidate.path === routePath);
  expect(route).toBeDefined();
  return route as RouteContract;
};

const expectEndpoint = (
  endpoints: ApiEndpoint[],
  endpointId: string,
): ApiEndpoint => {
  const endpoint = endpoints.find((candidate) => candidate.id === endpointId);
  expect(endpoint).toBeDefined();
  return endpoint as ApiEndpoint;
};

describe('PawMate Day 7 API/data contract', () => {
  it('keeps the Phase 1 app shell and Rescue status copy guardrails', () => {
    const contract = readPhase2Contract();

    expect(contract.guardrails.bottomNavLabels).toEqual([
      'Home',
      'Vet',
      'Health',
      'Rescue',
      'Profile',
    ]);
    expect(contract.guardrails.adoptionDoesNotReplaceNav).toBe(true);
    expect(contract.guardrails.rescueStatusUi).toEqual([
      'Chưa thấy',
      'Đã thấy',
    ]);
    expect(contract.guardrails.forbiddenRescueStatusUi).toEqual([
      'Chưa tìm',
      'Đã tìm',
      'Đang tìm',
    ]);
    expect(contract.modules.rescue.domainModels?.lostCase?.statusUiMap).toEqual(
      {
        missing: 'Chưa thấy',
        found: 'Đã thấy',
      },
    );
  });

  it('defines a complete and unique implementation contract for every endpoint', () => {
    const contract = readApiContract();
    const allowedAuth = new Set([
      'public',
      'authenticated',
      'owner',
      'adopter',
      'participant',
    ]);
    const endpointIds = contract.endpoints.map((endpoint) => endpoint.id);
    const routeKeys = contract.endpoints.map(
      (endpoint) => `${endpoint.method} ${endpoint.path}`,
    );

    expect(contract.status).toBe('LOCKED_FOR_IMPLEMENTATION');
    expect(new Set(endpointIds).size).toBe(endpointIds.length);
    expect(new Set(routeKeys).size).toBe(routeKeys.length);
    expect(contract.endpoints).toHaveLength(25);

    contract.endpoints.forEach((endpoint) => {
      expect(endpoint.id).toMatch(/^[a-z][a-z0-9.-]+$/);
      expect(endpoint.path).toMatch(/^\//);
      expect(allowedAuth.has(endpoint.auth)).toBe(true);
      expect(contract.dtos[endpoint.requestDto]).toBeDefined();
      expect(contract.dtos[endpoint.responseDto]).toBeDefined();
      expect(endpoint.successStatus).toBeGreaterThanOrEqual(200);
      expect(endpoint.successStatus).toBeLessThan(300);
      expect(endpoint.errors.length).toBeGreaterThan(0);
      expect(Array.isArray(endpoint.sideEffects)).toBe(true);
      expect(Array.isArray(endpoint.invalidates)).toBe(true);
      if (endpoint.method !== 'GET') {
        expect(endpoint.auth).not.toBe('public');
      }
    });
  });

  it('gives every required field a type and validates request examples structurally', () => {
    const contract = readApiContract();

    Object.entries(contract.dtos).forEach(([dtoName, dto]) => {
      expect(new Set(dto.required).size).toBe(dto.required.length);
      dto.required.forEach((field) => {
        if (!dto.types?.[field]) {
          throw new Error(`${dtoName}.${field} is missing a type`);
        }
      });
      (dto.rules ?? []).forEach((rule) => {
        expect(rule.trim().length).toBeGreaterThan(0);
      });
    });

    Object.entries(contract.models).forEach(([modelName, model]) => {
      const fields = [...model.required, ...(model.optional ?? [])];
      expect(new Set(fields).size).toBe(fields.length);
      fields.forEach((field) => {
        if (!model.types[field]) {
          throw new Error(`${modelName}.${field} is missing a type`);
        }
      });
      (model.forbidden ?? []).forEach((forbiddenField) => {
        expect(fields).not.toContain(forbiddenField);
      });
    });

    Object.entries(contract.examples).forEach(([exampleName, example]) => {
      const dto = contract.dtos[example.dto];
      if (!dto) {
        throw new Error(`${exampleName} references an unknown DTO`);
      }
      const optionalFields = Array.isArray(dto.optional)
        ? dto.optional
        : Object.keys(dto.optional);
      const allowedFields = new Set([...dto.required, ...optionalFields]);
      dto.required.forEach((requiredField) => {
        if (!Object.hasOwn(example.value, requiredField)) {
          throw new Error(`${exampleName} is missing ${requiredField}`);
        }
      });
      Object.keys(example.value).forEach((field) => {
        if (!allowedFields.has(field)) {
          throw new Error(`${exampleName} contains unknown field ${field}`);
        }
      });
    });
  });

  it('keeps public/auth read decisions aligned with both SRS impact matrices', () => {
    const { endpoints } = readApiContract();

    [
      'vet.search',
      'vet.nearby',
      'vet.detail',
      'vet.reviews.list',
      'rescue.cases.list',
      'rescue.cases.detail',
    ].forEach((endpointId) => {
      expect(expectEndpoint(endpoints, endpointId).auth).toBe('public');
    });

    expect(expectEndpoint(endpoints, 'rescue.discussion.list').auth).toBe(
      'authenticated',
    );
    expect(expectEndpoint(endpoints, 'adoption.listings.list').auth).toBe(
      'authenticated',
    );
    expect(expectEndpoint(endpoints, 'adoption.listings.detail').auth).toBe(
      'authenticated',
    );
  });

  it('locks Day 35 Rescue public-read defaults, projection and privacy allowlists', () => {
    const phase2 = readPhase2Contract();
    const api = readApiContract();
    const rescueList = expectEndpoint(api.endpoints, 'rescue.cases.list');
    const rescueDetail = expectEndpoint(api.endpoints, 'rescue.cases.detail');
    const rescueDiscussion = expectEndpoint(
      api.endpoints,
      'rescue.discussion.list',
    );
    const phase2List = phase2.modules.rescue.backendEndpoints.find(
      (endpoint) => endpoint.contractId === 'rescue.cases.list',
    );
    const phase2Detail = phase2.modules.rescue.backendEndpoints.find(
      (endpoint) => endpoint.contractId === 'rescue.cases.detail',
    );
    const phase2Discussion = phase2.modules.rescue.backendEndpoints.find(
      (endpoint) => endpoint.contractId === 'rescue.discussion.list',
    );
    const listQuery = api.dtos.RescueCaseListQuery;
    const listOptional = listQuery.optional as Record<string, string>;
    const publicRead = api.conventions.rescuePublicRead;
    const publicMedia = api.models.PublicMediaAsset;
    const rescueSummary = api.models.RescueCaseSummary;
    const rescueDetailModel = api.models.RescueCaseDetail;
    const lostCase = phase2.modules.rescue.domainModels?.lostCase;

    expect(phase2.modules.rescue.status).toBe(
      'day34-schema-verified-day35-read-day36-write-implemented',
    );
    expect(rescueList.implementation).toBe('implemented-day35');
    expect(rescueDetail.implementation).toBe('implemented-day35');
    expect(rescueDiscussion.implementation).toBe('implemented-day36');
    expect(phase2List?.implementation).toBe('implemented-day35');
    expect(phase2Detail?.implementation).toBe('implemented-day35');
    expect(phase2Discussion?.implementation).toBe('implemented-day36');

    expect(listOptional.sort).toContain('default recent');
    expect(listOptional.limit).toContain('default 20');
    expect(listOptional.radiusMeters).toContain(
      'default 1000 only when lat/lng are present',
    );
    expect(listQuery.rules).toEqual(
      expect.arrayContaining([
        'radiusMeters is rejected unless lat and lng are supplied',
        'cursor is opaque and can be reused only when status, species, lostFrom, lostTo, sort, lat, lng and radiusMeters match the request that issued it',
      ]),
    );
    expect(publicRead).toMatchObject({
      defaultSort: 'recent',
      defaultLimit: 20,
      radiusDefaultMeters: 1000,
      radiusRequiresCoordinates: true,
    });
    expect(publicRead.cursorBindingFields).toEqual([
      'status',
      'species',
      'lostFrom',
      'lostTo',
      'sort',
      'lat',
      'lng',
      'radiusMeters',
    ]);

    expect(publicRead.persistenceSpeciesProjection).toMatchObject({
      bird: 'other',
      rabbit: 'other',
    });
    expect(publicRead.otherSpeciesFilterMatchesPersistenceValues).toEqual([
      'bird',
      'rabbit',
      'other',
    ]);
    expect(lostCase?.publicSpeciesValues).toEqual(['dog', 'cat', 'other']);
    expect(lostCase?.publicSpeciesProjection).toMatchObject({
      bird: 'other',
      rabbit: 'other',
    });

    expect(publicMedia.required).toEqual([
      'mediaId',
      'mimeType',
      'publicUrl',
      'createdAt',
    ]);
    expect(publicMedia.optional).toEqual([
      'width',
      'height',
      'durationSeconds',
    ]);
    expect(publicMedia.forbidden).toEqual(
      expect.arrayContaining([
        'ownerUserId',
        'sha256',
        'storageKey',
        'status',
        'rescueCaseId',
        'caseCommentId',
      ]),
    );
    expect(rescueSummary.types.media).toBe('PublicMediaAsset[]');
    expect(rescueDetailModel.types.media).toBe('PublicMediaAsset[]');
    expect(rescueDetailModel.required).toContain('version');
    expect(rescueDetailModel.types.version).toBe('integer:min1');
    expect(rescueDetailModel.forbidden).toEqual(
      expect.arrayContaining([
        'ownerUserId',
        'sourceDraftId',
        'exactLocation',
        'privateLocation',
        'houseNumber',
        'phone',
        'storageKey',
        'sha256',
      ]),
    );
  });

  it('locks all eight Day 36 Rescue write/media endpoints as implemented', () => {
    const phase2 = readPhase2Contract();
    const api = readApiContract();
    const day36Ids = [
      'rescue.drafts.create',
      'rescue.drafts.update',
      'rescue.drafts.publish',
      'rescue.comments.create',
      'rescue.discussion.list',
      'rescue.cases.status.update',
      'media.uploads.request',
      'media.uploads.complete',
    ];

    day36Ids.forEach((contractId) => {
      expect(expectEndpoint(api.endpoints, contractId).implementation).toBe(
        'implemented-day36',
      );
      expect(
        phase2.modules.rescue.backendEndpoints.find(
          (endpoint) => endpoint.contractId === contractId,
        )?.implementation,
      ).toBe('implemented-day36');
    });
  });

  it('links every Phase 2 endpoint to the detailed API contract without drift', () => {
    const phase2 = readPhase2Contract();
    const api = readApiContract();
    const apiById = new Map(
      api.endpoints.map((endpoint) => [endpoint.id, endpoint]),
    );
    const phase2Endpoints = [
      ...phase2.modules.rescue.backendEndpoints,
      ...phase2.modules.adoption.backendEndpoints,
      ...phase2.modules.settingsAndPrivacy.backendEndpoints,
    ];

    phase2Endpoints.forEach((endpoint) => {
      const detail = apiById.get(endpoint.contractId);
      expect(detail).toBeDefined();
      expect(detail?.method).toBe(endpoint.method);
      expect(detail?.path).toBe(endpoint.path);
      expect(detail?.auth).toBe(endpoint.auth);
    });
  });

  it('uses canonical Phase 2 identifiers and prevents owner-action leakage', () => {
    const phase2 = readPhase2Contract();
    const api = readApiContract();

    expect(api.conventions.identifiers.canonicalFields).toEqual(
      expect.arrayContaining([
        'caseId',
        'draftId',
        'commentId',
        'listingId',
        'requestId',
        'threadId',
        'messageId',
        'mediaId',
      ]),
    );
    expect(api.models.RescueCaseSummary.required).toContain('caseId');
    expect(api.models.RescueCaseSummary.forbidden).toEqual(
      expect.arrayContaining(['exactLocation', 'houseNumber', 'phone']),
    );
    expect(api.models.AdoptionListingSummary.required).toContain('listingId');
    expect(
      expectRoute(phase2.modules.rescue.routes, '/rescue/:caseId/status')
        .permission,
    ).toBe('owner-only');
    expect(
      expectEndpoint(api.endpoints, 'rescue.cases.status.update').auth,
    ).toBe('owner');
  });

  it('locks idempotency, media and exact-location privacy semantics', () => {
    const contract = readApiContract();
    const idempotentModes = new Set(
      contract.conventions.idempotency.requiredForEndpointModes,
    );

    expect(contract.conventions.idempotency.header).toBe('Idempotency-Key');
    expect(contract.conventions.media.directBase64InJson).toBe(false);
    expect(contract.conventions.media.allowedMimeTypes).toEqual(
      expect.arrayContaining([
        'image/jpeg',
        'image/png',
        'image/webp',
        'video/mp4',
      ]),
    );
    expect(contract.conventions.media.imageMaxBytes).toBe(
      RESCUE_IMAGE_MAX_BYTES,
    );
    expect(contract.conventions.media.videoMaxBytes).toBe(
      RESCUE_VIDEO_MAX_BYTES,
    );
    const mediaLimitSql = [
      readText('../prisma/sql/day34_rescue_foundation_patch.sql'),
      readText('../prisma/sql/day36_rescue_write_patch.sql'),
    ];
    mediaLimitSql.forEach((sql) => {
      expect(sql).toContain(String(RESCUE_IMAGE_MAX_BYTES));
      expect(sql).toContain(String(RESCUE_VIDEO_MAX_BYTES));
      expect(sql).not.toContain('104857600');
    });
    expect(contract.conventions.media.maxAttachmentsPerEntity).toBeGreaterThan(
      0,
    );
    expect(contract.conventions.locationPrivacy.publicRule).toContain(
      'Never return house number or exact coordinates',
    );
    expect(contract.conventions.locationPrivacy.publicRule).toContain(
      '0.003 degree quantization cell',
    );
    expect(contract.conventions.locationPrivacy.publicRule).toContain(
      'not a minimum displacement',
    );
    expect(contract.conventions.locationPrivacy.seamRule).toContain(
      'half-open [-180, 180)',
    );
    expect(contract.conventions.locationPrivacy.seamRule).toContain(
      'canonical -180',
    );
    expect(contract.conventions.locationPrivacy.decisionSource).toContain(
      'Day 38',
    );
    expect(contract.conventions.outbox.deliveryGuarantee).toBe('producer-only');
    expect(contract.conventions.outbox.consumer).toContain('no claim');
    expect(contract.conventions.outbox.events).toEqual([
      'rescue.case_published.v1',
      'rescue.comment_created.v1',
      'rescue.case_status_changed.v1',
    ]);

    contract.endpoints.forEach((endpoint) => {
      if (idempotentModes.has(endpoint.idempotencyMode)) {
        expect(endpoint.method).not.toBe('GET');
      }
    });

    expectEndpoint(contract.endpoints, 'media.uploads.request');
    expectEndpoint(contract.endpoints, 'media.uploads.complete');
  });

  it('covers Phase 2 impacts and bans production in-memory implementation order', () => {
    const contract = readPhase2Contract();
    const implementationOrder = contract.implementationOrder
      .join(' ')
      .toLowerCase();

    expect(contract.impactCoverage.rescue).toHaveLength(15);
    expect(contract.impactCoverage.adoption).toHaveLength(6);
    expect(contract.impactCoverage.settingsAndPrivacy).toEqual(
      expect.arrayContaining(['P2-IM-026', 'P2-IM-027']),
    );
    expect(implementationOrder).toMatch(/migration|migrated persistence/);
    expect(implementationOrder).not.toContain('in-memory');
    expect(implementationOrder).toContain(
      'process-local transient stores are forbidden',
    );
  });

  it('documents compatibility risks instead of silently breaking current consumers', () => {
    const contract = readApiContract();

    expect(contract.compatibilityRisks.map((risk) => risk.id)).toEqual([
      'COMPAT-001',
      'COMPAT-002',
      'COMPAT-003',
    ]);
    contract.compatibilityRisks.forEach((risk) => {
      expect(risk.mitigation.length).toBeGreaterThan(20);
    });
    expect(contract.conventions.errorEnvelope.required).toEqual(
      expect.arrayContaining(['success', 'error', 'requestId']),
    );
    expect(contract.conventions.errorEnvelope.errorRequired).toEqual([
      'code',
      'message',
    ]);
  });
});
