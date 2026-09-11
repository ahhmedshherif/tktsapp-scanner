import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import 'src/core/api_client.dart';
import 'src/core/staff_session.dart';

// TKTSAPP Scanner design tokens — Velvet Concierge Design System
const _primary = Color(0xFF5C061F);
const _gold = Color(0xFFB89A6A);
const _ivory = Color(0xFFFCF9F8);
const _oxblood = Color(0xFF4A0519);
const _charcoal = Color(0xFF1A1A1A);
const _smoke = Color(0xFF6B6B6B);
const _success = Color(0xFF1E4D2B);
const _red = Color(0xFFB42318);

// Aliases for seamless integration
const _burgundy = _primary;
const _green = _success;

void main() => runApp(const ScannerApp());

class ScannerApp extends StatefulWidget {
  const ScannerApp({super.key});

  @override
  State<ScannerApp> createState() => _ScannerAppState();
}

class _ScannerAppState extends State<ScannerApp> {
  final _api = ApiClient();
  final _store = StaffSessionStore();
  StaffSession? _session;
  Timer? _quickLoginExpiryTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = await _store.restore();
    if (session != null) {
      _api.setToken(session.token);
      try {
        final response = await _api.get('/mobile/staff/me');
        final user = Map<String, dynamic>.from(response['data'] as Map);
        _session = StaffSession(session.token, user);
        await _store.save(_session!);
        _scheduleQuickLoginExpiry(_session!);
      } catch (_) {
        await _store.clear();
        _api.setToken(null);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signedIn(StaffSession session) async {
    _api.setToken(session.token);
    await _store.save(session);
    _scheduleQuickLoginExpiry(session);
    if (mounted) setState(() => _session = session);
  }

  Future<void> _signOut() async {
    _quickLoginExpiryTimer?.cancel();
    try {
      await _api.post('/mobile/staff/logout');
    } catch (_) {
      // A local logout must still succeed if the device is offline.
    }
    _api.setToken(null);
    await _store.clear();
    if (mounted) setState(() => _session = null);
  }

  void _scheduleQuickLoginExpiry(StaffSession session) {
    _quickLoginExpiryTimer?.cancel();
    final raw = session.user['quick_login_expires_at']?.toString();
    if (raw == null || raw.isEmpty) return;
    final expiresAt = DateTime.tryParse(raw)?.toLocal();
    if (expiresAt == null) return;
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      unawaited(_signOut());
      return;
    }
    _quickLoginExpiryTimer = Timer(remaining, () => unawaited(_signOut()));
  }

  @override
  void dispose() {
    _quickLoginExpiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TKTSAPP Scanner',
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    home: AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _loading
          ? const _BrandLoading()
          : _session == null
          ? StaffLoginScreen(api: _api, onSignedIn: _signedIn)
          : StaffShell(
              api: _api,
              session: _session!,
              onSignOut: _signOut,
              onSessionUpdated: _signedIn,
            ),
    ),
  );
}

ThemeData _theme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _ivory,
    colorScheme: const ColorScheme.light(
      primary: _primary,
      secondary: _gold,
      surface: _ivory,
      onSurface: _charcoal,
      error: _red,
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      labelLarge: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.spaceGrotesk(
        color: _charcoal,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _ivory.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 1,
      iconTheme: const IconThemeData(color: _charcoal),
      titleTextStyle: GoogleFonts.spaceGrotesk(
        color: _primary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _gold, width: 1),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEADFC9), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEADFC9), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primary, width: 1),
      ),
      hintStyle: const TextStyle(color: _smoke),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEADFC9), width: 1),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// Creative Animated Splash Screen
// ─────────────────────────────────────────────

class _BrandLoading extends StatefulWidget {
  const _BrandLoading();
  @override
  State<_BrandLoading> createState() => _BrandLoadingState();
}

