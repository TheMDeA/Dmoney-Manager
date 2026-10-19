import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/categories/category_picker_section.dart';

/// moveCategoryToFront: the selected/suggested category is always visible
/// up front in the quick-pick grid.
void main() {
  Category cat(int id, String name) => Category(
        id: id,
        name: name,
        kind: 'expense',
        iconKey: 'other',
        colorHex: '#A78BFA',
        sortOrder: 0,
      );

  List<Category> cats() =>
      [cat(1, 'A'), cat(2, 'B'), cat(3, 'C'), cat(4, 'D'), cat(5, 'E')];

  List<int> ids(List<Category> cs) => [for (final c in cs) c.id];

  test('moves a later category to the front', () {
    final cs = cats();
    moveCategoryToFront(cs, 5);
    expect(ids(cs), [5, 1, 2, 3, 4]);
  });

  test('leaves the order alone when already first or absent', () {
    final cs = cats();
    moveCategoryToFront(cs, 1);
    expect(ids(cs), [1, 2, 3, 4, 5]);

    moveCategoryToFront(cs, 999);
    expect(ids(cs), [1, 2, 3, 4, 5]);

    moveCategoryToFront(cs, null);
    expect(ids(cs), [1, 2, 3, 4, 5]);
  });

  test('explicit selection wins over suggestion for slot one', () {
    final cs = cats();
    moveCategoryToFront(cs, 4); // suggestion
    moveCategoryToFront(cs, 5); // selection, applied after
    expect(ids(cs), [5, 4, 1, 2, 3]);
  });
}
