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
import 'pantalla_seleccion.dart';

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
      case 'principal':  return Colors.blue;
      case 'secundario': return Colors.green;
      case 'compartida': return Colors.amber;
      case 'practica':   return Colors.purple.shade900;
      default:           return Colors.grey;
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
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaSeleccion(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: 'Ej. Plan 2026-2',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                counterText: '',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF1A1FC8), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              final texto = ctrl.text.trim();
              Navigator.pop(ctx, texto.isEmpty ? null : texto);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1FC8),
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

  @override
  Widget build(BuildContext context) {
    // PopScope con canPop: false impide volver atras con gesto o boton del sistema.
    // Desde esta pantalla solo se puede salir por los botones de la barra inferior,
    // de esta manera evitamos que se pueda modificar el plan final.
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      drawer: MenuLateral(token: widget.token, datosUsuario: widget.datosUsuario),
      appBar: AppBar(
        title: const Text('Plan de Estudios'),
        backgroundColor: const Color(0xFF1A1FC8),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
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
                    color: const Color(0xFF4ADE00),
                    borderRadius: BorderRadius.circular(20),
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
                      color: Color(0xFF1A1FC8)),
                  label: const Text(
                    'Nombrar plan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1FC8),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFF1A1FC8), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                    backgroundColor: const Color(0xFF4ADE00),
                    disabledBackgroundColor:
                        const Color(0xFF4ADE00).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del semestre
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: semestre.esPrimero
                        ? Colors.deepPurple.shade100
                        : semestre.esUltimo
                            ? Colors.orange.shade100
                            : Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
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
                                  ? Colors.orange
                                  : const Color(0xFF1A1FC8),
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
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              if (semestre.esUltimo)
                                const Text(
                                  'Practica Profesional',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
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
                          color: const Color(0xFF1A1FC8),
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
                    children: semestre.materias.map((materia) {
                      return Padding(
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
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        materia.codigo,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4, height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade400,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${materia.creditos} creditos',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4, height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade400,
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
                                              .withOpacity(0.1),
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
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.amber.shade300,
                                      width: 0.5),
                                ),
                                child: const Text(
                                  'Doble',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                          ],
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
                      color: Colors.orange.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.work_outline,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text(
                          'Semestre de practica profesional',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange),
                        ),
                        const Spacer(),
                        Text(
                        '${semestre.totalCreditos} creditos',
                        style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                        ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),  // Scaffold
    );  // PopScope
  }
}
