import 'package:flutter/material.dart';

/// String keys stored in the DB map to Material icons here,
/// so categories stay serializable and themeable.
const Map<String, IconData> categoryIconMap = {
  // Legacy keys (kept for existing data).
  'food': Icons.restaurant,
  'coffee': Icons.coffee,
  'transport': Icons.directions_car,
  'shopping': Icons.shopping_bag,
  'bills': Icons.receipt_long,
  'health': Icons.favorite,
  'entertainment': Icons.movie,
  'salary': Icons.work,
  'gift': Icons.card_giftcard,
  'travel': Icons.flight,
  'education': Icons.school,
  'swap_horiz': Icons.swap_horiz,
  'other': Icons.category,
  'wallet': Icons.wallet,
  'account_balance': Icons.account_balance,
  'smartphone': Icons.smartphone,
  'credit_card': Icons.credit_card,
  'handshake': Icons.handshake,
  // General.
  'home': Icons.home,
  'pets': Icons.pets,
  'phone': Icons.phone_android,
  'receipt': Icons.receipt,
  // Food & drinks.
  'fastfood': Icons.fastfood,
  'cake': Icons.cake,
  'pizza': Icons.local_pizza,
  'ramen': Icons.ramen_dining,
  'breakfast': Icons.breakfast_dining,
  'icecream': Icons.icecream,
  'wine': Icons.wine_bar,
  'bar': Icons.sports_bar,
  'apple': Icons.apple,
  // Home & living.
  'chair': Icons.chair,
  'bed': Icons.bed,
  'kitchen': Icons.kitchen,
  'tv': Icons.tv,
  'wifi': Icons.wifi,
  'cleaning': Icons.cleaning_services,
  'garage': Icons.garage,
  'garden': Icons.yard,
  // Transport.
  'train': Icons.train,
  'bus': Icons.directions_bus,
  'motorcycle': Icons.motorcycle,
  'bike': Icons.pedal_bike,
  'gas': Icons.local_gas_station,
  'boat': Icons.directions_boat,
  // Shopping.
  'cart': Icons.shopping_cart,
  'store': Icons.store,
  'sell': Icons.sell,
  // Money & work.
  'savings': Icons.savings,
  'payments': Icons.payments,
  'trending_up': Icons.trending_up,
  'currency': Icons.currency_exchange,
  'paid': Icons.paid,
  'cash': Icons.attach_money,
  'tune': Icons.tune,
  // Health & fitness.
  'medical': Icons.medical_services,
  'fitness': Icons.fitness_center,
  'spa': Icons.spa,
  'medication': Icons.medication,
  // Fun & hobbies.
  'gaming': Icons.sports_esports,
  'music': Icons.music_note,
  'book': Icons.book,
  'art': Icons.palette,
  'soccer': Icons.sports_soccer,
  'camera': Icons.camera_alt,
  'brush': Icons.brush,
};

IconData iconForKey(String key) => categoryIconMap[key] ?? Icons.category;

