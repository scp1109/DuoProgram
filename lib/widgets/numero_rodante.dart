// ============================================================
//  numero_rodante.dart
//  Contador tipo odometro con desenfoque de movimiento.
// ============================================================

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../theme/movimiento.dart';

/// Numero que cuenta hasta su valor rodando como un odometro mecanico.
///
/// Cada posicion decimal es una cinta con los digitos 0-9 que se desplaza
/// hacia arriba. No hay "cambio" de digito: el desplazamiento es continuo,
/// asi que a cualquier velocidad se ve la cinta rodar en vez de parpadear
/// entre valores, que es lo que pasa si se hace con un AnimatedSwitcher.
///
/// El desenfoque NO es decorativo ni va por tiempo: se calcula a partir de
/// la velocidad real de cada cinta. Como la cinta de las unidades rueda
/// diez veces mas rapido que la de las decenas, sale mas borrosa sola. Eso
/// produce justo lo que se busca: el digito entra desde abajo difuminado y
/// se resuelve nitido al frenar, y el que sale se difumina hacia arriba.
///
/// La curva es [Movimiento.principal]: arranca rapido y frena largo,
/// aterrizando exacto en el valor final.
class NumeroRodante extends StatefulWidget {
  const NumeroRodante({
    super.key,
    required this.valor,
    required this.estilo,
    this.sufijo = '',
    this.duracion = const Duration(milliseconds: 1900),
    this.desenfoqueMaximo = 7,
  });

  final int valor;
  final TextStyle estilo;

  /// Texto fijo pegado al numero, por ejemplo '%'. No rueda.
  final String sufijo;

  final Duration duracion;

  /// Tope del sigma. Sin tope, un salto grande deja la cinta ilegible.
  final double desenfoqueMaximo;

  @override
  State<NumeroRodante> createState() => _NumeroRodanteState();
}

class _NumeroRodanteState extends State<NumeroRodante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duracion);

  // Curva expuesta como objeto para poder muestrearla y derivarla: la
  // velocidad instantanea es lo que alimenta el desenfoque.
  static const Curve _curva = Movimiento.principal;

  double _desde = 0;
  late double _hasta = widget.valor.toDouble();

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(NumeroRodante anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.valor == widget.valor) return;
    // Arranca desde donde va la animacion, no desde el valor viejo: si el
    // usuario marca varias materias seguidas, el contador encadena en vez
    // de saltar hacia atras.
    _desde = _valorEn(_ctrl.value);
    _hasta = widget.valor.toDouble();
    _ctrl
      ..value = 0
      ..forward();
  }

  double _valorEn(double t) =>
      _desde + (_hasta - _desde) * _curva.transform(t.clamp(0.0, 1.0));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Unidades por segundo en el instante t, por diferencias finitas.
  /// La curva no tiene derivada analitica a mano, y muestrearla es exacto
  /// de sobra para decidir cuanto desenfoque aplicar.
  double _velocidad(double t) {
    const paso = 0.004;
    final a = _curva.transform(t.clamp(0.0, 1.0));
    final b = _curva.transform((t + paso).clamp(0.0, 1.0));
    final porUnidadDeT = ((b - a) / paso) * (_hasta - _desde).abs();
    final segundos = widget.duracion.inMilliseconds / 1000;
    return segundos == 0 ? 0 : porUnidadDeT / segundos;
  }

  /// Pasos ENTEROS que recorre la rueda de la posicion decimal [p].
  ///
  /// Es la clave de que el contador aterrice bien. Derivar la posicion del
  /// valor continuo (valor / 10^p) deja la rueda a medio giro en reposo:
  /// para 26 las decenas se quedaban en 2.6, y para 191 las centenas en
  /// 1.1. Contando pasos enteros la rueda cae siempre en un digito, y en
  /// el que toca.
  ///
  /// De paso conserva el efecto de odometro sin trucos: las unidades dan
  /// diez veces mas pasos que las decenas, asi que ruedan diez veces mas
  /// rapido y salen mas desenfocadas solas.
  double _pasos(int p) {
    final escala = math.pow(10, p).toDouble();
    return (_hasta / escala).floorToDouble() -
        (_desde / escala).floorToDouble();
  }

  /// Digito de partida de la rueda [p].
  double _inicio(int p) =>
      (_desde / math.pow(10, p).toDouble()).floorToDouble();

  @override
  Widget build(BuildContext context) {
    final altura = (widget.estilo.fontSize ?? 19) * 1.16;
    // Las ranuras se fijan por el valor objetivo para que el ancho no
    // salte a mitad de la animacion.
    final ranuras = math.max(1, widget.valor.abs().toString().length);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final avance = _curva.transform(_ctrl.value.clamp(0.0, 1.0));
        final valor = _valorEn(_ctrl.value);
        final velocidad = _velocidad(_ctrl.value);

        // center y no baseline: las cintas son cajas sin linea base y el
        // sufijo si la tiene, asi que mezclarlos daba cifras a alturas
        // distintas entre una columna y otra.
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int p = ranuras - 1; p >= 0; p--)
              _Cinta(
                posicion: _inicio(p) + _pasos(p) * avance,
                // Cada posicion rueda 10 veces mas lento que la anterior.
                velocidad: velocidad / math.pow(10, p),
                altura: altura,
                estilo: widget.estilo,
                desenfoqueMaximo: widget.desenfoqueMaximo,
                // La ranura de mas peso aparece solo cuando el numero la
                // necesita, para no mostrar ceros a la izquierda.
                opacidad: p == 0
                    ? 1
                    : (valor / math.pow(10, p)).clamp(0.0, 1.0).toDouble(),
              ),
            if (widget.sufijo.isNotEmpty)
              // Misma altura que las cintas para que no desplace la fila.
              SizedBox(
                height: altura,
                child: Center(child: Text(widget.sufijo, style: widget.estilo)),
              ),
          ],
        );
      },
    );
  }
}

