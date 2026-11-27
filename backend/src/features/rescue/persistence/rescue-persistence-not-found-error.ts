export class RescuePersistenceNotFoundError extends Error {
  constructor(message = 'Rescue persistence resource was not found.') {
    super(message);
    this.name = 'RescuePersistenceNotFoundError';
  }
}
