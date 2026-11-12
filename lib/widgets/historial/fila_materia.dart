// ============================================================
//  fila_materia.dart
//  Piezas visuales del historial academico que no dependen del
//  estado del wizard.
//
//  Se sacaron de pantalla_historial.dart porque ese archivo pasaba
//  de 2000 lineas y estas tres clases son las unicas que viven
//  fuera de _PantallaHistorialState: reciben todo por parametro y
//  no leen nada privado de la pantalla.
//
//  Lenguaje visual (ver theme/colores.dart y widgets/superficie.dart):
//  cada fila es una tarjeta de bisel doble — cascara tenue afuera,
//  nucleo blanco adentro — con radios concentricos. Nada de bordes
//  grises de 1px ni sombras negras: hairline tintado de marca y
//  sombras difusas de Superficies.
//
//  MOVIMIENTO: todo cambio de estado interpola con Movimiento.principal.
//  Movimiento.resorte sobrepasa 1.0 y SOLO se usa en escala/transform
//  (dentro de Presionable y del ScaleTransition de los iconos); pasarlo
//  a una decoracion extrapola el blurRadius a negativo y revienta.
// ============================================================

import 'package:flutter/material.dart';
import '../../data/datos_programa.dart';
import '../../theme/colores.dart';
import '../../theme/movimiento.dart';
import '../superficie.dart';

// ── Estados de fila ───────────────────────────────────────────
enum EstadoMateria { sinRegistrar, aprobada, perdida, aprobadaAntes, homologada }

// ── Geometria compartida ──────────────────────────────────────
// La fila usa el radio interior (18) y no el de tarjeta (26): es una
// pieza baja, y con 26 se leeria como pastilla en vez de tarjeta.
// El nucleo se curva menos, exactamente por el grosor del marco.
const double _radioFila = Superficies.radioInterior;
const double _marcoFila = 4;
final double _radioNucleoFila =
    Superficies.radioInterno(_radioFila, _marcoFila);

// La card de homologacion si es una tarjeta completa: radio de tarjeta
// y el marco de 6 que usa TarjetaBisel por defecto.
const double _marcoCard = 6;
final double _radioNucleoCard =
    Superficies.radioInterno(Superficies.radioTarjeta, _marcoCard);

/// Squircle chico para la gema de la card (derivado, no un 12 suelto).
final double _radioGema = Superficies.radioInterno(Superficies.radioInterior, 6);

// ── Fila de materia ───────────────────────────────────────────
class FilaMateria extends StatelessWidget {
  final String nombre;
  final EstadoMateria estado;
  final bool bloqueada;
  final String? etiquetaExtra;
  final VoidCallback? onAprobada;
  final VoidCallback? onPerdida;
  final VoidCallback? onQuitar;

  const FilaMateria({
    super.key,
    required this.nombre,
    required this.estado,
    required this.bloqueada,
    this.etiquetaExtra,
    this.onAprobada,
    this.onPerdida,
    this.onQuitar,
  });

  /// Tinte de la fila: el color con el que se pintan fondos y hairlines.
  /// Null = estado sin color propio (sin registrar / ya aprobada antes).
  Color? get _acento => switch (estado) {
        EstadoMateria.aprobada => Colores.exito,
        EstadoMateria.perdida => Colores.error,
        EstadoMateria.homologada => Colores.acentoMorado,
        _ => null,
      };

  /// Tinta legible del estado. El verde de marca es muy luminoso para
  /// texto e iconos, asi que ahi se usa su version oscura; el tinte de
  /// fondo sigue siendo el color oficial.
  Color get _tinta => switch (estado) {
        EstadoMateria.aprobada => Colores.exitoOscuro,
        EstadoMateria.perdida => Colores.errorOscuro,
        EstadoMateria.homologada => Colores.acentoMorado,
        _ => Colores.textoTenue,
      };

  /// Segunda linea. La homologacion muestra de donde viene; cualquier
  /// otro estado con etiqueta la muestra tal cual.
  String? get _subtitulo {
    if (estado == EstadoMateria.homologada) {
      return etiquetaExtra == null ? 'Homologada' : 'Homologada · $etiquetaExtra';
    }
    return etiquetaExtra;
  }

