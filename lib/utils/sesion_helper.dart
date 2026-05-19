// ============================================================
//  sesion_helper:
//  Utilidades estaticas para manejo de sesion del usuario.
//  Centraliza: cerrar sesion, limpiar credenciales y manejar
//  tokens expirados (401) desde cualquier pantalla.
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/servicio_api.dart';
import '../screens/pantalla_inicio.dart';

class SesionHelper {
  static Future<void> limpiarCredenciales() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_data');
  }

  static Future<void> cerrarSesion(BuildContext context) async {
    await limpiarCredenciales();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaInicio()),
      (route) => false,
    );
  }

  static Future<void> manejarSesionExpirada(BuildContext context) async {
    await limpiarCredenciales();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tu sesion ha vencido. Inicia sesion de nuevo para continuar.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaInicio()),
      (route) => false,
    );
  }

  static bool esSesionExpirada(Object e) => e is SesionExpiradaException;
}
