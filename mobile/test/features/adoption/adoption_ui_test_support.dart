import 'dart:ui';

import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_location_service.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_saved_listing_store.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_share_service.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';

import 'adoption_test_fixtures.dart';

const adoptionListingId = '11111111-1111-4111-8111-111111111111';
const adoptionSecondListingId = '22222222-2222-4222-8222-222222222222';

AdoptionListingSummary uiAdoptionSummary({
  String listingId = adoptionListingId,
  String petName = 'Mochi',
  AdoptionSpecies species = AdoptionSpecies.dog,
  AdoptionListingStatus status = AdoptionListingStatus.available,
  double? distanceKm = 2.4,
  List<String> traits = const ['Hiền lành', 'Thân thiện'],
}) {
  final json = adoptionSummaryJson(
    listingId: listingId,
    petName: petName,
    species: species.wireValue,
    status: status.wireValue,
    distanceKm: distanceKm,
  );
  json
    ..['heroMedia'] = adoptionMediaJson(
      mediaId: 'media-$listingId',
      publicUrl: null,
    )
    ..['traits'] = traits;
  return AdoptionListingSummary.fromJson(json);
}

AdoptionListingDetail uiAdoptionDetail({
  String listingId = adoptionListingId,
  String petName = 'Mochi',
  AdoptionSpecies species = AdoptionSpecies.dog,
  AdoptionListingStatus status = AdoptionListingStatus.available,
  bool canLike = true,
  bool canRequest = true,
  bool canManageListing = false,
  double? distanceKm = 2.4,
  String description =
      'Mochi thân thiện, thích đi dạo và đang chờ một mái ấm phù hợp.',
  List<String> traits = const ['Hiền lành', 'Thân thiện', 'Quấn người'],
  List<String> healthBadges = const ['Đã tiêm phòng', 'Đã tẩy giun'],
  List<String> verificationBadges = const [
    'Hồ sơ đã xác minh',
    'Thông tin sức khỏe rõ ràng',
  ],
  Uri? heroMediaPublicUrl,
}) {
  final json = adoptionDetailJson(
    listingId: listingId,
    petName: petName,
    species: species.wireValue,
    canRequest: canRequest,
  );
  json
    ..['status'] = status.wireValue
    ..['distanceKm'] = distanceKm
    ..['description'] = description
    ..['heroMedia'] = adoptionMediaJson(
      mediaId: 'media-$listingId',
      publicUrl: heroMediaPublicUrl?.toString(),
    )
    ..['traits'] = traits
    ..['healthBadges'] = healthBadges
    ..['verificationBadges'] = verificationBadges
    ..['viewerPermissions'] = {
      'canLike': canLike,
      'canRequest': canRequest,
      'canManageListing': canManageListing,
    };
  return AdoptionListingDetail.fromJson(json);
}

AdoptionListingPage uiAdoptionPage({
  List<AdoptionListingSummary>? items,
  bool hasMore = false,
  String? nextCursor,
}) {
  return AdoptionListingPage(
    items: items ?? [uiAdoptionSummary()],
    pageInfo: AdoptionPageInfo(
      nextCursor: nextCursor,
      hasMore: hasMore,
      limit: 20,
    ),
  );
}

class AdoptionDecisionCall {
  const AdoptionDecisionCall({
    required this.listingId,
    required this.decision,
    required this.accessToken,
    required this.idempotencyKey,
  });

  final String listingId;
  final AdoptionDecision decision;
  final String accessToken;
  final String idempotencyKey;
}

class FakeAdoptionUiSource implements AdoptionSource {
  FakeAdoptionUiSource({
    AdoptionListingPage? page,
    AdoptionListingDetail? detail,
    this.listError,
    this.detailError,
  }) : page = page ?? uiAdoptionPage(),
       detail = detail ?? uiAdoptionDetail();

  AdoptionListingPage page;
  AdoptionListingDetail detail;
  Object? listError;
  Object? detailError;
  final List<AdoptionListQuery> listQueries = [];
  final List<String> detailCalls = [];
  final List<AdoptionDecisionCall> decisionCalls = [];

  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) async {
    listQueries.add(query);
    if (listError != null) throw listError!;
    return page;
  }

  @override
  Future<AdoptionListingDetail> getListing(
    String listingId, {
    required String accessToken,
  }) async {
    detailCalls.add(listingId);
    if (detailError != null) throw detailError!;
    return detail;
  }

  @override
  Future<AdoptionDecisionResult> recordDecision(
    String listingId,
    AdoptionDecision decision, {
    required String accessToken,
    required String idempotencyKey,
  }) async {
    decisionCalls.add(
      AdoptionDecisionCall(
        listingId: listingId,
        decision: decision,
        accessToken: accessToken,
        idempotencyKey: idempotencyKey,
      ),
    );
    return adoptionDecisionResult(listingId: listingId, decision: decision);
  }
}

class FakeAdoptionLocationSource implements AdoptionLocationSource {
  FakeAdoptionLocationSource({
    this.coordinates = const AdoptionCoordinates(
      latitude: 10.7769,
      longitude: 106.7009,
    ),
    this.error,
  });

  final AdoptionCoordinates coordinates;
  final Object? error;
  int calls = 0;

  @override
  Future<AdoptionCoordinates> resolveCurrentLocation() async {
    calls += 1;
    if (error != null) throw error!;
    return coordinates;
  }
}

class MemoryAdoptionSavedListingStore implements AdoptionSavedListingStore {
  MemoryAdoptionSavedListingStore([Set<String> initial = const <String>{}])
    : values = Set<String>.from(initial);

  Set<String> values;
  int writes = 0;
  bool failWrites = false;

  @override
  Future<Set<String>> readAll() async => Set<String>.unmodifiable(values);

  @override
  Future<void> writeAll(Set<String> listingIds) async {
    writes += 1;
    if (failWrites) {
      throw StateError('Synthetic local-save failure.');
    }
    values = Set<String>.from(listingIds);
  }
}

class FakeAdoptionShareSource implements AdoptionShareSource {
  final List<AdoptionListingDetail> sharedDetails = [];
  final List<Rect> sharePositionOrigins = [];
  Object? error;

  @override
  Future<void> shareProfile(
    AdoptionListingDetail detail, {
    required Rect sharePositionOrigin,
  }) async {
    if (error != null) throw error!;
    sharedDetails.add(detail);
    sharePositionOrigins.add(sharePositionOrigin);
  }
}
