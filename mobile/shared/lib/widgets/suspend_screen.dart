import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

/// Layar Tampilan Suspend Akun Beres v1.4.0 (BR-42)
/// Menangani Suspend Otomatis 2 Hari (karena > 3x Strike) & Suspend Permanen Admin
class SuspendScreen extends StatefulWidget {
  final bool isPermanent;
  final String reason;
  final DateTime? suspendedUntil;
  final String appealEmail;
  final VoidCallback onSignOut;
  final VoidCallback? onRefresh;

  const SuspendScreen({
    super.key,
    required this.isPermanent,
    required this.reason,
    this.suspendedUntil,
    this.appealEmail = 'support@beres.id',
    required this.onSignOut,
    this.onRefresh,
  });

  @override
  State<SuspendScreen> createState() => _SuspendScreenState();
}

class _SuspendScreenState extends State<SuspendScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    if (!widget.isPermanent && widget.suspendedUntil != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _calculateRemaining();
      });
    }
  }

  void _calculateRemaining() {
    if (widget.suspendedUntil != null) {
      final diff = widget.suspendedUntil!.difference(DateTime.now());
      if (mounted) {
        setState(() {
          _remaining = diff.isNegative ? Duration.zero : diff;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPermanent = widget.isPermanent;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Icon Badge
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isPermanent
                        ? AppColors.dangerLight
                        : AppColors.warningLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPermanent ? Icons.gavel_rounded : Icons.timer_outlined,
                    size: 44,
                    color: isPermanent
                        ? AppColors.dangerCrimson
                        : AppColors.warningAmber,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                isPermanent
                    ? 'Akun Dinonaktifkan Permanen'
                    : 'Akun Ditangguhkan Sementara (48 Jam)',
                style: AppTypography.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle / Reason
              Text(
                widget.reason,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Countdown Card (Hanya untuk Suspend Otomatis 2 Hari)
              if (!isPermanent && widget.suspendedUntil != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Sisa Waktu Penangguhan',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_remaining.inHours.toString().padLeft(2, '0')}:${(_remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(_remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                        style:
                            AppTypography.timerDisplay.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Berakhir pada: ${BeresFormatters.formatDateTime(widget.suspendedUntil!)}',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.warningAmber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sanksi ini dipicu otomatis karena akun telah mengumpulkan lebih dari 3 pelanggaran (strike) dalam bulan ini (BR-42b).',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.warningAmber),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Info Banding (Hanya untuk Suspend Permanen Admin)
              if (isPermanent) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.mail_outline,
                          color: AppColors.trustCobalt, size: 32),
                      const SizedBox(height: 10),
                      Text(
                        'Pengajuan Banding Resmi',
                        style: AppTypography.headingSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Jika Anda merasa keputusan ini keliru, silakan ajukan banding melalui email resmi perusahaan:',
                        style: AppTypography.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        widget.appealEmail,
                        style: AppTypography.button
                            .copyWith(color: AppColors.trustCobalt),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Action Buttons
              if (widget.onRefresh != null) ...[
                OutlinedButton.icon(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Cek Status Akun'),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dari Akun'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPermanent
                      ? AppColors.dangerCrimson
                      : AppColors.primaryNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