  @override
  Widget build(BuildContext context) {
    final acento = _acento;
    final marcado = acento != null;
    final inerte = estado == EstadoMateria.aprobadaAntes;
    final sub = _subtitulo;

    return AnimatedContainer(
      duration: Movimiento.corta,
      curve: Movimiento.principal,
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      padding: const EdgeInsets.all(_marcoFila),
      decoration: BoxDecoration(
        // Cascara exterior: tinte del estado, o bruma lavanda cuando no
        // hay estado. Nunca blanco sobre blanco.
        color: acento?.withValues(alpha: 0.10) ??
            (inerte ? Colores.fondoNeutroClaro : Superficies.brumaLavanda),
        borderRadius: BorderRadius.circular(_radioFila),
        border: Border.all(
          color: (acento ?? Superficies.nieblaAzul)
              .withValues(alpha: marcado ? 0.45 : 0.60),
        ),
        // Solo las filas ya resueltas se elevan; las pendientes quedan
        // planas para que la jerarquia se lea sin leer.
        boxShadow: marcado ? Superficies.sutil : Superficies.ninguna,
      ),
      child: AnimatedContainer(
        duration: Movimiento.corta,
        curve: Movimiento.principal,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: inerte ? Superficies.brumaLavanda : Colors.white,
          borderRadius: BorderRadius.circular(_radioNucleoFila),
        ),
        // La fila cambia de alto cuando aparece el subtitulo: sin esto
        // el salto seria instantaneo.
        child: AnimatedSize(
          duration: Movimiento.corta,
          curve: Movimiento.principal,
          alignment: Alignment.topCenter,
          child: Row(
            children: [
              _Gema(estado: estado, acento: acento, tinta: _tinta),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: Movimiento.corta,
                      curve: Movimiento.principal,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.25,
                        letterSpacing: -0.1,
                        fontWeight:
                            marcado ? FontWeight.w600 : FontWeight.w500,
                        color:
                            inerte ? Colores.textoTenue : Colores.textoOscuro,
                        fontStyle:
                            inerte ? FontStyle.italic : FontStyle.normal,
                      ),
                      child: Text(nombre,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          color: estado == EstadoMateria.homologada
                              ? Colores.acentoMorado
                              : Colores.textoTenue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: Movimiento.corta,
                switchInCurve: Movimiento.entrada,
                switchOutCurve: Movimiento.salida,
                transitionBuilder: _aparecer,
                child: KeyedSubtree(
                  key: ValueKey(
                      '$estado|$bloqueada|${onQuitar != null}|${onAprobada != null}'),
                  child: _accion(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Zona derecha: lo que el usuario puede hacer con la fila.
  Widget _accion() {
    switch (estado) {
      case EstadoMateria.aprobada:
      case EstadoMateria.perdida:
        if (onQuitar == null) return const SizedBox.shrink();
        return _BotonQuitar(onTap: onQuitar);

      case EstadoMateria.aprobadaAntes:
        return const Cejilla('Ya aprobada', color: Colores.textoTenue);

      case EstadoMateria.homologada:
        // El sello ya lo dan la gema y el subtitulo; repetirlo aqui
        // solo agrega ruido.
        return const SizedBox.shrink();

      case EstadoMateria.sinRegistrar:
        if (bloqueada) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BotonMarca(
              texto: 'Aprobé',
              tinte: Colores.exito,
              tinta: Colores.exitoOscuro,
              onTap: onAprobada,
            ),
            const SizedBox(width: 7),
            _BotonMarca(
              texto: 'Perdí',
              tinte: Colores.error,
              tinta: Colores.errorOscuro,
              onTap: onPerdida,
            ),
          ],
        );
    }
  }
}

/// Transicion compartida de los intercambios: entra escalando desde
/// abajo con rebote. El rebote vive en el ScaleTransition — la opacidad
/// usa la curva cruda porque un valor > 1 en Opacity dispara assert.
Widget _aparecer(Widget child, Animation<double> animacion) {
  return FadeTransition(
    opacity: animacion,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.82, end: 1).animate(
        CurvedAnimation(parent: animacion, curve: Movimiento.resorte),
      ),
      child: child,
    ),
  );
}

/// Indicador circular de estado. Es lo que permite barrer la lista con
/// la vista y saber en que va cada materia sin leer una palabra.
class _Gema extends StatelessWidget {
  const _Gema({required this.estado, required this.acento, required this.tinta});

  final EstadoMateria estado;
  final Color? acento;
  final Color tinta;

  @override
  Widget build(BuildContext context) {
    final inerte = estado == EstadoMateria.aprobadaAntes;

    final (IconData?, double) icono = switch (estado) {
      EstadoMateria.aprobada => (Icons.check_rounded, 15),
      EstadoMateria.perdida => (Icons.close_rounded, 15),
      EstadoMateria.homologada => (Icons.verified_rounded, 15),
      EstadoMateria.aprobadaAntes => (Icons.done_all_rounded, 13),
      EstadoMateria.sinRegistrar => (null, 0),
    };

    return AnimatedContainer(
      duration: Movimiento.corta,
      curve: Movimiento.principal,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: acento?.withValues(alpha: 0.16) ??
            (inerte ? Colors.white : Colors.transparent),
        border: Border.all(
          color: (acento ?? Superficies.nieblaAzul)
              .withValues(alpha: acento != null ? 0.40 : 0.95),
        ),
      ),
      child: AnimatedSwitcher(
        duration: Movimiento.corta,
        switchInCurve: Movimiento.entrada,
        switchOutCurve: Movimiento.salida,
        transitionBuilder: _aparecer,
        child: icono.$1 == null
            ? const SizedBox.shrink(key: ValueKey('vacia'))
            : Icon(icono.$1,
                key: ValueKey(estado), size: icono.$2, color: tinta),
      ),
    );
  }
}

/// Pildora "Aprobé" / "Perdí". Hairline tintado en vez de relleno solo,
/// y fisica de presion: el dedo espera que el objeto ceda.
class _BotonMarca extends StatelessWidget {
  const _BotonMarca({
    required this.texto,
    required this.tinte,
    required this.tinta,
    required this.onTap,
  });

  final String texto;
  final Color tinte;
  final Color tinta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Presionable(
      onTap: onTap,
      escala: 0.93,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 6, 11, 6),
        decoration: BoxDecoration(
          color: tinte.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Superficies.radioPildora),
          border: Border.all(color: tinte.withValues(alpha: 0.38)),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: tinta,
          ),
        ),
      ),
    );
  }
}

