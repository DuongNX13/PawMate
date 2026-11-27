export const AUTH_ERROR_CODES = {
  invalidEmail: 'AUTH_001',
  weakPassword: 'AUTH_002',
  invalidCredentials: 'AUTH_003',
  duplicateEmail: 'AUTH_004',
  accountLocked: 'AUTH_005',
  emailUnverified: 'AUTH_006',
  invalidRefreshToken: 'AUTH_007',
  expiredRefreshToken: 'AUTH_008',
  refreshTokenReuse: 'AUTH_009',
  oauthConflict: 'AUTH_010',
  oauthVerificationFailed: 'AUTH_011',
  unsupportedProvider: 'AUTH_012',
  unauthorized: 'AUTH_013',
  verificationUnavailable: 'AUTH_014',
  invalidVerificationToken: 'AUTH_015',
  providerDisabled: 'AUTH_016',
  expiredVerificationToken: 'AUTH_017',
  invalidPhone: 'AUTH_018',
} as const;

export const PET_ERROR_CODES = {
  unauthorized: 'PET_001',
  invalidSpecies: 'PET_002',
  invalidGender: 'PET_003',
  invalidWeight: 'PET_004',
  notFound: 'PET_005',
  forbidden: 'PET_006',
  duplicateMicrochip: 'PET_007',
  invalidDate: 'PET_008',
  invalidPhotoReference: 'PET_009',
  invalidHealthStatus: 'PET_010',
  invalidName: 'PET_011',
  invalidBreed: 'PET_012',
  invalidColor: 'PET_013',
  invalidMicrochip: 'PET_014',
  photoStorageFailure: 'PET_015',
} as const;

export const VET_ERROR_CODES = {
  invalidQuery: 'VET_001',
  notFound: 'VET_002',
} as const;

export const REVIEW_ERROR_CODES = {
  duplicateReview: 'REVIEW_001',
  invalidRating: 'REVIEW_002',
  invalidInput: 'REVIEW_003',
  notFound: 'REVIEW_004',
  unauthorized: 'REVIEW_005',
  invalidReportReason: 'REVIEW_006',
  duplicateReport: 'REVIEW_007',
  vetNotFound: 'REVIEW_008',
  photoUploadFailed: 'REVIEW_009',
} as const;

export const HEALTH_ERROR_CODES = {
  unauthorized: 'HEALTH_001',
  invalidInput: 'HEALTH_002',
  petNotFound: 'HEALTH_003',
  notFound: 'HEALTH_004',
} as const;

export const REMINDER_ERROR_CODES = {
  unauthorized: 'REMINDER_001',
  invalidInput: 'REMINDER_002',
  petNotFound: 'REMINDER_003',
  notFound: 'REMINDER_004',
} as const;

export const NOTIFICATION_ERROR_CODES = {
  unauthorized: 'NOTIFICATION_001',
  invalidInput: 'NOTIFICATION_002',
  notFound: 'NOTIFICATION_003',
} as const;

export const PREFERENCE_ERROR_CODES = {
  invalidInput: 'PREFERENCE_002',
  notFound: 'PREFERENCE_003',
  versionConflict: 'PREFERENCE_004',
} as const;

export const RESCUE_ERROR_CODES = {
  forbidden: 'RESCUE_002',
  notFound: 'RESCUE_003',
  invalidInput: 'RESCUE_004',
  invalidStatusTransition: 'RESCUE_005',
  commentsClosed: 'RESCUE_010',
  versionConflict: 'RESCUE_011',
  featureUnavailable: 'RESCUE_012',
} as const;

export const ADOPTION_ERROR_CODES = {
  forbidden: 'ADOPTION_002',
  notFound: 'ADOPTION_003',
  invalidInput: 'ADOPTION_004',
  selfListing: 'ADOPTION_005',
  duplicateActiveRequest: 'ADOPTION_006',
  chatNotFound: 'ADOPTION_007',
  chatClosed: 'ADOPTION_008',
} as const;

export const IDEMPOTENCY_ERROR_CODES = {
  payloadConflict: 'IDEMPOTENCY_001',
} as const;

export const MEDIA_ERROR_CODES = {
  unsupportedMimeType: 'MEDIA_001',
  sizeExceeded: 'MEDIA_002',
  invalidRequest: 'MEDIA_003',
  objectMissingOrExpired: 'MEDIA_004',
  integrityMismatch: 'MEDIA_005',
} as const;

export const SECURITY_ERROR_CODES = {
  rateLimited: 'SEC_001',
  quotaUnavailable: 'SEC_002',
  quotaContextInvalid: 'SEC_003',
} as const;

export type ErrorCode =
  | (typeof AUTH_ERROR_CODES)[keyof typeof AUTH_ERROR_CODES]
  | (typeof PET_ERROR_CODES)[keyof typeof PET_ERROR_CODES]
  | (typeof VET_ERROR_CODES)[keyof typeof VET_ERROR_CODES]
  | (typeof REVIEW_ERROR_CODES)[keyof typeof REVIEW_ERROR_CODES]
  | (typeof HEALTH_ERROR_CODES)[keyof typeof HEALTH_ERROR_CODES]
  | (typeof REMINDER_ERROR_CODES)[keyof typeof REMINDER_ERROR_CODES]
  | (typeof NOTIFICATION_ERROR_CODES)[keyof typeof NOTIFICATION_ERROR_CODES]
  | (typeof PREFERENCE_ERROR_CODES)[keyof typeof PREFERENCE_ERROR_CODES]
  | (typeof RESCUE_ERROR_CODES)[keyof typeof RESCUE_ERROR_CODES]
  | (typeof ADOPTION_ERROR_CODES)[keyof typeof ADOPTION_ERROR_CODES]
  | (typeof IDEMPOTENCY_ERROR_CODES)[keyof typeof IDEMPOTENCY_ERROR_CODES]
  | (typeof MEDIA_ERROR_CODES)[keyof typeof MEDIA_ERROR_CODES]
  | (typeof SECURITY_ERROR_CODES)[keyof typeof SECURITY_ERROR_CODES];
