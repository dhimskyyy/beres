import 'dart:ui';
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
          // 1. Background Image with Fallback Ambient Theme
          Image.asset(
            'assets/images/auth_bg.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.3),
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'packages/beres_shared/assets/images/auth_bg.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.3),
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

          // 2. Multi-layer Dark Gradient for Contrast & Top Notch Protection
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.7, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.65), // Ensures white status bar clock & icons pop cleanly
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),

          // 3. Logo BERES in a Sleek Frosted Glass Badge
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                top: (topPadding * 0.7).clamp(24.0, 48.0),
                bottom: 24,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/beres_long.png',
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'packages/beres_shared/assets/beres_long.png',
                          height: 44,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, st) => const Text(
                            'BERES',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF16397E),
                              letterSpacing: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
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
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
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
