import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';

Map<String, dynamic> adoptionMediaJson({
  String mediaId = 'media-1',
  String? publicUrl = 'https://cdn.example.test/adoption/mochi.webp',
}) {
  return {
    'mediaId': mediaId,
    'ownerUserId': 'shelter-1',
    'purpose': 'adoption_listing',
    'mimeType': 'image/webp',
    'sizeBytes': 2048,
    'sha256': 'abc123',
    'status': 'attached',
    'createdAt': '2026-07-28T02:00:00.000Z',
    'publicUrl': ?publicUrl,
    'width': 1080,
    'height': 1350,
  };
}

Map<String, dynamic> adoptionSummaryJson({
  String listingId = 'listing-1',
  String petName = 'Mochi',
  String species = 'dog',
  String status = 'available',
  double? distanceKm,
}) {
  return {
    'listingId': listingId,
    'petName': petName,
    'species': species,
    'breed': 'Golden Retriever',
    'ageLabel': '2 tuổi',
    'status': status,
    'shelterId': 'shelter-1',
    'heroMedia': adoptionMediaJson(mediaId: 'media-$listingId'),
    'traits': ['Hiền lành', 'Thân thiện'],
    'healthBadges': ['Đã tiêm phòng'],
    'verificationBadges': ['Đã xác minh'],
    'createdAt': '2026-07-28T03:00:00.000Z',
    'distanceKm': ?distanceKm,
  };
}

Map<String, dynamic> adoptionDetailJson({
  String listingId = 'listing-1',
  String petName = 'Mochi',
  String species = 'dog',
  bool canRequest = true,
}) {
  return {
    ...adoptionSummaryJson(
      listingId: listingId,
      petName: petName,
      species: species,
    ),
    'description': 'Một người bạn nhỏ đang chờ mái ấm phù hợp.',
    'viewerPermissions': {
      'canLike': true,
      'canRequest': canRequest,
      'canManageListing': false,
    },
  };
}

Map<String, dynamic> adoptionPageJson({
  List<Map<String, dynamic>>? items,
  String? nextCursor,
  bool hasMore = false,
  int limit = 20,
}) {
  return {
    'data': items ?? [adoptionSummaryJson()],
    'pageInfo': {'nextCursor': nextCursor, 'hasMore': hasMore, 'limit': limit},
  };
}

AdoptionListingSummary adoptionSummary({
  String listingId = 'listing-1',
  String petName = 'Mochi',
}) {
  return AdoptionListingSummary.fromJson(
    adoptionSummaryJson(listingId: listingId, petName: petName),
  );
}

AdoptionListingDetail adoptionDetail({
  String listingId = 'listing-1',
  String petName = 'Mochi',
  AdoptionSpecies species = AdoptionSpecies.dog,
}) {
  return AdoptionListingDetail.fromJson(
    adoptionDetailJson(
      listingId: listingId,
      petName: petName,
      species: species.wireValue,
    ),
  );
}

AdoptionListingPage adoptionPage({
  List<AdoptionListingSummary>? items,
  String? nextCursor,
  bool hasMore = false,
}) {
  return AdoptionListingPage(
    items: items ?? [adoptionSummary()],
    pageInfo: AdoptionPageInfo(
      nextCursor: nextCursor,
      hasMore: hasMore,
      limit: 20,
    ),
  );
}

AdoptionDecisionResult adoptionDecisionResult({
  String listingId = 'listing-1',
  AdoptionDecision decision = AdoptionDecision.skip,
}) {
  return AdoptionDecisionResult(
    listingId: listingId,
    adopterUserId: 'adopter-1',
    decision: decision,
    createdAt: DateTime.utc(2026, 7, 28, 4),
  );
}
