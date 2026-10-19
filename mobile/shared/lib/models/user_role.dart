/// Peran Pengguna di Ekosistem Beres v1.4.0 (BR-44: 1 Email = 1 Peran)
enum UserRole {
  user('USER', 'Pelanggan'),
  tukang('TUKANG', 'Mitra Tukang'),
  admin('ADMIN', 'Admin Operasional');

  final String value;
  final String label;

  const UserRole(this.value, this.label);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.user,
    );
  }
}
