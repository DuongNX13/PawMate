import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const backendRoot = join(__dirname, '..');
const read = (relativePath: string) =>
  readFileSync(join(backendRoot, relativePath), 'utf8');
const readProject = (relativePath: string) =>
  readFileSync(join(backendRoot, '..', relativePath), 'utf8');

describe('Day 51 Adoption chat persistence contract', () => {
  const schema = read('prisma/schema.prisma');
  const preflight = read('prisma/sql/day51_adoption_chat_preflight.sql');
  const patch = read('prisma/sql/day51_adoption_chat_patch.sql');
  const hardening = read(
    'prisma/sql/day51_adoption_chat_monotonic_hardening.sql',
  );
  const postflight = read('prisma/sql/day51_adoption_chat_postflight.sql');
  const rollback = read('prisma/sql/day51_adoption_chat_rollback.sql');
  const seed = read('prisma/sql/day51_adoption_chat_seed.sql');
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

  it('models participants, monotonic sequence cursors and message media', () => {
    expect(schema).toMatch(
      /model AdoptionChatParticipant \{[\s\S]*@@id\(\[threadId, userId\]\)/,
    );
    expect(schema).toMatch(
      /model AdoptionChatMessage \{[\s\S]*sequence\s+BigInt[\s\S]*@default\(autoincrement\(\)\)/,
    );
    expect(schema).toContain(
      '@relation("AdoptionChatParticipantMessages", fields: [threadId, senderUserId], references: [threadId, userId]',
    );
    expect(schema).toContain(
      '@@index([threadId, sequence(sort: Desc)], map: "adoption_chat_messages_thread_sequence_idx")',
    );
    expect(schema).toContain(
      'adoptionChatMessageId String?                    @map("adoption_chat_message_id") @db.Uuid',
    );
  });

  it('fails preflight on any partial Day 51 schema', () => {
    expect(preflight).toContain('DAY51_ADOPTION_CHAT_PREFLIGHT_PASS');
    expect(preflight).toContain('adoption_chat_participants');
    expect(preflight).toContain('adoption_chat_messages');
    expect(preflight).toContain('AdoptionChatParticipantRole');
    expect(preflight).toContain('adoption_chat_message_id');
    expect(preflight).toContain('partial or previously applied chat schema');
  });

  it('enforces participant identity, role and deny-by-default RLS', () => {
    expect(patch).toContain('adoption_chat_messages_sender_participant_fkey');
    expect(patch).toContain(
      'REFERENCES public.adoption_chat_participants(thread_id, user_id)',
    );
    expect(patch).toContain('adoption_chat_participants_role_guard');
    expect(patch).toContain('Chat read sequence cannot move backwards');
    expect(patch).toContain(
      'UPDATE OF thread_id, user_id, role, last_read_sequence',
    );
    expect(hardening).toContain('DAY51_ADOPTION_CHAT_MONOTONIC_HARDENING_PASS');
    expect(hardening).toContain('Chat read sequence cannot move backwards');
    expect(patch).toContain('\'adopter\'::"AdoptionChatParticipantRole"');
    expect(patch).toContain('\'shelter\'::"AdoptionChatParticipantRole"');
    ['adoption_chat_participants', 'adoption_chat_messages'].forEach(
      (table) => {
        expect(patch).toContain(
          `ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY`,
        );
      },
    );
    expect(patch).not.toMatch(/CREATE POLICY/i);
  });

  it('extends media lifecycle constraints without weakening ownership binding', () => {
    expect(patch).toContain('media_assets_adoption_chat_message_fkey');
    expect(patch).toContain('adoption_chat_message_id');
    expect(patch).toContain("purpose = 'adoption_chat'");
    expect(patch).toContain('media_assets_adoption_chat_message_position_key');
    expect(postflight).toContain('media_assets_entity_count_check');
    expect(postflight).toContain('media_assets_purpose_entity_check');
    expect(postflight).toContain('monotonic read-sequence guard is missing');
  });

  it('ships postflight, test-only seed and explicit fail-closed rollback', () => {
    expect(postflight).toContain('DAY51_ADOPTION_CHAT_POSTFLIGHT_PASS');
    expect(seed).toContain('Do not run this file against production');
    expect(rollback).toContain('allow_destructive_rollback');
    expect(rollback).toContain('rollback refused');
    expect(rollback).toContain('message_count <> 0 OR media_count <> 0');
  });

  it('keeps the forward migration non-destructive', () => {
    expect(patch).not.toMatch(/\bDROP\s+(TABLE|TYPE|COLUMN)\b/i);
    expect(patch).not.toMatch(/\bTRUNCATE\b/i);
    expect(patch).not.toMatch(/\bDELETE\s+FROM\b/i);
  });

  it('publishes all three authenticated chat endpoints', () => {
    const byId = new Map(
      apiContract.endpoints.map((endpoint) => [endpoint.id, endpoint]),
    );
    expect(byId.get('adoption.chat.read')).toMatchObject({
      implementation: 'implemented-day51',
      method: 'GET',
      path: '/adoption/chat/:threadId',
      auth: 'participant',
      successStatus: 200,
    });
    expect(byId.get('adoption.chat.messages.create')).toMatchObject({
      implementation: 'implemented-day51',
      method: 'POST',
      path: '/adoption/chat/:threadId/messages',
      auth: 'participant',
      successStatus: 201,
    });
    expect(byId.get('adoption.chat.read.update')).toMatchObject({
      implementation: 'implemented-day51',
      method: 'PUT',
      path: '/adoption/chat/:threadId/read',
      auth: 'participant',
      successStatus: 200,
    });
  });
});
