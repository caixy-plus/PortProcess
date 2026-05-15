import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:port_process/widgets/tab_hit/tab_hit.dart';
import 'package:port_process/widgets/tab_hit/keyword_matcher.dart';

void main() {
  Future<void> pumpTabHit(WidgetTester tester, {List<String>? keywords}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TabHit(
            matcher: KeywordHitMatcher(
              keywords: keywords ?? const ['java', 'javascript', 'node', 'nginx'],
            ),
          ),
        ),
      ),
    );
  }

  group('TabHit', () {
    testWidgets('shows dropdown on ArrowDown when multiple matches', (tester) async {
      await pumpTabHit(tester);
      await tester.enterText(find.byType(TextField), 'j');
      await tester.pump();

      expect(find.text('java'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(find.text('java'), findsOneWidget);
      expect(find.text('javascript'), findsOneWidget);
    });

    testWidgets('completes with shortest match on Tab', (tester) async {
      await pumpTabHit(tester);
      await tester.enterText(find.byType(TextField), 'j');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final controller = tester.widget<TextField>(find.byType(TextField)).controller;
      expect(controller?.text, 'java');
    });

    testWidgets('cycles selection with arrow keys', (tester) async {
      await pumpTabHit(tester);
      await tester.enterText(find.byType(TextField), 'j');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final controller = tester.widget<TextField>(find.byType(TextField)).controller;
      expect(controller?.text, 'javascript');
    });

    testWidgets('hides dropdown on Escape', (tester) async {
      await pumpTabHit(tester);
      await tester.enterText(find.byType(TextField), 'j');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(find.text('java'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('java'), findsNothing);
    });
  });
}
