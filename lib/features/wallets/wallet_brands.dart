import 'package:flutter/material.dart';

/// A brand logo template for a wallet.
///
/// The marks are original stylized wordmarks/icons in the brand's colors —
/// not the banks' official logo artwork. Picking a template also suggests
/// the brand's color, which the user can still override.
class WalletBrand {
  const WalletBrand({
    required this.id,
    required this.label,
    required this.category,
    required this.colorHex,
    this.wordmark,
    this.wordmarkAccent,
    this.wordmarkAccentHex,
    this.icon,
    this.badgeHex,
  });

  /// Stable id stored in `wallets.logoTemplate`.
  final String id;

  /// Display label, e.g. 'BCA'.
  final String label;

  /// 'bank' | 'ewallet' | 'general'.
  final String category;

  /// Suggested wallet accent color.
  final String colorHex;

  /// Wordmark text rendered on the badge, e.g. 'GoPay'.
  final String? wordmark;

  /// Optional trailing accent character, e.g. the '.' in 'Jago.'.
  final String? wordmarkAccent;

  /// Color of [wordmarkAccent]; defaults to white.
  final String? wordmarkAccentHex;

  /// Icon mark used instead of a wordmark for generic templates.
  final IconData? icon;

  /// Badge tile base color; defaults to [colorHex]. Differs when the
  /// badge needs a dark tile behind a light accent (e.g. Jago).
  final String? badgeHex;

  bool get hasWordmark => wordmark != null && wordmark!.isNotEmpty;
}

const _banks = <WalletBrand>[
  WalletBrand(id: 'bca', label: 'BCA', category: 'bank', colorHex: '#2F6DF6', wordmark: 'BCA'),
  WalletBrand(id: 'bri', label: 'BRI', category: 'bank', colorHex: '#0A8BD6', wordmark: 'BRI'),
  WalletBrand(
    id: 'mandiri',
    label: 'Mandiri',
    category: 'bank',
    colorHex: '#2A74C9',
    wordmark: 'Mandiri',
    wordmarkAccent: '~',
    wordmarkAccentHex: '#FFCF40',
  ),
  WalletBrand(id: 'bni', label: 'BNI', category: 'bank', colorHex: '#F26522', wordmark: 'BNI'),
  WalletBrand(id: 'cimb', label: 'CIMB', category: 'bank', colorHex: '#E53246', wordmark: 'CIMB'),
  WalletBrand(id: 'danamon', label: 'Danamon', category: 'bank', colorHex: '#FFA53A', wordmark: 'Danamon'),
  WalletBrand(id: 'btn', label: 'BTN', category: 'bank', colorHex: '#0F83D4', wordmark: 'BTN'),
  WalletBrand(id: 'bsi', label: 'BSI', category: 'bank', colorHex: '#159186', wordmark: 'BSI'),
  WalletBrand(
    id: 'jago',
    label: 'Jago',
    category: 'bank',
    colorHex: '#FFB800',
    badgeHex: '#16283F',
    wordmark: 'Jago',
    wordmarkAccent: '.',
    wordmarkAccentHex: '#FFB800',
  ),
  WalletBrand(id: 'seabank', label: 'SeaBank', category: 'bank', colorHex: '#FF7F1F', wordmark: 'SeaBank'),
  WalletBrand(id: 'blu', label: 'blu', category: 'bank', colorHex: '#3FB2F2', wordmark: 'blu'),
  WalletBrand(id: 'neo', label: 'neo', category: 'bank', colorHex: '#8F55F5', wordmark: 'neo'),
];

const _ewallets = <WalletBrand>[
  WalletBrand(id: 'gopay', label: 'GoPay', category: 'ewallet', colorHex: '#00B4DD', wordmark: 'GoPay'),
  WalletBrand(id: 'dana', label: 'DANA', category: 'ewallet', colorHex: '#1F9BF0', wordmark: 'DANA'),
  WalletBrand(id: 'ovo', label: 'OVO', category: 'ewallet', colorHex: '#6D28D9', wordmark: 'OVO'),
  WalletBrand(id: 'shopeepay', label: 'ShopeePay', category: 'ewallet', colorHex: '#F4633F', wordmark: 'ShopeePay'),
  WalletBrand(id: 'linkaja', label: 'LinkAja', category: 'ewallet', colorHex: '#EF3439', wordmark: 'LinkAja'),
  WalletBrand(id: 'astrapay', label: 'AstraPay', category: 'ewallet', colorHex: '#2A86E8', wordmark: 'AstraPay'),
];

const _general = <WalletBrand>[
  WalletBrand(
    id: 'cash',
    label: 'Cash',
    category: 'general',
    colorHex: '#22C55E',
    badgeHex: '#1D3A2A',
    icon: Icons.payments_outlined,
  ),
  WalletBrand(
    id: 'bank',
    label: 'Bank',
    category: 'general',
    colorHex: '#8B9BB4',
    badgeHex: '#2A2F38',
    icon: Icons.account_balance_outlined,
  ),
  WalletBrand(
    id: 'ewallet',
    label: 'E-wallet',
    category: 'general',
    colorHex: '#A78BFA',
    badgeHex: '#2C2340',
    icon: Icons.account_balance_wallet_outlined,
  ),
  WalletBrand(
    id: 'card',
    label: 'Card',
    category: 'general',
    colorHex: '#94A3B8',
    badgeHex: '#333A45',
    icon: Icons.credit_card_outlined,
  ),
];

/// All brand templates: banks, e-wallets, then generic marks.
const allWalletBrands = <WalletBrand>[..._banks, ..._ewallets, ..._general];

/// Templates grouped for the picker's sectioned rows.
const walletBrandGroups = <String, List<WalletBrand>>{
  'Banks': _banks,
  'E-wallets': _ewallets,
  'General': _general,
};

/// Looks up a template by id; null when unknown or not set.
WalletBrand? walletBrandForId(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final b in allWalletBrands) {
    if (b.id == id) return b;
  }
  return null;
}

/// Resolves the badge for a wallet: its chosen template, or the generic
/// mark matching its kind when no template is set.
WalletBrand walletBrandForWallet({String? logoTemplate, required String kind}) {
  final chosen = walletBrandForId(logoTemplate);
  if (chosen != null) return chosen;
  return switch (kind) {
    'bank' => walletBrandForId('bank')!,
    'ewallet' => walletBrandForId('ewallet')!,
    'credit' => walletBrandForId('card')!,
    _ => walletBrandForId('cash')!,
  };
}