class _BrandLoadingState extends State<_BrandLoading>
    with TickerProviderStateMixin {
  // Stage 1 — bg pulse (0–400ms)
  late final AnimationController _bgCtrl;
  // Stage 2 — ticket drop + rotation (300–900ms)
  late final AnimationController _ticketCtrl;
  // Stage 3 — scan line sweep (900–1400ms)
  late final AnimationController _scanCtrl;
  // Stage 4 — text + badge reveal (1100–1700ms)
  late final AnimationController _textCtrl;
  // Continuous — particle orbit after reveal
  late final AnimationController _particleCtrl;

  late final Animation<double> _bgScale;
  late final Animation<double> _ticketY;
  late final Animation<double> _ticketRotate;
  late final Animation<double> _ticketScale;
  late final Animation<double> _ticketOpacity;
  late final Animation<double> _scanLine;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ticketCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _bgScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOutCubic));

    _ticketY = Tween<double>(
      begin: -120,
      end: 0,
    ).animate(CurvedAnimation(parent: _ticketCtrl, curve: Curves.easeOutBack));
    _ticketRotate = Tween<double>(
      begin: 0.3,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ticketCtrl, curve: Curves.easeOutCubic));
    _ticketScale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ticketCtrl, curve: Curves.easeOutBack));
    _ticketOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ticketCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _scanLine = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 80));
    _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 220));
    _ticketCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 480));
    _scanCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 320));
    _textCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _ticketCtrl.dispose();
    _scanCtrl.dispose();
    _textCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _oxblood,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgCtrl,
          _ticketCtrl,
          _scanCtrl,
          _textCtrl,
          _particleCtrl,
        ]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── BG radial glow ──
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 1.0,
                    colors: [Color(0xFF541627), Color(0xFF1A0008)],
                  ),
                ),
              ),
              // ── Expanding ring pulse ──
              Center(
                child: Transform.scale(
                  scale: _bgScale.value,
                  child: Opacity(
                    opacity: (1.0 - _bgCtrl.value * 0.6).clamp(0, 1),
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _gold.withValues(alpha: .18),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // ── Particles ──
              CustomPaint(
                painter: _ParticlePainter(
                  progress: _particleCtrl.value,
                  opacity: _textCtrl.value,
                ),
              ),
              // ── Main content ──
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ticket with scan overlay
                    Transform.translate(
                      offset: Offset(0, _ticketY.value),
                      child: Transform.rotate(
                        angle: _ticketRotate.value,
                        child: Transform.scale(
                          scale: _ticketScale.value,
                          child: Opacity(
                            opacity: _ticketOpacity.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow behind ticket
                                Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _burgundy.withValues(alpha: .6),
                                        blurRadius: 60,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                // Ticket SVG
                                SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: CustomPaint(
                                    painter: _TicketPainter(
                                      scanProgress: _scanLine.value,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Text reveal
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo wordmark
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -2.5,
                                  height: 1,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'tkts',
                                    style: TextStyle(color: _ivory),
                                  ),
                                  TextSpan(
                                    text: 'app',
                                    style: TextStyle(color: _burgundy),
                                  ),
                                  TextSpan(
                                    text: '.',
                                    style: TextStyle(color: _gold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // SCANNER badge
                            ScaleTransition(
                              scale: _badgeScale,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _gold.withValues(alpha: .5),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                  color: _gold.withValues(alpha: .1),
                                ),
                                child: Text(
                                  'SCANNER',
                                  style: TextStyle(
                                    color: _gold,
                                    letterSpacing: 4,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    shadows: [
                                      Shadow(
                                        color: _gold.withValues(alpha: .4),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Ticket CustomPainter (SVG-equivalent drawn in canvas) ──
class _TicketPainter extends CustomPainter {
  const _TicketPainter({required this.scanProgress});
  final double scanProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: .5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final ticketRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx + 4, cy + 6),
        width: w * .82,
        height: h * .52,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(ticketRect, shadowPaint);

    // Ticket body
    final ticketRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: w * .82, height: h * .52),
      const Radius.circular(14),
    );
    final ticketPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, const Color(0xFFEAE3DB)],
      ).createShader(ticketRRect.outerRect);
    canvas.drawRRect(ticketRRect, ticketPaint);

    // Notch cutouts
    final notchPaint = Paint()
      ..color = const Color(0xFF1A0008)
      ..blendMode = BlendMode.srcOver;
    final nr = h * .12;
    // Left notch
    canvas.drawCircle(Offset(cx - w * .41, cy), nr, notchPaint);
    // Right notch
    canvas.drawCircle(Offset(cx + w * .41, cy), nr, notchPaint);

    // Perforation dots
    final dotPaint = Paint()
      ..color = const Color(0xFF541627).withValues(alpha: .5);
    final dotR = h * .025;
    final dotY = cy;
    final dotSpacing = w * .065;
    for (
      double dx = cx - dotSpacing * 1.5;
      dx <= cx + dotSpacing * 2;
      dx += dotSpacing
    ) {
      canvas.drawCircle(Offset(dx, dotY), dotR, dotPaint);
    }

    // Scan line sweep
    if (scanProgress > 0) {
      final scanY =
          (ticketRRect.outerRect.top) +
          ticketRRect.outerRect.height * scanProgress;
      final scanPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _gold.withValues(alpha: 0),
            _gold.withValues(alpha: .9),
            _gold.withValues(alpha: 0),
          ],
        ).createShader(ticketRRect.outerRect)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(ticketRRect.outerRect.left, scanY),
        Offset(ticketRRect.outerRect.right, scanY),
        scanPaint,
      );
      // Glow below scan line
      final glowPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _gold.withValues(alpha: .15),
                _gold.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromLTWH(
                ticketRRect.outerRect.left,
                scanY,
                ticketRRect.outerRect.width,
                20,
              ),
            );
      canvas.drawRect(
        Rect.fromLTWH(
          ticketRRect.outerRect.left,
          scanY,
          ticketRRect.outerRect.width,
          20,
        ),
        glowPaint,
      );
    }

    // QR scan bracket corners below ticket
    final bracketTop = ticketRRect.outerRect.bottom + h * .1;
    final bracketH = h * .14;
    final bracketW = w * .3;
    final bl = h * .045;
    final lw = h * .018;
    final goldPaint = Paint()
      ..color = _gold
      ..strokeWidth = lw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Left bracket
    canvas.drawPath(
      Path()
        ..moveTo(cx - bracketW / 2 + bl, bracketTop)
        ..lineTo(cx - bracketW / 2, bracketTop)
        ..lineTo(cx - bracketW / 2, bracketTop + bl),
      goldPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - bracketW / 2 + bl, bracketTop + bracketH)
        ..lineTo(cx - bracketW / 2, bracketTop + bracketH)
        ..lineTo(cx - bracketW / 2, bracketTop + bracketH - bl),
      goldPaint,
    );
    // Right bracket
    canvas.drawPath(
      Path()
        ..moveTo(cx + bracketW / 2 - bl, bracketTop)
        ..lineTo(cx + bracketW / 2, bracketTop)
        ..lineTo(cx + bracketW / 2, bracketTop + bl),
      goldPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx + bracketW / 2 - bl, bracketTop + bracketH)
        ..lineTo(cx + bracketW / 2, bracketTop + bracketH)
        ..lineTo(cx + bracketW / 2, bracketTop + bracketH - bl),
      goldPaint,
    );
  }

  @override
  bool shouldRepaint(_TicketPainter old) => old.scanProgress != scanProgress;
}

// ── Orbiting particles ──
class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.progress, required this.opacity});
  final double progress;
  final double opacity;

  static const _count = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2 - 40;
    final rng = math.Random(42);

    for (int i = 0; i < _count; i++) {
      final angle =
          (i / _count) * math.pi * 2 +
          progress * math.pi * 2 * (i.isEven ? 1 : -1) * 0.18;
      final radius = 100.0 + rng.nextDouble() * 60;
      final px = cx + math.cos(angle) * radius;
      final py = cy + math.sin(angle) * radius * 0.45;
      final ptSize = 1.5 + rng.nextDouble() * 2.5;
      final ptOpacity = (0.15 + rng.nextDouble() * 0.3) * opacity;
      canvas.drawCircle(
        Offset(px, py),
        ptSize,
        Paint()..color = _gold.withValues(alpha: ptOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.progress != progress || old.opacity != opacity;
}

// ─────────────────────────────────────────────
// Brand Mark (used on login screen + elsewhere)
// ─────────────────────────────────────────────
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.light = false, this.subtitle});
  final bool light;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = light ? _ivory : _charcoal;
    final textColor = light ? _ivory : const Color(0xFF2D1A0E);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ticket icon badge — SVG-drawn via CustomPaint
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _burgundy.withValues(alpha: .45),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              // Icon background
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFF6B1E35), Color(0xFF3D0E1A)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _gold.withValues(alpha: .25),
                    width: 1,
                  ),
                ),
              ),
              // Ticket drawn
              SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(painter: _TicketPainter(scanProgress: 0)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RichText(
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -2,
            ),
            children: [
              TextSpan(
                text: 'tkts',
                style: TextStyle(color: color),
              ),
              TextSpan(
                text: 'app',
                style: TextStyle(color: light ? _burgundy : _burgundy),
              ),
              const TextSpan(
                text: '.',
                style: TextStyle(color: _gold),
              ),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _gold.withValues(alpha: .4)),
            ),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: _gold,
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({
    super.key,
    required this.api,
    required this.onSignedIn,
  });
  final ApiClient api;
  final Future<void> Function(StaffSession) onSignedIn;

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _working = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _working = true);
    try {
      final response = await widget.api.post(
        '/mobile/auth/staff/login',
        data: {
          'login': _email.text.trim().toLowerCase(),
          'password': _password.text,
          'device_name': 'TKTSAPP Scanner',
        },
      );
      if (!mounted) return;
      if (response['requires_two_factor'] == true) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TwoFactorScreen(
              api: widget.api,
              login: response,
              onSignedIn: widget.onSignedIn,
            ),
          ),
        );
        return;
      }
      await _complete(response);
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _complete(Map<String, dynamic> response) async {
    final token = response['access_token']?.toString();
    final rawUser = response['user'];
    if (token == null || rawUser is! Map)
      throw const ApiFailure('The server did not return a staff session.');
    await widget.onSignedIn(
      StaffSession(token, Map<String, dynamic>.from(rawUser)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _oxblood,
    body: Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF260A11), Color(0xFF3D1020), Color(0xFF1A0008)],
            ),
          ),
        ),
        // Decorative circle top
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _burgundy.withValues(alpha: .18),
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          left: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: .07),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    const _BrandMark(light: true, subtitle: 'SCANNER'),
                    const SizedBox(height: 40),
                    // Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _ivory,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .35),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Staff sign in',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _charcoal,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Use your assigned organizer work email.',
                            style: TextStyle(
                              color: Color(0xFF6E6863),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: const InputDecoration(
                                    labelText: 'Work email',
                                    prefixIcon: Icon(
                                      Icons.alternate_email_rounded,
                                    ),
                                  ),
                                  validator: (value) =>
                                      value != null && value.contains('@')
                                      ? null
                                      : 'Enter your work email.',
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: (_) => _login(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (value) =>
                                      (value?.isNotEmpty ?? false)
                                      ? null
                                      : 'Enter your password.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _working ? null : _login,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              backgroundColor: _burgundy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _working
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign in securely',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _working
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => QuickScannerLoginPage(
                                        api: widget.api,
                                        onSignedIn: widget.onSignedIn,
                                      ),
                                    ),
                                  ),
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text('Quick login with Event QR'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              foregroundColor: _burgundy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SecurityNote(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class QuickScannerLoginPage extends StatefulWidget {
  const QuickScannerLoginPage({
    super.key,
    required this.api,
    required this.onSignedIn,
  });
  final ApiClient api;
  final Future<void> Function(StaffSession) onSignedIn;
  @override
  State<QuickScannerLoginPage> createState() => _QuickScannerLoginPageState();
}

class _QuickScannerLoginPageState extends State<QuickScannerLoginPage> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _working = false;
  Future<void> _detect(BarcodeCapture capture) async {
    if (_working) return;
    final value = capture.barcodes.isEmpty
        ? ''
        : (capture.barcodes.first.rawValue?.trim() ?? '');
    if (!value.startsWith('TKTSAPP_SCANNER_LOGIN:')) return;
    setState(() => _working = true);
    await _camera.stop();
    try {
      final response = await widget.api.post(
        '/mobile/auth/staff/quick-login',
        data: {'qr_payload': value, 'device_name': 'TKTSAPP Scanner'},
      );
      final token = response['access_token']?.toString();
      if (token == null || response['user'] is! Map)
        throw const ApiFailure(
          'The QR code could not start a scanner session.',
        );
      await widget.onSignedIn(
        StaffSession(token, Map<String, dynamic>.from(response['user'] as Map)),
      );
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
      await _camera.start();
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: _charcoal,
      foregroundColor: Colors.white,
      title: const Text('Quick event login'),
    ),
    body: Stack(
      children: [
        MobileScanner(controller: _camera, onDetect: _detect),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: _gold, width: 3),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 42,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _working
                  ? 'Signing in securely…'
                  : 'Scan the Event Quick Login QR from the organizer dashboard.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({
    super.key,
    required this.api,
    required this.login,
    required this.onSignedIn,
  });
  final ApiClient api;
  final Map<String, dynamic> login;
  final Future<void> Function(StaffSession) onSignedIn;
  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());
  bool _working = false;
  int _seconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _seconds = 0);
      } else if (mounted)
        setState(() => _seconds--);
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length != 6 || _working) return;
    setState(() => _working = true);
    try {
      final response = await widget.api.post(
        '/mobile/auth/staff/two-factor/verify',
        data: {
          'challenge_token': widget.login['challenge_token'],
          'code': _code,
        },
      );
      final token = response['access_token']?.toString();
      final rawUser = response['user'];
      if (token == null || rawUser is! Map)
        throw const ApiFailure('The verification response was incomplete.');
      await widget.onSignedIn(
        StaffSession(token, Map<String, dynamic>.from(rawUser)),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiFailure catch (error) {
      for (final controller in _controllers) {
        controller.clear();
      }
      _focus.first.requestFocus();
      if (mounted) _message(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0) return;
    try {
      final response = await widget.api.post(
        '/mobile/auth/staff/two-factor/resend',
        data: {'challenge_token': widget.login['challenge_token']},
      );
      _startTimer();
      if (mounted)
        _message(
          context,
          response['message']?.toString() ?? 'A new code was sent.',
        );
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.verified_user_outlined,
              size: 54,
              color: _burgundy,
            ),
            const SizedBox(height: 24),
            Text(
              'Verify it’s you',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.login['method'] == 'sms'
                  ? 'Enter the 6-digit code sent to ${widget.login['masked_destination'] ?? 'your phone'}.'
                  : 'Enter the current 6-digit code from your authenticator app.',
            ),
            const SizedBox(height: 34),
            Row(
              children: List.generate(
                6,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focus[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(counterText: ''),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focus[index + 1].requestFocus();
                        }
                        if (_code.length == 6) _verify();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _working || _code.length != 6 ? null : _verify,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _burgundy,
              ),
              child: _working
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verify and continue'),
            ),
            if (widget.login['method'] == 'sms') ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _seconds == 0 ? _resend : null,
                child: Text(
                  _seconds == 0
                      ? 'Resend code'
                      : 'Resend available in ${_seconds}s',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class StaffShell extends StatefulWidget {
  const StaffShell({
    super.key,
    required this.api,
    required this.session,
    required this.onSignOut,
    required this.onSessionUpdated,
  });
  final ApiClient api;
  final StaffSession session;
  final Future<void> Function() onSignOut;
  final Future<void> Function(StaffSession) onSessionUpdated;
  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    // Role-based navigation
    final isScanner = widget.session.role == 'scanner';
    final pages = <Widget>[
      OverviewPage(
        api: widget.api,
        session: widget.session,
      ), // Home (Analytics for managers, standard for others)
      if (!isScanner) EventsPage(api: widget.api, session: widget.session),
      if (widget.session.canScan)
        ScannerPage(
          api: widget.api,
          session: widget.session,
          onBack: () => setState(() => _index = 0),
        ),
      if (widget.session.canManageTeam) TeamPage(api: widget.api),
      ProfilePage(
        api: widget.api,
        session: widget.session,
        onSignOut: widget.onSignOut,
        onSessionUpdated: widget.onSessionUpdated,
      ),
    ];

    final items = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Home',
      ),
      if (!isScanner)
        const NavigationDestination(
          icon: Icon(Icons.event_note_outlined),
          selectedIcon: Icon(Icons.event_note_rounded),
          label: 'Events',
        ),
      if (widget.session.canScan)
        const NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_outlined),
          selectedIcon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Scan',
        ),
      if (widget.session.canManageTeam)
        const NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups_rounded),
          label: 'Team',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Account',
      ),
    ];

    if (_index >= pages.length) _index = 0;

    return Scaffold(
      backgroundColor: _ivory,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(.025, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _gold, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A5C061F),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: items,
          backgroundColor: Colors.white,
          indicatorColor: _gold.withValues(alpha: .16),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              letterSpacing: .15,
            ),
          ),
        ),
      ),
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.api, required this.session});
  final ApiClient api;
  final StaffSession session;

  @override
  Widget build(BuildContext context) {
    // Kept as a server-controlled escape hatch while the new Home rolls out.
    // No API currently enables it, so all staff get Operations Pulse.
    final isManagerOrAnalyst = session.user['legacy_home'] != true;

    if (isManagerOrAnalyst) {
      return _AnalyticsDashboard(api: api, session: session);
    }

    return _PageFrame(
      title: _greeting(session.user['name']?.toString()),
      subtitle: _roleLabel(session.role),
      child: FutureBuilder<Map<String, dynamic>>(
        future: api.get(
          session.isAdmin
              ? '/mobile/admin/dashboard'
              : '/mobile/staff/dashboard',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const _Skeleton();
          if (snapshot.hasError)
            return _Retry(onRetry: () => (context as Element).markNeedsBuild());

          final data = Map<String, dynamic>.from(
            snapshot.data?['data'] as Map? ?? const {},
          );
          final rows = data.entries
              .where((entry) => entry.key != 'user' && entry.value != null)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SecurityBanner(role: session.role),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.sizeOf(context).width > 640 ? 3 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: rows
                    .map(
                      (row) =>
                          _Metric(label: row.key, value: _value(row.value)),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Today’s operating principle',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan only after selecting the right event and station. Every validation is checked live against the ticket, event and session rules.',
                style: TextStyle(color: Color(0xFF6E6863)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsDashboard extends StatefulWidget {
  const _AnalyticsDashboard({required this.api, required this.session});
  final ApiClient api;
  final StaffSession session;

  @override
  State<_AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<_AnalyticsDashboard> {
  List<Map<String, dynamic>> _events = [];
  String? _selectedEventId;
  Map<String, dynamic>? _dashboardData;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      // 1. Fetch events
      final eventsRes = await widget.api.get('/mobile/staff/events');
      final eventsList = (eventsRes['data'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      _events = eventsList;
      if (_events.isNotEmpty && _selectedEventId == null) {
        _selectedEventId = _events.first['id']?.toString();
      }

      // Always start from the scoped workspace summary. Scanner-only accounts
      // never receive organizer revenue and are kept on this safe data set.
      final summaryRes = await widget.api.get(
        widget.session.isAdmin
            ? '/mobile/admin/dashboard'
            : '/mobile/staff/dashboard',
      );
      _dashboardData = Map<String, dynamic>.from(
        summaryRes['data'] as Map? ?? const {},
      );

      // Enrich the selected event only for roles authorized to view analytics.
      if (_selectedEventId != null && widget.session.canSeeAnalytics) {
        final detailRes = await widget.api.get(
          '/mobile/staff/events/$_selectedEventId',
        );
        final details = Map<String, dynamic>.from(
          detailRes['data'] as Map? ?? {},
        );
        final analytics = Map<String, dynamic>.from(
          details['analytics'] as Map? ?? {},
        );
        _dashboardData!.addAll(analytics);
        _dashboardData!.addAll({
          'event_name': details['name'],
          'venue_name': (details['venue'] as Map?)?['name'],
          'event_capacity': details['capacity'],
        });
      }
    } catch (e) {
      _error = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'Operations pulse',
      subtitle: 'A focused view of your event floor in real time.',
      action: IconButton(
        onPressed: _loadData,
        icon: const Icon(Icons.refresh_rounded, color: _burgundy),
      ),
      child: _loading
          ? const _Skeleton(count: 4)
          : _error
          ? _Retry(onRetry: _loadData)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_dashboardData != null) ...[
                  _OperationsHero(
                    name: widget.session.user['name']?.toString(),
                    role: widget.session.role,
                    eventName: _dashboardData!['event_name']?.toString(),
                    venueName: _dashboardData!['venue_name']?.toString(),
                    canScan: widget.session.canScan,
                  ),
                  const SizedBox(height: 20),
                  if (_events.isNotEmpty) ...[
                    _EventPulseSelector(
                      events: _events,
                      selectedEventId: _selectedEventId,
                      onChanged: (value) {
                        setState(() => _selectedEventId = value);
                        _loadData();
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  _PulseMetricGrid(
                    data: _dashboardData!,
                    showRevenue: widget.session.canSeeAnalytics,
                  ),
                  const SizedBox(height: 20),
                  _ReadinessCard(
                    attendees: _asInt(
                      _dashboardData!['total_attendees'] ??
                          _dashboardData!['tickets_sold'] ??
                          _dashboardData!['tickets'],
                    ),
                    attended: _asInt(_dashboardData!['total_attended']),
                    devices: _asInt(_dashboardData!['scanner_devices']),
                    capacity: _asInt(_dashboardData!['event_capacity']),
                    canScan: widget.session.canScan,
                  ),
                  const SizedBox(height: 20),
                  _SecurityBanner(role: widget.session.role),
                ],
              ],
            ),
    );
  }
}

class _OperationsHero extends StatelessWidget {
  const _OperationsHero({
    required this.name,
    required this.role,
    required this.eventName,
    required this.venueName,
    required this.canScan,
  });
  final String? name;
  final String role;
  final String? eventName;
  final String? venueName;
  final bool canScan;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_oxblood, _primary, Color(0xFF7B2740)],
      ),
      boxShadow: [
        BoxShadow(
          color: _primary.withValues(alpha: .24),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: .6)),
          ),
          child: Icon(
            canScan ? Icons.qr_code_scanner_rounded : Icons.insights_rounded,
            color: _gold,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(name),
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                eventName?.isNotEmpty == true
                    ? eventName!
                    : 'Your assigned event workspace',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (venueName?.isNotEmpty == true) ...[
                const SizedBox(height: 3),
                Text(
                  venueName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _gold.withValues(alpha: .95),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        const _LiveChip(label: 'LIVE'),
      ],
    ),
  );
}

class _EventPulseSelector extends StatelessWidget {
  const _EventPulseSelector({
    required this.events,
    required this.selectedEventId,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> events;
  final String? selectedEventId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _gold.withValues(alpha: .38)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedEventId,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded, color: _primary),
        items: events
            .map(
              (event) => DropdownMenuItem(
                value: event['id']?.toString(),
                child: Text(
                  event['name']?.toString() ?? 'Untitled event',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    ),
  );
}

class _PulseMetricGrid extends StatelessWidget {
  const _PulseMetricGrid({required this.data, required this.showRevenue});
  final Map<String, dynamic> data;
  final bool showRevenue;

  @override
  Widget build(BuildContext context) {
    final attendees = _asInt(
      data['total_attendees'] ?? data['tickets_sold'] ?? data['tickets'],
    );
    final attended = _asInt(data['total_attended']);
    final devices = _asInt(data['scanner_devices']);
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LIVE OPERATIONS',
          style: TextStyle(
            color: _smoke,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        _PulseHeroMetric(attendees: attendees, attended: attended),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PulseMiniMetric(
                label: 'Total attended',
                value: _value(attended),
                caption: attendees > 0
                    ? '${((attended / attendees) * 100).round()}% checked in'
                    : 'Waiting for arrivals',
                icon: Icons.how_to_reg_rounded,
                color: _success,
                compact: compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PulseMiniMetric(
                label: 'Scanner fleet',
                value: _value(devices),
                caption: devices == 1 ? 'Device online' : 'Devices online',
                icon: Icons.sensors_rounded,
                color: _success,
                compact: compact,
              ),
            ),
          ],
        ),
        if (showRevenue) ...[
          const SizedBox(height: 12),
          _PulseRevenueMetric(value: 'EGP ${_value(data['revenue'])}'),
        ],
      ],
    );
  }
}

class _PulseHeroMetric extends StatelessWidget {
  const _PulseHeroMetric({required this.attendees, required this.attended});
  final int attendees;
  final int attended;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 520);
    return Container(
      height: 144,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_primary, _oxblood],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: .22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -31,
            top: -57,
            child: Container(
              height: 177,
              width: 177,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .13),
                  width: 28,
                ),
              ),
            ),
          ),
          Positioned(
            right: 22,
            bottom: 19,
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white.withValues(alpha: .18),
              size: 54,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _LiveChip(label: 'LIVE'),
                    SizedBox(width: 8),
                    Text(
                      'TOTAL ATTENDEES',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: attendees.toDouble()),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Text(
                    _value(value.round()),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 35,
                      height: .95,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$attended checked in so far',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

class _PulseMiniMetric extends StatelessWidget {
  const _PulseMiniMetric({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.compact,
  });
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 13 : 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: .16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_outward_rounded,
              color: _smoke.withValues(alpha: .55),
              size: 16,
            ),
          ],
        ),
        SizedBox(height: compact ? 11 : 14),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: compact ? 23 : 26,
            height: 1,
            fontWeight: FontWeight.w800,
            color: _charcoal,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _charcoal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: _smoke),
        ),
      ],
    ),
  );
}

