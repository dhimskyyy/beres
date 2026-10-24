import 'user_role.dart';

/// Jenis Suspend Pengguna (BR-42, BR-58)
enum SuspendType {
  none('NONE', 'Aktif'),
  auto2Days('AUTO_2_DAYS', 'Suspend Otomatis 2 Hari (48 Jam)'),
  manualPermanent('MANUAL_PERMANENT', 'Suspend Permanen Admin');

  final String value;
  final String label;

  const SuspendType(this.value, this.label);

  static SuspendType fromString(String value) {
    return SuspendType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SuspendType.none,
    );
  }
}

/// Model Profil Dasar Pengguna Beres v1.4.0 (BR-44: 1 Email = 1 Peran)
class Profile {
  final String id;
  final String email;
  final UserRole role;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String? birthPlace;
  final DateTime? birthDate;
  final String timezone;
  final bool isEmailVerified;
  final DateTime? emailVerifiedAt;
  final SuspendType suspendType;
  final DateTime? suspendedUntil;
  final String? suspendReason;
  final String appealEmailInfo;
  final DateTime? deletedAt;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.birthPlace,
    this.birthDate,
    this.timezone = 'Asia/Jakarta',
    this.isEmailVerified = false,
    this.emailVerifiedAt,
    this.suspendType = SuspendType.none,
    this.suspendedUntil,
    this.suspendReason,
    this.appealEmailInfo = 'support@beres.id',
    this.deletedAt,
    required this.createdAt,
  });

  String? get birthPlaceAndDateFormatted {
    if (birthPlace != null && birthDate != null) {
      final d = birthDate!;
      final months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ];
      return '$birthPlace, ${d.day} ${months[d.month - 1]} ${d.year}';
    } else if (birthPlace != null) {
      return birthPlace;
    } else if (birthDate != null) {
      final d = birthDate!;
      final months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    }
    return null;
  }

  bool get isSuspended {
    if (suspendType == SuspendType.manualPermanent) return true;
    if (suspendType == SuspendType.auto2Days) {
      if (suspendedUntil != null && suspendedUntil!.isAfter(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  bool get isUser => role == UserRole.user;
  bool get isTukang => role == UserRole.tukang;
  bool get isAdmin => role == UserRole.admin;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'USER'),
      fullName: (json['full_name'] as String?) ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      birthPlace: json['birth_place'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
      timezone: (json['timezone'] as String?) ?? 'Asia/Jakarta',
      isEmailVerified: (json['is_email_verified'] as bool?) ?? false,
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.tryParse(json['email_verified_at'].toString())
          : null,
      suspendType:
          SuspendType.fromString(json['suspend_type'] as String? ?? 'NONE'),
      suspendedUntil: json['suspended_until'] != null
          ? DateTime.tryParse(json['suspended_until'].toString())
          : null,
      suspendReason: json['suspend_reason'] as String?,
      appealEmailInfo:
          (json['appeal_email_info'] as String?) ?? 'support@beres.id',
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Profile copyWith({
    String? id,
    String? email,
    UserRole? role,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? birthPlace,
    DateTime? birthDate,
    String? timezone,
    bool? isEmailVerified,
    DateTime? emailVerifiedAt,
    SuspendType? suspendType,
    DateTime? suspendedUntil,
    String? suspendReason,
    String appealEmailInfo = 'support@beres.id',
    DateTime? deletedAt,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      birthPlace: birthPlace ?? this.birthPlace,
      birthDate: birthDate ?? this.birthDate,
      timezone: timezone ?? this.timezone,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      suspendType: suspendType ?? this.suspendType,
      suspendedUntil: suspendedUntil ?? this.suspendedUntil,
      suspendReason: suspendReason ?? this.suspendReason,
      appealEmailInfo: appealEmailInfo,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role.value,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'birth_place': birthPlace,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'timezone': timezone,
      'is_email_verified': isEmailVerified,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'suspend_type': suspendType.value,
      'suspended_until': suspendedUntil?.toIso8601String(),
      'suspend_reason': suspendReason,
      'appeal_email_info': appealEmailInfo,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
