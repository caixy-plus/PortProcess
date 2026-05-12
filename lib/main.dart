import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_theme/system_theme.dart';

import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await SystemTheme.accentColor.load();

  final windowOptions = WindowOptions(
    size: const Size(900, 600),
    center: true,
    title: 'PortProcess',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    backgroundColor: Colors.transparent,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const PortProcessApp());
}

class PortProcessApp extends StatelessWidget {
  const PortProcessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accentColor = SystemTheme.accentColor.accent;

    return MaterialApp(
      title: 'PortProcess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: '.SF Pro Text',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: '.SF Pro Text',
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
