export class RescuePersistenceConflictError extends Error {
  constructor(message = 'Rescue persistence version or ownership conflict.') {
    super(message);
    this.name = 'RescuePersistenceConflictError';
  }
}
