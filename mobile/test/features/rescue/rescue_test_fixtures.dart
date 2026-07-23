import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';

class FakeRescueSource implements RescueCaseSource {
  FakeRescueSource({List<RescueCasePage>? pages, this.delay = Duration.zero})
    : pages = [...?pages];

  final List<RescueCasePage> pages;
  final Duration delay;
  final List<RescueCaseQuery> queries = [];
  int callCount = 0;

  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) async {
    queries.add(query);
    callCount += 1;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (pages.isEmpty) return emptyPage();
    if (callCount <= pages.length) return pages[callCount - 1];
    return pages.last;
  }
}

RescueCasePage samplePage({
  List<RescueCaseSummary>? items,
  String? nextCursor,
  bool? hasMore,
}) {
  final values = items ?? sampleCases();
  return RescueCasePage(
    items: values,
    pageInfo: RescuePageInfo(
      hasMore: hasMore ?? nextCursor != null,
      limit: 5,
      nextCursor: nextCursor,
    ),
  );
}

RescueCasePage emptyPage() => samplePage(items: const [], hasMore: false);

List<RescueCaseSummary> sampleCases() => [
  rescueCase(
    caseId: '11111111-1111-4111-8111-111111111111',
    petName: 'LuLu',
    species: RescueSpecies.dog,
    status: RescueCaseStatus.missing,
    areaLabel: 'Q. Tân Bình',
    breedOrColor: 'Poodle',
    distanceMeters: 1200,
  ),
  rescueCase(
    caseId: '22222222-2222-4222-8222-222222222222',
    petName: 'Mực',
    species: RescueSpecies.cat,
    status: RescueCaseStatus.missing,
    areaLabel: 'Q. 3',
    breedOrColor: 'Mèo ta',
    distanceMeters: 2500,
  ),
  rescueCase(
    caseId: '33333333-3333-4333-8333-333333333333',
    petName: 'Bông',
    species: RescueSpecies.dog,
    status: RescueCaseStatus.found,
    areaLabel: 'Q. Phú Nhuận',
    breedOrColor: 'Samoyed',
    distanceMeters: 800,
  ),
];

List<RescueCaseSummary> sampleCasesWithoutImages() => sampleCases()
    .map(
      (item) => RescueCaseSummary(
        caseId: item.caseId,
        petName: item.petName,
        species: item.species,
        status: item.status,
        lostAt: item.lostAt,
        publicLocation: item.publicLocation,
        media: const [],
        commentCount: item.commentCount,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        breedOrColor: item.breedOrColor,
        ageLabel: item.ageLabel,
        distanceMeters: item.distanceMeters,
      ),
    )
    .toList(growable: false);

RescueCaseSummary rescueCase({
  required String caseId,
  required String petName,
  required RescueSpecies species,
  required RescueCaseStatus status,
  required String areaLabel,
  required String breedOrColor,
  int? distanceMeters,
}) {
  final date = DateTime.utc(2026, 7, 23, 8);
  return RescueCaseSummary(
    caseId: caseId,
    petName: petName,
    species: species,
    status: status,
    lostAt: date,
    publicLocation: RescuePublicLocation(
      areaLabel: areaLabel,
      approximateLatitude: 10.8,
      approximateLongitude: 106.7,
      privacyRadiusMeters: 500,
    ),
    media: [
      RescuePublicMedia(
        mediaId: '44444444-4444-4444-8444-444444444444',
        mimeType: 'image/jpeg',
        publicUrl: Uri.parse('https://cdn.example.test/$caseId.jpg'),
        createdAt: date,
      ),
    ],
    commentCount: 0,
    createdAt: date,
    updatedAt: date,
    breedOrColor: breedOrColor,
    ageLabel: '2 tuổi',
    distanceMeters: distanceMeters,
  );
}

RescueClock fixedRescueClock() =>
    () => DateTime.utc(2026, 7, 23, 10);
