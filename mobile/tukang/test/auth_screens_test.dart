import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_shared/beres_shared.dart';
import 'package:beres_tukang/features/auth/tukang_login_screen.dart';
import 'package:beres_tukang/features/auth/tukang_register_screen.dart';
import 'package:beres_tukang/features/auth/tukang_reset_password_screen.dart';

void main() {
  testWidgets('TukangLoginScreen renders all elements properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TukangLoginScreen(),
        ),
      ),
    );

    expect(find.text('Selamat Datang Mitra'), findsOneWidget);
    expect(find.text('Silahkan Masuk ke Akun Mitra Tukang Anda'), findsOneWidget);
    expect(find.text('Email Mitra'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Lupa Password?'), findsOneWidget);
    expect(find.text('MASUK'), findsOneWidget);
    expect(find.text('Atau masuk dengan'), findsOneWidget);
    expect(find.text('Masuk menggunakan Google'), findsOneWidget);
    expect(find.text('Daftar Disini'), findsOneWidget);
  });

  testWidgets('TukangRegisterScreen renders all elements properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TukangRegisterScreen(),
        ),
      ),
    );

    expect(find.text('Daftar Sebagai Mitra'), findsOneWidget);
    expect(find.text('Bergabung bersama ribuan mitra tukang profesional Beres'), findsOneWidget);
    expect(find.text('Nama Lengkap Sesuai KTP'), findsOneWidget);
    expect(find.text('Email Mitra'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Konfirmasi Password'), findsOneWidget);
    expect(find.text('Syarat Keamanan Password:'), findsOneWidget);
    expect(find.text('DAFTAR'), findsOneWidget);
    expect(find.text('Masuk Disini'), findsOneWidget);
  });

  testWidgets('TukangResetPasswordScreen renders step 1 properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TukangResetPasswordScreen(),
        ),
      ),
    );

    expect(find.text('Lupa Password Mitra'), findsOneWidget);
    expect(find.text('Email Mitra'), findsOneWidget);
    expect(find.text('KIRIM KODE OTP'), findsOneWidget);
    expect(find.text('Masuk Disini'), findsOneWidget);
  });

  test('CheckEmailRoleResult blocks USER-only account on Tukang login and allows BOTH/TUKANG', () {
    final userOnly = CheckEmailRoleResult.fromJson({
      'status': 'ALLOWED_EXISTING_USER',
      'role': 'USER',
    });
    expect(userOnly.isExistingUser, isTrue);
    expect(userOnly.currentRole, UserRole.user);
    expect(userOnly.hasRoleFor(UserRole.tukang), isFalse);
    expect(userOnly.hasRoleFor(UserRole.user), isTrue);

    final bothRoles = CheckEmailRoleResult.fromJson({
      'status': 'ALLOWED_EXISTING_USER',
      'role': 'BOTH',
    });
    expect(bothRoles.hasRoleFor(UserRole.tukang), isTrue);
    expect(bothRoles.hasRoleFor(UserRole.user), isTrue);

    final tukangOnly = CheckEmailRoleResult.fromJson({
      'status': 'ALLOWED_EXISTING_USER',
      'role': 'TUKANG',
    });
    expect(tukangOnly.hasRoleFor(UserRole.tukang), isTrue);
    expect(tukangOnly.hasRoleFor(UserRole.user), isFalse);
  });
}
