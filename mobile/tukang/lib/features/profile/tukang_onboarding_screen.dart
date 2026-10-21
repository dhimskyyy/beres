import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

final tukangServiceProvider = Provider<TukangService>((ref) => TukangService());

class TukangOnboardingScreen extends ConsumerStatefulWidget {
  final String tukangId;

  const TukangOnboardingScreen({super.key, required this.tukangId});

  @override
  ConsumerState<TukangOnboardingScreen> createState() =>
      _TukangOnboardingScreenState();
}

class _TukangOnboardingScreenState
    extends ConsumerState<TukangOnboardingScreen> {
  final _bioController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();

  int _radiusKm = 20;
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
      setState(
        () => _errorMessage = 'Pilih minimal 1 kategori bidang keahlian.',
      );
      return;
    }

    final bankName = _bankNameController.text.trim();
    final accNum = _accountNumberController.text.trim();
    final accHolder = _accountHolderController.text.trim();

    if (bankName.isEmpty || accNum.isEmpty || accHolder.isEmpty) {
      setState(
        () => _errorMessage =
            'Lengkapi rincian rekening atau e-wallet untuk menerima pembayaran.',
      );
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
        },
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
          _errorMessage = 'Gagal menyimpan pengaturan profil.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Keahlian & Rekening Mitra')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pengaturan Profil Kerja',
                      style: AppTypography.headingMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Informasi keahlian dan rekening pembayaran ini akan ditampilkan kepada pelanggan serta dicantumkan pada Nota Digital.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 18),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.dangerCrimson,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 1. Bio Pengalaman
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
                            'Ringkasan Pengalaman Kerja',
                            style: AppTypography.headingSmall,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _bioController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText:
                                  'Contoh: Berpengalaman 7 tahun dalam perbaikan instalasi listrik rumah, pompa air, dan atap...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Pilih Kategori Keahlian
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
                                'Bidang Keahlian',
                                style: AppTypography.headingSmall,
                              ),
                              Text(
                                '${_selectedCategoryIds.length} dipilih',
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategoryIds.contains(
                                cat.id,
                              );
                              return FilterChip(
                                label: Text(cat.name),
                                selected: isSelected,
                                selectedColor: AppColors.tukangBadgeBg,
                                checkmarkColor: AppColors.safetyOrange,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppColors.tukangBadgeText
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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
                    const SizedBox(height: 14),

                    // 3. Radius Jangkauan
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
                                'Jangkauan Radius Bertugas',
                                style: AppTypography.headingSmall,
                              ),
                              Text(
                                '$_radiusKm km',
                                style: AppTypography.rupiahMedium.copyWith(
                                  color: AppColors.safetyOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Jarak maksimal pesanan yang tampil di Bursa Pekerjaan Anda (hingga 50 km).',
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
                    const SizedBox(height: 14),

                    // 4. Rekening Pembayaran
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
                            'Rekening Penerima Pembayaran',
                            style: AppTypography.headingSmall,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Dicantumkan otomatis pada Nota Digital agar pelanggan dapat membayar langsung ke rekening Anda.',
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _bankNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nama Bank atau E-Wallet',
                              hintText: 'Contoh: BCA / Mandiri / GoPay / DANA',
                              prefixIcon: Icon(Icons.account_balance_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _accountNumberController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Nomor Rekening / Nomor E-Wallet',
                              hintText: '1234567890',
                              prefixIcon: Icon(Icons.numbers_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _accountHolderController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nama Pemilik Rekening',
                              hintText:
                                  'Sesuai buku tabungan atau akun e-wallet',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Simpan Pengaturan Mitra'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
