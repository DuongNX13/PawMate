enum VetSortOption { curated, ratingDesc, nameAsc }

extension VetSortOptionApiValue on VetSortOption {
  String get apiValue {
    switch (this) {
      case VetSortOption.curated:
        return 'curated';
      case VetSortOption.ratingDesc:
        return 'rating-desc';
      case VetSortOption.nameAsc:
        return 'name-asc';
    }
  }

  String get label {
    switch (this) {
      case VetSortOption.curated:
        return 'Ưu tiên PawMate';
      case VetSortOption.ratingDesc:
        return 'Đánh giá cao';
      case VetSortOption.nameAsc:
        return 'Tên A-Z';
    }
  }
}

class VetSummary {
  const VetSummary({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.address,
    required this.phone,
    this.summary,
    required this.services,
    required this.seedRank,
    this.averageRating,
    required this.reviewCount,
    this.is24h,
    this.isOpen,
    required this.readyForMap,
    this.latitude,
    this.longitude,
    this.distanceMeters,
  });

  final String id;
  final String name;
  final String city;
  final String district;
  final String address;
  final String phone;
  final String? summary;
  final List<String> services;
  final int seedRank;
  final double? averageRating;
  final int reviewCount;
  final bool? is24h;
  final bool? isOpen;
  final bool readyForMap;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;

  factory VetSummary.fromJson(Map<String, dynamic> json) {
    return VetSummary(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      summary: json['summary']?.toString(),
      services: _readStringList(json['services']),
      seedRank: _readInt(json['seedRank']),
      averageRating: _readDoubleOrNull(json['averageRating']),
      reviewCount: _readInt(json['reviewCount']),
      is24h: _readBoolOrNull(json['is24h']),
      isOpen: _readBoolOrNull(json['isOpen']),
      readyForMap: json['readyForMap'] == true,
      latitude: _readDoubleOrNull(json['latitude']),
      longitude: _readDoubleOrNull(json['longitude']),
      distanceMeters: _readDoubleOrNull(json['distanceMeters']),
    );
  }

  String get displaySummary {
    final value = summary?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }

    return 'Phòng khám tại $district, $city. Đang tiếp tục cập nhật giờ mở cửa và dịch vụ.';
  }

  List<String> get displayServices {
    if (services.isNotEmpty) {
      return services;
    }

    return const ['Đang cập nhật dịch vụ'];
  }

  String get statusLabel {
    if (is24h == true) {
      return '24/7';
    }
    if (isOpen == true) {
      return 'Đang mở';
    }
    if (isOpen == false) {
      return 'Tạm đóng';
    }

    return 'Đang cập nhật';
  }

  String? get distanceLabel {
    if (distanceMeters == null) {
      return null;
    }

    if (distanceMeters! >= 1000) {
      return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
    }

    return '${distanceMeters!.round()} m';
  }
}

class VetSource {
  const VetSource({
    required this.url,
    required this.list,
    required this.priorityTier,
    required this.enrichmentStatus,
    required this.selectionReason,
  });

  final String url;
  final String list;
  final String priorityTier;
  final String enrichmentStatus;
  final String selectionReason;

  factory VetSource.fromJson(Map<String, dynamic> json) {
    return VetSource(
      url: json['url']?.toString() ?? '',
      list: json['list']?.toString() ?? '',
      priorityTier: json['priorityTier']?.toString() ?? '',
      enrichmentStatus: json['enrichmentStatus']?.toString() ?? '',
      selectionReason: json['selectionReason']?.toString() ?? '',
    );
  }
}

class VetDetail extends VetSummary {
  const VetDetail({
    required super.id,
    required super.name,
    required super.city,
    required super.district,
    required super.address,
    required super.phone,
    super.summary,
    required super.services,
    required super.seedRank,
    super.averageRating,
    required super.reviewCount,
    super.is24h,
    super.isOpen,
    required super.readyForMap,
    super.latitude,
    super.longitude,
    this.website,
    required this.openHours,
    required this.photoUrls,
    required this.source,
  });

  final String? website;
  final List<String> openHours;
  final List<String> photoUrls;
  final VetSource source;

  factory VetDetail.fromJson(Map<String, dynamic> json) {
    return VetDetail(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      summary: json['summary']?.toString(),
      services: _readStringList(json['services']),
      seedRank: _readInt(json['seedRank']),
      averageRating: _readDoubleOrNull(json['averageRating']),
      reviewCount: _readInt(json['reviewCount']),
      is24h: _readBoolOrNull(json['is24h']),
      isOpen: _readBoolOrNull(json['isOpen']),
      readyForMap: json['readyForMap'] == true,
      website: json['website']?.toString(),
      latitude: _readDoubleOrNull(json['latitude']),
      longitude: _readDoubleOrNull(json['longitude']),
      openHours: _readStringList(json['openHours']),
      photoUrls: _readStringList(json['photoUrls']),
      source: VetSource.fromJson(_readMap(json['source'])),
    );
  }

