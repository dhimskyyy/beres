import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_shared/beres_shared.dart';
import '../profile/tukang_onboarding_screen.dart';

class TukangKycScreen extends ConsumerStatefulWidget {
  final String tukangId;

  const TukangKycScreen({super.key, required this.tukangId});

  @override
  ConsumerState<TukangKycScreen> createState() => _TukangKycScreenState();
}

class _TukangKycScreenState extends ConsumerState<TukangKycScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  KycStatus _currentStatus = KycStatus.pending;
  String? _rejectionReason;
  DateTime? _kycApprovedAt;

  // Mock / picked image indicators
  bool _hasKtpImage = false;
  bool _hasSelfieImage = false;
  String _ktpFileName = '';
  String _selfieFileName = '';

  String get _effectiveTukangId {
    if (widget.tukangId != 'me' && widget.tukangId.isNotEmpty) {
      return widget.tukangId;
    }
    return SupabaseClientService.instance.currentUser?.id ??
        '00000000-0000-0000-0000-000000000000';
  }

  @override
  void initState() {
    super.initState();
    _fetchKycStatus();
  }

  Future<void> _fetchKycStatus() async {
    setState(() => _isLoading = true);
    try {
      final tukangService = ref.read(tukangServiceProvider);
      final profile = await tukangService.getTukangProfile(_effectiveTukangId);
      final latestKyc = await tukangService.getLatestKycDocument(
        _effectiveTukangId,
      );

      if (mounted) {
        setState(() {
          if (profile != null) {
            _currentStatus = profile.kycStatus;
            _kycApprovedAt = profile.kycApprovedAt;
          }
          if (latestKyc != null) {
            _rejectionReason = latestKyc['rejection_reason'] as String?;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _simulatePickKtp() {
    final prefix = _effectiveTukangId.length >= 5
        ? _effectiveTukangId.substring(0, 5)
        : _effectiveTukangId;
    setState(() {
      _hasKtpImage = true;
      _ktpFileName = 'ktp_original_$prefix.jpg';
    });
  }

  void _simulatePickSelfie() {
    final prefix = _effectiveTukangId.length >= 5
        ? _effectiveTukangId.substring(0, 5)
        : _effectiveTukangId;
    setState(() {
      _hasSelfieImage = true;
      _selfieFileName = 'selfie_ktp_$prefix.jpg';
    });
  }

  Future<void> _handleSubmitKyc() async {
    if (!_hasKtpImage || !_hasSelfieImage) {
      setState(() {
        _errorMessage =
            'Foto KTP dan Foto Selfie memegang KTP wajib diunggah keduanya (FR-003).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final tukangService = ref.read(tukangServiceProvider);

      // Simulasikan byte file gambar untuk diunggah ke bucket privat kyc-private
      final dummyKtpBytes = utf8.encode(
        'DUMMY_KTP_IMAGE_CONTENT_${DateTime.now()}',
      );
      final dummySelfieBytes = utf8.encode(
        'DUMMY_SELFIE_IMAGE_CONTENT_${DateTime.now()}',
      );

      final ktpStoragePath = await tukangService.uploadKycFile(
        tukangId: _effectiveTukangId,
        fileName: _ktpFileName,
        fileBytes: dummyKtpBytes,
      );

      final selfieStoragePath = await tukangService.uploadKycFile(
        tukangId: _effectiveTukangId,
        fileName: _selfieFileName,
        fileBytes: dummySelfieBytes,
      );

      // Submit ke tabel kyc_documents & set kyc_status = PENDING
      await tukangService.submitKycDocument(
        tukangId: _effectiveTukangId,
        ktpStoragePath: ktpStoragePath,
        selfieStoragePath: selfieStoragePath,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _currentStatus = KycStatus.pending;
          _successMessage =
              'Dokumen KYC berhasil dikirim ke Admin untuk diverifikasi.';
          _hasKtpImage = false;
          _hasSelfieImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Gagal mengirim berkas KYC: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Verifikasi Identitas (KYC)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Badge Card
                    _buildStatusBanner(),
                    const SizedBox(height: 20),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.dangerCrimson,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.dangerCrimson,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.successGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.successGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Form Upload Hanya Ditampilkan jika REJECTED atau PENDING pertama kali
                    if (_currentStatus != KycStatus.approved) ...[
                      Text(
                        'Unggah Berkas Identitas (FR-003)',
                        style: AppTypography.headingSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Data KTP disimpan di server privat terenkripsi dan hanya digunakan Admin untuk verifikasi keamanan.',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 16),

                      // 1. Upload KTP
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.credit_card,
                                        color: AppColors.safetyOrange,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Foto KTP Asli',
                                        style: AppTypography.headingSmall,
                                      ),
                                    ],
                                  ),
                                  if (_hasKtpImage)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.successGreen,
                                      size: 20,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pastikan seluruh tulisan, NIK, nama lengkap, dan foto pada KTP terbaca jelas (tidak blur/terpotong).',
                                style: AppTypography.bodySmall,
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _simulatePickKtp,
                                icon: Icon(
                                  _hasKtpImage
                                      ? Icons.restart_alt
                                      : Icons.camera_alt_outlined,
                                ),
                                label: Text(
                                  _hasKtpImage
                                      ? 'Ganti Foto KTP ($_ktpFileName)'
                                      : 'Ambil / Pilih Foto KTP',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Upload Selfie Memegang KTP
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.face_retouching_natural,
                                        color: AppColors.safetyOrange,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Selfie Memegang KTP',
                                        style: AppTypography.headingSmall,
                                      ),
                                    ],
                                  ),
                                  if (_hasSelfieImage)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.successGreen,
                                      size: 20,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pegang KTP di samping wajah Anda. Pastikan wajah dan kartu KTP Anda terlihat jelas tanpa tertutup kacamata/masker.',
                                style: AppTypography.bodySmall,
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _simulatePickSelfie,
                                icon: Icon(
                                  _hasSelfieImage
                                      ? Icons.restart_alt
                                      : Icons.camera_alt_outlined,
                                ),
                                label: Text(
                                  _hasSelfieImage
                                      ? 'Ganti Foto Selfie ($_selfieFileName)'
                                      : 'Ambil Foto Selfie + KTP',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmitKyc,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.safetyOrange,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Kirim Dokumen ke Admin'),
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Info Aturan BR-10
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.gavel_outlined,
                            color: AppColors.trustCobalt,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Aturan Beres (BR-10): Mitra yang belum lolos verifikasi KYC dilarang melihat daftar pekerjaan dan dilarang melamar (bid) demi integritas & perlindungan pelanggan.',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusBanner() {
    switch (_currentStatus) {
      case KycStatus.approved:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.successGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified,
                color: AppColors.successGreen,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Akun Terverifikasi (APPROVED)',
                      style: AppTypography.headingSmall.copyWith(
                        color: AppColors.successGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Identitas Anda telah disetujui. Bursa pekerjaan dan fitur lamar (bid) aktif penuh (BR-10).',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.successGreen,
                      ),
                    ),
                    if (_kycApprovedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Disetujui pada: ${BeresFormatters.formatDateTime(_kycApprovedAt!)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

      case KycStatus.rejected:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.dangerCrimson.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.cancel,
                    color: AppColors.dangerCrimson,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Verifikasi KYC Ditolak',
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.dangerCrimson,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Alasan dari Admin: ${_rejectionReason ?? "Dokumen tidak terbaca jelas atau tidak sesuai ketentuan."}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.dangerCrimson,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Silakan ambil ulang foto KTP dan foto selfie Anda sesuai instruksi di bawah lalu kirim kembali.',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        );

      case KycStatus.pending:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.warningAmber.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule,
                color: AppColors.warningAmber,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menunggu Verifikasi Admin',
                      style: AppTypography.headingSmall.copyWith(
                        color: AppColors.warningAmber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dokumen Anda sedang dalam antrean pemeriksaan oleh tim operasional Beres (maks. 1x24 jam).',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.warningAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}
