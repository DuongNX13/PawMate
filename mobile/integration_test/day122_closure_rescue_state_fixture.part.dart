part of 'day122_closure_rescue_state_qa_app.dart';

// QA fixture pinned against day119_detail_support.dart at build time.
const day119LongPetName = 'Mochi — bạn nhỏ đáng yêu của gia đình Nguyễn';

List<RescueCaseSummary> day119Cases({bool longContent = false}) {
  final values = [
    ...sampleCases(),
    rescueCase(
      caseId: '44444444-4444-4444-8444-444444444444',
      petName: 'Nắng',
      species: RescueSpecies.dog,
      status: RescueCaseStatus.missing,
      areaLabel: 'Q. 1',
      breedOrColor: 'Corgi',
    ),
    rescueCase(
      caseId: '55555555-5555-4555-8555-555555555555',
      petName: 'Mây',
      species: RescueSpecies.cat,
      status: RescueCaseStatus.missing,
      areaLabel: 'Q. 5',
      breedOrColor: 'Mèo Anh lông ngắn',
    ),
  ];
  const images = ['p2_01_lulu.png', 'p2_01_muc.png', 'p2_01_bong.png'];
  return [
    for (var i = 0; i < values.length; i++)
      RescueCaseSummary(
        caseId: values[i].caseId,
        petName: longContent && i == 0 ? day119LongPetName : values[i].petName,
        species: values[i].species,
        status: values[i].status,
        lostAt: values[i].lostAt,
        publicLocation: values[i].publicLocation,
        media: [
          RescuePublicMedia(
            mediaId: 'day119-$i',
            mimeType: 'image/png',
            publicUrl: Uri(
              scheme: 'asset',
              path: 'assets/images/rescue/${images[i % 3]}',
            ),
            createdAt: values[i].createdAt,
          ),
        ],
        commentCount: values[i].commentCount,
        createdAt: values[i].createdAt,
        updatedAt: values[i].updatedAt,
        breedOrColor: longContent && i == 0
            ? 'Poodle lai — lông nâu kem, đeo vòng cổ xanh'
            : values[i].breedOrColor,
        ageLabel: values[i].ageLabel,
        distanceMeters: values[i].distanceMeters,
      ),
  ];
}
