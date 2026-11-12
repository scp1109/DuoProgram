// ============================================================
//  transiciones.dart
//  Transiciones entre pantallas.
//
//  Antes toda la app usaba MaterialPageRoute, que en Android hace el
//  slide horizontal de siempre. Estas rutas usan movimiento en el eje Z
//  (profundidad) y desvanecido cruzado: en vez de "la pantalla entra por
//  el borde", la sensacion es "me acerque a algo" o "cambie de lugar".
//
//  Todas animan SOLO transform y opacity. Nada de animar width/height ni
//  posiciones absolutas, que obligan al motor a recalcular layout en cada
//  frame y tiran los fps en movil.
// ============================================================

import 'package:flutter/material.dart';
import 'movimiento.dart';

/// Profundidad hacia adelante: entras "dentro" de algo.
///
/// La pantalla nueva llega desde atras (escala 0.92) mientras la vieja
/// se aleja hacia el fondo (escala 1.06) y se desvanece. Al volver, el
/// movimiento se invierte solo, sin codigo extra.
///
/// Se usa para navegacion en profundidad: seleccion -> historial ->
/// planificacion, o abrir el detalle de un plan.
class RutaProfundidad<T> extends PageRouteBuilder<T> {
  RutaProfundidad({required this.pagina, super.settings})
      : super(
          transitionDuration: Movimiento.media,
          reverseTransitionDuration: Movimiento.corta,
          pageBuilder: (_, _, _) => pagina,
        );

  final Widget pagina;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // animation: 0 -> 1 mientras ESTA pantalla entra.
    // secondaryAnimation: 0 -> 1 cuando otra pantalla se apila encima.
    final entrada = CurvedAnimation(
      parent: animation,
      curve: Movimiento.entrada,
      reverseCurve: Movimiento.salida,
    );
    final saliente = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Movimiento.principal,
    );

    return AnimatedBuilder(
      animation: saliente,
      builder: (context, hijo) {
        // La pantalla que queda debajo retrocede en Z y se apaga un poco.
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

/// Desvanecido cruzado con escala minima: cambias de lugar, no de nivel.
///
/// No hay direccion porque no hay jerarquia: ninguna pantalla es "hija"
/// de la otra. Se usa para los destinos del menu lateral (Perfil, Mis
/// planes, Inicio), donde un slide sugeriria un orden que no existe.
class RutaDesvanecido<T> extends PageRouteBuilder<T> {
  RutaDesvanecido({required this.pagina, super.settings})
      : super(
          transitionDuration: Movimiento.corta,
          reverseTransitionDuration: Movimiento.corta,
          pageBuilder: (_, _, _) => pagina,
          // Opaca en false: durante el cruce se ven las dos capas,
          // que es justo lo que hace que se sienta continuo.
          opaque: true,
        );

  final Widget pagina;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curva = CurvedAnimation(
      parent: animation,
      curve: Movimiento.principal,
      reverseCurve: Movimiento.principal.flipped,
    );
    return FadeTransition(
      opacity: curva,
      child: ScaleTransition(
        // Escala casi imperceptible: da vida sin que se lea como zoom.
        scale: Tween<double>(begin: 0.97, end: 1).animate(curva),
        child: child,
      ),
    );
  }
}

/// Sube desde abajo con desenfoque de entrada: para pantallas que
/// interrumpen el flujo (editar perfil, cambiar contrasena).
///
/// El desplazamiento es corto (8% de la altura) a proposito: un slide
/// completo desde el borde inferior se siente lento y barato.
class RutaModal<T> extends PageRouteBuilder<T> {
  RutaModal({required this.pagina, super.settings})
      : super(
          transitionDuration: Movimiento.media,
          reverseTransitionDuration: Movimiento.corta,
          pageBuilder: (_, _, _) => pagina,
        );

  final Widget pagina;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curva = CurvedAnimation(
      parent: animation,
      curve: Movimiento.entrada,
      reverseCurve: Movimiento.salida,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(curva),
      child: FadeTransition(opacity: curva, child: child),
    );
  }
}

/// Reemplazo de raiz: se usa al cerrar sesion o al entrar tras el login,
/// donde no hay pila que conservar. Escala hacia adentro y desvanece,
/// que lee como "la app se reinicia" en vez de "retrocedi".
class RutaRaiz<T> extends PageRouteBuilder<T> {
  RutaRaiz({required this.pagina, super.settings})
      : super(
          transitionDuration: Movimiento.media,
          reverseTransitionDuration: Movimiento.corta,
          pageBuilder: (_, _, _) => pagina,
        );

  final Widget pagina;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curva = CurvedAnimation(parent: animation, curve: Movimiento.entrada);
    return FadeTransition(
      opacity: curva,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.04, end: 1).animate(curva),
        child: child,
      ),
    );
  }
}
