import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../wallet_brands.dart';

/// Stylized brand badge for a wallet: a rounded tile with a gradient in
/// the brand's colors, carrying the wordmark or a generic icon mark.
class WalletBadge extends StatelessWidget {
  const WalletBadge({super.key, required this.brand, this.height = 36});

  final WalletBrand brand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = colorFromHex(brand.badgeHex ?? brand.colorHex);
    final from = Color.lerp(base, Colors.white, 0.08) ?? base;
    final to = Color.lerp(base, Colors.black, 0.28) ?? base;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
        borderRadius: BorderRadius.circular(height * 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: brand.icon != null
          ? Icon(
              brand.icon,
              color: colorFromHex(brand.colorHex),
              size: height * 0.56,
            )
          : Text.rich(
              TextSpan(
                text: brand.wordmark,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: height * 0.42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
                children: brand.wordmarkAccent == null
                    ? null
                    : [
                        TextSpan(
                          text: brand.wordmarkAccent,
                          style: TextStyle(
                            color: colorFromHex(
                              brand.wordmarkAccentHex ?? '#FFFFFF',
                            ),
                          ),
                        ),
                      ],
              ),
              maxLines: 1,
            ),
    );
  }
}
