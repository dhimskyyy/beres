import 'package:flutter/material.dart';

class AuthHeroHeader extends StatelessWidget {
  final double height;
  final bool showBackButton;
  final VoidCallback? onBack;

  const AuthHeroHeader({
    super.key,
    this.height = 250,
    this.showBackButton = false,
    this.onBack,
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
          // 1. Background Image (Aligned topCenter to display the black lamp & workshop wall)
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
                              const Color(0xFFFBBF24).withValues(alpha: 0.35),
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
                  Colors.black.withValues(alpha: 0.50), // Keeps white status bar clearly visible
                  Colors.black.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 3. Logo BERES Floating Directly on Background (No White Box, Exactly Matching Figma)
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                top: (topPadding * 0.7).clamp(24.0, 48.0),
                bottom: 16,
              ),
              child: Image.asset(
                'assets/images/beres_long.png',
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'packages/beres_shared/assets/beres_long.png',
                    height: 72,
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
