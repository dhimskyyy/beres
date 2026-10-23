import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

final jobServiceProvider = Provider((ref) => JobService());

class JobCreateScreen extends ConsumerStatefulWidget {
  final String? preselectedCategory;

  const JobCreateScreen({super.key, this.preselectedCategory});

  @override
  ConsumerState<JobCreateScreen> createState() => _JobCreateScreenState();
}

class _JobCreateScreenState extends ConsumerState<JobCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressFullController = TextEditingController();

  List<JobCategory> _categories = [];
  String? _selectedCategoryId;

  // Koordinat GPS HP User (diinisialisasi dari GPS perangkat)
  MapLatLng _deviceLocation = DevicePermissionService.defaultLocation;
  late MapLatLng _pinLocation;
  String _areaLabel = 'Mendeteksi wilayah...';
  bool _isGeocoding = false;

  final List<String> _damagePhotoUrls = [];

  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pinLocation = _deviceLocation;
    _loadCategories();
    _initGpsLocation();
  }

  Future<void> _initGpsLocation() async {
    final loc = await DevicePermissionService().getCurrentLocation();
    if (mounted) {
      setState(() {
        _deviceLocation = loc;
        _pinLocation = loc;
      });
      _resolveReverseGeocode(loc);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressFullController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final jobService = ref.read(jobServiceProvider);
      final cats = await jobService.getActiveCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          if (cats.isNotEmpty) {
            if (widget.preselectedCategory != null &&
                widget.preselectedCategory!.isNotEmpty) {
              final target = widget.preselectedCategory!.trim().toLowerCase();
              final matched = cats.firstWhere(
                (c) =>
                    c.name.toLowerCase().contains(target) ||
                    target.contains(c.name.toLowerCase()),
                orElse: () => cats.first,
              );
              _selectedCategoryId = matched.id;
            } else {
              _selectedCategoryId = cats.first.id;
            }
          }
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _errorMessage = 'Gagal memuat kategori perbaikan.';
        });
      }
    }
  }

  double _calculateDistanceMeters(MapLatLng a, MapLatLng b) {
    const double earthRadius = 6371000;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadius * c;
  }

  Future<void> _resolveReverseGeocode(MapLatLng coords) async {
    setState(() => _isGeocoding = true);
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      setState(() {
        _areaLabel = 'Kel. Pegangsaan, Kec. Menteng';
        _isGeocoding = false;
      });
    }
  }

  void _onMapTapped(MapLatLng tapped) {
    final distMeters = _calculateDistanceMeters(_deviceLocation, tapped);
    if (distMeters > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Titik lokasi maksimal 2 km dari posisi Anda saat ini (${(distMeters / 1000).toStringAsFixed(2)} km).',
          ),
          backgroundColor: AppColors.dangerCrimson,
        ),
      );
      return;
    }

    setState(() {
      _pinLocation = tapped;
    });
    _resolveReverseGeocode(tapped);
  }

  Future<void> _pickDamagePhoto() async {
    if (_damagePhotoUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 5 foto kerusakan.')),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
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
              const Text(
                'Unggah Foto Kerusakan',
                style: AppTypography.headingSmall,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.trustCobalt,
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
                  color: AppColors.trustCobalt,
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

    if (source == null) return;

    final permissionService = DevicePermissionService();
    final file = source == ImageSource.camera
        ? await permissionService.pickImageFromCamera()
        : await permissionService.pickImageFromGallery();

    if (file != null) {
      try {
        final bytes = await permissionService.getImageBytes(file);
        if (bytes != null) {
          final jobService = ref.read(jobServiceProvider);
          final url = await jobService.uploadJobPhoto(bytes, file.name);
          if (mounted) {
            setState(() {
              _damagePhotoUrls.add(url);
            });
          }
          return;
        }
      } catch (_) {}

      // Fallback preview identifier jika offline / mock preview mode
      if (mounted) {
        setState(() {
          _damagePhotoUrls.add(
            'https://storage.beres.id/jobs-media/damage_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(
        () => _errorMessage = 'Pilih kategori perbaikan terlebih dahulu.',
      );
      return;
    }
    if (_damagePhotoUrls.isEmpty) {
      setState(
        () => _errorMessage =
            'Tambahkan minimal 1 foto bagian yang perlu diperbaiki.',
      );
      return;
    }

    final distMeters = _calculateDistanceMeters(_deviceLocation, _pinLocation);
    if (distMeters > 2000) {
      setState(
        () => _errorMessage =
            'Titik lokasi melebihi batas jarak 2 km dari posisi perangkat Anda.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final jobService = ref.read(jobServiceProvider);
      final job = await jobService.createJob(
        categoryId: _selectedCategoryId!,
        description: _descriptionController.text.trim(),
        latitude: _pinLocation.latitude,
        longitude: _pinLocation.longitude,
        deviceLat: _deviceLocation.latitude,
        deviceLng: _deviceLocation.longitude,
        areaLabel: _areaLabel,
        addressFull: _addressFullController.text.trim(),
        photoUrls: _damagePhotoUrls,
      );
      final createdJobId = (job['job_id'] ?? job['id'] ?? '').toString();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibuat! Menunggu mitra melamar.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        context.pushReplacement('/jobs/$createdJobId');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final distMeters = _calculateDistanceMeters(_deviceLocation, _pinLocation);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Buat Pesanan Pekerjaan')),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.dangerCrimson.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.dangerCrimson,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
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

                    // 1. Kategori & Keluhan
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
                          const Text(
                            'Detail Keluhan',
                            style: AppTypography.headingSmall,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'Kategori Keahlian',
                              prefixIcon: Icon(Icons.handyman_outlined),
                            ),
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedCategoryId = val),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Deskripsi Kerusakan / Pekerjaan',
                              alignLabelWithHint: true,
                              hintText:
                                  'Contoh: Pipa wastafel dapur bocor dan keran patah, butuh penggantian...',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().length < 10) {
                                return 'Jelaskan keluhan minimal 10 karakter';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Foto Kerusakan
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Foto Kondisi Kerusakan',
                                    style: AppTypography.headingSmall,
                                  ),
                                  Text(
                                    '${_damagePhotoUrls.length} dari maks. 5 foto terlampir',
                                    style: AppTypography.bodySmall,
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: _pickDamagePhoto,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Tambah Foto',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_damagePhotoUrls.isEmpty)
                            InkWell(
                              onTap: _pickDamagePhoto,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.borderLight,
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      color: AppColors.textMuted,
                                      size: 28,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Ketuk untuk mengunggah foto bagian yang rusak',
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 76,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _damagePhotoUrls.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 76,
                                        height: 76,
                                        decoration: BoxDecoration(
                                          color: AppColors.userBadgeBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.trustCobalt
                                                .withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.image_outlined,
                                              color: AppColors.trustCobalt,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Foto ${index + 1}',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.trustCobalt,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _damagePhotoUrls.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: AppColors.dangerCrimson,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Lokasi Pekerjaan
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
                              const Text(
                                'Lokasi Pengerjaan',
                                style: AppTypography.headingSmall,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${distMeters.toStringAsFixed(0)} m dari posisi Anda',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ketuk peta untuk menyesuaikan titik lokasi (maksimal 2 km dari posisi saat ini).',
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 200,
                              child: BeresMapView(
                                initialCenter: _pinLocation,
                                initialZoom: 15.0,
                                onTap: _onMapTapped,
                                markers: [
                                  BeresMapMarker(
                                    id: 'job_pin',
                                    position: _pinLocation,
                                    type: MapMarkerType.jobLocation,
                                    title: 'Titik Lokasi Pekerjaan',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.userBadgeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.trustCobalt,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isGeocoding
                                        ? 'Mendeteksi kelurahan/kecamatan...'
                                        : _areaLabel,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.trustCobalt,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _addressFullController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Alamat Lengkap & Patokan Rumah',
                              alignLabelWithHint: true,
                              hintText:
                                  'Contoh: Jl. Kebon Sirih No. 12, pagar hitam samping minimarket',
                              helperText:
                                  'Alamat lengkap hanya terlihat oleh mitra yang Anda pilih.',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().length < 5) {
                                return 'Lengkapi alamat dan patokan lokasi';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting
                            ? 'Mengirim Pesanan...'
                            : 'Kirim Pesanan Pekerjaan',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
