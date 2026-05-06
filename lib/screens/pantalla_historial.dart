// ============================================================
//  pantalla_historial.dart
//  Wizard de 4 pasos: Promedio → Inglés → Homologaciones → Historial
//  Conectado al backend FastAPI
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/datos_programa.dart';
import '../services/api_service.dart';
import '../models/plan_model.dart';
import 'pantalla_planificacion.dart';
import '../widgets/drawer_menu.dart'; 

String _norm(String s) {
  const a = 'áéíóúàèìòùäëïöüâêîôûãõñÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÃÕÑ';
  const b = 'aeiouaeiouaeiouaeiouaonAEIOUAEIOUAEIOUAEIOUAON';
  var r = s.toLowerCase();
  for (var i = 0; i < a.length; i++) r = r.replaceAll(a[i], b[i]);
  return r;
}

class RegistroMateria {
  final String codigo;
  final int semestre;
  final bool aprobada;
  const RegistroMateria({
    required this.codigo,
    required this.semestre,
    required this.aprobada,
  });
}

class PantallaHistorial extends StatefulWidget {
  final Programa programa;
  final Programa? programaSecundario;
  final List<Map<String, dynamic>>? programas;
  final String token; 
  final Map<String, dynamic> userData;
  
  const PantallaHistorial({
    super.key,
    required this.programa,
    this.programaSecundario,
    this.programas,
    required this.token,
    required this.userData,
  });

  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class FormatoDecimal extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue valorAnterior,
    TextEditingValue valorNuevo,
  ) {
    // Detectar si el usuario está borrando
    final estaBorrando =
        valorNuevo.text.length < valorAnterior.text.length;

    String texto = valorNuevo.text;

    // Si está borrando, no intervenir
    if (estaBorrando) {
      return valorNuevo;
    }

    // Solo números
    texto = texto.replaceAll(RegExp(r'[^0-9]'), '');

    if (texto.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Máximo 3 dígitos → x.xx
    if (texto.length > 3) {
      texto = texto.substring(0, 3);
    }

    String formateado;

    if (texto.length == 1) {
      formateado = '$texto.';
    } else if (texto.length == 2) {
      formateado = '${texto[0]}.${texto[1]}';
    } else {
      formateado = '${texto[0]}.${texto.substring(1)}';
    }

    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  final ApiService _apiService = ApiService();
  bool _isGeneratingPlan = false;
  int _paso = 0;
  bool _practicaUnica = true;   // true = una práctica para ambos, false = dos separadas
  double _promedio = 0.0;
  // Controla si el usuario ya escribio algo en el campo de promedio.
  // El mensaje de feedback solo se muestra cuando es true.
  bool _promedioIngresado = false;
  final _ctrlPromedio = TextEditingController();

  final Set<int> _inglesHomologados = {};

  final List<HomologacionExterna> _homologacionesExternas = [];
  String _busqHomolog = '';
  final _ctrlHomolog = TextEditingController();

  final List<RegistroMateria> _registros = [];
  int _semestresCursados = 1;
  int? _semestreExpandido = 1;

  final Map<int, String> _busqAdicional = {};
  final Map<int, TextEditingController> _ctrlAdicional = {};
  final Map<int, bool> _mostrarAdicional = {};

  // ── Helpers ──────────────────────────────────────────────

  List<Materia> get _todasLasMaterias {
    final lista = [...widget.programa.materias];
    if (widget.programaSecundario != null) {
      for (final m in widget.programaSecundario!.materias) {
        if (!lista.any((x) => x.codigo == m.codigo)) lista.add(m);
      }
    }
    return lista;
  }

  List<Materia> get _todasLasMateriasYElectivas {
    final lista = [..._todasLasMaterias];
    for (final prog in [widget.programa, widget.programaSecundario]) {
      if (prog == null) continue;
      for (final grupo in prog.gruposElectivas) {
        for (final opcion in grupo.opciones) {
          if (!lista.any((m) => m.codigo == opcion.codigo)) {
            lista.add(opcion);
          }
        }
      }
    }
    return lista;
  }

  Set<String> get _aprobadas => _registros
      .where((r) => r.aprobada)
      .map((r) => r.codigo)
      .toSet();

  Set<String> get _todasAprobadas {
    final set = _aprobadas;
    for (final h in _homologacionesExternas) set.add(h.codigoMateria);
    for (final n in _inglesHomologados) {
      if (n >= 1 && n <= codigosIngles.length) {
        set.add(codigosIngles[n - 1]);
      }
    }
    return set;
  }

  List<RegistroMateria> _registrosDeSemestre(int sem) =>
      _registros.where((r) => r.semestre == sem).toList();

  List<Materia> _materiasDelNivel(int nivel) =>
      widget.programa.materias.where((m) => m.nivel == nivel).toList();

  bool _estaAprobada(String codigo) =>
      _todasAprobadas.contains(codigo);

  bool _estaHomologadaExterna(String codigo) =>
      _homologacionesExternas.any((h) => h.codigoMateria == codigo);

  bool _estaInglesHomologado(String codigo) {
    final idx = codigosIngles.indexOf(codigo);
    if (idx < 0) return false;
    final nivel = idx + 1;
    return _inglesHomologados.contains(nivel);
  }

  bool _fueRegistrada(String codigo, int semestre) =>
      _registros.any((r) => r.codigo == codigo && r.semestre == semestre);

  double get _avance {
    final totalMaterias = widget.programa.materias.length;
    if (totalMaterias == 0) return 0;
    final aprobadas = _todasAprobadas
        .where((c) => widget.programa.materias.any((m) => m.codigo == c))
        .length;
    return aprobadas / totalMaterias;
  }

  int get _creditosAprobados {
    int creditos = 0;
    for (final m in widget.programa.materias) {
      if (_todasAprobadas.contains(m.codigo)) {
        creditos += m.creditos;
      }
    }
    return creditos;
  }

  void _registrar(String codigo, int semestre, bool aprobada) {
    setState(() {
      final idx = _registros.indexWhere(
          (r) => r.codigo == codigo && r.semestre == semestre);
      if (idx >= 0) {
        _registros[idx] = RegistroMateria(
            codigo: codigo, semestre: semestre, aprobada: aprobada);
      } else {
        _registros.add(RegistroMateria(
            codigo: codigo, semestre: semestre, aprobada: aprobada));
      }
    });
  }

  void _quitarRegistro(String codigo, int semestre) {
    setState(() => _registros.removeWhere(
        (r) => r.codigo == codigo && r.semestre == semestre));
  }

  List<Materia> _buscarMaterias(String query, {int? excluirSemestre}) {
    if (query.trim().isEmpty) return [];
    final q = _norm(query);
    return _todasLasMateriasYElectivas.where((m) {
      if (excluirSemestre != null &&
          _fueRegistrada(m.codigo, excluirSemestre)) return false;
      return _norm(m.nombre).contains(q) || _norm(m.codigo).contains(q);
    }).toList();
  }

Future<void> _irAPlanificacion() async {
  setState(() => _isGeneratingPlan = true);

  try {
    final homologacionesList = _homologacionesExternas.map((h) => {
      'codigo_materia': h.codigoMateria,
      'nombre_programa': h.nombrePrograma,
    }).toList();

    final response = await _apiService.planificar(
      programaPrincipal: widget.programa.codigo,
      programaSecundario: widget.programaSecundario?.codigo,
      aprobadas: _aprobadas.toList(),
      nivelesInglesHomologados: _inglesHomologados.toList(),
      promedio: _promedio,
      semestresCursados: _semestresCursados,
      homologacionesExternas: homologacionesList,
      practicaUnica: _practicaUnica,
    );

    final planResponse = PlanResponse.fromJson(response);

    if (mounted) {
      setState(() => _isGeneratingPlan = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaPlanificacion(
            planResponse: planResponse,
            programaPrincipal: widget.programa,
            programaSecundario: widget.programaSecundario,
            token: widget.token,
            userData: widget.userData,
            // Datos necesarios para guardar el plan con nombre personalizado
            planData: response,
            semestresCursados: _semestresCursados,
            promedio: _promedio,
            materiasAprobadas: _aprobadas.toList(),
            homologaciones: homologacionesList,
          ),
        ),
      );
    }
  } catch (e) {
    setState(() => _isGeneratingPlan = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error al generar el plan: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
          drawer: DrawerMenu(  // ← AGREGAR
      token: widget.token,
      userData: widget.userData,
    ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1FC8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mi Historial Académico',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildIndicador(),
          Expanded(child: _buildPaso()),
        ],
      ),
    );
  }

  Widget _buildIndicador() {
    const labels = ['Promedio', 'Inglés', 'Homologaciones', 'Historial'];
    const iconos = [
      Icons.bar_chart_rounded,
      Icons.language_rounded,
      Icons.verified_rounded,
      Icons.checklist_rounded,
    ];
    return Container(
      color: const Color(0xFF1A1FC8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        children: List.generate(4, (i) {
          final activo = i == _paso;
          final completado = i < _paso;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: completado
                              ? const Color(0xFF4ADE00)
                              : activo
                                  ? Colors.white
                                  : const Color(0xFF2D33D4),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          completado ? Icons.check_rounded : iconos[i],
                          size: 16,
                          color: completado
                              ? Colors.black
                              : activo
                                  ? const Color(0xFF1A1FC8)
                                  : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(labels[i],
                          style: TextStyle(
                            fontSize: 9,
                            color: activo
                                ? Colors.white
                                : completado
                                    ? const Color(0xFF4ADE00)
                                    : const Color(0xFF6B7280),
                            fontWeight: activo
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    ],
                  ),
                ),
                if (i < 3)
                  Container(
                      width: 16,
                      height: 1,
                      color: i < _paso
                          ? const Color(0xFF4ADE00)
                          : const Color(0xFF2D33D4)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPaso() {
    switch (_paso) {
      case 0: return _buildPromedio();
      case 1: return _buildIngles();
      case 2: return _buildHomologExternas();
      case 3: return _buildHistorial();
      default: return const SizedBox();
    }
  }

  // ── PASO 0: Promedio ─────────────────────────────────────
  Widget _buildPromedio() {
    final maxCr = _promedio >= 4.0 ? 20 : 18;
    final ok = _promedio >= 4.0;
    // Nota invalida: menor a 3.0. No permite avanzar al siguiente paso.
    final invalida = _promedioIngresado && (_promedio < 3.0 || _promedio > 5.0);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Cuál es tu promedio acumulado?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          const Text(
              'Tu promedio determina cuántos créditos puedes tomar por semestre.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          TextField(
            controller: _ctrlPromedio,
            keyboardType:
                TextInputType.number,
            maxLength: 4,   // Evitamos problema con double al redondear con muchos 9s en 2.9...
            inputFormatters: [
              FormatoDecimal(),
            ],
            decoration: _inputDeco('Promedio (ej. 3.8)',
                icon: Icons.bar_chart_rounded).copyWith(counterText: ''),
            onChanged: (valor) {
              setState(() {
                _promedioIngresado = valor.trim().isNotEmpty;

                final p = double.tryParse(valor);

                if (p != null) {
                  _promedio = double.parse(p.toStringAsFixed(2));
                } else {
                  _promedio = 0.0;
                }
              });
            },
          ),
          const SizedBox(height: 20),
          if (_promedioIngresado)
            AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: invalida
                  ? const Color(0xFFFF6B6B).withOpacity(0.10)
                  : ok
                      ? const Color(0xFF4ADE00).withOpacity(0.10)
                      : const Color(0xFFFBBF24).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: invalida
                    ? const Color(0xFFFF6B6B)
                    : ok
                        ? const Color(0xFF4ADE00)
                        : const Color(0xFFFBBF24),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  invalida
                      ? Icons.cancel_rounded
                      : ok
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                  color: invalida
                      ? const Color(0xFF991B1B)
                      : ok
                          ? const Color(0xFF166534)
                          : const Color(0xFF92400E),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    invalida
                        ? 'Nota invalida. El promedio debe estar entre 3.0 y 5.0. Por favor revisa de nuevo.'
                        : ok
                            ? 'Promedio >= 4.0 → Maximo $maxCr creditos por semestre'
                            : 'Promedio < 4.0 → Maximo $maxCr creditos por semestre',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: invalida
                          ? const Color(0xFF991B1B)
                          : ok
                              ? const Color(0xFF166534)
                              : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // El boton se deshabilita si no se ha ingresado promedio o es invalido (<3.0)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (!_promedioIngresado || invalida)
                  ? null
                  : () => setState(() => _paso = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1FC8),
                disabledBackgroundColor: const Color(0xFF1A1FC8).withOpacity(0.4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Siguiente',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── PASO 1: Inglés ───────────────────────────────────────
  Widget _buildIngles() {
    const nombres = [
      'Lengua Extranjera I', 'Lengua Extranjera II',
      'Lengua Extranjera III', 'Lengua Extranjera IV',
      'Lengua Extranjera V',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Niveles de inglés homologados',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          const Text(
              'Marca los niveles que ya tienes homologados por examen. '
              'Estos no aparecerán en tu historial ni en el plan futuro.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 20),
          ...List.generate(5, (i) {
            final nivel = i + 1;
            final marcado = _inglesHomologados.contains(nivel);
            return GestureDetector(
              onTap: () => setState(() {
                if (marcado) {
                  for (int n = nivel; n <= 5; n++) {
                    _inglesHomologados.remove(n);
                  }
                } else {
                  for (int n = 1; n <= nivel; n++) {
                    _inglesHomologados.add(n);
                  }
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: marcado
                      ? const Color(0xFF1A1FC8).withOpacity(0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: marcado
                        ? const Color(0xFF1A1FC8)
                        : const Color(0xFFE5E7EB),
                    width: marcado ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: marcado
                            ? const Color(0xFF1A1FC8)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('$nivel',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: marcado
                                    ? Colors.white
                                    : const Color(0xFF6B7280))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(nombres[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: marcado
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: marcado
                                ? const Color(0xFF1A1FC8)
                                : const Color(0xFF374151),
                          )),
                    ),
                    if (marcado)
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF1A1FC8), size: 20),
                  ],
                ),
              ),
            );
          }),
          if (_inglesHomologados.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1FC8).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_inglesHomologados.length} nivel(es) homologado(s). '
                'En tu historial aparecerán marcados automáticamente '
                'y no tendrás que registrarlos.',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF1A1FC8)),
              ),
            ),
          const SizedBox(height: 24),
          Row(children: [
            _btnSecundario(() => setState(() => _paso = 0)),
            const SizedBox(width: 12),
            Expanded(
                child: _btnPrimario(
                    'Siguiente', () => setState(() => _paso = 2))),
          ]),
        ],
      ),
    );
  }

  // ── PASO 2: Homologaciones externas ─────────────────────
  Widget _buildHomologExternas() {
    final resultados = _buscarMaterias(_busqHomolog);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Homologaciones externas',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
              const SizedBox(height: 8),
              const Text(
                  'Busca materias homologadas mediante Talento Tech, '
                  'acuerdos con directores u otros programas. '
                  'Si no tienes, pasa al siguiente paso.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 14),
              if (_homologacionesExternas.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _homologacionesExternas.map((h) {
                    final mat = _todasLasMateriasYElectivas.firstWhere(
                        (m) => m.codigo == h.codigoMateria,
                        orElse: () => Materia(
                            codigo: h.codigoMateria,
                            nombre: h.codigoMateria,
                            creditos: 0,
                            nivel: 0));
                    return Chip(
                      label: Text(
                        '${mat.nombre} · ${h.nombrePrograma}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF7C3AED)),
                      ),
                      backgroundColor:
                          const Color(0xFF7C3AED).withOpacity(0.10),
                      side: const BorderSide(
                          color: Color(0xFF7C3AED), width: 0.8),
                      deleteIcon: const Icon(Icons.close,
                          size: 14, color: Color(0xFF7C3AED)),
                      onDeleted: () => setState(() =>
                          _homologacionesExternas.removeWhere(
                              (x) => x.codigoMateria == h.codigoMateria)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _ctrlHomolog,
                decoration: _inputDeco(
                    'Busca la materia (sin tildes también funciona)',
                    icon: Icons.search),
                onChanged: (v) => setState(() => _busqHomolog = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _busqHomolog.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified_outlined,
                          size: 48, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 8),
                      Text('Escribe para buscar materias',
                          style:
                              TextStyle(color: Color(0xFF9CA3AF))),
                    ],
                  ),
                )
              : resultados.isEmpty
                  ? const Center(
                      child: Text('No se encontraron materias',
                          style:
                              TextStyle(color: Color(0xFF9CA3AF))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount:
                          resultados.length > 6 ? 6 : resultados.length,
                      itemBuilder: (_, i) {
                        final m = resultados[i];
                        final yaHom =
                            _estaHomologadaExterna(m.codigo);
                        return _CardHomologacion(
                          materia: m,
                          yaAgregada: yaHom,
                          onAgregar: (prog) {
                            setState(() {
                              _homologacionesExternas.removeWhere(
                                  (h) => h.codigoMateria == m.codigo);
                              _homologacionesExternas.add(
                                HomologacionExterna(
                                  codigoMateria: m.codigo,
                                  nombrePrograma: prog,
                                ),
                              );
                              _busqHomolog = '';
                              _ctrlHomolog.clear();
                            });
                          },
                          onQuitar: () => setState(() =>
                              _homologacionesExternas.removeWhere(
                                  (h) =>
                                      h.codigoMateria == m.codigo)),
                        );
                      },
                    ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            _btnSecundario(() => setState(() => _paso = 1)),
            const SizedBox(width: 12),
            Expanded(
                child: _btnPrimario(
                    'Ir al historial',
                    () => setState(() => _paso = 3))),
          ]),
        ),
      ],
    );
  }

  // ── PASO 3: Historial ────────────────────────────────────
  Widget _buildHistorial() {
  return Column(
    children: [
      Container(
        color: const Color(0xFF1A1FC8),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          children: [
            Row(children: [
              _stat('Aprobadas', '${_todasAprobadas.length}'),
              _divV(),
              _stat('Créditos', '$_creditosAprobados'),
              _divV(),
              _stat('Avance', '${(_avance * 100).toStringAsFixed(0)}%'),
              _divV(),
              _stat('Semestres', '$_semestresCursados cursados'),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _avance,
                minHeight: 8,
                backgroundColor: const Color(0xFF2D33D4),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF4ADE00)),
              ),
            ),
          ],
        ),
      ),
      Container(
        color: const Color(0xFFEEF0FF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Text(
          'Registra qué materias cursaste en cada semestre. '
          'Los ingleses homologados y las homologaciones externas '
          'ya aparecen marcados automáticamente.',
          style: TextStyle(fontSize: 11, color: Color(0xFF374151)),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _semestresCursados,
          itemBuilder: (_, i) => _buildSemestre(i + 1),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            if (_semestresCursados > 1)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  height: 48,
                  width: 48,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _semestresCursados--),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B6B),
                      side: const BorderSide(color: Color(0xFFFF6B6B)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.remove_rounded, size: 20),
                  ),
                ),
              ),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _semestresCursados < 10
                      ? () {
                          setState(() => _semestresCursados++);
                          WidgetsBinding.instance.addPostFrameCallback(
                              (_) => setState(() =>
                                  _semestreExpandido = _semestresCursados));
                        }
                      : null,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    _semestresCursados < 10
                        ? 'Agregar semestre ${_semestresCursados + 1}'
                        : 'Máximo 10 semestres',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1FC8),
                    side: const BorderSide(
                        color: Color(0xFF1A1FC8), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor:
                        const Color(0xFF1A1FC8).withOpacity(0.05),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // ─── SWITCH PARA PRÁCTICA ÚNICA/DOBLE ─────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SwitchListTile(
          title: const Text('Práctica profesional única',
              style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: const Text('Una sola práctica que sirve para ambos programas'),
          value: _practicaUnica,
          onChanged: (value) {
            setState(() {
              _practicaUnica = value;
            });
          },
          activeColor: const Color(0xFF1A1FC8),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const SizedBox(height: 8),
      // ─── BOTONES FINALES ───────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            _btnSecundario(() => setState(() => _paso = 2)),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingPlan ? null : _irAPlanificacion,
                  icon: _isGeneratingPlan
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded,
                          color: Colors.black),
                  label: Text(
                    _isGeneratingPlan ? 'Generando plan...' : 'Generar mi plan',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ADE00),
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
    ],
  );
}
  Widget _buildSemestre(int semestre) {
    final esPrimero = semestre == 1;
    final expandido = _semestreExpandido == semestre;

    final materiasDelNivel = _materiasDelNivel(semestre)
        .where((m) => !_estaInglesHomologado(m.codigo))
        .toList();

    final registros = _registrosDeSemestre(semestre);
    final aprobCount = materiasDelNivel
        .where((m) => _estaAprobada(m.codigo) ||
            _fueRegistrada(m.codigo, semestre) &&
                _registros.any((r) =>
                    r.codigo == m.codigo &&
                    r.semestre == semestre &&
                    r.aprobada))
        .length;
    final totalReg = registros.length;

    _ctrlAdicional.putIfAbsent(semestre, () => TextEditingController());

    if (esPrimero) {
      for (final m in materiasDelNivel) {
        if (!_fueRegistrada(m.codigo, 1)) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _registrar(m.codigo, 1, true));
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: aprobCount > 0
              ? const Color(0xFF4ADE00)
              : const Color(0xFFE5E7EB),
          width: aprobCount > 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14)),
            onTap: () => setState(() =>
                _semestreExpandido = expandido ? null : semestre),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: aprobCount > 0
                          ? const Color(0xFF4ADE00)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text('$semestre',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: aprobCount > 0
                                  ? Colors.black
                                  : const Color(0xFF6B7280))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('Semestre $semestre',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1A1A2E))),
                          if (esPrimero) ...[
                            const SizedBox(width: 6),
                            _pill('Auto', const Color(0xFF1A1FC8)),
                          ],
                        ]),
                        Text(
                          totalReg == 0
                              ? 'Sin materias registradas'
                              : '$aprobCount aprobadas · $totalReg cursadas',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expandido
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (expandido) ...[
            if (materiasDelNivel.isNotEmpty) _seccion('Materias de la malla'),
            ...materiasDelNivel.map((m) {
              final reg = _registros.firstWhere(
                  (r) => r.codigo == m.codigo && r.semestre == semestre,
                  orElse: () =>
                      RegistroMateria(codigo: '', semestre: 0, aprobada: false));
              final tieneReg = reg.codigo.isNotEmpty;

              final aprobadaAntes = semestre > 1 && (
                _registros.any((r) =>
                    r.codigo == m.codigo &&
                    r.semestre < semestre &&
                    r.aprobada)
              );
              final homologadaExt = _estaHomologadaExterna(m.codigo);

              return _FilaMateria(
                nombre: m.nombre,
                estado: homologadaExt
                    ? _Estado.homologada
                    : aprobadaAntes
                        ? _Estado.aprobadaAntes
                        : !tieneReg
                            ? _Estado.sinRegistrar
                            : reg.aprobada
                                ? _Estado.aprobada
                                : _Estado.perdida,
                bloqueada: esPrimero || aprobadaAntes || homologadaExt,
                etiquetaExtra: homologadaExt
                    ? _homologacionesExternas
                        .firstWhere(
                            (h) => h.codigoMateria == m.codigo)
                        .nombrePrograma
                    : null,
                onAprobada:
                    (esPrimero || aprobadaAntes || homologadaExt)
                        ? null
                        : () => _registrar(m.codigo, semestre, true),
                onPerdida:
                    (esPrimero || aprobadaAntes || homologadaExt)
                        ? null
                        : () => _registrar(m.codigo, semestre, false),
                onQuitar:
                    (esPrimero || aprobadaAntes || homologadaExt || !tieneReg)
                        ? null
                        : () => _quitarRegistro(m.codigo, semestre),
              );
            }),

            () {
              final adicionales = _registrosDeSemestre(semestre)
                  .where((r) =>
                      !materiasDelNivel.any((m) => m.codigo == r.codigo))
                  .toList();
              if (adicionales.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _seccion('Materias adicionales'),
                  ...adicionales.map((r) {
                    final mat = _todasLasMaterias.firstWhere(
                        (m) => m.codigo == r.codigo,
                        orElse: () => Materia(
                            codigo: r.codigo,
                            nombre: r.codigo,
                            creditos: 0,
                            nivel: 0));
                    return _FilaMateria(
                      nombre: mat.nombre,
                      estado: r.aprobada
                          ? _Estado.aprobada
                          : _Estado.perdida,
                      bloqueada: false,
                      onAprobada: () =>
                          _registrar(mat.codigo, semestre, true),
                      onPerdida: () =>
                          _registrar(mat.codigo, semestre, false),
                      onQuitar: () =>
                          _quitarRegistro(mat.codigo, semestre),
                    );
                  }),
                ],
              );
            }(),

            _buildBuscadorAdicionales(semestre),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBuscadorAdicionales(int semestre) {
    final mostrar = _mostrarAdicional[semestre] ?? false;
    final query = _busqAdicional[semestre] ?? '';
    final resultados = _buscarMaterias(query, excluirSemestre: semestre);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _mostrarAdicional[semestre] = !mostrar),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: mostrar
                    ? const Color(0xFF00D4FF).withOpacity(0.10)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: mostrar
                        ? const Color(0xFF00D4FF)
                        : const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      mostrar
                          ? Icons.remove_rounded
                          : Icons.add_rounded,
                      size: 15,
                      color: const Color(0xFF0E7490)),
                  const SizedBox(width: 6),
                  const Text(
                      '¿Diste materias adicionales este semestre?',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0E7490),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          if (mostrar) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _ctrlAdicional[semestre],
              decoration: _inputDeco(
                  'Busca por nombre (sin tildes también funciona)',
                  icon: Icons.search),
              onChanged: (v) =>
                  setState(() => _busqAdicional[semestre] = v),
            ),
            if (query.isNotEmpty)
              ...resultados.take(5).map((m) => Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.nombre,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A1A2E))),
                              Text('${m.creditos} cr',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
                        _mini('Aprobé', const Color(0xFF4ADE00), () {
                          _registrar(m.codigo, semestre, true);
                          setState(() {
                            _busqAdicional[semestre] = '';
                            _ctrlAdicional[semestre]!.clear();
                            _mostrarAdicional[semestre] = false;
                          });
                        }),
                        const SizedBox(width: 6),
                        _mini('Perdí', const Color(0xFFFF6B6B), () {
                          _registrar(m.codigo, semestre, false);
                          setState(() {
                            _busqAdicional[semestre] = '';
                            _ctrlAdicional[semestre]!.clear();
                            _mostrarAdicional[semestre] = false;
                          });
                        }),
                      ],
                    ),
                  )),
            if (query.isNotEmpty && resultados.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No se encontraron materias',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ),
          ],
        ],
      ),
    );
  }

  // ── Widgets reutilizables ────────────────────────────────
  Widget _btnPrimario(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1FC8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  Widget _btnSecundario(VoidCallback onTap) => SizedBox(
        width: 52, height: 52,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1A1FC8),
            side: const BorderSide(color: Color(0xFF1A1FC8)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.zero,
          ),
          child: const Icon(Icons.arrow_back_rounded),
        ),
      );

  Widget _mini(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color == const Color(0xFF4ADE00)
                      ? const Color(0xFF166534)
                      : const Color(0xFF991B1B))),
        ),
      );

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );

  Widget _seccion(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.5)),
      );

  Widget _stat(String label, String valor) => Expanded(
        child: Column(children: [
          Text(valor,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFADB5FF), fontSize: 10)),
        ]),
      );

  Widget _divV() => Container(
      height: 22, width: 1, color: Colors.white.withOpacity(0.25));

  InputDecoration _inputDeco(String hint, {required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF1A1FC8), width: 2),
        ),
      );
}

