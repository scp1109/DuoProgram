// ============================================================
//  pantalla_seleccion.dart
//  Seleccion de programas principal y secundario
//  Los datos de malla se obtienen desde el backend (BD),
//  ya no se usan datos locales de datos_programa.dart
// ============================================================

import 'package:flutter/material.dart';
import '../services/servicio_api.dart';
import '../data/datos_programa.dart';
import 'pantalla_historial.dart';
import '../widgets/menu_lateral.dart';

const Map<String, Map<String, dynamic>> _metadatosUI = {
  'ISCO': {
    'icono': Icons.computer_rounded,
    'color': Color(0xFF1A1FC8),
  },
  'IIND': {
    'icono': Icons.business_center_rounded,
    'color': Color(0xFF00D4FF),
  },
  'IMEC': {
    'icono': Icons.settings_rounded,
    'color': Color(0xFF7C3AED),
  },
  'CDAT': {
    'icono': Icons.bar_chart_rounded,
    'color': Color(0xFFEA580C),
  },
};

class PantallaSeleccion extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? datosUsuario;

  const PantallaSeleccion({
    super.key,
    this.token,
    this.datosUsuario,
  });

  @override
  State<PantallaSeleccion> createState() => _PantallaSeleccionState();
}

class _PantallaSeleccionState extends State<PantallaSeleccion> {
  final ServicioApi _servicioApi = ServicioApi();
  List<Map<String, dynamic>> _programas = [];
  bool _cargando = true;
  String? _error;
  
  Programa? _programa1;
  Programa? _programa2;

  String get _nombrePrograma1 =>
      _programa1?.nombre ?? 'No seleccionado';

  String get _nombrePrograma2 =>
      _programa2?.nombre ?? 'No seleccionado';

  bool get _ambosSeleccionados => _programa1 != null && _programa2 != null;

