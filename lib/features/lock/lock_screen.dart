import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/haptics.dart';
import '../../state/providers.dart';

/// Passcode + biometric lock screen ("Secure and Private").
/// Verifies the 4-digit passcode set in More → Password protection.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';

  // Shake animation for wrong passcode entries.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _wrongPin() {
    setState(() => _pin = '');
    _shake.forward(from: 0);
    Haptics.medium();
    _msg('Wrong passcode, try again');
  }

  void _press(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        if (AppPrefs.verifyPin(_pin)) {
          ref.read(lockedProvider.notifier).unlock();
        } else {
          _wrongPin();
        }
      });
    }
  }

  void _backspace() {
    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _biometric() async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.canCheckBiometrics) {
        _msg('No biometrics enrolled on this device');
        return;
      }
      final ok = await auth.authenticate(
        localizedReason: 'Unlock Dmoney Manager',
        biometricOnly: true,
      );
      if (ok && mounted) ref.read(lockedProvider.notifier).unlock();
    } catch (_) {
      _msg('Biometric unlock failed');
    }
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 64),
            Text('Enter Password', style: AppTextStyles.displaySection),
            const SizedBox(height: 32),
            // The dot row wiggles side-to-side on a wrong entry.
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final t = _shake.value;
                // Two side-to-side oscillations with linear decay.
                final dx = 14 * sin(t * 4 * pi) * (1 - t);
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: child,
                );
              },
              child: Row(
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
            ),
            const SizedBox(height: 48),
            InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: _biometric,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(Icons.fingerprint, color: onAccent(accent), size: 40),
              ),
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
            children: [for (final d in row) _key(d, accent)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72),
            _key('0', accent),
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

  Widget _key(String digit, Color accent) {
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
