import 'package:intl/intl.dart';

/// Formatter Utilitas Ekosistem Beres v1.4.0
typedef Formatters = BeresFormatters;

class BeresFormatters {
  /// Format Rupiah integer tanpa desimal (BR-01, BR-05)
  /// Contoh: 150000 -> "Rp 150.000"
  static String formatRupiah(int amount) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return currencyFormatter.format(amount);
  }

  /// Alias untuk formatRupiah
  static String formatCurrency(int amount) => formatRupiah(amount);

  /// Format durasi detik ke format MM:SS untuk countdown timer (BR-31, BR-70)
  /// Contoh: 1800 detik -> "30:00"
  static String formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format tanggal lokal Indonesia
  static String formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    return formatter.format(dateTime);
  }

  /// Format jam lokal (HH:mm)
  static String formatTime(DateTime dateTime) {
    final formatter = DateFormat('HH:mm', 'id_ID');
    return formatter.format(dateTime);
  }

  /// Format jarak dalam kilometer
  /// Contoh: 2.35 -> "2.4 km"
  static String formatDistance(double km) {
    return '${km.toStringAsFixed(1)} km';
  }
}
