import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beres_shared/beres_shared.dart';

void main() {
  group('Enums & Supabase Integration', () {
    test('Verify OtpType enum values', () {
      expect(OtpType.email, isNotNull);
      expect(OtpType.magiclink, isNotNull);
    });

    test('UserRole enum values & serialization', () {
      expect(UserRole.user.value, 'USER');
      expect(UserRole.tukang.value, 'TUKANG');
      expect(UserRole.admin.value, 'ADMIN');

      expect(UserRole.fromString('USER'), UserRole.user);
      expect(UserRole.fromString('TUKANG'), UserRole.tukang);
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('UNKNOWN'), UserRole.user);
    });

    test('KycStatus enum mapping', () {
      expect(KycStatus.pending.name, 'pending');
      expect(KycStatus.approved.name, 'approved');
      expect(KycStatus.rejected.name, 'rejected');
      expect(KycStatus.fromString('APPROVED'), KycStatus.approved);
      expect(KycStatus.fromString('REJECTED'), KycStatus.rejected);
      expect(KycStatus.fromString('UNKNOWN'), KycStatus.pending);
    });

    test('JobStatus enum covers 10 PRD v1.4.0 statuses', () {
      const expectedStatuses = [
        JobStatus.open,
        JobStatus.negotiating,
        JobStatus.notaApproved,
        JobStatus.onTheWay,
        JobStatus.arrived,
        JobStatus.working,
        JobStatus.completed,
        JobStatus.cancelled,
        JobStatus.expired,
        JobStatus.cancelPending,
      ];
      expect(expectedStatuses.length, 10);
    });
  });

  group('CheckEmailRoleResult (BR-44, BR-42, BR-45)', () {
    test('Allowed new user', () {
      final res = CheckEmailRoleResult.fromJson({
        'status': 'ALLOWED_NEW_USER',
        'email': 'tukang.baru@beres.id',
      });
      expect(res.status, 'ALLOWED_NEW_USER');
      expect(res.isRoleMismatch, isFalse);
      expect(res.isSuspendedPermanent, isFalse);
      expect(res.isSuspendedAuto2Days, isFalse);
      expect(res.isDeleted, isFalse);
    });

    test('Role mismatch detection (BR-44)', () {
      final res = CheckEmailRoleResult.fromJson({
        'status': 'ROLE_MISMATCH',
        'message': '1 Email hanya boleh untuk 1 peran',
        'current_role': 'USER',
        'target_role': 'TUKANG',
      });
      expect(res.isRoleMismatch, isTrue);
      expect(res.message, contains('1 Email hanya boleh untuk 1 peran'));
    });

    test('Permanent suspend detection (BR-42a, BR-67)', () {
      final res = CheckEmailRoleResult.fromJson({
        'status': 'SUSPENDED_PERMANENT',
        'suspend_reason': 'Menolak membayar nota sah',
        'appeal_email': 'support@beres.id',
      });
      expect(res.isSuspendedPermanent, isTrue);
      expect(res.suspendReason, 'Menolak membayar nota sah');
      expect(res.appealEmail, 'support@beres.id');
    });

    test('Auto 2 days suspend detection (BR-42b, BR-57, BR-71)', () {
      final suspendedUntil =
          DateTime.now().add(const Duration(days: 2)).toIso8601String();
      final res = CheckEmailRoleResult.fromJson({
        'status': 'SUSPENDED_AUTO_2_DAYS',
        'suspend_reason': 'Akumulasi > 3 strike',
        'suspended_until': suspendedUntil,
      });
      expect(res.isSuspendedAuto2Days, isTrue);
      expect(res.suspendedUntil, isNotNull);
    });

    test('Deleted account detection (BR-45)', () {
      final res = CheckEmailRoleResult.fromJson({
        'status': 'ACCOUNT_DELETED',
        'message': 'Akun telah dinonaktifkan',
      });
      expect(res.isDeleted, isTrue);
    });
  });

  group('Profile and Category models', () {
    test('JobCategory serialization', () {
      final cat = JobCategory(
        id: 'cat-001',
        slug: 'listrik',
        name: 'Tukang Listrik',
        iconName: 'electrical_services',
        createdAt: DateTime(2026, 1, 1),
      );

      final json = cat.toJson();
      expect(json['slug'], 'listrik');
      expect(json['name'], 'Tukang Listrik');

      final parsed = JobCategory.fromJson(json);
      expect(parsed.id, 'cat-001');
      expect(parsed.name, 'Tukang Listrik');
    });

    test('TukangProfile model serialization and radius default', () {
      const profile = TukangProfile(
        userId: 'user-001',
        bio: 'Tukang berpengalaman 10 tahun',
        kycStatus: KycStatus.approved,
        isOnline: true,
        radiusKm: 25,
        ratingAvg: 4.85,
        ratingCount: 12,
      );

      expect(profile.radiusKm, 25);
      expect(profile.kycStatus, KycStatus.approved);
      expect(profile.isOnline, isTrue);
      expect(profile.isKycApproved, isTrue);
    });
  });

  group('BeresFormatters & Utilities', () {
    test('Rupiah currency formatting', () {
      expect(BeresFormatters.formatRupiah(150000), 'Rp 150.000');
      expect(BeresFormatters.formatRupiah(0), 'Rp 0');
      expect(BeresFormatters.formatRupiah(2500000), 'Rp 2.500.000');
    });

    test('Distance formatting', () {
      expect(BeresFormatters.formatDistance(1.2), '1.2 km');
      expect(BeresFormatters.formatDistance(15.4), '15.4 km');
    });

    test('Countdown timer formatting (BR-31, BR-70)', () {
      expect(BeresFormatters.formatCountdown(1800), '30:00');
      expect(BeresFormatters.formatCountdown(90), '01:30');
      expect(BeresFormatters.formatCountdown(0), '00:00');
    });
  });
}
