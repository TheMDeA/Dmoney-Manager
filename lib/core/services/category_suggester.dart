import '../../data/database/app_database.dart';
import 'app_prefs.dart';

/// A smart category suggestion: the learned [categoryId] plus the
/// [confidence] (0.0–1.0) behind it.
class CategorySuggestion {
  const CategorySuggestion({
    required this.categoryId,
    required this.confidence,
  });

  final int categoryId;
  final double confidence;

  /// High-confidence suggestions may auto-select the category.
  bool get autoSelect => confidence >= 0.9;
}

/// On-device smart category suggestions. Learns keyword → category
/// associations from saved transactions (nothing leaves the device) and
/// suggests a category while the note is being typed.
class CategorySuggester {
  CategorySuggester(this._db);

  final AppDatabase _db;

  /// Keywords need at least this many total observations before they
  /// influence a suggestion.
  static const minSamples = 3;

  /// Below this confidence the suggester stays quiet.
  static const suggestThreshold = 0.6;

  /// One-time backfill: learn from the existing history. Runs once per
  /// install (guarded by a prefs flag).
  Future<void> ensureBackfilled() async {
    if (AppPrefs.keywordBackfillDone) return;
    final txs = await _db.learnableTransactions();
    final counts = <String, Map<int, int>>{};
    for (final t in txs) {
      for (final token in tokenizeNote(t.note)) {
        counts.putIfAbsent(token, () => {})[t.categoryId] =
            (counts[token]![t.categoryId] ?? 0) + 1;
      }
    }
    if (counts.isNotEmpty) {
      await _db.learnKeywordCounts(counts);
    }
    await AppPrefs.setKeywordBackfillDone(true);
  }

  /// Records that [note] was saved with [categoryId].
  Future<void> learn({required String note, required int categoryId}) {
    final tokens = tokenizeNote(note);
    if (tokens.isEmpty) return Future.value();
    return _db.learnKeywords(tokens, categoryId);
  }

  /// Removes one learning record for an edited transaction's old values.
  Future<void> unlearn({required String note, required int categoryId}) {
    final tokens = tokenizeNote(note);
    if (tokens.isEmpty) return Future.value();
    return _db.unlearnKeywords(tokens, categoryId);
  }

  /// Suggests a top-level category of [kind] for [note], or null when
  /// nothing reaches the confidence threshold.
  Future<CategorySuggestion?> suggest({
    required String note,
    required String kind,
  }) async {
    final tokens = tokenizeNote(note);
    if (tokens.isEmpty) return null;
    final hits = await _db.keywordHits(tokens);
    if (hits.isEmpty) return null;
    final categories = await _db.allCategories();
    final kinds = {for (final c in categories) c.id: c.kind};
    final topLevel = {for (final c in categories) c.id: c.parentId == null};
    return scoreKeywords(
      hits: hits,
      kinds: kinds,
      topLevel: topLevel,
      kind: kind,
    );
  }
}

/// Splits a note into lowercase keyword tokens. Drops short tokens and
/// pure numbers; language-agnostic.
Set<String> tokenizeNote(String note) {
  return RegExp(r'[\p{L}0-9]+', unicode: true)
      .allMatches(note.toLowerCase())
      .map((m) => m.group(0)!)
      .where((t) => t.length >= 3 && int.tryParse(t) == null)
      .toSet();
}

/// Pure scoring: aggregates per-keyword category distributions into one
/// suggestion. [hits] is keyword → {categoryId → hits}.
CategorySuggestion? scoreKeywords({
  required Map<String, Map<int, int>> hits,
  required Map<int, String> kinds,
  required Map<int, bool> topLevel,
  required String kind,
  int minSamples = CategorySuggester.minSamples,
  double threshold = CategorySuggester.suggestThreshold,
}) {
  final scores = <int, double>{};
  var tokensWithData = 0;
  for (final entry in hits.entries) {
    final total = entry.value.values.fold(0, (a, b) => a + b);
    if (total < minSamples) continue;
    tokensWithData++;
    for (final ce in entry.value.entries) {
      if (kinds[ce.key] != kind) continue;
      if (topLevel[ce.key] != true) continue;
      scores[ce.key] = (scores[ce.key] ?? 0) + ce.value / total;
    }
  }
  if (tokensWithData == 0 || scores.isEmpty) return null;
  var bestId = -1;
  var best = 0.0;
  scores.forEach((id, sum) {
    final avg = sum / tokensWithData;
    if (avg > best) {
      best = avg;
      bestId = id;
    }
  });
  if (best < threshold) return null;
  return CategorySuggestion(categoryId: bestId, confidence: best);
}
