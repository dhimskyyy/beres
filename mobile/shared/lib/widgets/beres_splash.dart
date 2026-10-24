import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Splash animasi Beres:
/// kunci pas muter masuk -> centang "digambar" (beres!) -> tulisan BERES muncul.
/// Dirancang responsif untuk berbagai ukuran device mobile (FittedBox & dynamic scaling).
class BeresSplash extends StatefulWidget {
  const BeresSplash({
    super.key,
    required this.onFinished,
    this.tagline,
  });

  /// Dipanggil setelah animasi kelar (misal pindah ke halaman utama/login).
  final VoidCallback onFinished;

  /// Tagline opsional di bawah logo (misal: "Panggil Tukang Tanpa Ribet")
  final String? tagline;

  @override
  State<BeresSplash> createState() => _BeresSplashState();
}

class _BeresSplashState extends State<BeresSplash>
    with SingleTickerProviderStateMixin {
  static const double _iconAspect = 1.010;
  static const double _textH = 0.261;
  static const double _gap = 0.060;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2900), // 2.55s animasi + 0.35s hold
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) widget.onFinished();
      }
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Progres 0..1 untuk jendela waktu [a, b] dari total animasi.
  double _seg(double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final shortestSide = mediaQuery.size.shortestSide;

    // Responsif: Menyesuaikan tinggi logo secara proporsional dengan ukuran layar HP
    // HP kecil (320dp) -> h = 95, standar (390dp) -> h = 118, besar (430dp+) -> h = 130
    final double h = (shortestSide * 0.30).clamp(90.0, 135.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final wrench = _seg(0.00, 0.32, Curves.easeOutBack);
            final wrenchFade = _seg(0.00, 0.14, Curves.easeOut);
            final check = _seg(0.27, 0.50, Curves.easeInOutCubic);
            final pop = 1 + 0.08 * math.sin(_seg(0.50, 0.63) * math.pi);
            final text = _seg(0.61, 0.85, Curves.easeOutCubic);
            final taglineFade = _seg(0.76, 0.88, Curves.easeIn);

            final icon = Transform.scale(
              scale: pop,
              child: SizedBox(
                width: h * _iconAspect,
                height: h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: wrenchFade,
                      child: Transform.rotate(
                        angle: (1 - wrench) * -0.8,
                        child: Transform.scale(
                          scale: 0.5 + 0.5 * wrench,
                          child: Image.asset(
                            'assets/splash/wrench.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    if (check > 0)
                      ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) {
                          final e = check * 1.15;
                          return LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: const [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: [
                              0.0,
                              (e - 0.15).clamp(0.0, 1.0),
                              e.clamp(0.0, 1.0),
                              1.0,
                            ],
                          ).createShader(rect);
                        },
                        child: Image.asset(
                          'assets/splash/check.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                  ],
                ),
              ),
            );

            final label = ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: text,
                child: Opacity(
                  opacity: text,
                  child: Transform.translate(
                    offset: Offset(-24 * (1 - text), 0),
                    child: Image.asset(
                      'assets/splash/text.png',
                      height: h * _textH,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // FittedBox menjamin tampilan responsif & tidak overflow di layar apa pun
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          icon,
                          SizedBox(width: h * _gap * text),
                          label,
                        ],
                      ),
                    ),
                    if (widget.tagline != null &&
                        widget.tagline!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Opacity(
                        opacity: taglineFade,
                        child: Text(
                          widget.tagline!,
                          style: TextStyle(
                            fontSize: (h * 0.12).clamp(12.0, 14.5),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
