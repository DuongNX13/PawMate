import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

type VetFoundationContract = {
  compatibility: {
    canonicalVetId: string;
    legacyVetIdAlias: string;
    canonicalListPage: string;
    legacyListPageAlias: string;
  };
  endpoints: Array<{
    id: string;
    method: string;
    path: string;
    auth: string;
    successStatus: number;
  }>;
  nearby: {
    requiredQuery: Record<string, string>;
    distanceUnit: string;
    invalidQuery: { status: number; code: string; fieldRequired: boolean };
  };
  mapState: {
    statuses: string[];
    permissionDenied: string;
    serviceDisabled: string;
    timeoutOrUnknown: string;
  };
};

const readContract = (): VetFoundationContract =>
  JSON.parse(
    readFileSync(
      path.resolve(
        __dirname,
        '../../docs/architecture/pawmate_vet_contract_foundation_v1.json',
      ),
      'utf8',
    ),
  ) as VetFoundationContract;

describe('Day 22 Vet contract foundation', () => {
  it('locks the compatibility aliases and public endpoint matrix', () => {
    const contract = readContract();
    const endpointIds = contract.endpoints.map((endpoint) => endpoint.id);

    expect(new Set(endpointIds).size).toBe(endpointIds.length);
    expect(contract.compatibility).toMatchObject({
      canonicalVetId: 'vetId',
      legacyVetIdAlias: 'id',
      canonicalListPage: 'pageInfo',
      legacyListPageAlias: 'pagination',
    });
    expect(endpointIds).toEqual(
      expect.arrayContaining([
        'vet.search',
        'vet.nearby',
        'vet.detail',
        'vet.reviews.list',
      ]),
    );
    expect(
      contract.endpoints.every((endpoint) => endpoint.auth === 'public'),
    ).toBe(true);
    expect(
      contract.endpoints.every((endpoint) => endpoint.successStatus === 200),
    ).toBe(true);
  });

  it('locks Vietnam location bounds and non-crashing map permission states', () => {
    const contract = readContract();

    expect(contract.nearby).toMatchObject({
      requiredQuery: { lat: 'number:8..24', lng: 'number:102..110' },
      distanceUnit: 'meters',
      invalidQuery: { status: 400, code: 'VET_001', fieldRequired: true },
    });
    expect(contract.mapState.statuses).toEqual(
      expect.arrayContaining([
        'permissionDenied',
        'locationServicesDisabled',
        'empty',
        'ready',
        'error',
      ]),
    );
    expect(contract.mapState.permissionDenied).toContain('no nearby request');
    expect(contract.mapState.serviceDisabled).toContain('no nearby request');
    expect(contract.mapState.timeoutOrUnknown).toContain('fallback center');
  });

  it('keeps the contract document and OpenAPI anchor files present', () => {
    expect(
      existsSync(
        path.resolve(
          __dirname,
          '../../docs/architecture/day22_vet_contract_foundation.md',
        ),
      ),
    ).toBe(true);
    expect(
      existsSync(
        path.resolve(__dirname, '../../docs/architecture/openapi.phase1.yaml'),
      ),
    ).toBe(true);
  });
});
