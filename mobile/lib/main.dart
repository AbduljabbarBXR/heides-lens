import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_theme.dart';
import 'package:spikey/core/app_shell.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow();
    await windowManager.setMinimumSize(const Size(1024, 768));
    await windowManager.setSize(const Size(1280, 800));
    await windowManager.setTitle('Heides Lens');
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.show();
    await windowManager.focus();
  }

  runApp(const ProviderScope(child: SpikeyApp()));
}

class SpikeyApp extends ConsumerWidget {
  const SpikeyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Heides Lens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
