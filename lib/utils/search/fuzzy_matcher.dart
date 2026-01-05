import 'dart:math';

/// Fuzzy string matching using Jaro-Winkler similarity.
///
/// Jaro-Winkler is optimized for short strings like artist/song names
/// and gives extra weight to matching prefixes (common typos occur mid-word).
class FuzzyMatcher {
  /// Calculate Jaro-Winkler similarity between two strings.
  ///
  /// Returns a value between 0.0 (no similarity) and 1.0 (exact match).
  ///
  /// Jaro-Winkler gives bonus weight to strings that match from the beginning,
  /// which is useful for handling typos like "Beetles" vs "Beatles".
  double jaroWinklerSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final jaro = _jaroSimilarity(s1, s2);

    // Winkler modification: boost score for common prefix
    int prefixLength = 0;
    const maxPrefix = 4; // Standard Winkler prefix length
    final minLen = min(s1.length, s2.length);
    final prefixLimit = min(maxPrefix, minLen);

    for (int i = 0; i < prefixLimit; i++) {
      if (s1[i] == s2[i]) {
        prefixLength++;
      } else {
        break;
      }
    }

    const scalingFactor = 0.1; // Standard Winkler scaling factor
    return jaro + (prefixLength * scalingFactor * (1 - jaro));
  }

  /// Calculate base Jaro similarity.
  double _jaroSimilarity(String s1, String s2) {
    final s1Len = s1.length;
    final s2Len = s2.length;

    // Match window: characters within this distance can match
    final matchWindow = (max(s1Len, s2Len) / 2 - 1).floor();
    if (matchWindow < 0) return 0.0;

    final s1Matches = List.filled(s1Len, false);
    final s2Matches = List.filled(s2Len, false);

    int matches = 0;
    int transpositions = 0;

    // Find matching characters
    for (int i = 0; i < s1Len; i++) {
      final start = max(0, i - matchWindow);
      final end = min(s2Len, i + matchWindow + 1);

      for (int j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = true;
        s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    // Count transpositions
    int k = 0;
    for (int i = 0; i < s1Len; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }

    // Jaro similarity formula
    return (matches / s1Len +
            matches / s2Len +
            (matches - transpositions / 2) / matches) /
        3;
  }

  /// Find the best match score between query tokens and text tokens.
  ///
  /// Useful for matching individual words when full string matching fails.
  /// Returns the highest similarity score found between any token pair.
  double bestTokenMatch(List<String> queryTokens, List<String> textTokens) {
    if (queryTokens.isEmpty || textTokens.isEmpty) return 0.0;

    double bestScore = 0.0;

    for (final queryToken in queryTokens) {
      for (final textToken in textTokens) {
        final score = jaroWinklerSimilarity(queryToken, textToken);
        if (score > bestScore) {
          bestScore = score;
          // Early exit if we find a perfect match
          if (score == 1.0) return 1.0;
        }
      }
    }

    return bestScore;
  }

  /// Check if two strings are a fuzzy match within a threshold.
  bool isFuzzyMatch(String s1, String s2, {double threshold = 0.85}) {
    return jaroWinklerSimilarity(s1, s2) >= threshold;
  }

  /// Calculate average token match score.
  ///
  /// For each query token, finds the best matching text token,
  /// then averages all best matches. Useful for multi-word queries.
  double averageTokenMatch(List<String> queryTokens, List<String> textTokens) {
    if (queryTokens.isEmpty || textTokens.isEmpty) return 0.0;

    double totalScore = 0.0;

    for (final queryToken in queryTokens) {
      double bestForToken = 0.0;
      for (final textToken in textTokens) {
        final score = jaroWinklerSimilarity(queryToken, textToken);
        if (score > bestForToken) {
          bestForToken = score;
        }
      }
      totalScore += bestForToken;
    }

    return totalScore / queryTokens.length;
  }
}
