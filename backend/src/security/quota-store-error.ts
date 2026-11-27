export class QuotaStoreUnavailableError extends Error {
  constructor(
    message = 'Distributed quota store unavailable.',
    options?: { cause?: unknown },
  ) {
    super(message, options);
    this.name = 'QuotaStoreUnavailableError';
  }
}
