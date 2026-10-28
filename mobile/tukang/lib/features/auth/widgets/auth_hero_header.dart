import 'package:flutter/material.dart';

class AuthHeroHeader extends StatelessWidget {
  final double height;
  final bool showBackButton;
  final VoidCallback? onBack;
  final String? subtitleBadge;

  const AuthHeroHeader({
    super.key,
    this.height = 250,
    this.showBackButton = false,
    this.onBack,
    this.subtitleBadge,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image (Aligned topCenter to display the workshop & lamp)
          Image.asset(
            'assets/images/auth_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'packages/beres_shared/assets/images/auth_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (ctx, err, st) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF1E2430),
                          Color(0xFF2B3342),
                          Color(0xFF181D26),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFEA580C).withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // 2. Soft Gradient for Status Bar (White Icons/Clock) & Image Contrast
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 3. Logo BERES Floating Directly on Background + Optional Mitra Badge
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                top: (topPadding * 0.7).clamp(24.0, 48.0),
                bottom: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/beres_long.png',
                    height: 95,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'packages/beres_shared/assets/beres_long.png',
                        height: 95,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => const Text(
                          'BERES',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      );
                    },
                  ),
                  if (subtitleBadge != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        subtitleBadge!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4. Back Button (If enabled)
          if (showBackButton)
            Positioned(
              top: 0,
              left: 14,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