class _PulseRevenueMetric extends StatelessWidget {
  const _PulseRevenueMetric({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFAF1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _gold.withValues(alpha: .38)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: .17),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: _gold,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gross sales',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 2),
              Text(
                'Selected-event revenue',
                style: TextStyle(fontSize: 10, color: _smoke),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: _charcoal,
          ),
        ),
      ],
    ),
  );
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.attendees,
    required this.attended,
    required this.devices,
    required this.capacity,
    required this.canScan,
  });
  final int attendees;
  final int attended;
  final int devices;
  final int capacity;
  final bool canScan;

  @override
  Widget build(BuildContext context) {
    final progress = attendees > 0
        ? (attended / attendees).clamp(0.0, 1.0)
        : 0.0;
    final label = attendees > 0
        ? '${(progress * 100).round()}% attendance right now'
        : 'Waiting for the first attendee';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  canScan ? Icons.radar_rounded : Icons.monitor_heart_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Floor readiness',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              _LiveChip(label: devices > 0 ? '$devices ONLINE' : 'SETUP'),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: _primary,
              backgroundColor: _gold.withValues(alpha: .2),
            ),
          ),
          const SizedBox(height: 9),
          Text(label, style: const TextStyle(color: _smoke, fontSize: 12)),
          const SizedBox(height: 14),
          Text(
            '$attended of $attendees attendees have been checked in.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _charcoal,
            ),
          ),
        ],
      ),
    );
  }
}

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.api, required this.session});
  final ApiClient api;
  final StaffSession session;
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.api.get('/mobile/staff/events');
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'My Events',
    subtitle: 'Manage the schedule, capacity and access assigned to you.',
    action: IconButton(
      onPressed: () =>
          setState(() => _future = widget.api.get('/mobile/staff/events')),
      icon: const Icon(Icons.refresh_rounded),
    ),
    child: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _Skeleton(count: 4);
        if (snapshot.hasError)
          return _Retry(
            onRetry: () => setState(
              () => _future = widget.api.get('/mobile/staff/events'),
            ),
          );
        final events = (snapshot.data?['data'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        if (events.isEmpty)
          return const _Empty(
            icon: Icons.event_busy_outlined,
            title: 'No event assignments',
            message:
                'An organizer owner can assign this account to its events.',
          );
        return Column(
          children: events
              .map(
                (event) => _EventCard(
                  api: widget.api,
                  event: event,
                  session: widget.session,
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.api,
    required this.event,
    required this.session,
  });
  final ApiClient api;
  final Map<String, dynamic> event;
  final StaffSession session;

  @override
  Widget build(BuildContext context) {
    final imgUrl =
        event['event_image_path']?.toString() ??
        event['image_path']?.toString();
    final hasImage = imgUrl != null && imgUrl.startsWith('http');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: _ivory,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _gold.withValues(alpha: .2), width: 1),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  EventDetailPage(api: api, event: event, session: session),
            ),
          ),
          splashColor: _burgundy.withValues(alpha: .15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image strip or gradient placeholder
              Stack(
                children: [
                  if (hasImage)
                    Image.network(
                      imgUrl,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _EventCardPlaceholder(),
                    )
                  else
                    _EventCardPlaceholder(),
                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            _ivory.withValues(alpha: .95),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Date badge top right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: _gold.withValues(alpha: .35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _date(event['starts_at']),
                        style: const TextStyle(
                          color: _burgundy,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Info row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['name']?.toString() ?? 'Event',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _charcoal,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 12,
                                color: Color(0xFF8A7870),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  event['venue']?['name'] ?? 'Venue TBA',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF8A7870),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _gold.withValues(alpha: .3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: _burgundy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCardPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 110,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_burgundy.withValues(alpha: .1), _gold.withValues(alpha: .05)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.confirmation_number_outlined,
        color: _burgundy.withValues(alpha: .15),
        size: 42,
      ),
    ),
  );
}

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({
    super.key,
    required this.api,
    required this.event,
    required this.session,
  });
  final ApiClient api;
  final Map<String, dynamic> event;
  final StaffSession session;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Event access')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: api.get('/mobile/staff/events/${event['id']}'),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Padding(
            padding: EdgeInsets.all(20),
            child: _Skeleton(count: 3),
          );
        if (snapshot.hasError)
          return const Center(
            child: _Empty(
              icon: Icons.lock_outline_rounded,
              title: 'Access unavailable',
              message: 'This event is no longer assigned to your account.',
            ),
          );
        final details = Map<String, dynamic>.from(
          snapshot.data?['data'] as Map? ?? event,
        );
        final permissions = Map<String, dynamic>.from(
          details['permissions'] as Map? ?? const {},
        );
        final sessions = details['sessions'] as List? ?? const [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              details['name']?.toString() ?? 'Event',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${details['venue']?['name'] ?? 'Venue TBA'} • ${_date(details['starts_at'])}',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: permissions.entries
                  .where((item) => item.value == true)
                  .map(
                    (item) =>
                        Chip(label: Text(item.key.toString().toUpperCase())),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sessions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...sessions.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(item['name']?.toString() ?? 'Session'),
                  subtitle: Text(_date(item['starts_at'])),
                ),
              );
            }),
            if (details['analytics'] is Map) ...[
              const SizedBox(height: 18),
              const Text(
                'Attendance overview',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ...Map<String, dynamic>.from(
                details['analytics'] as Map,
              ).entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key.replaceAll('_', ' ')),
                  trailing: Text(
                    _value(entry.value),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({
    super.key,
    required this.api,
    required this.session,
    this.onBack,
  });
  final ApiClient api;
  final StaffSession session;
  final VoidCallback? onBack;
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _hardwareFocusNode = FocusNode();
  final _hardwareController = TextEditingController();
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _devices = const [];
  Map<String, dynamic>? _event;
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _fallbackSession;
  Map<String, dynamic>? _device;
  String _action = 'checkin';
  bool _autoAdmit = true;
  bool _useCamera = true;
  bool _loading = true;
  bool _processing = false;
  bool _isScanning = false;

  List<Map<String, dynamic>> get _sessions {
    final raw = _event?['sessions'];
    final sessions = raw is List
        ? raw.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    if (sessions.isNotEmpty) return sessions;
    final startsAt = _event?['starts_at']?.toString();
    return startsAt == null
        ? const []
        : [
            _fallbackSession ??= {
              'id': null,
              'name': 'Main session',
              'starts_at': startsAt,
            },
          ];
  }

  // Station is resolved automatically for the selected event/session.
  bool get _canStart => _event != null && _session != null;

  String _eventValue(Map<String, dynamic> event) => event['id'].toString();

  String _sessionValue(Map<String, dynamic> session) =>
      '${session['id'] ?? 'main'}:${session['starts_at'] ?? session['name'] ?? ''}';

  String _stationValue(Map<String, dynamic> station) =>
      station['id'].toString();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _camera.dispose();
    _hardwareFocusNode.dispose();
    _hardwareController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final response = await widget.api.get('/mobile/staff/events');
      _events = (response['data'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      // A scanner must be deliberately scoped; never silently select an event.
      _event = null;
      _session = null;
      _fallbackSession = null;
      _device = null;
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDevices() async {
    if (_event == null) {
      _devices = const [];
      _device = null;
      return;
    }
    final response = await widget.api.get(
      '/mobile/staff/events/${_event!['id']}/scanners',
    );
    _devices = (response['data'] as List? ?? const [])
        .where(
          (item) =>
              item['active'] == true &&
              (_session == null ||
                  item['event_session_id']?.toString() ==
                      _session!['id']?.toString()),
        )
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    _device = _devices.isEmpty ? null : _devices.first;
  }

  Future<void> _chooseEvent(Map<String, dynamic>? value) async {
    if (value == null) return;
    if (_isScanning) await _camera.stop();
    setState(() {
      _event = value;
      _session = null;
      _fallbackSession = null;
      _device = null;
      _isScanning = false;
    });
    await _loadDevices();
  }

  Future<void> _chooseSession(Map<String, dynamic>? value) async {
    if (value == null) return;
    if (_isScanning) await _camera.stop();
    setState(() {
      _session = value;
      _device = null;
      _isScanning = false;
    });
    await _loadDevices();
  }

  Future<void> _startScanning() async {
    if (!_canStart) return;
    if (_device == null) {
      await _loadDevices();
      if (_device == null &&
          (widget.session.isAdmin ||
              widget.session.isOwner ||
              widget.session.role == 'manager')) {
        await _createStation();
      }
      if (_device == null) {
        if (mounted) {
          _message(
            context,
            'No active scanner station is assigned to this session.',
            error: true,
          );
        }
        return;
      }
    }
    setState(() => _isScanning = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await _camera.start();
  }

  Future<void> _leaveScanner() async {
    if (_isScanning) await _camera.stop();
    if (!mounted) return;
    setState(() => _isScanning = false);
    widget.onBack?.call();
  }

  String _sessionLabel(Map<String, dynamic> session) {
    final name = session['name']?.toString() ?? 'Session';
    final raw = session['starts_at']?.toString();
    final startsAt = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (startsAt == null) return name;
    final hour = startsAt.hour % 12 == 0 ? 12 : startsAt.hour % 12;
    final minute = startsAt.minute.toString().padLeft(2, '0');
    final period = startsAt.hour >= 12 ? 'PM' : 'AM';
    return '$name • ${startsAt.day}/${startsAt.month} $hour:$minute $period';
  }

  Future<void> _createStation() async {
    if (_event == null || _session == null) return;
    try {
      await widget.api.post(
        '/mobile/staff/events/${_event!['id']}/scanners',
        data: {'label': 'TKTSAPP Scanner', 'event_session_id': _session!['id']},
      );
      await _loadDevices();
      if (mounted) {
        setState(() {});
        _message(context, 'Scanner station is ready for this event.');
      }
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
    }
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (_processing ||
        _event == null ||
        _device == null ||
        capture.barcodes.isEmpty)
      return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    await _processScan(value, _action, isInitial: true);
  }

  Future<void> _processScan(
    String value,
    String currentAction, {
    bool isInitial = false,
  }) async {
    setState(() => _processing = true);
    if (_useCamera && _isScanning) await _camera.stop();

    // If auto-admit is off, the first scan is always just 'validate'.
    final apiAction = (isInitial && !_autoAdmit && currentAction != 'validate')
        ? 'validate'
        : currentAction;

    try {
      final response = await widget.api.post(
        '/mobile/staff/events/${_event!['id']}/scan',
        data: {
          'scanner_device_id': _device!['id'],
          'action': apiAction,
          'qr_raw': value,
          'idempotency_key': const Uuid().v4(),
        },
      );
      if (!mounted) return;
      final result = Map<String, dynamic>.from(
        response['data'] as Map? ?? const {},
      );

      final isValid = result['status'] == 'valid';
      await _scanFeedback(success: isValid);
      if (isInitial && !_autoAdmit && currentAction != 'validate' && isValid) {
        await _showResult(
          result,
          onAdmit: () async {
            Navigator.pop(context); // Close the validate sheet
            await _processScan(value, currentAction, isInitial: false);
          },
        );
      } else {
        await _showResult(result);
      }
    } on ApiFailure catch (error) {
      await _scanFeedback(success: false);
      if (mounted) _message(context, error.message, error: true);
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        if (_useCamera && _isScanning) await _camera.start();
      }
    }
  }

  Future<void> _scanFeedback({required bool success}) async {
    if (success) {
      await Future.wait<void>([
        SystemSound.play(SystemSoundType.click),
        HapticFeedback.mediumImpact(),
      ]);
      return;
    }

    await Future.wait<void>([
      SystemSound.play(SystemSoundType.alert),
      HapticFeedback.heavyImpact(),
    ]);
  }

  Future<void> _showResult(
    Map<String, dynamic> result, {
    Future<void> Function()? onAdmit,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: onAdmit == null,
    enableDrag: onAdmit == null,
    builder: (context) {
      final valid = result['status'] == 'valid';
      final ticket = Map<String, dynamic>.from(
        result['ticket'] as Map? ?? const {},
      );
      return _ScanResultSheet(
        valid: valid,
        result: result,
        ticket: ticket,
        onAdmit: onAdmit,
      );
    },
  );

  Future<void> _openSettings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: _ivory,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33181416),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Scanner settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Changing this pauses the camera so tickets cannot be scanned on the wrong session.',
                style: TextStyle(color: Color(0xFF6E6863)),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: ValueKey('scan-event-${_event?['id']}'),
                initialValue: _event == null ? null : _eventValue(_event!),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Event'),
                items: _events
                    .map(
                      (event) => DropdownMenuItem<String>(
                        value: _eventValue(event),
                        child: Text(
                          event['name']?.toString() ?? 'Event',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  final matches = _events
                      .where((item) => _eventValue(item) == value)
                      .toList();
                  final event = matches.isEmpty ? null : matches.first;
                  await _chooseEvent(event);
                  setSheetState(() {});
                  if (mounted) {
                    setState(() {});
                    setSheetState(() {});
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'scan-session-${_event?['id']}-${_session?['id']}',
                ),
                initialValue: _session == null
                    ? null
                    : _sessionValue(_session!),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Date & time / session',
                ),
                hint: const Text('Choose the session you are working'),
                items: _sessions
                    .map(
                      (session) => DropdownMenuItem<String>(
                        value: _sessionValue(session),
                        child: Text(
                          _sessionLabel(session),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _event == null
                    ? null
                    : (value) async {
                        final matches = _sessions
                            .where((item) => _sessionValue(item) == value)
                            .toList();
                        final selected = matches.isEmpty ? null : matches.first;
                        await _chooseSession(selected);
                        setSheetState(() {});
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'scan-station-${_event?['id']}-${_device?['id']}',
                ),
                initialValue: _device == null ? null : _stationValue(_device!),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Scanner station'),
                items: _devices
                    .map(
                      (device) => DropdownMenuItem<String>(
                        value: _stationValue(device),
                        child: Text(
                          device['label']?.toString() ??
                              'Scanner ${device['id']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _session == null
                    ? null
                    : (value) {
                        final matches = _devices
                            .where((item) => _stationValue(item) == value)
                            .toList();
                        final selected = matches.isEmpty ? null : matches.first;
                        setState(() => _device = selected);
                        setSheetState(() {});
                      },
              ),
              if (_device == null && _event != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'No active station exists for this event.',
                  style: TextStyle(fontSize: 12, color: _red),
                ),
                if (widget.session.isAdmin ||
                    widget.session.isOwner ||
                    widget.session.role == 'manager')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        await _createStation();
                        setSheetState(() {});
                      },
                      child: const Text('Create station'),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Validation type',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'checkin',
                    icon: Icon(Icons.login_rounded),
                    label: Text('Entry'),
                  ),
                  ButtonSegment(
                    value: 'checkout',
                    icon: Icon(Icons.logout_rounded),
                    label: Text('Exit'),
                  ),
                  ButtonSegment(
                    value: 'validate',
                    icon: Icon(Icons.verified_outlined),
                    label: Text('Check only'),
                  ),
                ],
                selected: {_action},
                onSelectionChanged: (value) {
                  setState(() => _action = value.first);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text(
                'Admission flow',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SwitchListTile(
                title: const Text('Auto-admit valid tickets'),
                subtitle: const Text(
                  'If off, you must manually confirm entry.',
                ),
                value: _autoAdmit,
                activeThumbColor: _burgundy,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() => _autoAdmit = val);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Hardware',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SwitchListTile(
                title: const Text('Use device camera'),
                subtitle: const Text(
                  'Turn off if using a hardware barcode gun.',
                ),
                value: _useCamera,
                activeThumbColor: _burgundy,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() => _useCamera = val);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: !_canStart
                    ? null
                    : () async {
                        Navigator.pop(sheetContext);
                        await _startScanning();
                      },
                child: const Text('Apply & resume camera'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _isScanning ? _charcoal : _ivory,
    body: !_isScanning
        ? SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Back to Home',
                        onPressed: _leaveScanner,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: _StitchAppHeader()),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TERMINAL CONFIGURATION',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: _gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scanner Station Setup',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Configure terminal mode and validation rules before scanning.',
                    style: TextStyle(color: _smoke, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  // Stylized Scan Emblem / Scanner Target Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFEADFC9),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A5C061F),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x225C061F),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _gold.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Colors.white,
                                size: 54,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF9F6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _gold.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: _gold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'OPTIC ENGINE 4.2 READY',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: _gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  _ScannerSetupSummary(
                    event: _event,
                    session: _session,
                    device: _device,
                    action: _action,
                    loading: _loading,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('scanner-settings'),
                    onPressed: _loading ? null : _openSettings,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Configure Settings & Event'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _canStart ? _startScanning : null,
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    label: const Text('Open Full-Screen Camera'),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: _gold),
                      SizedBox(width: 6),
                      Text(
                        'Secured TLS Station Handshake Active',
                        style: TextStyle(
                          color: _smoke,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              if (!_loading && _event != null && _device != null)
                _useCamera
                    ? MobileScanner(controller: _camera, onDetect: _detect)
                    : ColoredBox(
                        color: _charcoal,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.usb_rounded,
                                size: 64,
                                color: _gold,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Hardware Scanner Ready',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Scan a ticket barcode to continue.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Opacity(
                                opacity: 0,
                                child: TextField(
                                  controller: _hardwareController,
                                  focusNode: _hardwareFocusNode,
                                  autofocus: true,
                                  onSubmitted: (value) async {
                                    _hardwareController.clear();
                                    if (value.isNotEmpty) {
                                      await _processScan(
                                        value,
                                        _action,
                                        isInitial: true,
                                      );
                                    }
                                    _hardwareFocusNode.requestFocus();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
              else
                const ColoredBox(color: _charcoal),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xAA000000),
                      Colors.transparent,
                      Color(0x99000000),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Back to Home',
                            onPressed: _leaveScanner,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live scanner',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Secure event validation',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            key: const Key('scanner-settings'),
                            tooltip: 'Scanner settings',
                            onPressed: _openSettings,
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (_useCamera) IgnorePointer(child: _ScannerBracket()),
                      const Spacer(),
                      _ScannerStatus(
                        event: _event,
                        device: _device,
                        action: _action,
                        loading: _loading,
                      ),
                    ],
                  ),
                ),
              ),
              if (_processing)
                const ColoredBox(
                  color: Color(0x99000000),
                  child: Center(child: CircularProgressIndicator(color: _gold)),
                ),
            ],
          ),
  );
}

class _ScannerSetupSummary extends StatelessWidget {
  const _ScannerSetupSummary({
    required this.event,
    required this.session,
    required this.device,
    required this.action,
    required this.loading,
  });
  final Map<String, dynamic>? event;
  final Map<String, dynamic>? session;
  final Map<String, dynamic>? device;
  final String action;
  final bool loading;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEADFC9), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A5C061F),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: loading
        ? const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primary,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Syncing terminal configuration…',
                style: TextStyle(color: _smoke),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _setupRow(
                Icons.event_outlined,
                'Active Event',
                event?['name']?.toString() ?? 'Not selected',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFEADFC9)),
              ),
              _setupRow(
                Icons.schedule_rounded,
                'Date & Session',
                session == null
                    ? 'Not selected'
                    : session!['name']?.toString() ?? 'Session',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFEADFC9)),
              ),
              _setupRow(
                Icons.fact_check_outlined,
                'Validation Mode',
                action == 'checkin'
                    ? 'Entry — validate and admit'
                    : action == 'checkout'
                    ? 'Exit — release capacity'
                    : 'Audit — check authenticity only',
              ),
              if (device != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFEADFC9)),
                ),
                _setupRow(
                  Icons.meeting_room_outlined,
                  'Station / Gate',
                  device!['label']?.toString() ?? 'Scanner station',
                ),
              ],
            ],
          ),
  );

  Widget _setupRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 20, color: _primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: _smoke,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: _charcoal,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ScannerStatus extends StatelessWidget {
  const _ScannerStatus({
    required this.event,
    required this.device,
    required this.action,
    required this.loading,
  });
  final Map<String, dynamic>? event;
  final Map<String, dynamic>? device;
  final String action;
  final bool loading;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x115C061F),
          blurRadius: 10,
          offset: Offset(0, -2),
        ),
      ],
    ),
    child: loading
        ? const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primary,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Syncing access controls…',
                style: TextStyle(color: _smoke, fontWeight: FontWeight.w500),
              ),
            ],
          )
        : event == null || device == null
        ? const Text(
            'Terminal not configured. Tap settings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _smoke, fontWeight: FontWeight.w500),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event!['name']?.toString() ?? 'Event',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: _charcoal,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F2ED),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      device!['label']?.toString().toUpperCase() ?? 'STATION',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _smoke,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    action == 'checkin'
                        ? 'ENTRY'
                        : action == 'checkout'
                        ? 'EXIT'
                        : 'VALIDATE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
  );
}

