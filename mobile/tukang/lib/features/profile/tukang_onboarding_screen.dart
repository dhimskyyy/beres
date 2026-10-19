import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

final tukangServiceProvider = Provider<TukangService>((ref) => TukangService());

class TukangOnboardingScreen extends ConsumerStatefulWidget {
  final String tukangId;

  const TukangOnboardingScreen({super.key, required this.tukangId});

  @override
  ConsumerState<TukangOnboardingScreen> createState() => _TukangOnboardingScreenState();
}

class _TukangOnboardingScreenState extends ConsumerState<TukangOnboardingScreen> {
  final _bioController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();

  int _radiusKm = 20; // Default 20 km, rentang 0-50 km (BR-20)
  final Set<String> _selectedCategoryIds = {};
  List<JobCategory> _categories = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final tukangService = ref.read(tukangServiceProvider);
      final list = await tukangService.getActiveCategories();
      if (mounted) {
        setState(() {
          _categories = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    final bio = _bioController.text.trim();
    if (bio.isEmpty) {
      setState(() => _errorMessage = 'Deskripsi pengalaman kerja wajib diisi.');
      return;
    }

    if (_selectedCategoryIds.isEmpty) {
      setState(() => _errorMessage = 'Pilih minimal 1 kategori keahlian (FR-002).');
      return;
    }

    final bankName = _bankNameController.text.trim();
    final accNum = _accountNumberController.text.trim();
    final accHolder = _accountHolderController.text.trim();

    if (bankName.isEmpty || accNum.isEmpty || accHolder.isEmpty) {
      setState(() => _errorMessage = 'Rincian rekening / e-wallet wajib diisi lengkap untuk dicantumkan di Nota (BR-06).');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final tukangService = ref.read(tukangServiceProvider);
      final paymentAccounts = [
        {
          'type': 'BANK_TRANSFER',
          'bank_name': bankName,
          'account_number': accNum,
          'account_holder': accHolder,
          'is_primary': true,
        }
      ];

      await tukangService.updateTukangProfile(
        tukangId: widget.tukangId,
        bio: bio,
        radiusKm: _radiusKm,
        paymentAccounts: paymentAccounts,
        categoryIds: _selectedCategoryIds.toList(),
      );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Gagal menyimpan profil: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Profil Keahlian Mitra'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Lengkapi Biodata Kerja (FR-002)',
                      style: AppTypography.headingMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Data ini membantu pelanggan mengenal keahlian Anda dan dicantumkan pada Nota Digital.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 20),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.dangerCrimson),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 1. Bio Pengalaman
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pengalaman & Keahlian', style: AppTypography.headingSmall),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _bioController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Contoh: Berpengalaman 7 tahun dalam instalasi listrik rumah, renovasi atap, dan pengecatan...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Pilih Kategori Keahlian (Multi-select)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Bidang Keahlian', style: AppTypography.headingSmall),
                                Text('Pilih ≥ 1', style: AppTypography.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((cat) {
                                final isSelected = _selectedCategoryIds.contains(cat.id);
                                return FilterChip(
                                  label: Text(cat.name),
                                  selected: isSelected,
                                  selectedColor: AppColors.tukangBadgeBg,
                                  checkmarkColor: AppColors.safetyOrange,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppColors.safetyOrange : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedCategoryIds.add(cat.id);
                                      } else {
                                        _selectedCategoryIds.remove(cat.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Slider Radius Operasional (0 - 50 km, BR-20)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Radius Siap Bertugas', style: AppTypography.headingSmall),
                                Text(
                                  '$_radiusKm km',
                                  style: AppTypography.rupiahMedium.copyWith(color: AppColors.safetyOrange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jangkauan pekerjaan yang muncul di bursa (maks. 50 km di MVP - BR-20).',
                              style: AppTypography.bodySmall,
                            ),
                            Slider(
                              value: _radiusKm.toDouble(),
                              min: 0,
                              max: 50,
                              divisions: 50,
                              activeColor: AppColors.safetyOrange,
                              onChanged: (val) {
                                setState(() => _radiusKm = val.round());
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Rekening Bank / E-Wallet (BR-06)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rekening Penerima Pembayaran', style: AppTypography.headingSmall),
                            const SizedBox(height: 4),
                            Text(
                              'Dicantumkan otomatis pada Nota Sah pelanggan (BR-06). Pembayaran 100% langsung ke Anda.',
                              style: AppTypography.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _bankNameController,
                              decoration: const InputDecoration(
                                labelText: 'Bank atau E-Wallet',
                                hintText: 'BCA / Mandiri / GoPay / OVO / Dana',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _accountNumberController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Nomor Rekening / No. HP E-Wallet',
                                hintText: '1234567890',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _accountHolderController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Pemilik Rekening',
                                hintText: 'Sesuai buku tabungan / e-wallet',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.safetyOrange,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Simpan & Masuk ke Beres Mitra'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
