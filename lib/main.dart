// ============================================================
//  main.dart
//  Punto de entrada de la app DuoProgram
// ============================================================

import 'package:flutter/material.dart';
import 'screens/pantalla_inicio.dart';

void main() {
  runApp(const DuoProgramApp());
}

class DuoProgramApp extends StatelessWidget {
  const DuoProgramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuoProgram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1FC8),
          primary: const Color(0xFF1A1FC8),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const PantallaInicio(),
    );
  }
}