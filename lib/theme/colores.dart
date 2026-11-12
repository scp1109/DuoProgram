// ============================================================
//  colores.dart
//  Paleta unica de la app. Antes cada pantalla repetia los
//  literales Color(0xFF...) — solo el azul institucional
//  aparecia 103 veces. Cambiar la marca aqui la cambia en
//  toda la app.
// ============================================================

import 'package:flutter/material.dart';

/// Paleta de DuoProgram. Todos los colores de la UI salen de aqui.
abstract final class Colores {
  // ── Marca UTB ─────────────────────────────────────────────
  /// Azul institucional. Color primario del tema.
  static const primario = Color(0xFF1A1FC8);

  /// Variante clara del primario, para estados no seleccionados.
  static const primarioClaro = Color(0xFF2D33D4);

  /// Primario desaturado, para texto sobre fondo azul.
  static const primarioSuave = Color(0xFFADB5FF);

  // ── Fondos ────────────────────────────────────────────────
  /// Fondo general de las pantallas (azul muy claro).
  static const fondoApp = Color(0xFFF0F2FF);

  /// Fondo de chips y badges con tinte primario.
  static const fondoPrimarioSuave = Color(0xFFEEF0FF);

  /// Fondo neutro de tarjetas y campos deshabilitados.
  static const fondoNeutro = Color(0xFFF3F4F6);

  /// Fondo neutro mas claro, casi blanco.
  static const fondoNeutroClaro = Color(0xFFF9FAFB);

  // ── Texto ─────────────────────────────────────────────────
  /// Titulos y encabezados.
  static const textoTitulo = Color(0xFF1A1A2E);

  /// Texto de cuerpo con enfasis.
  static const textoOscuro = Color(0xFF374151);

  /// Texto secundario y etiquetas.
  static const textoSecundario = Color(0xFF6B7280);

  /// Texto e iconos de baja prioridad, placeholders.
  static const textoTenue = Color(0xFF9CA3AF);

  // ── Bordes ────────────────────────────────────────────────
  /// Borde estandar de campos y tarjetas.
  static const borde = Color(0xFFD1D5DB);

  /// Borde sutil, separadores.
  static const bordeSuave = Color(0xFFE5E7EB);

  // ── Estados semanticos ────────────────────────────────────
  /// Materia aprobada, confirmaciones.
  ///
  /// Verde mate, no el lima #4ADE00 que habia antes: aquel era neon y
  /// sobre blanco daba 1.79:1, muy por debajo del 4.5:1 legible. Este se
  /// usa como RELLENO con texto oscuro encima (7.6:1), no como color de
  /// texto; para texto esta exitoOscuro.
  static const exito = Color(0xFF4CAF50);

  /// Verde para TEXTO sobre fondo claro. 5.1:1 sobre blanco.
  static const exitoOscuro = Color(0xFF2E7D32);

  /// Verde muy claro, para fondos de bloques de confirmacion.
  static const exitoBruma = Color(0xFFE8F5E9);

  /// Errores, materias perdidas, acciones destructivas.
  static const error = Color(0xFFFF6B6B);

  /// Texto sobre fondo de error.
  static const errorOscuro = Color(0xFF991B1B);

  /// Fondo suave para mensajes de error.
  static const errorSuave = Color(0xFFFFD1D1);

  /// Advertencias, limite de creditos cerca del tope.
  static const advertencia = Color(0xFFFBBF24);

  /// Advertencia con mas contraste.
  static const advertenciaFuerte = Color(0xFFF59E0B);

  /// Texto sobre fondo de advertencia.
  static const advertenciaOscura = Color(0xFF92400E);

  // ── Acentos por origen de materia ─────────────────────────
  /// Materias del programa secundario.
  static const acentoMorado = Color(0xFF7C3AED);

  /// Materias compartidas entre ambos programas.
  ///
  /// Azul digital mate. Reemplaza al cian #00D4FF, que era neon y sobre
  /// fondo claro daba 1.64:1: por eso el boton de cambiar contrasena no se
  /// leia. Este sirve como RELLENO o sobre fondo oscuro (3.3:1 sobre
  /// blanco, insuficiente para texto pequeno); para texto usa el oscuro.
  static const acentoCian = Color(0xFF0099CC);

