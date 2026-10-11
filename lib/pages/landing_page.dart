import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_page.dart';
import 'signup_page.dart';

// ============================================================
// RACETECH DESIGN SYSTEM
// Soft indigo palette — matches the home page, Find Events and admin.
// ============================================================

const _primary = Color(0xFF6366F1); // indigo-500
const _primaryDeep = Color(0xFF4F46E5); // indigo-600
const _accent = Color(0xFF0EA5E9); // sky-500
const _primaryTint = Color(0xFFC7D2FE); // indigo-200, for icons on dark bg
const _dark = Color(0xFF0F172A);
const _ink = Color(0xFF1E293B);
const _secondaryText = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _open(BuildContext context, Widget page) {
    HapticFeedback.selectionClick();

    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    // Light status-bar icons over the dark photo.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _dark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ====================================================
            // BACKGROUND
            // ====================================================
            Image.asset(
              "assets/login_bg.jpg",
              fit: BoxFit.cover,
              alignment: Alignment.center,
              // If the asset is missing, fall back to a brand gradient
              // instead of Flutter's red error box.
              errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_primaryDeep, _dark],
                  ),
                ),
              ),
            ),

            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _dark.withValues(alpha: 0.35),
                    _dark.withValues(alpha: 0.55),
                    _dark.withValues(alpha: 0.88),
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),

            // Indigo accent glow
            Positioned(
              top: -110,
              right: -90,
              child: _Glow(color: _primary.withValues(alpha: 0.28), size: 280),
            ),

            // Sky secondary glow
            Positioned(
              bottom: 120,
              left: -130,
              child: _Glow(color: _accent.withValues(alpha: 0.16), size: 260),
            ),

            // ====================================================
            // CONTENT
            // ====================================================
            SafeArea(
              child: _EntranceAnimation(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 52).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _Brand(),

                              const SizedBox(height: 32),

                              const _HeroContent(),

                              const SizedBox(height: 28),

                              _LandingCard(
                                onGetStarted: () =>
                                    _open(context, const SignUpPage()),
                                onLogin: () =>
                                    _open(context, const LoginPage()),
                              ),

                              const SizedBox(height: 22),

                              Text(
                                "Train smarter. Perform better.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Fades and slides the content up once on first build.
/// Skipped when the device has "reduce motion" turned on.
class _EntranceAnimation extends StatelessWidget {
  final Widget child;

  const _EntranceAnimation({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================
// BRAND
// ============================================================

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            "RACETECH",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// HERO
// ============================================================

class _HeroContent extends StatelessWidget {
  const _HeroContent();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final titleSize = width < 360
        ? 37.0
        : width < 400
        ? 42.0
        : 46.0;

    return Column(
      children: [
        // Eyebrow
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _primaryTint.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_rounded, size: 14, color: _primaryTint),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  "YOUR NEXT FINISH LINE STARTS HERE",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Text(
          "Train. Compete.\nConquer.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            height: 0.98,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),

        const SizedBox(height: 16),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 370),
          child: Text(
            "Discover local events, build your training journey, "
            "and connect with a community that keeps moving forward.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 22),

        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _FeatureChip(icon: Icons.event_outlined, label: "Events"),
            _FeatureChip(icon: Icons.insights_outlined, label: "Progress"),
            _FeatureChip(icon: Icons.groups_outlined, label: "Community"),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// FEATURE CHIP
// ============================================================

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primaryTint, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WHITE ACTION CARD
// ============================================================

class _LandingCard extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;

  const _LandingCard({required this.onGetStarted, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accent icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.flag_rounded, color: _primary, size: 24),
          ),

          const SizedBox(height: 14),

          const Text(
            "Ready to get moving?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            "Create your Racetech account and start your journey.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _secondaryText,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // ====================================================
          // GET STARTED
          // ====================================================
          SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [_primaryDeep, _primary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onGetStarted,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          "Get Started",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 19),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 17),

          // ====================================================
          // DIVIDER
          // ====================================================
          const Row(
            children: [
              Expanded(child: Divider(color: _border, height: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "OR",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              Expanded(child: Divider(color: _border, height: 1)),
            ],
          ),

          const SizedBox(height: 17),

          // ====================================================
          // LOGIN
          // ====================================================
          SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: OutlinedButton(
                onPressed: onLogin,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  foregroundColor: _primaryDeep,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "I already have an account",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
