import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/project_store.dart';
import 'features/projects/projects_screen.dart';

void main() {
  runApp(const VybeCodeApp());
}

class VybeCodeApp extends StatelessWidget {
  const VybeCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProjectStore(),
      child: MaterialApp(
        title: 'VybeCode',
        theme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFF00FF88),
          scaffoldBackgroundColor: const Color(0xFF0A0A0F),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00FF88),
            secondary: Color(0xFF00CCFF),
            surface: Color(0xFF12121A),
          ),
        ),
        home: const ProjectsScreen(),
      ),
    );
  }
}