// ── Estados de fila ──────────────────────────────────────────
enum _Estado { sinRegistrar, aprobada, perdida, aprobadaAntes, homologada }

// ── Fila de materia ──────────────────────────────────────────
class _FilaMateria extends StatelessWidget {
  final String nombre;
  final _Estado estado;
  final bool bloqueada;
  final String? etiquetaExtra;
  final VoidCallback? onAprobada;
  final VoidCallback? onPerdida;
  final VoidCallback? onQuitar;

  const _FilaMateria({
    required this.nombre,
    required this.estado,
    required this.bloqueada,
    this.etiquetaExtra,
    this.onAprobada,
    this.onPerdida,
    this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Widget trailing;

    switch (estado) {
      case _Estado.aprobada:
        bg = const Color(0xFF4ADE00).withOpacity(0.05);
        trailing = Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4ADE00), size: 18),
          if (onQuitar != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
                onTap: onQuitar,
                child: const Icon(Icons.close,
                    color: Color(0xFF9CA3AF), size: 14)),
          ],
        ]);
        break;
      case _Estado.perdida:
        bg = const Color(0xFFFF6B6B).withOpacity(0.05);
        trailing = Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cancel_rounded,
              color: Color(0xFFFF6B6B), size: 18),
          if (onQuitar != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
                onTap: onQuitar,
                child: const Icon(Icons.close,
                    color: Color(0xFF9CA3AF), size: 14)),
          ],
        ]);
        break;
      case _Estado.aprobadaAntes:
        bg = const Color(0xFFF9FAFB);
        trailing = const Text('Ya aprobada',
            style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)));
        break;
      case _Estado.homologada:
        bg = const Color(0xFF7C3AED).withOpacity(0.05);
        trailing = Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_rounded,
              color: Color(0xFF7C3AED), size: 16),
          const SizedBox(width: 4),
          Text(etiquetaExtra ?? 'Homologada',
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.w600)),
        ]);
        break;
      default:
        bg = Colors.white;
        trailing = bloqueada
            ? const SizedBox.shrink()
            : Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: onAprobada,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE00).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Aprobé',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534))),
                  ),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: onPerdida,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Perdí',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B))),
                  ),
                ),
              ]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(nombre,
                style: TextStyle(
                    fontSize: 13,
                    color: estado == _Estado.aprobadaAntes
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF374151),
                    fontStyle: estado == _Estado.aprobadaAntes
                        ? FontStyle.italic
                        : FontStyle.normal)),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