  @override
  void initState() {
    super.initState();
    _cargarProgramas();
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  Future<void> _cargarProgramas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final programas = await _servicioApi.obtenerProgramas();
      setState(() {
        _programas = programas;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  // Selecciona o deselecciona un programa. Llama al backend para obtener
  // la malla completa antes de asignarlo.
  Future<void> _seleccionarPrograma(Map<String, dynamic> data) async {
    final codigo = data['codigo'] as String;

    // Si ya esta seleccionado, deseleccionar
    if (_programa1?.codigo == codigo) {
      setState(() => _programa1 = null);
      return;
    }
    if (_programa2?.codigo == codigo) {
      setState(() => _programa2 = null);
      return;
    }

    // Obtener malla completa desde la BD via API
    final programa = await _fetchPrograma(data);

    if (_programa1 == null) {
      setState(() => _programa1 = programa);
    } else if (_programa2 == null) {
      setState(() => _programa2 = programa);
    } else {
      setState(() {
        _programa2 = _programa1;
        _programa1 = programa;
      });
    }
  }

  // Obtiene la malla completa del programa desde el backend.
  // Antes buscaba en programasDisponibles de datos_programa.dart (local).
  Future<Programa> _fetchPrograma(Map<String, dynamic> data) async {
    final codigo = data['codigo'] as String;
    try {
      final detalle = await _servicioApi.obtenerDetallePrograma(codigo);
      return Programa.fromJson(detalle);
    } catch (e) {
      print('[ERROR] No se pudo cargar malla de $codigo desde BD: $e');
      // Fallback: programa vacio para no bloquear la UI
      return Programa(
        codigo:   codigo,
        nombre:   data['nombre'] as String,
        facultad: data['facultad'] as String,
        materias: [],
      );
    }
  }

  void _intercambiarProgramas() {
    if (_programa1 == null && _programa2 == null) return;
    setState(() {
      final temp = _programa1;
      _programa1 = _programa2;
      _programa2 = temp;
    });
  }

  int _estadoPrograma(Map<String, dynamic> data) {
    final codigo = data['codigo'];
    if (_programa1?.codigo == codigo) return 1;
    if (_programa2?.codigo == codigo) return 2;
    return 0;
  }

  void _continuar() {
    if (!_ambosSeleccionados) return;
    print('[DEBUG] Continuando con: ${_programa1!.nombre} y ${_programa2!.nombre}');
    print('[DEBUG] Materias programa1: ${_programa1!.materias.length}');
    print('[DEBUG] Materias programa2: ${_programa2!.materias.length}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaHistorial(
          programa: _programa1!,
          programaSecundario: _programa2!,
          token: widget.token ?? '',
          datosUsuario: widget.datosUsuario ?? {},  
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF0F2FF),
    drawer: MenuLateral(
      token: widget.token ?? '',
      datosUsuario: widget.datosUsuario ?? {},
    ), 
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1FC8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Selecciona tus Programas',
          style: TextStyle(fontWeight: FontWeight.bold),
        )
      ),
      body: _cargando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF1A1FC8),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando programas...',
                    style: TextStyle(color: Color(0xFF6B7280)),
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
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            size: 40,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Error de conexión',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
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
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Asegúrate que el backend esté corriendo en:',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                        const Text(
                          'http://127.0.0.1:8000',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1FC8),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _cargarProgramas,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1FC8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Reintentar',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      color: const Color(0xFF1A1FC8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selecciona 2 programas',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Elige tu programa principal y el secundario para planificar tu doble programa.',
                            style: TextStyle(color: Color(0xFFADB5FF), fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _BadgeSlot(
                                label: 'Programa 1',
                                nombre: _nombrePrograma1,
                                seleccionado: _programa1 != null,
                                color: _programa1 != null
                                    ? (_metadatosUI[_programa1!.codigo]?['color'] as Color? ?? const Color(0xFF1A1FC8))
                                    : null,
                              )),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: GestureDetector(
                                  onTap: _intercambiarProgramas,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: (_programa1 != null || _programa2 != null)
                                          ? const Color(0xFF00D4FF)
                                          : const Color(0xFF2D33D4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.swap_horiz_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(child: _BadgeSlot(
                                label: 'Programa 2',
                                nombre: _nombrePrograma2,
                                seleccionado: _programa2 != null,
                                color: _programa2 != null
                                    ? (_metadatosUI[_programa2!.codigo]?['color'] as Color? ?? const Color(0xFF1A1FC8))
                                    : null,
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar programa...',
                          prefixIcon:
                              const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF1A1FC8), width: 2),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _programas.length,
                        itemBuilder: (context, index) {
                          final programa = _programas[index];
                          final estado = _estadoPrograma(programa);
                          final ui = _metadatosUI[programa['codigo']] ??
                              {'icono': Icons.school_rounded, 'color': const Color(0xFF1A1FC8)};
                          
                          final int creditos = _parseInt(programa['total_creditos']);
                          // total_semestres viene del backend; antes estaba
                          // hardcodeado como 10 para todos los programas
                          final int semestres = _parseInt(programa['total_semestres']);
                          
                          return _ProgramaCard(
                            nombre: programa['nombre'],
                            facultad: programa['facultad'],
                            semestres: semestres,
                            creditos: creditos,
                            icono: ui['icono'] as IconData,
                            color: ui['color'] as Color,
                            estado: estado,
                            onTap: () => _seleccionarPrograma(programa),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _ambosSeleccionados ? _continuar : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ADE00),
                            disabledBackgroundColor: const Color(0xFFD1D5DB),
                            foregroundColor: Colors.black,
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _ambosSeleccionados
                                ? 'Continuar con estos programas'
                                : 'Selecciona 2 programas para continuar',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Badge de slot ──────────────────────────────────────────
class _BadgeSlot extends StatelessWidget {
  final String label;
  final String nombre;
  final bool seleccionado;
  final Color? color;

  const _BadgeSlot({
    required this.label,
    required this.nombre,
    required this.seleccionado,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: seleccionado
            ? (color ?? const Color(0xFF1A1FC8)).withOpacity(0.25)
            : const Color(0xFF2D33D4),
        borderRadius: BorderRadius.circular(10),
        border: seleccionado
            ? Border.all(color: color ?? Colors.white, width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFADB5FF), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: seleccionado ? Colors.white : const Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight:
                  seleccionado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta de programa ─────────────────────────────────────
class _ProgramaCard extends StatelessWidget {
  final String nombre;
  final String facultad;
  final int semestres;
  final int creditos;
  final IconData icono;
  final Color color;
  final int estado;
  final VoidCallback onTap;

  const _ProgramaCard({
    required this.nombre,
    required this.facultad,
    required this.semestres,
    required this.creditos,
    required this.icono,
    required this.color,
    required this.estado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool seleccionado = estado > 0;
    final String etiqueta = estado == 1 ? 'P. Principal' : 'P. Secundario';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: seleccionado ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: seleccionado ? color : const Color(0xFFE5E7EB),
          width: seleccionado ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(seleccionado ? 0.2 : 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono, color: color, size: 26),
        ),
        title: Text(
          nombre,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: seleccionado ? color : const Color(0xFF1A1A2E),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(facultad,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                _infoChip(Icons.calendar_today_rounded,
                    '$semestres semestres'),
                const SizedBox(width: 8),
                _infoChip(Icons.menu_book_rounded, '$creditos creditos'),
                if (seleccionado) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        etiqueta,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: seleccionado ? color : const Color(0xFF1A1FC8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              seleccionado ? Icons.check_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}