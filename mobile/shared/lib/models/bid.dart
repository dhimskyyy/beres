/// Status Lamaran / Bid Tukang (BR-15, BR-17)
enum BidStatus {
  active('ACTIVE', 'Aktif'),
  locked('LOCKED', 'Terkunci (Dipilih User)'),
  withdrawn('WITHDRAWN', 'Ditarik Otomatis (Auto-Clear)');

  final String value;
  final String label;

  const BidStatus(this.value, this.label);

  static BidStatus fromString(String value) {
    return BidStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BidStatus.active,
    );
  }
}

/// Model Lamaran Tukang Beres v1.4.0
class Bid {
  final String id;
  final String jobId;
  final String tukangId;
  final double? distanceKm;
  final BidStatus status;
  final String? withdrawnReason;
  final DateTime createdAt;

  const Bid({
    required this.id,
    required this.jobId,
    required this.tukangId,
    this.distanceKm,
    required this.status,
    this.withdrawnReason,
    required this.createdAt,
  });

  bool get isLocked => status == BidStatus.locked;
  bool get isActive => status == BidStatus.active;
  bool get isWithdrawn => status == BidStatus.withdrawn;

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      tukangId: json['tukang_id'] as String,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      status: BidStatus.fromString(json['status'] as String? ?? 'ACTIVE'),
      withdrawnReason: json['withdrawn_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'tukang_id': tukangId,
      'distance_km': distanceKm,
      'status': status.value,
      'withdrawn_reason': withdrawnReason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
