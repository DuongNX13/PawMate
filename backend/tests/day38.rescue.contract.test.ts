import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

type RescueContract = {
  conventions: {
    locationPrivacy: {
      publicRule: string;
      decisionSource: string;
    };
    outbox: {
      producer: string;
      consumer: string;
      deliveryGuarantee: string;
      events: string[];
    };
  };
  models: {
    RescueCaseDetail: {
      optional: string[];
      permissionRule: string;
    };
  };
};

const repoRoot = resolve(__dirname, '../..');
const contract = JSON.parse(
  readFileSync(
    resolve(repoRoot, 'docs/architecture/pawmate_api_contract_v1.json'),
    'utf8',
  ),
) as RescueContract;
const repositorySource = readFileSync(
  resolve(
    __dirname,
    '../src/features/rescue/persistence/prisma-rescue-repository.ts',
  ),
  'utf8',
);

describe('Day 38 Rescue contract scope', () => {
  it('keeps public privacy quantization and deferred contactChannel explicit', () => {
    expect(contract.conventions.locationPrivacy.publicRule).toContain(
      'deterministic center of a fixed 0.003 degree quantization cell',
    );
    expect(contract.conventions.locationPrivacy.publicRule).toContain(
      'not a minimum displacement',
    );
    expect(contract.conventions.locationPrivacy.decisionSource).toContain(
      'Day 38',
    );
    expect(contract.models.RescueCaseDetail.optional).not.toContain(
      'contactChannel',
    );
    expect(contract.models.RescueCaseDetail.permissionRule).toContain(
      'contactChannel',
    );
    expect(contract.models.RescueCaseDetail.permissionRule).toContain(
      'deferred',
    );
  });

  it('proves the current repository is producer-only for the three agreed events', () => {
    expect(contract.conventions.outbox.deliveryGuarantee).toBe('producer-only');
    expect(contract.conventions.outbox.consumer).toContain('no claim');
    expect(contract.conventions.outbox.events).toEqual([
      'rescue.case_published.v1',
      'rescue.comment_created.v1',
      'rescue.case_status_changed.v1',
    ]);

    expect(repositorySource.match(/outboxEvent\.create\(/gu)).toHaveLength(3);
    expect(repositorySource).not.toMatch(
      /outboxEvent\.(update|updateMany|delete|deleteMany)\(/u,
    );
    expect(repositorySource).not.toMatch(/processedAt|claimedAt|lockToken/u);
    contract.conventions.outbox.events.forEach((eventType) => {
      expect(repositorySource).toContain(`eventType: '${eventType}'`);
    });
  });

  it('recomputes the public area label at publish time', () => {
    expect(repositorySource).toContain('projectRescueLocationPrivacy');
    expect(repositorySource).not.toContain('areaLabel: draft.areaLabel!');
    expect(repositorySource).toContain('areaLabel: publicLocation.areaLabel');
  });
});
