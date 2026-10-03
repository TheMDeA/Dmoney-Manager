import 'package:flutter/material.dart';

/// A theme accent option. [color] is null for Material You, whose color
/// is resolved from the OS dynamic palette at runtime.
class AppAccent {
  const AppAccent(this.id, this.name, this.color);

  final String id;
  final String name;
  final Color? color;
}

/// The six theme colors: five fixed accents + Material You.
const appAccents = <AppAccent>[
  AppAccent('lime', 'Lime', Color(0xFFC6FF4A)),
  AppAccent('sky', 'Sky', Color(0xFF38BDF8)),
  AppAccent('violet', 'Violet', Color(0xFFA78BFA)),
  AppAccent('tangerine', 'Tangerine', Color(0xFFFB923C)),
  AppAccent('rose', 'Rose', Color(0xFFF472B6)),
  AppAccent('material_you', 'Material You', null),
];

AppAccent accentById(String id) => appAccents.firstWhere(
      (a) => a.id == id,
      orElse: () => appAccents.first,
    );

/// Readable text/icon color on top of [accent].
Color onAccent(Color accent) =>
    accent.computeLuminance() > 0.5 ? Colors.black : Colors.white;

/// The active accent color, via the ambient theme.
extension AccentContext on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;
}
