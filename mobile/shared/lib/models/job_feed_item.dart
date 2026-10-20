import 'bid.dart';

/// Item Feed Pekerjaan untuk Mitra Tukang (FR-022 & BR-16 Privasi Sebelum Lock)
/// Menampilkan HANYA kelurahan/kecamatan (area_label), deskripsi, foto kerusakan,
/// jarak, dan kategori. DILARANG menampilkan nama, foto, atau alamat lengkap User!
class TukangJobFeedItem {
  final String jobId;
  final String categoryId;
  final String categoryName;
  final String? categoryIcon;
  final String description;
  final String areaLabel;
  final double distanceKm;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> damagePhotos;
  final bool hasBid;
  final BidStatus? bidStatus;

  const TukangJobFeedItem({
    required this.jobId,
    required this.categoryId,
    required this.categoryName,
    this.categoryIcon,
    required this.description,
    required this.areaLabel,
    required this.distanceKm,
    required this.createdAt,
    required this.expiresAt,
    this.damagePhotos = const [],
    this.hasBid = false,
    this.bidStatus,
  });

  factory TukangJobFeedItem.fromJson(Map<String, dynamic> json) {
    return TukangJobFeedItem(
      jobId: json['job_id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String? ?? 'Umum',
      categoryIcon: json['category_icon'] as String?,
      description: json['description'] as String? ?? '',
      areaLabel: json['area_label'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      damagePhotos: (json['damage_photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      hasBid: json['has_bid'] as bool? ?? false,
      bidStatus: json['bid_status'] != null
          ? BidStatus.fromString(json['bid_status'] as String)
          : null,
    );
  }
}

/// Item Penawaran Tukang yang dilihat oleh Pelanggan (FR-011, BR-16)
/// Menampilkan nama, foto profil, rating, hari aktif, jumlah job selesai, dan keahlian tukang.
class UserBidViewItem {
  final String bidId;
  final BidStatus bidStatus;
  final double? distanceKm;
  final DateTime createdAt;
  final String tukangId;
  final String tukangName;
  final String? tukangAvatar;
  final double ratingAvg;
  final int ratingCount;
  final int activeDays;
  final int completedJobsCount;
  final List<String> skills;

  const UserBidViewItem({
    required this.bidId,
    required this.bidStatus,
    this.distanceKm,
    required this.createdAt,
    required this.tukangId,
    required this.tukangName,
    this.tukangAvatar,
    required this.ratingAvg,
    required this.ratingCount,
    required this.activeDays,
    required this.completedJobsCount,
    this.skills = const [],
  });

  bool get isLocked => bidStatus == BidStatus.locked;
  bool get isActive => bidStatus == BidStatus.active;

  factory UserBidViewItem.fromJson(Map<String, dynamic> json) {
    return UserBidViewItem(
      bidId: json['bid_id'] as String,
      bidStatus:
          BidStatus.fromString(json['bid_status'] as String? ?? 'ACTIVE'),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      tukangId: json['tukang_id'] as String,
      tukangName: json['tukang_name'] as String? ?? 'Mitra Tukang',
      tukangAvatar: json['tukang_avatar'] as String?,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      activeDays: (json['active_days'] as num?)?.toInt() ?? 1,
      completedJobsCount: (json['completed_jobs_count'] as num?)?.toInt() ?? 0,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
