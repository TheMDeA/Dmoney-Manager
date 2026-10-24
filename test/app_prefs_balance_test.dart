import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';

/// The Home balance eye toggle must survive tab switches: the shell's
/// PageView disposes Home when jumping to a distant tab, so the flag
/// lives in prefs rather than screen state. This pins the pref itself;
/// the Home screen reads it on creation and writes it on every toggle.
void main() {
  test('balanceHidden pref round-trips and defaults to visible', () async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();

    expect(AppPrefs.balanceHidden, isFalse);

    await AppPrefs.setBalanceHidden(true);
    expect(AppPrefs.balanceHidden, isTrue);

    await AppPrefs.setBalanceHidden(false);
    expect(AppPrefs.balanceHidden, isFalse);
  });
}
