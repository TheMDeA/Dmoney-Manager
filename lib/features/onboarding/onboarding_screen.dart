import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'widgets/numeric_keypad.dart';
import 'widgets/onboarding_art.dart';

/// First-launch setup: welcome carousel -> account name -> currency ->
/// initial cash amount. Shown while the accounts table is empty; completing
/// it creates the first account + wallet, which flips the app to the shell.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0; // 0 = welcome, 1 = name, 2 = currency, 3 = amount
  int _welcomePage = 0;
  final _welcomeController = PageController();
  final _nameController = TextEditingController();
  String _currency = 'IDR';
  int _amount = 0;
  bool _finishing = false;

  static const _welcomePages = [
    (
      kind: OnboardingArtKind.monitoring,
      title: 'Financial monitoring',
      subtitle: 'Keep your income and expenses on track.',
    ),
    (
      kind: OnboardingArtKind.budgets,
      title: 'Smart budgets',
      subtitle: 'Set spending limits and get alerted before you overspend.',
    ),
    (
      kind: OnboardingArtKind.savings,
      title: 'Saving goals',
      subtitle: 'Set your first savings goal and track the progress.',
    ),
  ];

  @override
  void dispose() {
    _welcomeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (_step) {
            0 => _welcomeStep(key: const ValueKey(0)),
            1 => _nameStep(key: const ValueKey(1)),
            2 => _currencyStep(key: const ValueKey(2)),
            _ => _amountStep(key: const ValueKey(3)),
          },
        ),
      ),
    );
  }

  // ------------------------------ welcome ------------------------------

  Widget _welcomeStep({required Key key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _welcomeController,
              itemCount: _welcomePages.length,
              onPageChanged: (i) => setState(() => _welcomePage = i),
              itemBuilder: (context, i) {
                final page = _welcomePages[i];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OnboardingArt(kind: page.kind),
                    const SizedBox(height: 48),
                    Text(
                      page.title,
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      page.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _welcomePages.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _welcomePage
                      ? AppColors.lime
                      : AppColors.textMuted.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _primaryButton('GET STARTED', () => setState(() => _step = 1)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showRestoreSheet,
            child: const Text(
              'RESTORE DATA',
              style: TextStyle(
                color: AppColors.brandBlue,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRestoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.cloud_upload_outlined,
                color: AppColors.violet, size: 40),
            const SizedBox(height: 12),
            Text(
              'Restore data',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Backup & restore from a file is coming in a future update. '
              'Your data is stored safely on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 20),
            _primaryButton('GOT IT', () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  // ------------------------------- name --------------------------------

  Widget _nameStep({required Key key}) {
    final canNext = _nameController.text.trim().isNotEmpty;
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => setState(() => _step = 0),
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 24),
          _stepTitle('Add Account', 'Choose a name for your account.'),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Name',
              hintStyle:
                  TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6)),
              filled: true,
              fillColor: AppColors.bgRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (canNext) setState(() => _step = 2);
            },
          ),
          const Spacer(),
          _primaryButton('NEXT', canNext ? () => setState(() => _step = 2) : null),
        ],
      ),
    );
  }

  // ------------------------------ currency ------------------------------

  Widget _currencyStep({required Key key}) {
    final selected = currencyByCode(_currency);
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => setState(() => _step = 1),
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 24),
          _stepTitle('Select Currency', 'What is your favourite currency?'),
          const SizedBox(height: 24),
          InkWell(
            onTap: _pickCurrency,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.bgRaised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.label,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 16),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down,
                      color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const Spacer(),
          _primaryButton('NEXT', () => setState(() => _step = 3)),
        ],
      ),
    );
  }

  void _pickCurrency() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: supportedCurrencies.length,
          itemBuilder: (context, i) {
            final c = supportedCurrencies[i];
            final isSelected = c.code == _currency;
            return ListTile(
              title: Text(
                c.label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.lime
                      : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.lime)
                  : null,
              onTap: () {
                setState(() => _currency = c.code);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  // ------------------------------- amount -------------------------------

  Widget _amountStep({required Key key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _finishing ? null : () => _finish(skip: true),
              child: const Text(
                'SKIP',
                style: TextStyle(
                  color: AppColors.brandBlue,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          _stepTitle('Initial Amount',
              'How much money do you have in your cash wallet?'),
          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.bgRaised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatMoneyWith(_currency, _amount),
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_amount > 0)
                  InkWell(
                    onTap: () => setState(() => _amount = 0),
                    child: const Icon(Icons.backspace_outlined,
                        color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: NumericKeypad(
              onDigit: (d) => setState(() {
                final next = _amount * 10 + int.parse(d);
                if (next <= 999999999999999) _amount = next;
              }),
              onBackspace: () => setState(() => _amount ~/= 10),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FloatingActionButton(
              onPressed: _finishing ? null : () => _finish(skip: false),
              backgroundColor: AppColors.lime,
              child: _finishing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.bgBase),
                    )
                  : const Icon(Icons.check,
                      color: AppColors.bgBase, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finish({required bool skip}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      final db = ref.read(databaseProvider);
      final accountId = await db.addAccount(AccountsCompanion.insert(
        name: _nameController.text.trim(),
        kind: 'personal',
      ));
      await db.addWallet(WalletsCompanion.insert(
        accountId: accountId,
        name: 'Cash',
        kind: 'cash',
        balance: Value(skip ? 0 : _amount),
        initialAmount: Value(skip ? 0 : _amount),
        colorHex: const Value('#C6FF4A'),
      ));
      await AppPrefs.setCurrencyCode(_currency);
      await AppPrefs.setDisplayName(_nameController.text.trim());
      // The accounts stream flips non-empty -> app.dart shows the shell.
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  // -------------------------------- shared -------------------------------

  Widget _stepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          disabledBackgroundColor: AppColors.lime.withValues(alpha: 0.35),
          foregroundColor: AppColors.bgBase,
          disabledForegroundColor: AppColors.bgBase.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
