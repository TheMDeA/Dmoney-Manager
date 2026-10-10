import 'package:dmoney_manager/core/utils/category_icons.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the DB seed in app_database.dart: every iconKey it inserts
/// must resolve to a real icon, otherwise fresh installs get a
/// fallback glyph.
void main() {
  group('seed icon keys', () {
    const seedKeys = [
      // Income.
      'payments', // Allowance
      'award', // Award
      'paid', // Bonus
      'trending_up', // Dividend
      'savings', // Investment
      'lottery', // Lottery
      'salary', // Salary
      'tips', // Tips
      'other', // Others
      // Expense.
      'bills', // Bills
      'clothing', // Clothing
      'education', // Education
      'entertainment', // Entertainment
      'fitness', // Fitness
      'food', // Food
      'coffee', // Coffee (subcategory)
      'gift', // Gifts
      'health', // Health
      'furniture', // Furniture
      'pets', // Pet
      'shopping', // Shopping
      'bus', // Transportation
      'travel', // Travel
      'other', // Other
      // Transfer (hidden).
      'swap_horiz',
    ];

    test('every seed iconKey exists in categoryIconMap', () {
      for (final key in seedKeys) {
        expect(
          categoryIconMap.containsKey(key),
          isTrue,
          reason: 'missing icon for key "$key"',
        );
      }
    });

    test('iconForKey never falls back for seed keys', () {
      for (final key in seedKeys.toSet()) {
        expect(iconForKey(key), isNotNull);
      }
    });
  });
}
