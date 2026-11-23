import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/application/vet_providers.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';

// Keep this direct QA surface equivalent to pumpDay118VetDetail.
// The build guard verifies both data blocks against the pinned golden fixture.
// No CTA is activated: the device runner loads and scrolls only.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    ProviderScope(
      overrides: [
        vetDetailProvider(_detail.id).overrideWith((ref) async => _detail),
        vetReviewListProvider(_detail.id).overrideWith((ref) async => _reviews),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: VetDetailScreen(vetId: _detail.id),
      ),
    ),
  );
}

const _detail = VetDetail(
  id: 'pethome-q7',
  name: 'PetHome Q7',
  city: 'TP Hồ Chí Minh',
  district: 'Phú Mỹ, Quận 7',
  address: '120 Nguyễn Lương Bằng',
  phone: '0903 111 222',
  summary: 'Cấp cứu 24/7 và chăm sóc định kỳ cho thú cưng.',
  services: ['Tiêm phòng', 'Cấp cứu 24/7', 'Khám tổng quát'],
  seedRank: 1,
  averageRating: 4.8,
  reviewCount: 120,
  is24h: false,
  isOpen: true,
  readyForMap: true,
  latitude: 10.778,
  longitude: 106.701,
  website: 'https://pawmate.test/vets/pawmate-q1',
  openHours: ['08:00 - 21:00'],
  photoUrls: [],
  source: VetSource(
    url: 'https://pawmate.test',
    list: 'PawMate seeded clinic',
    priorityTier: 'P0',
    enrichmentStatus: 'verified',
    selectionReason: 'golden-fixture',
  ),
);

final _reviews = VetReviewResult(
  items: const [
    VetReview(
      id: 'review-1',
      vetId: 'pawmate-q1',
      rating: 5,
      title: 'Theo dõi rất kỹ',
      body: 'Bác sĩ tư vấn rõ và chăm sóc sau tiêm rất tốt.',
      photoUrls: [],
      isAnonymous: false,
      isVerifiedVisit: true,
      helpfulCount: 12,
      reportCount: 0,
      status: 'visible',
      sentiment: 'POSITIVE',
      isFlagged: false,
      reviewer: VetReviewer(id: 'reviewer-1', displayName: 'Nguyễn An'),
      createdAt: '2026-07-10T10:00:00.000Z',
      updatedAt: '2026-07-10T10:00:00.000Z',
    ),
  ],
  summary: const VetReviewSummary(
    averageRating: 4.8,
    reviewCount: 120,
    distribution: {1: 1, 2: 2, 3: 5, 4: 22, 5: 90},
  ),
  total: 1,
  limit: const VetReviewListRequest().limit,
);
