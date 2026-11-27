import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const backendRoot = join(__dirname, '..');
const read = (relativePath: string) =>
  readFileSync(join(backendRoot, relativePath), 'utf8');
const readProject = (relativePath: string) =>
  readFileSync(join(backendRoot, '..', relativePath), 'utf8');

describe('Day 50 Adoption persistence contract', () => {
  const schema = read('prisma/schema.prisma');
  const patch = read('prisma/sql/day50_adoption_foundation_patch.sql');
  const preflight = read('prisma/sql/day50_adoption_preflight.sql');
  const postflight = read('prisma/sql/day50_adoption_postflight.sql');
  const rollback = read('prisma/sql/day50_adoption_rollback.sql');
  const seed = read('prisma/sql/day50_adoption_seed.sql');
  const apiContract = JSON.parse(
    readProject('docs/architecture/pawmate_api_contract_v1.json'),
  ) as {
    endpoints: Array<{
      id: string;
      implementation: string;
      method: string;
      path: string;
      auth: string;
      successStatus: number;
    }>;
  };

  it('keeps canonical UUID listing/request/thread identifiers in Prisma', () => {
    expect(schema).toMatch(
      /model AdoptionListing \{[\s\S]*id\s+String\s+@id @default\(uuid\(\)\) @db\.Uuid/,
    );
    expect(schema).toMatch(
      /model AdoptionRequest \{[\s\S]*listingId\s+String\s+@map\("listing_id"\) @db\.Uuid/,
    );
    expect(schema).toMatch(
      /model AdoptionChatThread \{[\s\S]*requestId\s+String\s+@unique/,
    );
  });

  it('enforces one active request per adopter/listing at database level', () => {
    expect(patch).toContain(
      'CREATE UNIQUE INDEX IF NOT EXISTS adoption_requests_active_adopter_listing_key',
    );
    expect(patch).toMatch(
      /WHERE status IN \('submitted', 'reviewing', 'approved'\)/,
    );
  });

  it('binds request shelter and chat participants to their parent records', () => {
    expect(patch).toContain('adoption_requests_listing_shelter_fkey');
    expect(patch).toContain('adoption_chat_threads_request_participants_fkey');
    expect(patch).toContain('CHECK (adopter_user_id <> shelter_id)');
  });

  it('enables deny-by-default RLS on participant-sensitive public tables', () => {
    [
      'adoption_listings',
      'adoption_decisions',
      'adoption_requests',
      'adoption_chat_threads',
    ].forEach((table) => {
      expect(patch).toContain(
        `ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY`,
      );
    });
    expect(patch).not.toMatch(/CREATE POLICY/i);
    expect(postflight).toContain('NOT c.relrowsecurity');
  });

  it('ships preflight, postflight, development seed and fail-closed rollback', () => {
    expect(preflight).toContain('DAY50_ADOPTION_PREFLIGHT_PASS');
    expect(postflight).toContain('DAY50_ADOPTION_POSTFLIGHT_PASS');
    expect(seed).toContain('Do not run this file against production');
    expect(rollback).toContain('allow_destructive_rollback');
    expect(rollback).toContain('rollback refused');
  });

  it('does not contain destructive mutation in the forward patch', () => {
    expect(patch).not.toMatch(/\bDROP\s+(TABLE|TYPE|COLUMN)\b/i);
    expect(patch).not.toMatch(/\bTRUNCATE\b/i);
    expect(patch).not.toMatch(/\bDELETE\s+FROM\b/i);
  });

  it('preserves Day 50 endpoint markers after Day 51 chat implementation', () => {
    const byId = new Map(
      apiContract.endpoints.map((endpoint) => [endpoint.id, endpoint]),
    );
    [
      'adoption.listings.list',
      'adoption.listings.detail',
      'adoption.decisions.create',
      'adoption.requests.create',
    ].forEach((id) => {
      expect(byId.get(id)?.implementation).toBe('implemented-day50');
    });
    [
      'adoption.chat.read',
      'adoption.chat.messages.create',
      'adoption.chat.read.update',
    ].forEach((id) => {
      expect(byId.get(id)?.implementation).toBe('implemented-day51');
    });
    expect(byId.get('adoption.listings.list')).toMatchObject({
      method: 'GET',
      path: '/adoption/listings',
      auth: 'authenticated',
      successStatus: 200,
    });
    expect(byId.get('adoption.requests.create')).toMatchObject({
      method: 'POST',
      path: '/adoption/listings/:listingId/requests',
      auth: 'adopter',
      successStatus: 201,
    });
  });
});
