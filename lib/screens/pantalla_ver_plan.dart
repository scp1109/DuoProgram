// ============================================================
//  pantalla_ver_plan.dart
//  Muestra un plan guardado en detalle
// ============================================================

import 'package:flutter/material.dart';
import '../services/servicio_api.dart';
import '../utils/sesion_helper.dart';
import '../models/modelo_plan.dart';
import '../theme/colores.dart';
import '../widgets/superficie.dart';

class PantallaVerPlan extends StatefulWidget {
  final String token;
  final int planId;

  const PantallaVerPlan({
    super.key,
    required this.token,
    required this.planId,
  });

  @override
  State<PantallaVerPlan> createState() => _PantallaVerPlanState();
}

class _PantallaVerPlanState extends State<PantallaVerPlan> {
  final ServicioApi _servicioApi = ServicioApi();
  RespuestaPlan? _plan;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPlan();
  }

  Future<void> _cargarPlan() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final datosPlan = await _servicioApi.obtenerPlan(widget.token, widget.planId);
      
      // Convertir el mapa a RespuestaPlan
      final respuestaPlan = RespuestaPlan.fromJson(datosPlan['plan_generado']);

      // El usuario pudo navegar hacia atras mientras la peticion estaba en
      // vuelo; sin esta guarda setState revienta con "called after dispose".
      if (!mounted) return;
      setState(() {
        _plan = respuestaPlan;
        _cargando = false;
      });
    } on SesionExpiradaException {
      if (mounted) await SesionHelper.manejarSesionExpirada(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Color _getOrigenColor(String origen) {
    switch (origen) {
      case 'principal':
        return Colores.primario;
      case 'secundario':
        return Colores.exitoOscuro;
      case 'compartida':
        return Colores.advertenciaFuerte;
      case 'practica':
        return Colores.acentoMorado;
      default:
        return Colores.textoTenue;
    }
  }

  String _getOrigenTexto(String origen) {
    switch (origen) {
      case 'principal':
        return 'Principal';
      case 'secundario':
        return 'Secundario';
      case 'compartida':
        return 'Compartida';
      case 'practica':
        return 'Práctica';
      default:
        return origen;
    }
  }

  /// Semestres cuya animacion de entrada ya se ejecuto.
  ///
  /// ListView.builder destruye los items que salen de pantalla y los
  /// reconstruye al volver; sin esto la animacion se repetiria cada vez
  /// que el usuario sube. Este Set vive en el State, que no se destruye.
  final Set<int> _semestresRevelados = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colores.fondoApp,
      appBar: AppBar(
        // flexibleSpace y no backgroundColor: asi la barra lleva el mismo
        // degradado y las esquinas inferiores redondeadas del resto de la
        // app, en vez de quedar como una franja plana pegada al borde.
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          // Container y no DecoratedBox: en flexibleSpace el hijo recibe
          // restricciones sueltas y un DecoratedBox sin hijo mide cero,
          // asi que el degradado no llegaba a pintarse.
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colores.primario, Superficies.tintaMedia],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ),
        title: const Text(
          'Plan Guardado',
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarPlan,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colores.primario,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando plan...',
                    style: TextStyle(color: Colores.textoSecundario),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colores.error.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            size: 40,
                            color: Colores.error,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Error cargando el plan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colores.textoTitulo,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colores.textoSecundario,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colores.primario,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Volver',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _plan == null
                  ? const Center(
                      child: Text('No se pudo cargar el plan'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _plan!.semestres.length,
                      itemBuilder: (context, index) {
                        final semestre = _plan!.semestres[index];
                        final yaRevelado =
                            _semestresRevelados.contains(index);
                        return RevelarProfundidad(
                          indice: index,
                          animar: !yaRevelado,
                          alTerminar: () => _semestresRevelados.add(index),
                          builder: (context, progreso) => Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
                          ),
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
                                    top: Radius.circular(
                                        Superficies.radioTarjeta),
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
                                            borderRadius: BorderRadius.circular(12),
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
                                                'Práctica Profesional',
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
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colores.primario,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${semestre.totalCreditos} créditos',
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
                                  children: semestre.materias
                                      .asMap()
                                      .entries
                                      .map((entrada) {
                                    final materia = entrada.value;
                                    return RevelarApilado(
                                      indice: entrada.key,
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
                                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                                      width: 4,
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                        color: Colores.textoTenue,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${materia.creditos} créditos',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colores.textoSecundario,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      width: 4,
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                        color: Colores.textoTenue,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _getOrigenColor(materia.origen)
                                                            .withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Text(
                                                        _getOrigenTexto(materia.origen),
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: _getOrigenColor(materia.origen),
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
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colores.advertencia.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colores.advertencia,
                                                  width: 0.5,
                                                ),
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
                              // Footer con resumen
                              if (semestre.esUltimo)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colores.acentoNaranja.withValues(alpha: 0.08),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.work_outline,
                                        size: 16,
                                        color: Colores.acentoNaranja,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Semestre de práctica profesional',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colores.acentoNaranja,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '9 créditos',
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
    );
  }
}