/// Borra el registro de la fila. Neutro a proposito: no compite con el
/// color del estado que ya esta puesto.
class _BotonQuitar extends StatelessWidget {
  const _BotonQuitar({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Presionable(
      onTap: onTap,
      escala: 0.88,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Superficies.brumaLavanda,
          shape: BoxShape.circle,
          border: Border.all(color: Superficies.nieblaAzul),
        ),
        child: const Icon(Icons.close_rounded,
            size: 14, color: Colores.textoTenue),
      ),
    );
  }
}

// ── Card homologación externa ──────────────────────────────────
class CardHomologacion extends StatefulWidget {
  final Materia materia;
  final bool yaAgregada;
  final void Function(String programa) onAgregar;
  final VoidCallback onQuitar;

  const CardHomologacion({
    super.key,
    required this.materia,
    required this.yaAgregada,
    required this.onAgregar,
    required this.onQuitar,
  });

  @override
  State<CardHomologacion> createState() => _CardHomologacionState();
}

class _CardHomologacionState extends State<CardHomologacion> {
  String _prog = 'Talento Tech';
  static const _opciones = [
    'Talento Tech',
    'Acuerdo con director',
    'Transferencia externa',
    'Otro',
  ];

  @override
  Widget build(BuildContext context) {
    final agregada = widget.yaAgregada;
    final creditos = widget.materia.creditos;

    return AnimatedContainer(
      duration: Movimiento.corta,
      curve: Movimiento.principal,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(_marcoCard),
      decoration: BoxDecoration(
        color: agregada
            ? Colores.acentoMorado.withValues(alpha: 0.12)
            : Superficies.brumaLavanda,
        borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
        border: Border.all(
          color: agregada
              ? Colores.acentoMorado.withValues(alpha: 0.45)
              : Superficies.nieblaAzul.withValues(alpha: 0.60),
        ),
        boxShadow: agregada ? Superficies.sutil : Superficies.ninguna,
      ),
      child: AnimatedContainer(
        duration: Movimiento.corta,
        curve: Movimiento.principal,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radioNucleoCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GemaHomologacion(agregada: agregada),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.materia.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.25,
                          letterSpacing: -0.1,
                          fontWeight: FontWeight.w700,
                          color: Colores.textoTitulo,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.materia.codigo} · $creditos '
                        '${creditos == 1 ? "crédito" : "créditos"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.2,
                          color: Colores.textoTenue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              // El boton se alinea con el borde inferior del selector,
              // no con su centro: el bloque de la izquierda tiene dos
              // lineas y quedaria descuadrado.
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          'MEDIANTE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: Colores.textoTenue,
                          ),
                        ),
                      ),
                      _selector(),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _boton(agregada),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Selector de origen, montado como pildora tintada en vez del
  /// DropdownButton pelado con su subrayado por defecto.
  Widget _selector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 3, 7, 3),
      decoration: BoxDecoration(
        color: Superficies.brumaLavanda,
        borderRadius: BorderRadius.circular(Superficies.radioPildora),
        border: Border.all(color: Superficies.nieblaAzul),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _prog,
          isDense: true,
          isExpanded: true,
          elevation: 2,
          borderRadius: BorderRadius.circular(Superficies.radioInterior),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.expand_more_rounded,
              size: 18, color: Colores.textoTenue),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colores.textoOscuro,
          ),
          items: _opciones
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _prog = v ?? _prog),
        ),
      ),
    );
  }

  /// Homologar / Quitar. Es el mismo boton cambiando de peso: relleno
  /// cuando invita a actuar, hueco cuando solo deshace.
  Widget _boton(bool agregada) {
    return Presionable(
      onTap: agregada ? widget.onQuitar : () => widget.onAgregar(_prog),
      escala: 0.95,
      child: AnimatedContainer(
        duration: Movimiento.corta,
        curve: Movimiento.principal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: agregada
              ? Colores.acentoMorado.withValues(alpha: 0.10)
              : Colores.acentoMorado,
          borderRadius: BorderRadius.circular(Superficies.radioPildora),
          border: Border.all(
            color: Colores.acentoMorado
                .withValues(alpha: agregada ? 0.32 : 1),
          ),
          boxShadow: agregada ? Superficies.ninguna : Superficies.sutil,
        ),
        child: AnimatedDefaultTextStyle(
          duration: Movimiento.corta,
          curve: Movimiento.principal,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: agregada ? Colores.acentoMorado : Colors.white,
          ),
          child: AnimatedSwitcher(
            duration: Movimiento.corta,
            switchInCurve: Movimiento.entrada,
            switchOutCurve: Movimiento.salida,
            transitionBuilder: _aparecer,
            child: Text(agregada ? 'Quitar' : 'Homologar',
                key: ValueKey(agregada)),
          ),
        ),
      ),
    );
  }
}

/// Sello de la card. Cambia de icono y de intensidad segun si la
/// materia ya quedo homologada.
class _GemaHomologacion extends StatelessWidget {
  const _GemaHomologacion({required this.agregada});

  final bool agregada;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Movimiento.corta,
      curve: Movimiento.principal,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colores.acentoMorado.withValues(alpha: agregada ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(_radioGema),
        border: Border.all(
          color: Colores.acentoMorado
              .withValues(alpha: agregada ? 0.40 : 0.18),
        ),
      ),
      child: AnimatedSwitcher(
        duration: Movimiento.corta,
        switchInCurve: Movimiento.entrada,
        switchOutCurve: Movimiento.salida,
        transitionBuilder: _aparecer,
        child: Icon(
          agregada ? Icons.verified_rounded : Icons.swap_horiz_rounded,
          key: ValueKey(agregada),
          size: 18,
          color: Colores.acentoMorado
              .withValues(alpha: agregada ? 1 : 0.60),
        ),
      ),
    );
  }
}