class _ScanResultSheet extends StatelessWidget {
  const _ScanResultSheet({
    required this.valid,
    required this.result,
    required this.ticket,
    this.onAdmit,
  });
  final bool valid;
  final Map<String, dynamic> result;
  final Map<String, dynamic> ticket;
  final Future<void> Function()? onAdmit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
    decoration: BoxDecoration(
      color: _ivory,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F4A0519),
          blurRadius: 30,
          offset: Offset(0, -4),
        ),
      ],
      border: Border(top: BorderSide(color: valid ? _green : _red, width: 4)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: _smoke.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedScale(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            scale: 1.0,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: valid
                    ? _green.withValues(alpha: 0.1)
                    : _red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 48,
                color: valid ? _green : _red,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result['message']?.toString() ??
                (valid ? 'Access Granted' : 'Access Denied'),
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: valid ? _green : _red,
            ),
          ),
          const SizedBox(height: 24),
          if (ticket.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEADFC9), width: 1),
              ),
              child: Column(
                children: [
                  _ResultLine(
                    'Holder',
                    ticket['recipient_name']?.toString() ?? 'Ticket holder',
                  ),
                  const Divider(height: 16, color: Color(0xFFEADFC9)),
                  _ResultLine(
                    'Ticket',
                    ticket['ticket_type']?['name']?.toString() ?? 'Ticket',
                  ),
                  const Divider(height: 16, color: Color(0xFFEADFC9)),
                  _ResultLine(
                    'Gate',
                    ticket['ticket_type']?['gate_label']?.toString() ??
                        'Gate TBA',
                  ),
                  if (ticket['session'] != null) ...[
                    const Divider(height: 16, color: Color(0xFFEADFC9)),
                    _ResultLine(
                      'Session',
                      ticket['session']?['name']?.toString() ?? 'Session',
                    ),
                  ],
                  if (ticket['seat_label'] != null) ...[
                    const Divider(height: 16, color: Color(0xFFEADFC9)),
                    _ResultLine('Seat', ticket['seat_label'].toString()),
                  ],
                ],
              ),
            ),
          ],
          if (onAdmit != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _green),
              onPressed: () {
                Navigator.pop(context);
                onAdmit!();
              },
              child: const Text('ADMIT GUEST'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _smoke,
                side: const BorderSide(color: _smoke, width: 1),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel & Close'),
            ),
          ] else ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CONTINUE SCANNING'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ResultLine extends StatelessWidget {
  const _ResultLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF6E6863))),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class TeamPage extends StatefulWidget {
  const TeamPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.api.get('/mobile/staff/team');
  }

  void _reload() =>
      setState(() => _future = widget.api.get('/mobile/staff/team'));
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Event team',
    subtitle:
        'Create staff accounts and grant only the event access they need.',
    action: IconButton(
      onPressed: _reload,
      icon: const Icon(Icons.refresh_rounded),
    ),
    child: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _Skeleton(count: 3);
        if (snapshot.hasError) return _Retry(onRetry: _reload);
        final members = (snapshot.data?['data'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CreateStaffPage(api: widget.api),
                  ),
                );
                if (changed == true) _reload();
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create staff account'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 16),
            if (members.isEmpty)
              const _Empty(
                icon: Icons.groups_outlined,
                title: 'No staff accounts yet',
                message:
                    'Add a manager, analyst or scanner and assign their exact event access.',
              ),
            ...members.map(
              (member) => _StaffMemberCard(
                member: member,
                api: widget.api,
                onChanged: _reload,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _StaffMemberCard extends StatelessWidget {
  const _StaffMemberCard({
    required this.member,
    required this.api,
    required this.onChanged,
  });
  final Map<String, dynamic> member;
  final ApiClient api;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(member['user'] as Map? ?? const {});
    final events = member['events'] as List? ?? const [];
    final active = member['active'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0x12541627),
                  foregroundColor: _burgundy,
                  child: Text(
                    (user['name']?.toString() ?? '?')
                        .substring(0, 1)
                        .toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name']?.toString() ?? 'Staff member',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        user['email']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6863),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: active,
                  onChanged: (_) async {
                    try {
                      await api.post(
                        '/mobile/staff/team/${member['id']}/toggle',
                      );
                      onChanged();
                    } on ApiFailure catch (e) {
                      if (context.mounted)
                        _message(context, e.message, error: true);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    member['role']?.toString().toUpperCase() ?? 'STAFF',
                  ),
                ),
                Chip(
                  label: Text(
                    '${events.length} assigned event${events.length == 1 ? '' : 's'}',
                  ),
                ),
                if (!active) const Chip(label: Text('PAUSED')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CreateStaffPage extends StatefulWidget {
  const CreateStaffPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<CreateStaffPage> createState() => _CreateStaffPageState();
}

class _CreateStaffPageState extends State<CreateStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  List<Map<String, dynamic>> _events = const [];
  final Set<int> _selected = {};
  String _role = 'scanner';
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await widget.api.get('/mobile/staff/events');
      _events = (response['data'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on ApiFailure catch (e) {
      if (mounted) _message(context, e.message, error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _selected.isEmpty) {
      if (_selected.isEmpty)
        _message(context, 'Assign at least one event.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.post(
        '/mobile/staff/team',
        data: {
          'name': _name.text.trim(),
          'email': _email.text.trim().toLowerCase(),
          'password': _password.text,
          'staff_role': _role,
          'event_ids': _selected.toList(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (e) {
      if (mounted) _message(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create staff account')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'A staff member can only access the events selected below. Scanner accounts cannot see financial data or buyer contact details.',
                  style: TextStyle(color: Color(0xFF6E6863)),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: (v) => (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Enter a name.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Work email',
                        ),
                        validator: (v) => v != null && v.contains('@')
                            ? null
                            : 'Enter a valid email.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Temporary password',
                        ),
                        validator: (v) => (v?.length ?? 0) >= 8
                            ? null
                            : 'Use at least 8 characters.',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                            value: 'scanner',
                            child: Text('Scanner — scan only'),
                          ),
                          DropdownMenuItem(
                            value: 'analyst',
                            child: Text('Analyst — read-only analytics'),
                          ),
                          DropdownMenuItem(
                            value: 'manager',
                            child: Text('Manager — operations'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _role = v ?? 'scanner'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Event access',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._events.map((event) {
                  final id = event['id'] as int;
                  return CheckboxListTile(
                    value: _selected.contains(id),
                    onChanged: (checked) => setState(
                      () => checked == true
                          ? _selected.add(id)
                          : _selected.remove(id),
                    ),
                    title: Text(event['name']?.toString() ?? 'Event'),
                    subtitle: Text(_date(event['starts_at'])),
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _burgundy,
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create staff account'),
                ),
              ],
            ),
          ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.session,
    required this.onSignOut,
    required this.onSessionUpdated,
  });
  final ApiClient api;
  final StaffSession session;
  final Future<void> Function() onSignOut;
  final Future<void> Function(StaffSession) onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    final method = session.user['two_factor_method']?.toString();
    final twoFactor = session.user['two_factor_enabled'] == true
        ? 'Enabled${method == null ? '' : ' ($method)'}'
        : 'Not enabled';
    return _PageFrame(
      title: 'Account & Terminal Settings',
      subtitle: 'Your secure TKTSAPP staff identity and station controls.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'TERMINAL',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SECURE STAFF IDENTITY',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .9,
                  color: _smoke,
                ),
              ),
              const Spacer(),
              const _LiveChip(label: 'ONLINE'),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            color: _charcoal,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.user['name']?.toString() ?? 'Staff member',
                    style: const TextStyle(
                      color: _ivory,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.user['email']?.toString() ?? '',
                    style: const TextStyle(color: Color(0xBDF4EFE8)),
                  ),
                  const SizedBox(height: 14),
                  Chip(
                    label: Text(_roleLabel(session.role).toUpperCase()),
                    backgroundColor: _gold,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _ProfileMetric(value: 'LIVE', label: 'Terminal sync'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ProfileMetric(value: '100%', label: 'Secure channel'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _ProfileMetric(value: 'TLS', label: 'Transport'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'SECURITY & HARDWARE IDENTITY',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Two-factor authentication',
                  subtitle: twoFactor,
                ),
                _SettingsTile(
                  icon: Icons.password_rounded,
                  title: 'Change password',
                  subtitle: 'Use your current password to secure this account',
                  onTap: () => _showStaffPasswordDialog(context, api),
                ),
                _SettingsTile(
                  icon: Icons.history_rounded,
                  title: 'Scan history',
                  subtitle: 'Serial, status and scan time only',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScanHistoryPage(api: api),
                    ),
                  ),
                ),
                const _SettingsTile(
                  icon: Icons.pin_outlined,
                  title: 'Passcode & terminal PIN',
                  subtitle: 'Managed by the secure web dashboard',
                ),
                const _SettingsTile(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Offline cache & encrypted sync',
                  subtitle: 'Realtime synchronization is active',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StitchAppHeader(),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _charcoal,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Color(0xFF6E6863)),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
        sliver: SliverToBoxAdapter(child: child),
      ),
    ],
  );
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _success.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        color: _success,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(color: _primary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _smoke, fontSize: 10)),
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: _primary),
    ),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: _smoke, fontSize: 11),
    ),
    trailing: Icon(
      Icons.chevron_right_rounded,
      color: onTap == null ? _smoke.withValues(alpha: .45) : _smoke,
    ),
  );
}

