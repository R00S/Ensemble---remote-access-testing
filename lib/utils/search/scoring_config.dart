/// Configuration for search scoring weights and thresholds.
///
/// All scores are designed to work with the existing sorting system
/// where higher scores indicate better matches.
class ScoringConfig {
  // Base scores for match types (primary name matching)
  final double exactMatch;
  final double exactMatchNoStopwords;
  final double startsWithMatch;
  final double startsWithNoStopwords;
  final double wordBoundaryMatch;
  final double wordBoundaryNoStopwords;
  final double reverseContainsMatch;
  final double reverseContainsNoStopwords;
  final double containsMatch;
  final double containsNoStopwords;
  final double fuzzyMatchHigh;
  final double fuzzyMatchMedium;
  final double ngramMatch;
  final double baseline;

  // Bonuses (additive)
  final double libraryBonus;
  final double favoriteBonus;
  final double artistFieldExactBonus;
  final double artistFieldPartialBonus;
  final double albumFieldBonus;
  final double authorFieldExactBonus;
  final double authorFieldPartialBonus;
  final double narratorFieldBonus;
  final double creatorFieldExactBonus;
  final double creatorFieldPartialBonus;
  final double descriptionBonus;

  // Thresholds
  final double fuzzyHighThreshold;
  final double fuzzyMediumThreshold;
  final double ngramThreshold;

  // Minimum lengths for matching
  final int minReverseMatchLength;
  final int minTokenLength;

  const ScoringConfig({
    // Primary match scores
    this.exactMatch = 100,
    this.exactMatchNoStopwords = 95,
    this.startsWithMatch = 85,
    this.startsWithNoStopwords = 80,
    this.wordBoundaryMatch = 70,
    this.wordBoundaryNoStopwords = 65,
    this.reverseContainsMatch = 60,
    this.reverseContainsNoStopwords = 55,
    this.containsMatch = 50,
    this.containsNoStopwords = 45,
    this.fuzzyMatchHigh = 40,
    this.fuzzyMatchMedium = 35,
    this.ngramMatch = 25,
    this.baseline = 20,

    // Bonuses
    this.libraryBonus = 10,
    this.favoriteBonus = 5,
    this.artistFieldExactBonus = 15,
    this.artistFieldPartialBonus = 8,
    this.albumFieldBonus = 5,
    this.authorFieldExactBonus = 15,
    this.authorFieldPartialBonus = 8,
    this.narratorFieldBonus = 5,
    this.creatorFieldExactBonus = 15,
    this.creatorFieldPartialBonus = 8,
    this.descriptionBonus = 5,

    // Thresholds
    this.fuzzyHighThreshold = 0.90,
    this.fuzzyMediumThreshold = 0.85,
    this.ngramThreshold = 0.5,

    // Minimum lengths
    this.minReverseMatchLength = 3,
    this.minTokenLength = 3,
  });

  /// Default configuration
  static const ScoringConfig defaults = ScoringConfig();
}
