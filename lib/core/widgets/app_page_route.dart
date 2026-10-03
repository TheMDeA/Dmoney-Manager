import 'package:flutter/material.dart';

/// App-wide page transition: gentle slide + fade with soft cubic curves.
///
/// Drop-in replacement for [MaterialPageRoute] — same constructor shape,
/// so existing `builder:` call sites keep working unchanged.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final slide =
                Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
                    .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            final fade =
                CurvedAnimation(parent: animation, curve: Curves.easeOut);
            // Outgoing page drifts slightly for a parallax feel.
            final outSlide =
                Tween<Offset>(begin: Offset.zero, end: const Offset(-0.04, 0))
                    .animate(
              CurvedAnimation(
                  parent: secondaryAnimation, curve: Curves.easeOutCubic),
            );
            return SlideTransition(
              position: outSlide,
              child: SlideTransition(
                position: slide,
                child: FadeTransition(opacity: fade, child: child),
              ),
            );
          },
        );
}
