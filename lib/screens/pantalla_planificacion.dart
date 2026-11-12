// ============================================================
//  pantalla_planificacion.dart
//  Muestra el plan generado con badges por carrera.
//  El plan se guarda al presionar "Ir al inicio" (sin nombre)
//  o "Nombrar plan" (con nombre personalizado ingresado por el usuario).
// ============================================================

import 'package:flutter/material.dart';
import '../models/modelo_plan.dart';
import '../data/datos_programa.dart';
import '../services/servicio_api.dart';
import '../utils/sesion_helper.dart';
import '../widgets/menu_lateral.dart';
import '../theme/colores.dart';
import 'pantalla_seleccion.dart';
import '../theme/transiciones.dart';
import '../widgets/superficie.dart';

class PantallaPlanificacion extends StatefulWidget {
  final RespuestaPlan respuestaPlan;
  final Programa? programaPrincipal;
  final Programa? programaSecundario;
  final String token;
  final Map<String, dynamic> datosUsuario;

  // Datos necesarios para guardar el plan
  final Map<String, dynamic> datosPlan;
  final int semestresCursados;
  final double promedio;
  final List<String> materiasAprobadas;
  final List<Map<String, String>> homologaciones;

  const PantallaPlanificacion({
    super.key,
    required this.respuestaPlan,
    this.programaPrincipal,
    this.programaSecundario,
    required this.token,
    required this.datosUsuario,
    required this.datosPlan,
    required this.semestresCursados,
    required this.promedio,
    required this.materiasAprobadas,
    required this.homologaciones,
  });

  @override
  State<PantallaPlanificacion> createState() => _PantallaPlanificacionState();
}

class _PantallaPlanificacionState extends State<PantallaPlanificacion> {
  final ServicioApi _servicioApi = ServicioApi();
  bool _guardando = false;

  Color _getOrigenColor(String origen) {
    switch (origen) {
      case 'principal':  return Colores.primario;
      case 'secundario': return Colores.exitoOscuro;
      case 'compartida': return Colores.advertenciaFuerte;
      case 'practica':   return Colores.acentoMorado;
      default:           return Colores.textoTenue;
    }
  }

  String _getOrigenTexto(String origen) {
    switch (origen) {
      case 'principal':  return 'Principal';
      case 'secundario': return 'Secundario';
      case 'compartida': return 'Compartida';
      case 'practica':   return 'Practica';
      default:           return origen;
    }
  }

  // Guarda el plan en la BD y navega al inicio.
  // Si [nombre] es null se guarda sin nombre personalizado.
  Future<void> _guardarYSalir({String? nombre}) async {
    if (_guardando) return;
    setState(() => _guardando = true);

    try {
      await _servicioApi.guardarPlan(
        token:              widget.token,
        nombre:             nombre,
        programaPrincipal:  widget.programaPrincipal?.codigo ?? '',
        programaSecundario: widget.programaSecundario?.codigo,
        semestresCursados:  widget.semestresCursados,
        promedio:           widget.promedio,
        materiasAprobadas:  widget.materiasAprobadas,
        homologaciones:     widget.homologaciones,
        planGenerado:       widget.datosPlan,
      );
    } on SesionExpiradaException {
      if (mounted) {
        setState(() => _guardando = false);
        await SesionHelper.manejarSesionExpirada(context);
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el plan: $e'),
            backgroundColor: Colores.acentoNaranja,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        RutaRaiz(
          pagina: PantallaSeleccion(
            token:    widget.token,
            datosUsuario: widget.datosUsuario,
          ),
        ),
        (route) => false,
      );
    }
  }