Future<void> _showStaffPasswordDialog(
  BuildContext context,
  ApiClient api,
) async {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  var working = false;
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText:
                      '10+ characters with uppercase, lowercase, number and symbol',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: working ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: working
                  ? null
                  : () async {
                      if (next.text != confirm.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('New passwords do not match.'),
                          ),
                        );
                        return;
                      }
                      setModalState(() => working = true);
                      try {
                        await api.post(
                          '/mobile/staff/profile/password',
                          data: {
                            'current_password': current.text,
                            'password': next.text,
                            'password_confirmation': confirm.text,
                          },
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password updated. Sign in again on your other devices.',
                              ),
                            ),
                          );
                      } catch (error) {
                        if (context.mounted)
                          _message(context, error.toString(), error: true);
                      } finally {
                        if (context.mounted)
                          setModalState(() => working = false);
                      }
                    },
              child: working
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  } finally {
    current.dispose();
    next.dispose();
    confirm.dispose();
  }
}

/// Shared top rail taken from the Stitch “Velvet Concierge” screens. Keeping
/// this in the page shell makes every staff workspace feel like one product.
class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  Future<List<Map<String, dynamic>>> _load() async {
    final response = await widget.api.get('/mobile/staff/scan-history');
    return (response['data'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan history')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(() => _future = _load()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          );
        final logs = snapshot.data ?? const [];
        if (logs.isEmpty) return const Center(child: Text('No scans yet.'));
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final log = logs[index];
              final status = log['status']?.toString() ?? 'unknown';
              final valid = status == 'valid';
              return Card(
                child: ListTile(
                  leading: Icon(
                    valid
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: valid ? _success : _red,
                  ),
                  title: Text(
                    log['serial']?.toString() ?? 'Serial unavailable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(log['scanned_at']?.toString() ?? ''),
                  trailing: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: valid ? _success : _red,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class _StitchAppHeader extends StatelessWidget {
  const _StitchAppHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _charcoal,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'T',
          style: GoogleFonts.spaceGrotesk(
            color: _ivory,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        'TKTSAPP',
        style: GoogleFonts.spaceGrotesk(
          color: _charcoal,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
      ),
      const SizedBox(width: 10),
      Container(width: 1, height: 16, color: _gold.withValues(alpha: .55)),
      const SizedBox(width: 10),
      Text(
        'CONCIERGE SCANNER',
        style: GoogleFonts.spaceGrotesk(
          color: _primary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.25,
        ),
      ),
      const Spacer(),
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _primary,
          shape: BoxShape.circle,
          border: Border.all(color: _gold.withValues(alpha: .7)),
        ),
        child: const Icon(Icons.person_rounded, size: 18, color: _ivory),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _gold.withValues(alpha: .3), width: 1),
      boxShadow: [
        BoxShadow(
          color: _burgundy.withValues(alpha: .06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w800,
              fontSize: 26,
              color: _burgundy,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.replaceAll('_', ' '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6E6863),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0x14541627),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _burgundy.withValues(alpha: .15), width: 1),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _burgundy.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.shield_outlined, color: _burgundy, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'This workspace is scoped to your role and assigned events. Activity is logged for operational security.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _charcoal.withValues(alpha: .8),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();
  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.lock_outline_rounded, size: 17, color: Color(0xFF6E6863)),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Staff access is protected by event-level permissions and optional two-factor authentication.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6E6863)),
        ),
      ),
    ],
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.count = 3});
  final int count;
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      count,
      (index) => Container(
        height: 88,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0x0A541627),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _burgundy.withValues(alpha: .05), width: 1),
        ),
      ),
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _Empty(
    icon: Icons.wifi_off_rounded,
    title: 'Could not load this page',
    message: 'Check your internet connection and retry.',
    action: FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(icon, size: 42, color: _burgundy),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6E6863)),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class _ScannerBracket extends StatefulWidget {
  @override
  State<_ScannerBracket> createState() => _ScannerBracketState();
}

class _ScannerBracketState extends State<_ScannerBracket>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(
            color: _gold.withValues(alpha: _anim.value),
            width: 3,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

void _message(BuildContext context, String message, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? _red : _charcoal,
        content: Text(message),
      ),
    );
String _greeting(String? name) {
  final first = (name ?? '').trim().split(' ').first;
  return first.isEmpty ? 'Welcome back' : 'Welcome, $first';
}

String _roleLabel(String role) => switch (role) {
  'super_admin' => 'Super admin',
  'admin' => 'Administrator',
  'organizer' => 'Organizer owner',
  'manager' => 'Organizer manager',
  'analyst' => 'Analytics',
  'scanner' => 'Scanner staff',
  _ => 'Staff workspace',
};
String _value(Object? value) => value is num
    ? (value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2))
    : value?.toString() ?? '—';
String _date(Object? raw) {
  if (raw == null) return 'Date TBA';
  final value = DateTime.tryParse(raw.toString());
  if (value == null) return raw.toString();
  return '${value.day.toString().padLeft(2, '0')} ${_month(value.month)} • ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _month(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