  /// Azul para TEXTO e iconos sobre fondo claro. 6.3:1 sobre blanco.
  static const acentoCianOscuro = Color(0xFF006699);

  /// Azul palido, para tintes sobre fondo oscuro.
  static const acentoAzulSuave = Color(0xFFA0C4E7);

  /// Azul muy claro, para fondos de bloques informativos.
  static const brumaAzul = Color(0xFFE6F2FF);

  /// Practicas profesionales.
  static const acentoNaranja = Color(0xFFEA580C);

  /// Tinta de las sombras. NO es negro puro: un negro azulado evita el
  /// gris sucio que deja rgba(0,0,0,x) sobre fondos con color.
  static const tintaSombra = Color(0xFF0B0D2E);
}

/// Superficies, sombras y acentos derivados de la marca.
///
/// La paleta de arriba son los colores oficiales de la UTB y no se tocan.
/// Esto de aca es material de apoyo elegido POR CERCANIA a ese azul: todos
/// caen en el rango indigo-violeta-cian, asi que la app se ve mas rica sin
/// dejar de leerse como institucional.
abstract final class Superficies {
  // ── Fondos profundos ──────────────────────────────────────
  /// Indigo casi negro. Base para cabeceras y secciones de contraste.
  /// Es el azul de marca llevado a su version mas oscura, no un gris neutro.
  static const tintaProfunda = Color(0xFF0B0D2E);

  /// Un paso mas claro que tintaProfunda, para capas superpuestas.
  static const tintaMedia = Color(0xFF141845);

  // ── Tintes claros ─────────────────────────────────────────
  /// Lavanda muy claro. Fondo de tarjetas que deben separarse del blanco.
  static const brumaLavanda = Color(0xFFF4F5FF);

  /// Periwinkle suave, para bordes y divisores con tinte de marca
  /// en vez del gris generico.
  static const nieblaAzul = Color(0xFFDDE0FA);

  // ── Sombras ───────────────────────────────────────────────
  // Regla del sistema: nunca sombras negras duras. La luz se tinta con el
  // color de marca y se difunde mucho, que es lo que separa una tarjeta
  // "cara" de una con drop shadow por defecto.

  /// Sombra ambiental amplia. Da elevacion sin ensuciar el fondo.
  static List<BoxShadow> get ambiente => [
        BoxShadow(
          color: Colores.primario.withValues(alpha: 0.07),
          blurRadius: 40,
          offset: const Offset(0, 16),
          spreadRadius: -12,
        ),
        BoxShadow(
          color: Colores.tintaSombra.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: -4,
        ),
      ];

  /// Sombra corta para elementos que flotan poco (chips, botones).
  static List<BoxShadow> get sutil => [
        BoxShadow(
          color: Colores.primario.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -6,
        ),
      ];

  /// Sombra "apagada": misma forma que las demas pero sin desenfoque.
  ///
  /// Es higiene, NO una proteccion. Da a la interpolacion dos extremos de la
  /// misma forma en vez de hacerla adivinar contra null, pero no evita que
  /// una curva con rebote extrapole a negativo: lerp(16, 0, 1.0978) sigue
  /// dando -1.56. Lo unico que evita ese crash es no usar curvas que
  /// sobrepasen 1.0 en decoraciones (ver Movimiento.resorte).
  static const List<BoxShadow> ninguna = [
    BoxShadow(color: Colors.transparent, blurRadius: 0, offset: Offset.zero),
  ];

  /// Sombra pronunciada para superficies que se elevan al interactuar.
  static List<BoxShadow> get elevada => [
        BoxShadow(
          color: Colores.primario.withValues(alpha: 0.16),
          blurRadius: 56,
          offset: const Offset(0, 24),
          spreadRadius: -16,
        ),
      ];

  // ── Radios (squircle exagerado) ───────────────────────────
  // El sistema usa radios grandes y concentricos. Cuando una tarjeta va
  // dentro de otra, el radio interno se calcula restando el padding para
  // que las curvas queden paralelas: radioInterno(externo, padding).
  static const double radioTarjeta = 26;
  static const double radioInterior = 18;
  static const double radioPildora = 999;

  /// Radio concentrico: el hijo debe curvarse menos que el padre,
  /// exactamente por el grosor del marco que lo rodea.
  static double radioInterno(double externo, double padding) {
    final r = externo - padding;
    return r < 0 ? 0 : r;
  }
}