  String get locationQuery {
    if (latitude != null && longitude != null) {
      return '${latitude!},${longitude!}';
    }

    return '$address, $district, $city';
  }

  String get openingNote {
    if (openHours.isNotEmpty) {
      return openHours.first;
    }
    if (is24h == true) {
      return 'Mở cửa 24/7';
    }
    return 'Giờ mở cửa đang cập nhật';
  }
}

class VetSearchRequest {
  const VetSearchRequest({
    this.keyword = '',
    this.city,
    this.district,
    this.only24h = false,
    this.openNow = false,
    this.minRating,
    this.sort = VetSortOption.curated,
    this.limit = 20,
    this.cursor,
  });

  final String keyword;
  final String? city;
  final String? district;
  final bool only24h;
  final bool openNow;
  final double? minRating;
  final VetSortOption sort;
  final int limit;
  final String? cursor;

  @override
  bool operator ==(Object other) {
    return other is VetSearchRequest &&
        other.keyword == keyword &&
        other.city == city &&
        other.district == district &&
        other.only24h == only24h &&
        other.openNow == openNow &&
        other.minRating == minRating &&
        other.sort == sort &&
        other.limit == limit &&
        other.cursor == cursor;
  }

  @override
  int get hashCode => Object.hash(
    keyword,
    city,
    district,
    only24h,
    openNow,
    minRating,
    sort,
    limit,
    cursor,
  );
}

class VetSearchResult {
  const VetSearchResult({
    required this.items,
    this.nextCursor,
    required this.total,
    required this.limit,
  });

  final List<VetSummary> items;
  final String? nextCursor;
  final int total;
  final int limit;

  factory VetSearchResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = _readMap(json['pagination']);

    return VetSearchResult(
      items: data is List
          ? data.map((item) => VetSummary.fromJson(_readMap(item))).toList()
          : const [],
      nextCursor: pagination['nextCursor']?.toString(),
      total: _readInt(pagination['total']),
      limit: _readInt(pagination['limit']),
    );
  }
}

class VetNearbyRequest {
  const VetNearbyRequest({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 3000,
    this.limit = 20,
    this.cursor,
    this.only24h = false,
    this.openNow = false,
    this.minRating,
  });

  final double latitude;
  final double longitude;
  final int radiusMeters;
  final int limit;
  final String? cursor;
  final bool only24h;
  final bool openNow;
  final double? minRating;
}

class VetNearbyResult {
  const VetNearbyResult({
    required this.items,
    this.nextCursor,
    required this.total,
    required this.limit,
  });

  final List<VetSummary> items;
  final String? nextCursor;
  final int total;
  final int limit;

  factory VetNearbyResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = _readMap(json['pagination']);

    return VetNearbyResult(
      items: data is List
          ? data.map((item) => VetSummary.fromJson(_readMap(item))).toList()
          : const [],
      nextCursor: pagination['nextCursor']?.toString(),
      total: _readInt(pagination['total']),
      limit: _readInt(pagination['limit']),
    );
  }
}

enum VetReviewSort { newest, helpful, ratingDesc, ratingAsc }

extension VetReviewSortApiValue on VetReviewSort {
  String get apiValue {
    switch (this) {
      case VetReviewSort.newest:
        return 'newest';
      case VetReviewSort.helpful:
        return 'helpful';
      case VetReviewSort.ratingDesc:
        return 'rating-desc';
      case VetReviewSort.ratingAsc:
        return 'rating-asc';
    }
  }
}

class VetReviewListRequest {
  const VetReviewListRequest({
    this.limit = 20,
    this.cursor,
    this.sort = VetReviewSort.newest,
  });

  final int limit;
  final String? cursor;
  final VetReviewSort sort;
}

class VetReviewSummary {
  const VetReviewSummary({
    required this.averageRating,
    required this.reviewCount,
    required this.distribution,
  });

  final double? averageRating;
  final int reviewCount;
  final Map<int, int> distribution;

  factory VetReviewSummary.fromJson(Map<String, dynamic> json) {
    final distribution = _readMap(json['distribution']);

    return VetReviewSummary(
      averageRating: _readDoubleOrNull(json['averageRating']),
      reviewCount: _readInt(json['reviewCount']),
      distribution: {
        for (final rating in [1, 2, 3, 4, 5])
          rating: _readInt(distribution[rating.toString()]),
      },
    );
  }
}

class VetReviewer {
  const VetReviewer({required this.id, required this.displayName});

  final String id;
  final String displayName;

  factory VetReviewer.fromJson(Map<String, dynamic> json) {
    return VetReviewer(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Thanh vien PawMate',
    );
  }
}

