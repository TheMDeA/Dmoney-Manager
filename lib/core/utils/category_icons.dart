import 'package:flutter/material.dart';

/// String keys stored in the DB map to Material icons here,
/// so categories stay serializable and themeable.
const Map<String, IconData> categoryIconMap = {
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
  'other': Icons.category,
};

IconData iconForKey(String key) => categoryIconMap[key] ?? Icons.category;

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
