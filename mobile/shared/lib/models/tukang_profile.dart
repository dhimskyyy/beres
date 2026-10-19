/// Status KYC Tukang (BR-10)
enum KycStatus {
  pending('PENDING', 'Menunggu Verifikasi Admin'),
  approved('APPROVED', 'Terverifikasi'),
  rejected('REJECTED', 'Ditolak');

  final String value;
  final String label;

  const KycStatus(this.value, this.label);

  static KycStatus fromString(String value) {
    return KycStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => KycStatus.pending,
    );
  }
}

/// Model Profil Mitra Tukang Beres v1.4.0 (BR-10, BR-20, BR-26, BR-27)
class TukangProfile {
  final String userId;
  final String? bio;
  final KycStatus kycStatus;
  final DateTime? kycApprovedAt;
  final bool isOnline;
  final int radiusKm; // 0–50 km (BR-20)
  final List<Map<String, dynamic>> paymentAccounts; // BR-06
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;
  final double ratingAvg;
  final int ratingCount;
  final String tier;
  final DateTime? goldUntil;

  const TukangProfile({
    required this.userId,
    this.bio,
    this.kycStatus = KycStatus.pending,
    this.kycApprovedAt,
    this.isOnline = false,
    this.radiusKm = 20,
    this.paymentAccounts = const [],
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.tier = 'STANDARD',
    this.goldUntil,
  });

  bool get isKycApproved => kycStatus == KycStatus.approved;

  /// Tukang dianggap offline jika update lokasi > 60 menit lalu (BR-27)
  bool get isEffectiveOnline {
    if (!isOnline) return false;
    if (locationUpdatedAt == null) return false;
    final diff = DateTime.now().difference(locationUpdatedAt!);
    return diff.inMinutes <= 60;
  }

  /// Menghitung berapa hari aktif sejak KYC disetujui (FR-011)
  int get activeDays {
    if (kycApprovedAt == null) return 0;
    return DateTime.now().difference(kycApprovedAt!).inDays;
  }

  factory TukangProfile.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;
    if (json['latitude'] != null && json['longitude'] != null) {
      lat = (json['latitude'] as num).toDouble();
      lng = (json['longitude'] as num).toDouble();
    } else if (json['last_known_location'] != null &&
        json['last_known_location'] is Map) {
      final loc = json['last_known_location'] as Map<String, dynamic>;
      if (loc['coordinates'] is List &&
          (loc['coordinates'] as List).length >= 2) {
        lng = ((loc['coordinates'] as List)[0] as num).toDouble();
        lat = ((loc['coordinates'] as List)[1] as num).toDouble();
      }
    }

    final rawAccounts = json['payment_accounts'];
    List<Map<String, dynamic>> accountsList = [];
    if (rawAccounts is List) {
      accountsList =
          rawAccounts.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return TukangProfile(
      userId: json['user_id'] as String,
      bio: json['bio'] as String?,
      kycStatus:
          KycStatus.fromString(json['kyc_status'] as String? ?? 'PENDING'),
      kycApprovedAt: json['kyc_approved_at'] != null
          ? DateTime.parse(json['kyc_approved_at'] as String)
          : null,
      isOnline: json['is_online'] as bool? ?? false,
      radiusKm: (json['radius_km'] as num?)?.toInt() ?? 20,
      paymentAccounts: accountsList,
      latitude: lat,
      longitude: lng,
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.parse(json['location_updated_at'] as String)
          : null,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      tier: json['tier'] as String? ?? 'STANDARD',
      goldUntil: json['gold_until'] != null
          ? DateTime.parse(json['gold_until'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'bio': bio,
      'kyc_status': kycStatus.value,
      'kyc_approved_at': kycApprovedAt?.toIso8601String(),
      'is_online': isOnline,
      'radius_km': radiusKm,
      'payment_accounts': paymentAccounts,
      'latitude': latitude,
      'longitude': longitude,
      'location_updated_at': locationUpdatedAt?.toIso8601String(),
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
      'tier': tier,
      'gold_until': goldUntil?.toIso8601String(),
    };
  }
}
