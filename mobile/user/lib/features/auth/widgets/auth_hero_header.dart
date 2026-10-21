import 'package:flutter/material.dart';

class AuthHeroHeader extends StatelessWidget {
  final double height;
  final bool showBackButton;
  final VoidCallback? onBack;

  const AuthHeroHeader({
    super.key,
    this.height = 240,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image with Fallback Ambient Theme
          Image.asset(
            'assets/images/auth_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
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
                child: Stack(
                  children: [
                    // Warm overhead lamp glow
                    Positioned(
                      top: -40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 180,
                          height: 180,
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
                    ),
                  ],
                ),
              );
            },
          ),

          // Subtle Dark/Contrast Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.40),
                ],
              ),
            ),
          ),

          // Logo BERES Centered
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 20),
              child: Image.asset(
                'assets/images/beres_long.png',
                height: 64,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to shared package path
                  return Image.asset(
                    'packages/beres_shared/assets/beres_long.png',
                    height: 64,
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

          // Back Button (If enabled)
          if (showBackButton)
            Positioned(
              top: 0,
              left: 12,
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
