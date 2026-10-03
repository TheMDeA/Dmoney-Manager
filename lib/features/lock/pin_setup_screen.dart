import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Set (or change) the 4-digit app passcode: enter once, then confirm.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key, this.isChange = false});

  final bool isChange;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _first = '';
  String _pin = '';

  bool get _confirming => _first.isNotEmpty;

  void _press(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 250), () async {
        if (!mounted) return;
        if (!_confirming) {
          setState(() {
            _first = _pin;
            _pin = '';
          });
        } else if (_pin == _first) {
          await AppPrefs.setPin(_pin);
          if (mounted) Navigator.of(context).pop(true);
        } else {
          setState(() {
            _first = '';
            _pin = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passcodes do not match, try again')),
          );
        }
      });
    }
  }

  void _backspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.lime : AppColors.brandBlue;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isChange ? 'Change passcode' : 'Set passcode')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Text(
              _confirming ? 'Confirm your passcode' : 'Enter a 4-digit passcode',
              style: AppTextStyles.displaySection.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? accent : Colors.transparent,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            _keypad(accent),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _keypad(Color accent) {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final d in row) _key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72),
            _key('0'),
            SizedBox(
              width: 72,
              child: IconButton(
                onPressed: _backspace,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _key(String digit) {
    return SizedBox(
      width: 72,
      height: 64,
      child: TextButton(
        onPressed: () => _press(digit),
        child: Text(digit, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
