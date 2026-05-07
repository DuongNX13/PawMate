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

export type ErrorCode =
  | (typeof AUTH_ERROR_CODES)[keyof typeof AUTH_ERROR_CODES]
  | (typeof PET_ERROR_CODES)[keyof typeof PET_ERROR_CODES]
  | (typeof VET_ERROR_CODES)[keyof typeof VET_ERROR_CODES]
  | (typeof REVIEW_ERROR_CODES)[keyof typeof REVIEW_ERROR_CODES]
  | (typeof HEALTH_ERROR_CODES)[keyof typeof HEALTH_ERROR_CODES]
  | (typeof REMINDER_ERROR_CODES)[keyof typeof REMINDER_ERROR_CODES]
  | (typeof NOTIFICATION_ERROR_CODES)[keyof typeof NOTIFICATION_ERROR_CODES];
