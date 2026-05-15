import 'hit_matcher.dart';

/// Default [HitMatcher] that matches against a static keyword list by prefix.
class KeywordHitMatcher implements HitMatcher {
  KeywordHitMatcher({
    required this.keywords,
    this.caseSensitive = false,
  });

  final List<String> keywords;
  final bool caseSensitive;

  @override
  List<String> match(String input) {
    if (input.isEmpty) return const [];

    final query = caseSensitive ? input : input.toLowerCase();

    final matches = keywords.where((keyword) {
      final target = caseSensitive ? keyword : keyword.toLowerCase();
      return target.startsWith(query);
    }).toList();

    // Shortest first, then alphabetically.
    matches.sort((a, b) {
      final lenCmp = a.length.compareTo(b.length);
      if (lenCmp != 0) return lenCmp;
      return a.compareTo(b);
    });

    return matches;
  }
}