/// Grouped icon choices for the Pick Icon screen.
/// Each section is (title, list of (key, icon)).
const List<({String title, List<({String key, IconData icon})> entries})>
    iconPickerSections = [
  (
    title: 'General',
    entries: [
      (key: 'other', icon: Icons.category),
      (key: 'home', icon: Icons.home),
      (key: 'wallet', icon: Icons.wallet),
      (key: 'handshake', icon: Icons.handshake),
      (key: 'swap_horiz', icon: Icons.swap_horiz),
      (key: 'receipt', icon: Icons.receipt),
      (key: 'bills', icon: Icons.receipt_long),
      (key: 'gift', icon: Icons.card_giftcard),
      (key: 'education', icon: Icons.school),
      (key: 'pets', icon: Icons.pets),
      (key: 'phone', icon: Icons.phone_android),
    ],
  ),
  (
    title: 'Food & Drinks',
    entries: [
      (key: 'food', icon: Icons.restaurant),
      (key: 'coffee', icon: Icons.coffee),
      (key: 'fastfood', icon: Icons.fastfood),
      (key: 'breakfast', icon: Icons.breakfast_dining),
      (key: 'ramen', icon: Icons.ramen_dining),
      (key: 'pizza', icon: Icons.local_pizza),
      (key: 'cake', icon: Icons.cake),
      (key: 'apple', icon: Icons.apple),
      (key: 'icecream', icon: Icons.icecream),
      (key: 'wine', icon: Icons.wine_bar),
      (key: 'bar', icon: Icons.sports_bar),
    ],
  ),
  (
    title: 'Home & Living',
    entries: [
      (key: 'chair', icon: Icons.chair),
      (key: 'bed', icon: Icons.bed),
      (key: 'kitchen', icon: Icons.kitchen),
      (key: 'tv', icon: Icons.tv),
      (key: 'wifi', icon: Icons.wifi),
      (key: 'cleaning', icon: Icons.cleaning_services),
      (key: 'garage', icon: Icons.garage),
      (key: 'garden', icon: Icons.yard),
    ],
  ),
  (
    title: 'Transport',
    entries: [
      (key: 'transport', icon: Icons.directions_car),
      (key: 'gas', icon: Icons.local_gas_station),
      (key: 'motorcycle', icon: Icons.motorcycle),
      (key: 'bike', icon: Icons.pedal_bike),
      (key: 'bus', icon: Icons.directions_bus),
      (key: 'train', icon: Icons.train),
      (key: 'boat', icon: Icons.directions_boat),
      (key: 'travel', icon: Icons.flight),
    ],
  ),
  (
    title: 'Shopping',
    entries: [
      (key: 'shopping', icon: Icons.shopping_bag),
      (key: 'cart', icon: Icons.shopping_cart),
      (key: 'store', icon: Icons.store),
      (key: 'sell', icon: Icons.sell),
    ],
  ),
  (
    title: 'Money & Work',
    entries: [
      (key: 'salary', icon: Icons.work),
      (key: 'account_balance', icon: Icons.account_balance),
      (key: 'savings', icon: Icons.savings),
      (key: 'credit_card', icon: Icons.credit_card),
      (key: 'payments', icon: Icons.payments),
      (key: 'cash', icon: Icons.attach_money),
      (key: 'paid', icon: Icons.paid),
      (key: 'trending_up', icon: Icons.trending_up),
      (key: 'currency', icon: Icons.currency_exchange),
    ],
  ),
  (
    title: 'Health & Fitness',
    entries: [
      (key: 'health', icon: Icons.favorite),
      (key: 'medical', icon: Icons.medical_services),
      (key: 'medication', icon: Icons.medication),
      (key: 'fitness', icon: Icons.fitness_center),
      (key: 'spa', icon: Icons.spa),
    ],
  ),
  (
    title: 'Fun & Hobbies',
    entries: [
      (key: 'entertainment', icon: Icons.movie),
      (key: 'gaming', icon: Icons.sports_esports),
      (key: 'music', icon: Icons.music_note),
      (key: 'soccer', icon: Icons.sports_soccer),
      (key: 'book', icon: Icons.book),
      (key: 'art', icon: Icons.palette),
      (key: 'camera', icon: Icons.camera_alt),
      (key: 'brush', icon: Icons.brush),
    ],
  ),
];

const List<String> availableIconKeys = [
  'food',
  'coffee',
  'transport',
  'shopping',
  'bills',
  'health',
  'entertainment',
  'salary',
  'gift',
  'travel',
  'education',
  'swap_horiz',
  'other',
];

const List<String> availableColors = [
  '#C6FF4A',
  '#A78BFA',
  '#FB923C',
  '#38BDF8',
  '#F472B6',
  '#FACC15',
  '#34D399',
  '#22C55E',
  '#F04444',
  '#9CA3AF',
];
