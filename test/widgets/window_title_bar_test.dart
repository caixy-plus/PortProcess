import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:port_process/widgets/window_title_bar/restore_icon.dart';
import 'package:port_process/widgets/window_title_bar/window_title_bar.dart';

void main() {
  group('WindowTitleBar', () {
    testWidgets('renders title and leading when forceShow is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindowTitleBar(
            title: 'Test App',
            leading: const Icon(Icons.ac_unit),
            forceShow: true,
          ),
        ),
      );

      expect(find.text('Test App'), findsOneWidget);
      expect(find.byIcon(Icons.ac_unit), findsOneWidget);
    });

    testWidgets('renders all control buttons by default when forceShow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindowTitleBar(
            forceShow: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.crop_square), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('hides minimize button when showMinimize is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindowTitleBar(
            forceShow: true,
            showMinimize: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.remove), findsNothing);
    });

    testWidgets('hides maximize button when showMaximize is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindowTitleBar(
            forceShow: true,
            showMaximize: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.crop_square), findsNothing);
    });

    testWidgets('hides close button when showClose is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindowTitleBar(
            forceShow: true,
            showClose: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('shows restore icon when isMaximized is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindowTitleBar(
            forceShow: true,
            isMaximized: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.crop_square), findsNothing);
      expect(find.byType(RestoreIcon), findsOneWidget);
    });

    testWidgets('triggers callbacks on button taps', (tester) async {
      bool minimized = false;
      bool maximized = false;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: WindowTitleBar(
            forceShow: true,
            onMinimize: () => minimized = true,
            onMaximize: () => maximized = true,
            onClose: () => closed = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.remove));
      expect(minimized, isTrue);

      await tester.tap(find.byIcon(Icons.crop_square));
      expect(maximized, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });
  });
}
