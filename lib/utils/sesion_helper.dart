// ============================================================
//  sesion_helper:
//  Utilidades estaticas para manejo de sesion del usuario.
//  Centraliza: cerrar sesion, limpiar credenciales y manejar
//  tokens expirados (401) desde cualquier pantalla.
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/claves_prefs.dart';
import '../services/servicio_api.dart';
import '../screens/pantalla_inicio.dart';
import '../theme/transiciones.dart';
import '../theme/colores.dart';

class SesionHelper {
  static Future<void> limpiarCredenciales() async {
    final prefs = await SharedPreferences.getInstance();
    // Se recorre la lista de ClavesPrefs en vez de borrar clave por
    // clave: asi, si mañana se agrega otro dato de sesion, se limpia
    // solo con agregarlo alla y no se queda colgado en el dispositivo.
    for (final clave in ClavesPrefs.clavesDeSesion) {
      await prefs.remove(clave);
    }
  }

  static Future<void> cerrarSesion(BuildContext context) async {
    await limpiarCredenciales();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      RutaRaiz(pagina: const PantallaInicio()),
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
        backgroundColor: Colores.error,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      RutaRaiz(pagina: const PantallaInicio()),
      (route) => false,
    );
  }

  static bool esSesionExpirada(Object e) => e is SesionExpiradaException;
}
