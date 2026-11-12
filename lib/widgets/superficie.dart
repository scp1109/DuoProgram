// ============================================================
//  superficie.dart
//  Componentes base del lenguaje visual.
//
//  La idea de fondo es que nada se apoya plano sobre el fondo: cada
//  superficie importante va montada dentro de otra, como una placa de
//  vidrio en una bandeja de aluminio. Eso es lo que hace que una tarjeta
//  se lea como objeto fisico y no como un div con borde gris.
// ============================================================

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../theme/colores.dart';
import '../theme/movimiento.dart';

/// Tarjeta de bisel doble.
///
/// Dos contenedores anidados: un marco exterior tenue y el nucleo real
/// adentro. El radio del nucleo se calcula restando el grosor del marco,
/// asi las dos curvas quedan concentricas. Si se usa el mismo radio en
/// ambos, la curva interior se ve apretada y delata el truco.
class TarjetaBisel extends StatelessWidget {
  const TarjetaBisel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.marco = 6,
    this.radio = Superficies.radioTarjeta,
    this.colorNucleo = Colors.white,
    this.colorMarco,
    this.sombra,
    this.acento,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Grosor del marco exterior. Es lo que separa las dos curvas.
  final double marco;
  final double radio;
  final Color colorNucleo;
  final Color? colorMarco;
  final List<BoxShadow>? sombra;

  /// Tinte opcional del marco, para tarjetas que deben destacar
  /// (semestre excedido, plan seleccionado).
  final Color? acento;

