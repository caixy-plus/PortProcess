/// Abstract interface for matching input text against a set of candidates.
///
/// Implementations decide how suggestions are produced and ordered.
/// The [match] method is called on every keystroke with the current input.
abstract class HitMatcher {
  /// Returns a list of suggestion strings for the given [input].
  ///
  /// The list should be ordered so that the most desirable completion
  /// (e.g. the shortest prefix match) appears first.
  List<String> match(String input);
}
