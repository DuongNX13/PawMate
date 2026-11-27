export function claimRequest(path: string, kind?: 'runtime' | 'cloud', cleanup?: boolean, now?: number): unknown;
export function assertBudgetActive(path: string, now?: number): unknown;
export function stopOrdinary(path: string, reason: string): void;
