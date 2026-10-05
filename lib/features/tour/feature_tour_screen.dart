import 'package:flutter/material.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/haptics.dart';

/// Full-screen feature tour: one page per headline feature.
///
/// Shown automatically once right after onboarding (via
/// [pendingFromOnboarding]), and replayable anytime from
/// Settings → Feature tour. Skipping or finishing both mark the tour as
/// seen so it never nags.
class FeatureTourScreen extends StatefulWidget {
  const FeatureTourScreen({super.key});

  /// Set by the onboarding flow when a *fresh* account is created.
  /// AppShell consumes it once and shows the tour.
  static bool pendingFromOnboarding = false;

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const FeatureTourScreen(),
      ),
    );
  }

  @override
  State<FeatureTourScreen> createState() => _FeatureTourScreenState();
}

class _TourPage {
  const _TourPage(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _pages = [
  _TourPage(
    Icons.receipt_long_outlined,
    'Track every rupiah',
    'Log income and expenses in seconds — or snap a receipt and let the app file it for you.',
  ),
  _TourPage(
    Icons.wallet_outlined,
    'Wallets that match real life',
    'Cash, bank, e-wallet — track each balance separately, or see them all combined.',
  ),
  _TourPage(
    Icons.savings_outlined,
    'Budgets & savings goals',
    'Set monthly budgets per category and watch your savings goals grow toward their targets.',
  ),
  _TourPage(
    Icons.handshake_outlined,
    'Debts, without the awkwardness',
    'Track what you borrowed and lent, with due dates and reminders so nothing slips.',
  ),
  _TourPage(
    Icons.calendar_month_outlined,
    'Calendar & smart insights',
    'See each day\u2019s money flow on the calendar and get insights about your spending habits.',
  ),
  _TourPage(
    Icons.shield_outlined,
    'Private by design',
    'Your data stays on your device. Back it up anytime, and lock the app with a passcode.',
  ),
];

class _FeatureTourScreenState extends State<FeatureTourScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await AppPrefs.setHasSeenTour(true);
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    Haptics.light();
    if (_index == _pages.length - 1) {
      _close();
    } else {
      _controller.nextPage(
        duration: AppMotion.normal,
        curve: AppMotion.enter,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip is always one tap away.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Haptics.light();
                  _close();
                },
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: context.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _page(context, _pages[i]),
              ),
            ),
            // Dots.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.enter,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _index
                          ? context.accent
                          : context.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.accent,
                    foregroundColor: onAccent(context.accent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    last ? 'Get started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

  Widget _page(BuildContext context, _TourPage page) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(page.icon, size: 56, color: context.accent),
          ),
          const SizedBox(height: 32),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
