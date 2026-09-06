import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChromaCamApp());
}

class ChromaCamApp extends StatelessWidget {
  const ChromaCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'クロマキャム',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'NotoSansJP',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF40671),
          secondary: Color(0xFF0069FC),
          tertiary: Color(0xFFFDB200),
          surface: Color(0xFF121218),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0B10),
      ),
      home: const HomeScreen(),
    );
  }
}