  // Abre un dialogo para ingresar un nombre y luego guarda.
  Future<void> _mostrarDialogoNombre() async {
    final ctrl = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Superficies.radioTarjeta)),
        title: const Text(
          'Nombrar plan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ponle un nombre para identificarlo despues.',
              style: TextStyle(fontSize: 13, color: Colores.textoSecundario),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: 'Ej. Plan 2026-2',
                filled: true,
                fillColor: Colores.fondoNeutroClaro,
                counterText: '',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colores.bordeSuave),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Colores.primario, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Colores.textoSecundario)),
          ),
          ElevatedButton(
            onPressed: () {
              final texto = ctrl.text.trim();
              Navigator.pop(ctx, texto.isEmpty ? null : texto);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colores.primario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    // Si el usuario canceló el dialogo, no hacemos nada.
    if (nombre == null && ctrl.text.trim().isEmpty) return;

    // Si presionó "Guardar" (con o sin nombre escrito), guardamos y salimos.
    await _guardarYSalir(nombre: nombre);
  }

  /// Semestres cuya animacion de entrada ya se ejecuto.
  ///
  /// ListView.builder destruye los items que salen de pantalla y los
  /// reconstruye al volver, asi que sin esto la animacion se repetia cada
  /// vez que el usuario subia. Este Set vive en el State de la pantalla,
  /// que no se destruye con el scroll.
  final Set<int> _semestresRevelados = {};

  @override
  Widget build(BuildContext context) {
    // PopScope con canPop: false impide volver atras con gesto o boton del sistema.
    // Desde esta pantalla solo se puede salir por los botones de la barra inferior,
    // de esta manera evitamos que se pueda modificar el plan final.
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: Colores.fondoApp,
      drawer: MenuLateral(token: widget.token, datosUsuario: widget.datosUsuario),
      appBar: AppBar(
        title: const Text('Plan de Estudios',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: -0.3)),
        // flexibleSpace y no backgroundColor: la cabecera lleva degradado y
        // esquinas inferiores redondeadas como en el resto de la app, para
        // que se lea como panel apoyado y no como franja pegada al borde.
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          // Container y no DecoratedBox: en flexibleSpace el hijo recibe
          // restricciones sueltas y un DecoratedBox sin hijo mide cero,
          // asi que el degradado no llegaba a pintarse.
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colores.primario, Superficies.tintaProfunda],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Semestres restantes:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colores.exito,
                    borderRadius:
                        BorderRadius.circular(Superficies.radioPildora),
                  ),
                  child: Text(
                    '${widget.respuestaPlan.totalSemestresFuturos}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // ── Barra inferior con dos botones ──────────────────────
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Row(
          children: [
            // Boton izquierdo: Nombrar plan (abre dialogo)
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _guardando ? null : _mostrarDialogoNombre,
                  icon: const Icon(Icons.bookmark_outline_rounded,
                      color: Colores.primario),
                  label: const Text(
                    'Nombrar plan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colores.primario,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Colores.primario, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Superficies.radioPildora)),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Boton derecho: Ir al inicio (guarda sin nombre)
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed:
                      _guardando ? null : () => _guardarYSalir(nombre: null),
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.home_rounded, color: Colors.black),
                  label: Text(
                    _guardando ? 'Guardando...' : 'Ir al inicio',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colores.exito,
                    disabledBackgroundColor:
                        Colores.exito.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Superficies.radioPildora)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.respuestaPlan.semestres.length,
        itemBuilder: (context, index) {
          final semestre = widget.respuestaPlan.semestres[index];
          // ListView.builder construye cada tarjeta al entrar en pantalla,
          // asi que este revelado coincide solo con el scroll: no hace
          // falta detectar visibilidad.
          final yaRevelado = _semestresRevelados.contains(index);
          return RevelarProfundidad(
            indice: index,
            // Ya visto: se pinta en su estado final, sin repetir la entrada.
            animar: !yaRevelado,
            alTerminar: () => _semestresRevelados.add(index),
            builder: (context, progreso) => Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Superficies.radioTarjeta)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del semestre
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: semestre.esPrimero
                        ? Colores.acentoMorado.withValues(alpha: 0.16)
                        : semestre.esUltimo
                            ? Colores.acentoNaranja.withValues(alpha: 0.14)
                            : Superficies.brumaLavanda,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Superficies.radioTarjeta),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: semestre.esUltimo
                                  ? Colores.acentoNaranja
                                  : Colores.primario,
                              borderRadius: BorderRadius.circular(Superficies.radioPildora),
                            ),
                            child: Center(
                              child: Text(
                                '${semestre.numero}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Semestre ${semestre.numero}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colores.textoTitulo,
                                ),
                              ),
                              if (semestre.esUltimo)
                                const Text(
                                  'Practica Profesional',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colores.acentoNaranja,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colores.primario,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${semestre.totalCreditos} creditos',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista de materias
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children:
                        semestre.materias.asMap().entries.map((entrada) {
                      final posicion = entrada.key;
                      final materia = entrada.value;
                      return RevelarApilado(
                        indice: posicion,
                        // Mismo reloj que la tarjeta: la materia no guarda
                        // tiempo propio, solo lee su tramo.
                        progreso: progreso,
                        child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getOrigenColor(materia.origen),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    materia.nombre,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colores.textoTitulo,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        materia.codigo,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colores.textoSecundario,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4, height: 4,
                                        decoration: BoxDecoration(
                                          color: Colores.textoTenue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${materia.creditos} creditos',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colores.textoSecundario,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4, height: 4,
                                        decoration: BoxDecoration(
                                          color: Colores.textoTenue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getOrigenColor(
                                                  materia.origen)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _getOrigenTexto(materia.origen),
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: _getOrigenColor(
                                                materia.origen),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (materia.sirveParaAmbas)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colores.advertencia.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(Superficies.radioPildora),
                                  border: Border.all(
                                      color: Colores.advertencia,
                                      width: 0.5),
                                ),
                                child: const Text(
                                  'Doble',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colores.advertenciaFuerte,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      );
                    }).toList(),
                  ),
                ),
                // Footer semestre de practica
                if (semestre.esUltimo)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colores.acentoNaranja.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(Superficies.radioTarjeta),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.work_outline,
                            size: 16, color: Colores.acentoNaranja),
                        const SizedBox(width: 8),
                        const Text(
                          'Semestre de practica profesional',
                          style: TextStyle(
                              fontSize: 12, color: Colores.acentoNaranja),
                        ),
                        const Spacer(),
                        Text(
                        '${semestre.totalCreditos} creditos',
                        style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colores.acentoNaranja,
                        ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          );
        },
      ),
    ),  // Scaffold
    );  // PopScope
  }
}
