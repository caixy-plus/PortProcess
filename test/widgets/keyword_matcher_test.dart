import 'package:flutter_test/flutter_test.dart';
import 'package:port_process/widgets/tab_hit/keyword_matcher.dart';

void main() {
  group('KeywordHitMatcher', () {
    test('returns empty list for empty input', () {
      final matcher = KeywordHitMatcher(keywords: const ['java', 'node']);
      expect(matcher.match(''), isEmpty);
    });

    test('matches by prefix case-insensitively by default', () {
      final matcher = KeywordHitMatcher(keywords: const ['Java', 'Node', 'JavaScript']);
      expect(matcher.match('j'), equals(['Java', 'JavaScript']));
      expect(matcher.match('J'), equals(['Java', 'JavaScript']));
    });

    test('sorts shortest match first', () {
      final matcher = KeywordHitMatcher(
        keywords: const ['java', 'javascript', 'jakarta'],
      );
      expect(matcher.match('j'), equals(['java', 'jakarta', 'javascript']));
    });

    test('sorts alphabetically when lengths are equal', () {
      final matcher = KeywordHitMatcher(
        keywords: const ['node', 'nginx', 'nest'],
      );
      expect(matcher.match('n'), equals(['nest', 'node', 'nginx']));
    });

    test('respects caseSensitive flag', () {
      final matcher = KeywordHitMatcher(
        keywords: const ['Java', 'Node'],
        caseSensitive: true,
      );
      expect(matcher.match('j'), isEmpty);
      expect(matcher.match('J'), equals(['Java']));
    });

    test('returns empty when no match', () {
      final matcher = KeywordHitMatcher(keywords: const ['java', 'node']);
      expect(matcher.match('xyz'), isEmpty);
    });
  });
}
