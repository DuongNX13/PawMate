import { type ErrorCode } from './error-codes';

export class AppError extends Error {
  readonly code: ErrorCode;

  readonly statusCode: number;

  readonly field?: string;

  readonly retryAfterSeconds?: number;

  constructor(
    code: ErrorCode,
    message: string,
    statusCode: number,
    field?: string,
    retryAfterSeconds?: number,
  ) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    this.field = field;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}