  @override
  Widget build(BuildContext context) {
    final tinteMarco = acento ?? colorMarco ?? Superficies.nieblaAzul;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: acento != null
            ? acento!.withValues(alpha: 0.10)
            : Superficies.brumaLavanda,
        borderRadius: BorderRadius.circular(radio),
        // Hairline en vez de borde gris solido de 1px: casi no se ve,
        // pero define el canto de la superficie.
        border: Border.all(color: tinteMarco.withValues(alpha: 0.55)),
        boxShadow: sombra ?? Superficies.ambiente,
      ),
      child: Padding(
        padding: EdgeInsets.all(marco),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorNucleo,
            borderRadius:
                BorderRadius.circular(Superficies.radioInterno(radio, marco)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Envoltura que aplica fisica de presion a cualquier hijo tocable.
///
/// Al presionar, el elemento se hunde levemente con una curva de resorte.
/// Es la diferencia entre un boton que responde y uno que solo cambia de
/// color: el dedo espera sentir que el objeto cede.
class Presionable extends StatefulWidget {
  const Presionable({
    super.key,
    required this.child,
    this.onTap,
    this.escala = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double escala;

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> {
  bool _presionado = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (_presionado != v) setState(() => _presionado = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _presionado ? widget.escala : 1,
        duration: Movimiento.instante,
        curve: Movimiento.resorte,
        child: widget.child,
      ),
    );
  }
}

/// CTA principal con icono anidado, el patron de boton dentro del boton.
///
/// El icono nunca va suelto al lado del texto: vive en su propio circulo
/// pegado al borde interno derecho. Al presionar, ese circulo se desplaza
/// en diagonal, creando tension interna en vez de mover el boton entero.
class BotonIsla extends StatefulWidget {
  const BotonIsla({
    super.key,
    required this.texto,
    required this.onTap,
    this.icono = Icons.arrow_forward_rounded,
    this.color = Colores.primario,
    this.colorTexto = Colors.white,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? onTap;
  final IconData icono;
  final Color color;
  final Color colorTexto;
  final bool cargando;

  @override
  State<BotonIsla> createState() => _BotonIslaState();
}

class _BotonIslaState extends State<BotonIsla> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.onTap != null && !widget.cargando;
    return GestureDetector(
      onTapDown: activo ? (_) => setState(() => _presionado = true) : null,
      onTapUp: activo ? (_) => setState(() => _presionado = false) : null,
      onTapCancel: activo ? () => setState(() => _presionado = false) : null,
      onTap: activo ? widget.onTap : null,
      child: AnimatedScale(
        scale: _presionado ? 0.98 : 1,
        duration: Movimiento.instante,
        curve: Movimiento.resorte,
        child: AnimatedContainer(
          duration: Movimiento.corta,
          curve: Movimiento.principal,
          height: 56,
          padding: const EdgeInsets.fromLTRB(24, 0, 8, 0),
          decoration: BoxDecoration(
            color: activo ? widget.color : widget.color.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(Superficies.radioPildora),
            // Misma razon que en la tarjeta: nunca interpolar una
            // sombra contra null.
            boxShadow: activo ? Superficies.sutil : Superficies.ninguna,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.texto,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.colorTexto,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // El circulo anidado, pegado al padding interno derecho.
              AnimatedContainer(
                duration: Movimiento.corta,
                curve: Movimiento.principal,
                width: 40,
                height: 40,
                transform: Matrix4.translationValues(
                    _presionado ? 3 : 0, _presionado ? -1 : 0, 0),
                decoration: BoxDecoration(
                  color: widget.colorTexto.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: widget.cargando
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(widget.colorTexto),
                        ),
                      )
                    : Icon(widget.icono, size: 18, color: widget.colorTexto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta microscopica que antecede a un titulo grande.
///
/// Texto diminuto, mayusculas y tracking muy abierto. Es un recurso
/// barato de implementar que sube mucho la percepcion de cuidado.
class Cejilla extends StatelessWidget {
  const Cejilla(this.texto, {super.key, this.color = Colores.primario});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(Superficies.radioPildora),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: color,
        ),
      ),
    );
  }
}

/// Revelado de entrada: el hijo nunca aparece estatico.
///
/// Sube desde abajo mientras se desvanece hacia adentro. Solo anima
/// transform y opacity; el skill pide ademas desenfoque, pero animar blur
/// en Flutter obliga a repintar la capa en cada frame y tumba los fps en
/// movil, asi que se respeta la regla de rendimiento por encima del efecto.
///
/// [indice] escalona el arranque para que una lista caiga en cascada.
class Revelar extends StatefulWidget {
  const Revelar({
    super.key,
    required this.child,
    this.indice = 0,
    this.desplazamiento = 24,
  });

  final Widget child;
  final int indice;
  final double desplazamiento;

  @override
  State<Revelar> createState() => _RevelarState();
}

class _RevelarState extends State<Revelar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Movimiento.larga,
  );

  @override
  void initState() {
    super.initState();
    final retraso = Movimiento.escalonar(widget.indice);
    if (retraso == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(retraso, () {
        // El widget puede haberse desmontado durante el retraso.
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(parent: _ctrl, curve: Movimiento.entrada);
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.desplazamiento / 100),
          end: Offset.zero,
        ).animate(curva),
        child: widget.child,
      ),
    );
  }
}


/// Revelado en profundidad: la tarjeta llega desenfocada desde el fondo y
/// se resuelve nitida en su sitio.
///
/// El desenfoque es lo que vende la distancia: sin el, una escala mas
/// opacidad se lee como "algo crecio", no como "algo se acerco".
///
/// Es dueno del UNICO reloj de la tarjeta. Sus hijos no guardan tiempo:
/// reciben esta animacion por [builder] y leen su tramo con Interval. Eso
/// es deliberado — si cada hijo tuviera su propio controlador, recrearlo a
/// mitad de vuelo reiniciaria su animacion, y aqui se recrean: al cruzar el
/// umbral del desenfoque se quita el ImageFiltered, cambia la forma del
/// arbol y Flutter rehace el subarbol entero.
///
/// Sobre el coste del blur: animarlo obliga a repintar el subarbol en cada
/// frame, por eso el sistema lo prohibe en contenido que scrollea. Aqui se
/// permite porque es una entrada corta, de una sola vez, y porque el
/// ImageFiltered se retira del arbol al terminar: en reposo no cuesta nada.
class RevelarProfundidad extends StatefulWidget {
  const RevelarProfundidad({
    super.key,
    required this.builder,
    this.indice = 0,
    this.desenfoque = 14,
    this.animar = true,
    this.alTerminar,
  });

  /// Construye el contenido recibiendo el progreso de la tarjeta, para que
  /// los hijos escalonen contra el mismo reloj.
  final Widget Function(BuildContext context, Animation<double> progreso)
      builder;

  /// Escalona el arranque cuando varias tarjetas entran juntas.
  final int indice;

  /// Sigma inicial. Por encima de ~18 el texto se vuelve mancha y el efecto
  /// se siente sucio en vez de profundo.
  final double desenfoque;

  /// En false pinta el estado final de una vez, sin animar. Lo usa la
  /// pantalla para las tarjetas que el usuario ya vio: sin esto, volver a
  /// subir en un ListView.builder repite toda la animacion.
  final bool animar;

  /// Se llama una vez al terminar, para que la pantalla marque esta tarjeta
  /// como ya revelada.
  final VoidCallback? alTerminar;

  @override
  State<RevelarProfundidad> createState() => _RevelarProfundidadState();
}

class _RevelarProfundidadState extends State<RevelarProfundidad>
    with SingleTickerProviderStateMixin {
  // Un poco mas largo que Movimiento.larga: aqui caben los dos tiempos,
  // el de la tarjeta y el de la cascada de materias.
  static const Duration _duracion = Duration(milliseconds: 1150);

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _duracion,
  );
  late final Animation<double> _curva = CurvedAnimation(
    parent: _ctrl,
    // La tarjeta ocupa la primera mitad del reloj; el resto es para que
    // las materias terminen de subir.
    curve: const Interval(0, 0.55, curve: Movimiento.entrada),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.animar) {
      _ctrl.value = 1;
      return;
    }
    _ctrl.addStatusListener(_alCambiarEstado);
    final retraso = Movimiento.escalonar(widget.indice, maximo: 4);
    if (retraso == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(retraso, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  void _alCambiarEstado(AnimationStatus estado) {
    if (estado == AnimationStatus.completed) {
      widget.alTerminar?.call();
    }
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_alCambiarEstado);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // El hijo se construye UNA vez y se pasa por `child`, no dentro del
    // builder: asi no se rehace en cada frame. Los descendientes que deban
    // moverse escuchan _ctrl por su cuenta.
    final hijo = widget.builder(context, _ctrl);

    if (!widget.animar) return hijo;

    return AnimatedBuilder(
      animation: _curva,
      child: hijo,
      builder: (context, contenido) {
        final t = _curva.value;
        final sigma = widget.desenfoque * (1 - t);

        Widget resultado = Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            // Rango corto a proposito: un salto grande de escala se lee
            // como zoom, no como profundidad.
            scale: 0.94 + (0.06 * t),
            child: contenido,
          ),
        );

        // Por debajo de 0.05 el desenfoque ya no se percibe: se desmonta el
        // filtro y la tarjeta deja de costar.
        if (sigma > 0.05) {
          resultado = ImageFiltered(
            // decal evita que el desenfoque arrastre los bordes hacia
            // afuera y ensucie las tarjetas vecinas.
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: resultado,
          );
        }
        return resultado;
      },
    );
  }
}

/// Revelado apilado: el hijo sube desde abajo y se asienta.
///
/// NO guarda tiempo propio: lee su tramo del reloj de la tarjeta que lo
/// contiene. Por eso es StatelessWidget y por eso recrearlo a mitad de la
/// animacion es inofensivo — vuelve a pintarse en el valor que toca en vez
/// de empezar de cero.
class RevelarApilado extends StatelessWidget {
  const RevelarApilado({
    super.key,
    required this.child,
    required this.progreso,
    this.indice = 0,
    this.desplazamiento = 26,
  });

  final Widget child;

  /// Reloj de la tarjeta, provisto por RevelarProfundidad.
  final Animation<double> progreso;

  final int indice;

  /// Cuanto sube, en pixeles logicos.
  final double desplazamiento;

  /// Fraccion del reloj en la que arranca la primera materia. Solapa con el
  /// revelado de la tarjeta a proposito: esperar a que termine deja un hueco
  /// muerto entre los dos movimientos.
  static const double _arranque = 0.24;

  /// Separacion entre materias consecutivas, como fraccion del reloj.
  static const double _escalon = 0.05;

  /// Cuanto dura la subida de una materia.
  static const double _tramo = 0.34;

  @override
  Widget build(BuildContext context) {
    // Se topa el indice para que la ultima materia de un semestre cargado
    // no arranque tan tarde que se salga del reloj.
    final n = indice > 9 ? 9 : indice;
    final inicio = (_arranque + n * _escalon).clamp(0.0, 1.0 - _tramo);
    final propia = CurvedAnimation(
      parent: progreso,
      curve: Interval(inicio, inicio + _tramo, curve: Movimiento.entrada),
    );

    return AnimatedBuilder(
      animation: propia,
      child: child,
      builder: (context, contenido) {
        final t = propia.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          // Translate y no Padding: mover con transform no dispara layout.
          child: Transform.translate(
            offset: Offset(0, desplazamiento * (1 - t)),
            child: contenido,
          ),
        );
      },
    );
  }
}