class VetReview {
  const VetReview({
    required this.id,
    required this.vetId,
    required this.rating,
    this.title,
    this.body,
    required this.photoUrls,
    required this.isAnonymous,
    required this.isVerifiedVisit,
    required this.helpfulCount,
    required this.reportCount,
    required this.status,
    required this.sentiment,
    required this.isFlagged,
    required this.reviewer,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String vetId;
  final int rating;
  final String? title;
  final String? body;
  final List<String> photoUrls;
  final bool isAnonymous;
  final bool isVerifiedVisit;
  final int helpfulCount;
  final int reportCount;
  final String status;
  final String sentiment;
  final bool isFlagged;
  final VetReviewer reviewer;
  final String createdAt;
  final String updatedAt;

  factory VetReview.fromJson(Map<String, dynamic> json) {
    return VetReview(
      id: json['id']?.toString() ?? '',
      vetId: json['vetId']?.toString() ?? '',
      rating: _readInt(json['rating']),
      title: json['title']?.toString(),
      body: json['body']?.toString(),
      photoUrls: _readStringList(json['photoUrls']),
      isAnonymous: json['isAnonymous'] == true,
      isVerifiedVisit: json['isVerifiedVisit'] == true,
      helpfulCount: _readInt(json['helpfulCount']),
      reportCount: _readInt(json['reportCount']),
      status: json['status']?.toString() ?? 'visible',
      sentiment: json['sentiment']?.toString() ?? 'UNPROCESSED',
      isFlagged: json['isFlagged'] == true,
      reviewer: VetReviewer.fromJson(_readMap(json['reviewer'])),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  String get starLabel => '★' * rating;
}

class VetReviewResult {
  const VetReviewResult({
    required this.items,
    required this.summary,
    this.nextCursor,
    required this.total,
    required this.limit,
  });

  final List<VetReview> items;
  final VetReviewSummary summary;
  final String? nextCursor;
  final int total;
  final int limit;

  factory VetReviewResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = _readMap(json['pagination']);

    return VetReviewResult(
      items: data is List
          ? data.map((item) => VetReview.fromJson(_readMap(item))).toList()
          : const [],
      summary: VetReviewSummary.fromJson(_readMap(json['summary'])),
      nextCursor: pagination['nextCursor']?.toString(),
      total: _readInt(pagination['total']),
      limit: _readInt(pagination['limit']),
    );
  }
}

class CreateVetReviewInput {
  const CreateVetReviewInput({
    required this.rating,
    this.title,
    this.body,
    this.photoUrls = const [],
    this.isAnonymous = false,
  });

  final int rating;
  final String? title;
  final String? body;
  final List<String> photoUrls;
  final bool isAnonymous;

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
      if (body != null && body!.trim().isNotEmpty) 'body': body!.trim(),
      if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      'isAnonymous': isAnonymous,
    };
  }
}

class UploadReviewPhotoInput {
  const UploadReviewPhotoInput({
    required this.fileName,
    required this.contentType,
    required this.base64Data,
  });

  final String fileName;
  final String contentType;
  final String base64Data;

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'contentType': contentType,
      'base64Data': base64Data,
    };
  }
}

class UploadReviewPhotoResult {
  const UploadReviewPhotoResult({
    required this.url,
    required this.path,
    required this.contentType,
    required this.sizeBytes,
    required this.storage,
  });

  final String url;
  final String path;
  final String contentType;
  final int sizeBytes;
  final String storage;

  factory UploadReviewPhotoResult.fromJson(Map<String, dynamic> json) {
    return UploadReviewPhotoResult(
      url: json['url']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      sizeBytes: _readInt(json['sizeBytes']),
      storage: json['storage']?.toString() ?? 'local',
    );
  }
}

class VetReviewHelpfulResult {
  const VetReviewHelpfulResult({
    required this.reviewId,
    required this.helpfulCount,
    required this.hasVoted,
  });

  final String reviewId;
  final int helpfulCount;
  final bool hasVoted;

  factory VetReviewHelpfulResult.fromJson(Map<String, dynamic> json) {
    return VetReviewHelpfulResult(
      reviewId: json['reviewId']?.toString() ?? '',
      helpfulCount: _readInt(json['helpfulCount']),
      hasVoted: json['hasVoted'] == true,
    );
  }
}

class VetReviewReportResult {
  const VetReviewReportResult({
    required this.reportId,
    required this.reviewId,
    required this.reportCount,
    required this.reviewStatus,
  });

  final String reportId;
  final String reviewId;
  final int reportCount;
  final String reviewStatus;

  factory VetReviewReportResult.fromJson(Map<String, dynamic> json) {
    return VetReviewReportResult(
      reportId: json['reportId']?.toString() ?? '',
      reviewId: json['reviewId']?.toString() ?? '',
      reportCount: _readInt(json['reportCount']),
      reviewStatus: json['reviewStatus']?.toString() ?? 'visible',
    );
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return <String, dynamic>{};
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _readDoubleOrNull(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

bool? _readBoolOrNull(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value == null) {
    return null;
  }
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }
  return null;
}