/// Una cinta vertical de digitos 0-9 desplazada de forma continua.
class _Cinta extends StatelessWidget {
  const _Cinta({
    required this.posicion,
    required this.velocidad,
    required this.altura,
    required this.estilo,
    required this.desenfoqueMaximo,
    required this.opacidad,
  });

  /// Valor continuo de esta posicion decimal. Su parte entera dice que
  /// digito se ve y la fraccionaria cuanto lleva rodado hacia el siguiente.
  final double posicion;

  /// Digitos por segundo que recorre esta cinta.
  final double velocidad;

  final double altura;
  final TextStyle estilo;
  final double desenfoqueMaximo;
  final double opacidad;

  @override
  Widget build(BuildContext context) {
    final enCinta = posicion % 10;
    final digito = enCinta.floor();
    final avance = enCinta - digito;

    // Pixeles que recorre la cinta en un frame a 60fps. Desenfocar por esa
    // distancia es lo que hace una camara real, y por eso se lee natural.
    final sigma =
        (velocidad * altura / 60).clamp(0.0, desenfoqueMaximo).toDouble();

    final ancho = (estilo.fontSize ?? 19) * 0.62;

    Widget cinta = SizedBox(
      width: ancho,
      height: altura,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Solo se montan los dos digitos visibles, no los diez: montar
            // la cinta completa multiplica por cinco el trabajo de texto
            // por cada posicion y por frame.
            _digito(digito, -avance * altura),
            _digito(digito + 1, (1 - avance) * altura),
          ],
        ),
      ),
    );

    // Por debajo de 0.05 el desenfoque no se percibe: se desmonta el filtro
    // y la cinta deja de costar cuando esta quieta.
    if (sigma > 0.05) {
      cinta = ImageFiltered(
        // Solo en Y: el movimiento es vertical, desenfocar en X solo
        // emborrona el digito sin aportar sensacion de velocidad.
        imageFilter: ImageFilter.blur(
          sigmaX: 0,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: cinta,
      );
    }

    return Opacity(opacity: opacidad.clamp(0.0, 1.0), child: cinta);
  }

  Widget _digito(int valor, double desplazamiento) => Positioned(
        left: 0,
        right: 0,
        top: desplazamiento,
        height: altura,
        child: Center(
          child: Text(
            '${valor % 10}',
            style: estilo,
            textAlign: TextAlign.center,
          ),
        ),
      );
}
