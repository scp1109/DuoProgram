// ============================================================
//  main.dart
//  Punto de entrada de la app DuoProgram
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/pantalla_inicio.dart';
import 'theme/colores.dart';
import 'theme/movimiento.dart';

void main() {
  runApp(const DuoProgramApp());
}

class DuoProgramApp extends StatelessWidget {
  const DuoProgramApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Plus Jakarta Sans reemplaza a Roboto. Roboto es la fuente por defecto
    // de Android: correcta, pero tan comun que la interfaz se lee como un
    // borrador. Esta grotesca tiene mas personalidad en titulares grandes y
    // sigue siendo muy legible en texto corrido.
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colores.primario,
        primary: Colores.primario,
      ),
    );

    return MaterialApp(
      title: 'DuoProgram',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
        scaffoldBackgroundColor: Colores.fondoApp,

        // Transiciones por defecto en TODA la app. Sin esto, cualquier
        // Navigator.push que no use una ruta propia vuelve al slide
        // horizontal de Android.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _TransicionProfundidadBuilder(),
            TargetPlatform.iOS: _TransicionProfundidadBuilder(),
            TargetPlatform.windows: _TransicionProfundidadBuilder(),
            TargetPlatform.macOS: _TransicionProfundidadBuilder(),
            TargetPlatform.linux: _TransicionProfundidadBuilder(),
          },
        ),

        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            // Pildora completa en vez del radio timido de 12: es el
            // remate que separa un CTA cuidado de uno por defecto.
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Superficies.radioPildora),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          // 14 y no 18: con icono a ambos lados, 18 dejaba sin ancho a
          // etiquetas largas como 'Confirmar contrasena', que se cortaban.
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          // Hairline tintado de marca en lugar del gris generico.
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Superficies.radioInterior),
            borderSide: const BorderSide(color: Superficies.nieblaAzul),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Superficies.radioInterior),
            borderSide: const BorderSide(color: Colores.primario, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Superficies.radioInterior),
            borderSide: const BorderSide(color: Superficies.nieblaAzul),
          ),
          // El borde de error vive aqui y no en cada pantalla: antes el
          // registro lo repetia inline en sus cuatro campos.
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Superficies.radioInterior),
            borderSide: const BorderSide(color: Colores.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Superficies.radioInterior),
            borderSide: const BorderSide(color: Colores.error, width: 1.5),
          ),
          errorStyle: const TextStyle(
              color: Colores.errorOscuro,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Superficies.radioInterior),
          ),
          contentTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
          ),
        ),
      ),
      home: const PantallaInicio(),
    );
  }
}

/// Adapta la transicion de profundidad al contrato de PageTransitionsTheme,
/// que Flutter usa para las rutas que no traen animacion propia.
class _TransicionProfundidadBuilder extends PageTransitionsBuilder {
  const _TransicionProfundidadBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final entrada = CurvedAnimation(
      parent: animation,
      curve: Movimiento.entrada,
      reverseCurve: Movimiento.salida,
    );
    final saliente =
        CurvedAnimation(parent: secondaryAnimation, curve: Movimiento.principal);

    return AnimatedBuilder(
      animation: saliente,
      builder: (context, hijo) {
        final t = saliente.value;
        return Transform.scale(
          scale: 1 - (0.06 * t),
          child: Opacity(opacity: 1 - (0.35 * t), child: hijo),
        );
      },
      child: FadeTransition(
        opacity: entrada,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(entrada),
          child: child,
        ),
      ),
    );
  }
}
