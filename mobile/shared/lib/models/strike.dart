/// Tipe Pelanggaran / Strike Beres v1.4.0 (BR-57, BR-71, BR-67)
enum StrikeReason {
  noDepart30m(
    'NO_DEPART_30M',
    'Tukang tidak klik Berangkat dalam 30 menit setelah NOTA_APPROVED (BR-31)',
  ),
  tukangCancelApproved(
    'TUKANG_CANCEL_APPROVED',
    'Tukang membatalkan pekerjaan saat NOTA_APPROVED / ON_THE_WAY / ARRIVED (BR-55)',
  ),
  otw3hUnresponsive(
    'OTW_3H_UNRESPONSIVE',
    'Tukang ON_THE_WAY >= 3 jam dan di-cancel User tanpa respons 30 menit (BR-56b)',
  ),
  userUnresponsiveOtwArrived(
    'USER_UNRESPONSIVE_OTW_ARRIVED',
    'User tidak aktif / tidak membalas chat > 30 menit saat Tukang ON_THE_WAY atau ARRIVED (BR-71)',
  );

  final String value;
  final String description;

  const StrikeReason(this.value, this.description);

  static StrikeReason fromString(String value) {
    return StrikeReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StrikeReason.noDepart30m,
    );
  }
}

/// Model Strike / Pelanggaran Beres v1.4.0
class Strike {
  final String id;
  final String profileId;
  final String? jobId;
  final StrikeReason reason;
  final String? notes;
  final DateTime createdAt;

  const Strike({
    required this.id,
    required this.profileId,
    this.jobId,
    required this.reason,
    this.notes,
    required this.createdAt,
  });

  /// Aturan batas toleransi: 3x per bulan kalender lokal (BR-57, BR-71)
  static const int maxStrikesBeforeSuspend = 3;
  static const int autoSuspendDurationHours = 48;

  factory Strike.fromJson(Map<String, dynamic> json) {
    return Strike(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      jobId: json['job_id'] as String?,
      reason: StrikeReason.fromString(json['type'] as String? ?? json['reason'] as String? ?? 'NO_DEPART_30M'),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'job_id': jobId,
      'type': reason.value,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
