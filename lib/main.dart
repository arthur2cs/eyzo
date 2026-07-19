import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_shell.dart';
import 'core/storage/hive_boxes.dart';
import 'core/theme/app_theme.dart';
import 'widgets/keyboard_dismiss_unfocus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  runApp(const ProviderScope(child: EyzoApp()));
}

class EyzoApp extends StatelessWidget {
  const EyzoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eyzo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      theme: AppTheme.dark,
      builder: (context, child) => KeyboardDismissUnfocus(child: child!),
      home: const AppShell(),
    );
  }
}
