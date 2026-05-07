import { type ErrorCode } from './error-codes';

export class AppError extends Error {
  readonly code: ErrorCode;

  readonly statusCode: number;

  readonly field?: string;

  constructor(
    code: ErrorCode,
    message: string,
    statusCode: number,
    field?: string,
  ) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    this.field = field;
  }
}
