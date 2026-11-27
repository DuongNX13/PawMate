import {
  type RescueCaseReadItem,
  type RescueCaseRecord,
  type RescueMediaAssetRecord,
} from '../../features/rescue/persistence/rescue-repository';

export type PublicRescueSpecies = 'dog' | 'cat' | 'other';

export type RescueViewerPermissions = {
  canComment: boolean;
  canUpdateStatus: boolean;
  canViewPrivateContact: boolean;
};

export type PublicRescueMediaAsset = {
  mediaId: string;
  mimeType: RescueMediaAssetRecord['mimeType'];
  publicUrl: string;
  createdAt: string;
  width?: number;
  height?: number;
  durationSeconds?: number;
};

export type PublicRescueLocation = {
  areaLabel: string;
  approximateLatitude: number;
  approximateLongitude: number;
  privacyRadiusMeters: number;
};

export type RescueCaseSummary = {
  caseId: string;
  petName: string;
  species: PublicRescueSpecies;
  status: RescueCaseRecord['status'];
  lostAt: string;
  publicLocation: PublicRescueLocation;
  media: PublicRescueMediaAsset[];
  commentCount: number;
  createdAt: string;
  updatedAt: string;
  breedOrColor?: string;
  ageLabel?: string;
  distanceMeters?: number;
  viewerPermissions?: RescueViewerPermissions;
};

export type RescueCaseDetail = RescueCaseSummary & {
  version: number;
  identifyingFeatures: string;
  behaviorHint?: string;
  viewerPermissions: RescueViewerPermissions;
};

const toPublicSpecies = (
  species: RescueCaseRecord['species'],
): PublicRescueSpecies =>
  species === 'dog' || species === 'cat' ? species : 'other';

const toPublicMedia = (
  media: RescueMediaAssetRecord[],
): PublicRescueMediaAsset[] =>
  media.flatMap((item) => {
    if (item.status !== 'attached' || !item.publicUrl) return [];
    return [
      {
        mediaId: item.mediaId,
        mimeType: item.mimeType,
        publicUrl: item.publicUrl,
        createdAt: item.createdAt,
        ...(item.width === undefined ? {} : { width: item.width }),
        ...(item.height === undefined ? {} : { height: item.height }),
        ...(item.durationSeconds === undefined
          ? {}
          : { durationSeconds: item.durationSeconds }),
      },
    ];
  });

const buildPermissions = (
  rescueCase: RescueCaseRecord,
  viewerUserId?: string,
): RescueViewerPermissions => {
  const isOwner = viewerUserId === rescueCase.ownerUserId;
  const isOpen = rescueCase.status === 'missing';
  return {
    canComment: Boolean(viewerUserId) && isOpen,
    canUpdateStatus: isOwner && isOpen,
    // Private contact data is intentionally outside the two public Day 35 APIs.
    canViewPrivateContact: false,
  };
};

const buildCommonFields = (rescueCase: RescueCaseRecord) => ({
  caseId: rescueCase.caseId,
  petName: rescueCase.petName,
  species: toPublicSpecies(rescueCase.species),
  status: rescueCase.status,
  lostAt: rescueCase.lostAt,
  publicLocation: {
    areaLabel: rescueCase.areaLabel,
    approximateLatitude: rescueCase.approximateLatitude,
    approximateLongitude: rescueCase.approximateLongitude,
    privacyRadiusMeters: rescueCase.privacyRadiusMeters,
  },
  media: toPublicMedia(rescueCase.media),
  commentCount: rescueCase.commentCount,
  createdAt: rescueCase.createdAt,
  updatedAt: rescueCase.updatedAt,
  ...(rescueCase.breedOrColor ? { breedOrColor: rescueCase.breedOrColor } : {}),
  ...(rescueCase.ageLabel ? { ageLabel: rescueCase.ageLabel } : {}),
});

export const toRescueCaseSummary = (
  item: RescueCaseReadItem,
  viewerUserId?: string,
): RescueCaseSummary => ({
  ...buildCommonFields(item.rescueCase),
  ...(item.distanceMeters === undefined
    ? {}
    : { distanceMeters: item.distanceMeters }),
  ...(viewerUserId
    ? { viewerPermissions: buildPermissions(item.rescueCase, viewerUserId) }
    : {}),
});

export const toRescueCaseDetail = (
  rescueCase: RescueCaseRecord,
  viewerUserId?: string,
): RescueCaseDetail => ({
  ...buildCommonFields(rescueCase),
  version: rescueCase.version,
  identifyingFeatures: rescueCase.identifyingFeatures,
  ...(rescueCase.behaviorHint ? { behaviorHint: rescueCase.behaviorHint } : {}),
  viewerPermissions: buildPermissions(rescueCase, viewerUserId),
});
