import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_motion.dart';
import '../../core/utils/haptics.dart';
import '../budgets/budgets_screen.dart';
import '../calendar/calendar_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../transactions/add_transaction_sheet.dart';
import '../wallets/wallets_screen.dart';
import '../../state/providers.dart';

/// Bottom navigation with a center-docked FAB opening the add-transaction sheet.
///
/// Tabs swipe left/right via [PageView]; tapping a nav item animates to it.
/// External jumps (e.g. goal spotlight → Budgets) animate through the same path.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _screens = [
    HomeScreen(),
    WalletsScreen(),
    CalendarScreen(),
    StatsScreen(),
    BudgetsScreen(),
    SettingsScreen(),
  ];

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: ref.read(tabIndexProvider));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (!_pageController.hasClients) return;
    final current = _pageController.page?.round() ?? 0;
    if (current == index) return;
    _pageController.animateToPage(
      index,
      duration: AppMotion.normal,
      curve: AppMotion.enter,
    );
  }

  @override
  Widget build(BuildContext context) {
    // External tab jumps (quick actions, deep links) animate like taps.
    ref.listen<int>(tabIndexProvider, (_, next) => _goTo(next));

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => ref.read(tabIndexProvider.notifier).go(i),
        children: _screens,
      ),
      // The FAB opens the same modal bottom sheet as the Top up quick
      // action, so the animation and swipe-to-dismiss behave identically
      // no matter which entry point is used.
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const AddTransactionSheet(),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _navItem(0, Icons.home_outlined, Icons.home, 'Home'),
            _navItem(1, Icons.wallet_outlined, Icons.wallet, 'Wallets'),
            _navItem(2, Icons.calendar_month_outlined, Icons.calendar_month,
                'Calendar'),
            const Spacer(),
            _navItem(3, Icons.pie_chart_outline, Icons.pie_chart, 'Stats'),
            _navItem(4, Icons.savings_outlined, Icons.savings, 'Budgets'),
            _navItem(5, Icons.settings_outlined, Icons.settings, 'More'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final active = ref.watch(tabIndexProvider) == index;
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Expanded(
      child: InkWell(
        onTap: () {
          Haptics.select();
          ref.read(tabIndexProvider.notifier).go(index);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.18 : 1.0,
                duration: AppMotion.fast,
                curve: Curves.easeOutBack,
                child: Icon(active ? activeIcon : icon, color: color, size: 24),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: AppMotion.fast,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
