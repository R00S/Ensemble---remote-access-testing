/// Text normalization utilities for search scoring.
///
/// Handles query normalization, stopword removal, and tokenization.

/// Represents a normalized search query with various forms for matching.
class NormalizedQuery {
  /// Original query as entered by user
  final String original;

  /// Lowercased and trimmed query
  final String normalized;

  /// Query with stopwords removed
  final String withoutStopwords;

  /// Individual tokens from normalized query
  final List<String> tokens;

  /// Tokens with stopwords removed
  final List<String> tokensNoStop;

  const NormalizedQuery({
    required this.original,
    required this.normalized,
    required this.withoutStopwords,
    required this.tokens,
    required this.tokensNoStop,
  });

  /// Whether the query is empty after normalization
  bool get isEmpty => normalized.isEmpty;

  /// Whether stopword removal changed the query
  bool get hasStopwordsRemoved => normalized != withoutStopwords;
}

/// Normalizes text and queries for search matching.
class TextNormalizer {
  /// Common English stopwords relevant to music/media searches.
  ///
  /// Intentionally minimal to avoid over-filtering:
  /// - Articles that commonly prefix artist/album names
  /// - Common prepositions that add noise
  static const Set<String> _stopwords = {
    // Articles
    'the',
    'a',
    'an',
    // Common prepositions in music/media context
    'of',
    'and',
    'in',
    'on',
    'at',
    'to',
    'for',
    'with',
    'by',
    // Common noise words
    'is',
    'are',
    'was',
    'be',
  };

  /// Normalize a search query into multiple forms for matching.
  ///
  /// Returns a [NormalizedQuery] containing:
  /// - Original query
  /// - Lowercased/trimmed version
  /// - Version with stopwords removed
  /// - Tokenized versions
  NormalizedQuery normalizeQuery(String query) {
    final normalized = query.toLowerCase().trim();
    final tokens = tokenize(normalized);
    final tokensNoStop = tokens.where((t) => !_stopwords.contains(t)).toList();

    // If all tokens were stopwords, preserve original tokens
    // e.g., "The The" (band name) shouldn't become empty
    final effectiveTokensNoStop =
        tokensNoStop.isEmpty ? tokens : tokensNoStop;
    final withoutStopwords = effectiveTokensNoStop.join(' ');

    return NormalizedQuery(
      original: query,
      normalized: normalized,
      withoutStopwords: withoutStopwords,
      tokens: tokens,
      tokensNoStop: effectiveTokensNoStop,
    );
  }

  /// Normalize text for comparison (lowercase, trim).
  String normalizeText(String text) {
    return text.toLowerCase().trim();
  }

  /// Normalize text with stopwords removed.
  String normalizeTextNoStopwords(String text) {
    final tokens = tokenize(text.toLowerCase().trim());
    final filtered = tokens.where((t) => !_stopwords.contains(t)).toList();
    return filtered.isEmpty ? text.toLowerCase().trim() : filtered.join(' ');
  }

  /// Split text into tokens on whitespace.
  List<String> tokenize(String text) {
    return text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  /// Check if a word is a stopword.
  bool isStopword(String word) {
    return _stopwords.contains(word.toLowerCase());
  }
}
