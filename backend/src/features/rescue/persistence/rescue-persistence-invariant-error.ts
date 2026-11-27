export class RescuePersistenceInvariantError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'RescuePersistenceInvariantError';
  }
}
