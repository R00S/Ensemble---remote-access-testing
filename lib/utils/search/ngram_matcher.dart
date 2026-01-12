/// N-gram based string matching for partial matches.
///
/// Uses character bigrams (2-grams) to find partial string matches
/// when exact and fuzzy matching fail.
class NgramMatcher {
  /// Generate character bigrams from text.
  ///
  /// Example: "hello" -> ["he", "el", "ll", "lo"]
  ///
  /// For strings shorter than 2 characters, returns the string itself.
  List<String> generateBigrams(String text) {
    if (text.length < 2) return text.isNotEmpty ? [text] : [];

    final bigrams = <String>[];
    for (int i = 0; i < text.length - 1; i++) {
      bigrams.add(text.substring(i, i + 2));
    }
    return bigrams;
  }

  /// Generate character trigrams from text.
  ///
  /// Example: "hello" -> ["hel", "ell", "llo"]
  List<String> generateTrigrams(String text) {
    if (text.length < 3) return text.isNotEmpty ? [text] : [];

    final trigrams = <String>[];
    for (int i = 0; i < text.length - 2; i++) {
      trigrams.add(text.substring(i, i + 3));
    }
    return trigrams;
  }

  /// Calculate bigram similarity using Dice coefficient.
  ///
  /// Dice coefficient: 2 * |intersection| / (|set1| + |set2|)
  /// Returns a value between 0.0 and 1.0.
  double bigramSimilarity(String s1, String s2) {
    final lower1 = s1.toLowerCase();
    final lower2 = s2.toLowerCase();

    final bigrams1 = generateBigrams(lower1);
    final bigrams2 = generateBigrams(lower2);

    if (bigrams1.isEmpty || bigrams2.isEmpty) return 0.0;

    final set1 = bigrams1.toSet();
    final set2 = bigrams2.toSet();

    final intersection = set1.intersection(set2).length;

    // Dice coefficient
    return (2 * intersection) / (set1.length + set2.length);
  }

  /// Calculate Jaccard similarity between bigram sets.
  ///
  /// Jaccard: |intersection| / |union|
  /// More conservative than Dice coefficient.
  double jaccardSimilarity(String s1, String s2) {
    final lower1 = s1.toLowerCase();
    final lower2 = s2.toLowerCase();

    final bigrams1 = generateBigrams(lower1).toSet();
    final bigrams2 = generateBigrams(lower2).toSet();

    if (bigrams1.isEmpty || bigrams2.isEmpty) return 0.0;

    final intersection = bigrams1.intersection(bigrams2).length;
    final union = bigrams1.union(bigrams2).length;

    return intersection / union;
  }

  /// Check if query partially matches text via bigrams.
  ///
  /// Uses Dice coefficient with configurable threshold.
  bool hasPartialMatch(String query, String text, {double threshold = 0.5}) {
    return bigramSimilarity(query, text) >= threshold;
  }

  /// Calculate containment coefficient.
  ///
  /// Measures how many of the query's bigrams are in the text.
  /// Useful when query is expected to be shorter than text.
  /// Returns |intersection| / |query bigrams|
  double containmentScore(String query, String text) {
    final queryBigrams = generateBigrams(query.toLowerCase()).toSet();
    final textBigrams = generateBigrams(text.toLowerCase()).toSet();

    if (queryBigrams.isEmpty) return 0.0;

    final intersection = queryBigrams.intersection(textBigrams).length;
    return intersection / queryBigrams.length;
  }
}
