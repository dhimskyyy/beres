import 'dart:convert';
import 'dart:typed_data';
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

  Uint8List? _ktpBytes;
  Uint8List? _selfieBytes;

  Future<void> _pickKtpImage() async {
    final source = await _showImageSourceSheet('Pilih Foto KTP');
    if (source == null) return;

    final permissionService = DevicePermissionService();
    final file = source == ImageSource.camera
        ? await permissionService.pickImageFromCamera()
        : await permissionService.pickImageFromGallery();

    if (file != null) {
      final bytes = await permissionService.getImageBytes(file);
      setState(() {
        _hasKtpImage = true;
        _ktpFileName = file.name;
        _ktpBytes = bytes;
      });
    }
  }

  Future<void> _pickSelfieImage() async {
    final source = await _showImageSourceSheet('Pilih Foto Selfie + KTP');
    if (source == null) return;

    final permissionService = DevicePermissionService();
    final file = source == ImageSource.camera
        ? await permissionService.pickImageFromCamera()
        : await permissionService.pickImageFromGallery();

    if (file != null) {
      final bytes = await permissionService.getImageBytes(file);
      setState(() {
        _hasSelfieImage = true;
        _selfieFileName = file.name;
        _selfieBytes = bytes;
      });
    }
  }

  Future<ImageSource?> _showImageSourceSheet(String title) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(title, style: AppTypography.headingSmall),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.safetyOrange,
                ),
                title: const Text(
                  'Ambil Foto dengan Kamera',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Buka kamera ponsel Anda langsung',
                  style: AppTypography.bodySmall,
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.safetyOrange,
                ),
                title: const Text(
                  'Pilih dari Galeri Foto',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Pilih file gambar dari galeri perangkat',
                  style: AppTypography.bodySmall,
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmitKyc() async {
    if (!_hasKtpImage || !_hasSelfieImage) {
      setState(() {
        _errorMessage =
            'Unggah Foto KTP dan Foto Selfie memegang KTP terlebih dahulu.';
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

      final ktpBytes =
          _ktpBytes ?? utf8.encode('DUMMY_KTP_IMAGE_CONTENT_${DateTime.now()}');
      final selfieBytes =
          _selfieBytes ??
          utf8.encode('DUMMY_SELFIE_IMAGE_CONTENT_${DateTime.now()}');

      final ktpStoragePath = await tukangService.uploadKycFile(
        tukangId: _effectiveTukangId,
        fileName: _ktpFileName,
        fileBytes: ktpBytes,
      );

      final selfieStoragePath = await tukangService.uploadKycFile(
        tukangId: _effectiveTukangId,
        fileName: _selfieFileName,
        fileBytes: selfieBytes,
      );

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
              'Dokumen berhasil dikirim dan sedang ditinjau oleh tim verifikasi.';
          _hasKtpImage = false;
          _hasSelfieImage = false;
        });
      }
    } catch (e) {
      debugPrint('Error submitting KYC documents: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Gagal mengirim dokumen verifikasi: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Verifikasi Identitas Mitra')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusBanner(),
                    const SizedBox(height: 18),

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
                              Icons.error_outline_rounded,
                              color: AppColors.dangerCrimson,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.dangerCrimson,
                                  fontWeight: FontWeight.w600,
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
                              Icons.check_circle_outline_rounded,
                              color: AppColors.successGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_currentStatus != KycStatus.approved) ...[
                      const Text(
                        'Unggah Dokumen KTP',
                        style: AppTypography.headingSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Data identitas disimpan secara terenkripsi untuk menjamin keamanan dan kepercayaan pelanggan.',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 14),

                      // 1. Foto KTP
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.credit_card_rounded,
                                      color: AppColors.safetyOrange,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Foto KTP Asli',
                                      style: AppTypography.headingSmall,
                                    ),
                                  ],
                                ),
                                if (_hasKtpImage)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.successGreen,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Pastikan NIK, nama lengkap, dan foto pada kartu KTP terlihat jelas serta tidak terpotong.',
                              style: AppTypography.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _pickKtpImage,
                              icon: Icon(
                                _hasKtpImage
                                    ? Icons.refresh_rounded
                                    : Icons.camera_alt_outlined,
                                size: 18,
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
                      const SizedBox(height: 14),

                      // 2. Selfie + KTP
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.face_retouching_natural_rounded,
                                      color: AppColors.safetyOrange,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Foto Selfie Memegang KTP',
                                      style: AppTypography.headingSmall,
                                    ),
                                  ],
                                ),
                                if (_hasSelfieImage)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.successGreen,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Pegang KTP di samping wajah Anda tanpa menggunakan masker atau kacamata hitam.',
                              style: AppTypography.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : _pickSelfieImage,
                              icon: Icon(
                                _hasSelfieImage
                                    ? Icons.refresh_rounded
                                    : Icons.camera_alt_outlined,
                                size: 18,
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
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmitKyc,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Kirim Dokumen Verifikasi'),
                      ),
                    ],
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
                Icons.verified_rounded,
                color: AppColors.successGreen,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identitas Terverifikasi',
                      style: AppTypography.headingSmall.copyWith(
                        color: AppColors.successGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Akun mitra Anda telah terverifikasi dan dapat melamar pekerjaan di Bursa Kerja.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_kycApprovedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Disetujui pada ${BeresFormatters.formatDateTime(_kycApprovedAt!)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.w600,
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
                    Icons.cancel_rounded,
                    color: AppColors.dangerCrimson,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Verifikasi Perlu Diperbaiki',
                    style: AppTypography.headingSmall.copyWith(
                      color: AppColors.dangerCrimson,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Catatan: ${_rejectionReason ?? "Dokumen kurang jelas atau belum sesuai panduan."}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.dangerCrimson,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Silakan unggah ulang foto KTP dan selfie Anda di bawah ini.',
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
                Icons.schedule_rounded,
                color: AppColors.warningAmber,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menunggu Verifikasi Identitas',
                      style: AppTypography.headingSmall.copyWith(
                        color: AppColors.warningAmber,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unggah dokumen di bawah jika belum mengirim, atau tunggu proses peninjauan oleh tim operasional (maksimal 1x24 jam).',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
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
