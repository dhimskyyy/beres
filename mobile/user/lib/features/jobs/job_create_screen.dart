import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beres_shared/beres_shared.dart';

final jobServiceProvider = Provider((ref) => JobService());

class JobCreateScreen extends ConsumerStatefulWidget {
  final Job? existingJob;

  const JobCreateScreen({super.key, this.existingJob});

  @override
  ConsumerState<JobCreateScreen> createState() => _JobCreateScreenState();
}

class _JobCreateScreenState extends ConsumerState<JobCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _areaLabelController = TextEditingController();
  final _addressFullController = TextEditingController();

  String? _selectedCategoryId;
  List<Category> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Koordinat acuan GPS HP User (FR-010)
  final double _deviceLat = -6.2088;
  final double _deviceLng = 106.8456;

  // Koordinat pin lokasi pekerjaan
  late double _pinLat;
  late double _pinLng;

  // Foto Kerusakan (maks 3 foto)
  final List<String> _photoUrls = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingJob != null) {
      _selectedCategoryId = widget.existingJob!.categoryId;
      _descriptionController.text = widget.existingJob!.description;
      _areaLabelController.text = widget.existingJob!.areaLabel;
      _addressFullController.text = widget.existingJob!.addressFull;
      _pinLat = widget.existingJob!.latitude;
      _pinLng = widget.existingJob!.longitude;
    } else {
      _pinLat = _deviceLat;
      _pinLng = _deviceLng;
      _areaLabelController.text = 'Tebet, Jakarta Selatan';
      _addressFullController.text = 'Jl. Tebet Barat Dalam Raya No. 45';
    }
    _loadCategories();
    if (widget.existingJob != null) {
      _loadExistingPhotos();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final list = (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _categories = list;
          _isLoadingCategories = false;
          if (_selectedCategoryId == null && list.isNotEmpty) {
            _selectedCategoryId = list.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _errorMessage = 'Gagal memuat kategori: $e';
        });
      }
    }
  }

  Future<void> _loadExistingPhotos() async {
    try {
      final photos = await ref
          .read(jobServiceProvider)
          .getJobDamagePhotos(widget.existingJob!.id);
      if (mounted) {
        setState(() {
          _photoUrls.addAll(photos);
        });
      }
    } catch (_) {}
  }

  double _getDistanceFromDeviceMeters() {
    const double earthRadius = 6371000;
    final double dLat = (_pinLat - _deviceLat) * (pi / 180.0);
    final double dLon = (_pinLng - _deviceLng) * (pi / 180.0);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deviceLat * (pi / 180.0)) *
            cos(_pinLat * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  void _onPinMoved(double newLat, double newLng) {
    setState(() {
      _pinLat = newLat;
      _pinLng = newLng;
    });
  }

  Future<void> _addMockPhoto() async {
    if (_photoUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 3 foto kerusakan')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Mock 1x1 transparent PNG bytes for cross-platform upload
      final sampleBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      final url = await ref
          .read(jobServiceProvider)
          .uploadJobPhoto(sampleBytes, 'photo_${_photoUrls.length + 1}.png');

      if (mounted) {
        setState(() {
          _photoUrls.add(url);
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal unggah foto: $e')));
      }
    }
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori pekerjaan terlebih dahulu'),
        ),
      );
      return;
    }

    final distanceMeters = _getDistanceFromDeviceMeters();
    if (distanceMeters > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pin lokasi (${distanceMeters.toStringAsFixed(0)} m) melebihi batas 2 km dari GPS HP Anda (FR-010). Geser pin lebih dekat.',
          ),
          backgroundColor: AppColors.dangerCrimson,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final jobService = ref.read(jobServiceProvider);

    try {
      if (widget.existingJob != null) {
        await jobService.updateJob(
          jobId: widget.existingJob!.id,
          categoryId: _selectedCategoryId!,
          description: _descriptionController.text.trim(),
          latitude: _pinLat,
          longitude: _pinLng,
          areaLabel: _areaLabelController.text.trim(),
          addressFull: _addressFullController.text.trim(),
          photoUrls: _photoUrls,
        );
      } else {
        await jobService.createJob(
          categoryId: _selectedCategoryId!,
          description: _descriptionController.text.trim(),
          latitude: _pinLat,
          longitude: _pinLng,
          areaLabel: _areaLabelController.text.trim(),
          addressFull: _addressFullController.text.trim(),
          photoUrls: _photoUrls,
          deviceLat: _deviceLat,
          deviceLng: _deviceLng,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingJob != null
                  ? 'Pekerjaan berhasil diperbarui!'
                  : 'Pekerjaan berhasil diposting! Menunggu penawaran tukang...',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
        context.pop(true);
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
  void dispose() {
    _descriptionController.dispose();
    _areaLabelController.dispose();
    _addressFullController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distanceMeters = _getDistanceFromDeviceMeters();
    final isDistanceExceeded = distanceMeters > 2000;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          widget.existingJob != null
              ? 'Edit Pekerjaan'
              : 'Posting Pekerjaan Baru',
        ),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.dangerCrimson.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.dangerCrimson),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: AppColors.dangerCrimson),
                        ),
                      ),

                    // 1. Kategori Pekerjaan
                    Text(
                      'Kategori Pekerjaan',
                      style: AppTypography.headingSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.handyman_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCategoryId = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    // 2. Deskripsi Kerusakan (FR-010: Min 10 Karakter)
                    Text(
                      'Deskripsi Kerusakan',
                      style: AppTypography.headingSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jelaskan keluhan atau kerusakan secara detail (minimal 10 karakter)',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'Contoh: Pipa wastafel bocor dan rembes ke lantai dapur...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 10) {
                          return 'Deskripsi minimal 10 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 3. Foto Kerusakan (Maks 3)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Foto Kerusakan (${_photoUrls.length}/3)',
                          style: AppTypography.headingSmall,
                        ),
                        if (_photoUrls.length < 3)
                          TextButton.icon(
                            onPressed: _isSubmitting ? null : _addMockPhoto,
                            icon: const Icon(Icons.add_a_photo, size: 18),
                            label: const Text('Tambah Foto'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_photoUrls.isEmpty)
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.borderLight,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library_outlined,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Belum ada foto kerusakan',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photoUrls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            return Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: AppColors.primaryNavy.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: AppColors.trustCobalt,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _photoUrls.removeAt(idx));
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
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
                    const SizedBox(height: 24),

                    // 4. Pin Lokasi & Validasi Jarak <= 2 km (FR-010)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pin Lokasi Pekerjaan',
                          style: AppTypography.headingSmall,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isDistanceExceeded
                                ? AppColors.dangerCrimson.withValues(
                                    alpha: 0.15,
                                  )
                                : AppColors.successGreen.withValues(
                                    alpha: 0.15,
                                  ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Jarak Pin: ${distanceMeters.toStringAsFixed(0)} m ${isDistanceExceeded ? '(> 2 km!)' : '(Maks 2 km)'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDistanceExceeded
                                  ? AppColors.dangerCrimson
                                  : AppColors.successGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDistanceExceeded
                              ? AppColors.dangerCrimson
                              : AppColors.borderLight,
                          width: isDistanceExceeded ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: BeresMapView(
                        initialCenter: MapLatLng(_pinLat, _pinLng),
                        markers: [
                          BeresMapMarker(
                            id: 'device_loc',
                            position: MapLatLng(_deviceLat, _deviceLng),
                            type: MapMarkerType.userLocation,
                            title: 'GPS HP Anda',
                          ),
                          BeresMapMarker(
                            id: 'job_pin',
                            position: MapLatLng(_pinLat, _pinLng),
                            type: MapMarkerType.jobLocation,
                            title: 'Titik Pekerjaan',
                          ),
                        ],
                        onTap: (point) {
                          _onPinMoved(point.latitude, point.longitude);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _onPinMoved(_deviceLat, _deviceLng);
                            },
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text('Reset ke Titik GPS Saya'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Simulasi geser pin 500m ke utara
                              _onPinMoved(_pinLat + 0.0045, _pinLng);
                            },
                            icon: const Icon(Icons.pin_drop, size: 16),
                            label: const Text('Geser Pin Peta'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 5. Area Label (Kelurahan/Kecamatan via OS Geocoding HP Rp 0)
                    Text(
                      'Kelurahan / Kecamatan (Area Label)',
                      style: AppTypography.headingSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nama area diambil via OS Geocoder HP (bebas limit server). Hanya data ini yang terlihat oleh tukang sebelum di-lock (BR-16).',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _areaLabelController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Kelurahan/Kecamatan wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 6. Alamat Lengkap
                    Text(
                      'Alamat Lengkap & Patokan',
                      style: AppTypography.headingSmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressFullController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText:
                            'Nama jalan, nomor rumah, RT/RW, dan patokan pagar/pos...',
                        prefixIcon: Icon(Icons.home_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Alamat lengkap wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitJob,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.existingJob != null
                                  ? 'Simpan Perubahan'
                                  : 'Posting Pekerjaan Sekarang',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
