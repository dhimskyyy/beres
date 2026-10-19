/// 10 Status Pekerjaan Resmi Beres v1.4.0 (PRD Bagian 7 & BR-31, BR-50 s/d BR-71)
enum JobStatus {
  open('OPEN', 'Bursa Terbuka'),
  negotiating('NEGOTIATING', 'Negosiasi Chat'),
  notaApproved('NOTA_APPROVED', 'Nota Disetujui'),
  onTheWay('ON_THE_WAY', 'Tukang Menuju Lokasi'),
  arrived('ARRIVED', 'Tukang Sudah Tiba'),
  working('WORKING', 'Pekerjaan Berjalan'),
  completed('COMPLETED', 'Selesai'),
  cancelled('CANCELLED', 'Dibatalkan'),
  expired('EXPIRED', 'Kedaluwarsa (24 Jam)'),
  cancelPending('CANCEL_PENDING', 'Pengajuan Pembatalan');

  final String value;
  final String label;

  const JobStatus(this.value, this.label);

  static JobStatus fromString(String value) {
    return JobStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => JobStatus.open,
    );
  }

  bool get isTerminal =>
      this == JobStatus.completed ||
      this == JobStatus.cancelled ||
      this == JobStatus.expired;

  bool get isActive => !isTerminal;

  /// Cek apakah pembatalan dilarang mutlak (BR-65)
  bool get isCancellationForbidden => this == JobStatus.working;
}
