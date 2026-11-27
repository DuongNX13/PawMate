import {
  type AdoptionListingRecord,
  type AdoptionMediaRecord,
} from '../../features/adoption/persistence/adoption-repository';

const toPublicSpecies = (species: AdoptionListingRecord['species']) =>
  species === 'dog' || species === 'cat' ? species : 'other';

const toMedia = (media: AdoptionMediaRecord) => ({
  mediaId: media.mediaId,
  ownerUserId: media.ownerUserId,
  purpose: media.purpose,
  mimeType: media.mimeType,
  sizeBytes: media.sizeBytes,
  sha256: media.sha256,
  status: media.status,
  createdAt: media.createdAt,
  ...(media.publicUrl ? { publicUrl: media.publicUrl } : {}),
  ...(media.width !== undefined ? { width: media.width } : {}),
  ...(media.height !== undefined ? { height: media.height } : {}),
  ...(media.durationSeconds !== undefined
    ? { durationSeconds: media.durationSeconds }
    : {}),
});

const sharedListingFields = (listing: AdoptionListingRecord) => ({
  listingId: listing.listingId,
  petName: listing.petName,
  species: toPublicSpecies(listing.species),
  ageLabel: listing.ageLabel,
  status: listing.status,
  shelterId: listing.shelterId,
  heroMedia: toMedia(listing.heroMedia),
  traits: listing.traits,
  createdAt: listing.createdAt,
  ...(listing.breed ? { breed: listing.breed } : {}),
  ...(listing.distanceMeters !== undefined
    ? { distanceKm: Number((listing.distanceMeters / 1_000).toFixed(1)) }
    : {}),
});

export const toAdoptionListingSummary = (listing: AdoptionListingRecord) => ({
  ...sharedListingFields(listing),
  ...(listing.healthBadges.length
    ? { healthBadges: listing.healthBadges }
    : {}),
  ...(listing.verificationBadges.length
    ? { verificationBadges: listing.verificationBadges }
    : {}),
});

export const toAdoptionListingDetail = (
  listing: AdoptionListingRecord,
  viewerUserId: string,
) => {
  const isOwner = listing.shelterId === viewerUserId;
  const isAvailable = listing.status === 'available';
  return {
    ...sharedListingFields(listing),
    healthBadges: listing.healthBadges,
    verificationBadges: listing.verificationBadges,
    viewerPermissions: {
      canLike: isAvailable && !isOwner,
      canRequest: isAvailable && !isOwner,
      canManageListing: isOwner,
    },
    ...(listing.description ? { description: listing.description } : {}),
  };
};
