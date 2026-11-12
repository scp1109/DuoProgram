// ============================================================
//  movimiento.dart
//  Curvas y duraciones unicas de la app.
//
//  Regla del sistema: nada de `Curves.linear` ni `Curves.easeInOut`.
//  Esas curvas son simetricas y por eso se sienten mecanicas: el objeto
//  acelera y frena igual, cosa que no pasa con nada que tenga masa.
//  Todo aqui arranca rapido y frena largo, que es como se mueve algo
//  fisico, y es lo que separa una transicion "cara" de una por defecto.
// ============================================================

import 'package:flutter/animation.dart';

abstract final class Movimiento {
  // ── Curvas ────────────────────────────────────────────────

  /// Curva principal. Salida casi instantanea y frenado muy largo.
  /// Es la misma de los sistemas de diseno tipo Linear/Vercel.
  static const Cubic principal = Cubic(0.32, 0.72, 0, 1);

  /// Para elementos que ENTRAN a pantalla. Empuja un poco al final,
  /// dando sensacion de que el objeto se asienta.
  static const Cubic entrada = Cubic(0.16, 1, 0.3, 1);

  /// Para elementos que SALEN. Acelera al irse, sin frenado:
  /// lo que se va no necesita que lo miren.
  static const Cubic salida = Cubic(0.7, 0, 0.84, 0);

  /// Resorte suave para respuestas al tacto (presionar, soltar).
  ///
  /// CUIDADO: el 1.56 hace que esta curva SOBREPASE 1.0; ese rebote es su
  /// razon de ser. Por eso solo puede manejar propiedades que aguanten
  /// extrapolarse: scale, translate, rotate.
  ///
  /// Nunca se la pases a un AnimatedContainer que interpole colores o
  /// sombras. Con t > 1 el blurRadius se vuelve negativo y Flutter lanza
  /// "Text shadow blur radius should be non-negative". Para decoraciones
  /// usa `principal`, que se queda dentro de [0, 1].
  static const Cubic resorte = Cubic(0.34, 1.56, 0.64, 1);

  // ── Duraciones ────────────────────────────────────────────
  // Escalonadas a proposito: mientras mas grande el elemento que se mueve,
  // mas lento debe ir, o parece que salta.

  /// Reaccion inmediata: color de un boton, estado de un check.
  static const Duration instante = Duration(milliseconds: 180);

  /// Movimiento de un componente: card que se expande, chip que aparece.
  static const Duration corta = Duration(milliseconds: 320);

  /// Transicion entre pantallas.
  static const Duration media = Duration(milliseconds: 520);

  /// Revelados de entrada, que deben sentirse pausados.
  static const Duration larga = Duration(milliseconds: 780);

  /// Retraso entre elementos de una misma lista al revelarse.
  /// Se escalona para que la lista "caiga" en cascada y no de golpe.
  static const Duration escalon = Duration(milliseconds: 70);

  /// Retraso acumulado del elemento en la posicion [indice].
  /// Se topa a los 6 elementos: mas alla de eso el usuario ya
  /// esta esperando en vez de disfrutar la animacion.
  static Duration escalonar(int indice, {int maximo = 6}) =>
      escalon * (indice > maximo ? maximo : indice);
}
