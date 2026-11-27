export interface FinalProviderGuard {
  authIds: Set<string>;
  attemptedEmails: Set<string>;
  objects: Map<string, string>;
  ticketKeys: Map<string, string>;
  setCleanup(): void;
  ownAuth(id: string): void;
  ownToken(token: string): void;
  ticket(bucket: string, key: string): void;
  object(bucket: string, key: string): void;
  check(url: URL, method: string, body: unknown, headers?: Headers): string;
}
export function createFinalProviderGuard(options: { emails: string[]; buckets: string[] }): FinalProviderGuard;
