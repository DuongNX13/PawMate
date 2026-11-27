import { RescuePersistenceConflictError } from './rescue-persistence-conflict-error';

export type RescuePersistenceDomainFailure =
  | 'forbidden'
  | 'not_found'
  | 'version_conflict'
  | 'invalid_transition'
  | 'comments_closed'
  | 'idempotency_conflict'
  | 'invalid_media'
  | 'media_expired';

export class RescuePersistenceDomainError extends RescuePersistenceConflictError {
  constructor(
    readonly failure: RescuePersistenceDomainFailure,
    message: string,
  ) {
    super(message);
    this.name = 'RescuePersistenceDomainError';
  }
}