// ── Card homologación externa ─────────────────────────────────
class _CardHomologacion extends StatefulWidget {
  final Materia materia;
  final bool yaAgregada;
  final void Function(String programa) onAgregar;
  final VoidCallback onQuitar;

  const _CardHomologacion({
    required this.materia,
    required this.yaAgregada,
    required this.onAgregar,
    required this.onQuitar,
  });

  @override
  State<_CardHomologacion> createState() => _CardHomologacionState();
}

class _CardHomologacionState extends State<_CardHomologacion> {
  String _prog = 'Talento Tech';
  final _opciones = [
    'Talento Tech',
    'Acuerdo con director',
    'Transferencia externa',
    'Otro',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.yaAgregada
            ? const Color(0xFF7C3AED).withOpacity(0.07)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.yaAgregada
              ? const Color(0xFF7C3AED)
              : const Color(0xFFE5E7EB),
          width: widget.yaAgregada ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.materia.nombre,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Mediante:',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _prog,
                isDense: true,
                underline: const SizedBox(),
                items: _opciones
                    .map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(o,
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _prog = v!),
              ),
              const Spacer(),
              widget.yaAgregada
                  ? TextButton(
                      onPressed: widget.onQuitar,
                      child: const Text('Quitar',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF7C3AED))),
                    )
                  : ElevatedButton(
                      onPressed: () => widget.onAgregar(_prog),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Homologar',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}