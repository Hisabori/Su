import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() => runApp(const SuhoAngelApp());

class SuhoAngelApp extends StatelessWidget {
  const SuhoAngelApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '수호천사',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'NanumGothic',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00C896)),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const LoginScreen(),
      );
}
