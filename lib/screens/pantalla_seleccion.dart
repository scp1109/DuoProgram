// ============================================================
//  pantalla_seleccion.dart
//  Seleccion de programas principal y secundario
//  Los datos de malla se obtienen desde el backend (BD),
//  ya no se usan datos locales de datos_programa.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugMode, debugPrint
import '../services/servicio_api.dart';
import '../data/datos_programa.dart';
import 'pantalla_historial.dart';
import '../widgets/menu_lateral.dart';
import '../theme/colores.dart';
import '../theme/transiciones.dart';
import '../widgets/superficie.dart';
import '../theme/movimiento.dart';

const Map<String, Map<String, dynamic>> _metadatosUI = {
  'ISCO': {
    'icono': Icons.computer_rounded,
    'color': Colores.primario,
  },
  'IIND': {
    'icono': Icons.business_center_rounded,
    'color': Colores.acentoCian,
  },
  'IMEC': {
    'icono': Icons.settings_rounded,
    'color': Colores.acentoMorado,
  },
  'CDAT': {
    'icono': Icons.bar_chart_rounded,
    'color': Colores.acentoNaranja,
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
      // El usuario pudo navegar hacia atras mientras la peticion estaba en
      // vuelo; sin esta guarda setState revienta con "called after dispose".
      if (!mounted) return;
      setState(() {
        _programas = programas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
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

    // Guarda tras el await: el usuario pudo salir de la pantalla.
    if (!mounted) return;

    // Si la malla no se pudo cargar NO seleccionamos el programa. Antes se
    // devolvia un Programa con materias vacias y la app seguia como si nada:
    // el usuario llegaba al wizard de historial con una malla vacia y
    // generaba un plan sin sentido sin entender por que.
    if (programa == null) {
      _mostrarErrorMalla(data['nombre'] as String? ?? codigo);
      return;
    }

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

  // Avisa al usuario de que la malla no se pudo traer del backend.
  void _mostrarErrorMalla(String nombrePrograma) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colores.error,
        duration: const Duration(seconds: 4),
        content: Text(
          'No se pudo cargar la malla de $nombrePrograma. '
          'Revisa tu conexion e intenta de nuevo.',
        ),
      ),
    );
  }

  // Obtiene la malla completa del programa desde el backend.
  // Antes buscaba en programasDisponibles de datos_programa.dart (local).
  // Devuelve null si la peticion falla: el fallo tiene que ser visible, asi
  // que quien llama decide que hacer en vez de recibir una malla vacia.
  Future<Programa?> _fetchPrograma(Map<String, dynamic> data) async {
    final codigo = data['codigo'] as String;
    try {
      final detalle = await _servicioApi.obtenerDetallePrograma(codigo);
      return Programa.fromJson(detalle);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ERROR] No se pudo cargar malla de $codigo desde BD: $e');
      }
      return null;
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

    Navigator.push(
      context,
      RutaProfundidad(
        pagina: PantallaHistorial(
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
    backgroundColor: Colores.fondoApp,
    drawer: MenuLateral(
      token: widget.token ?? '',
      datosUsuario: widget.datosUsuario ?? {},
    ), 
      // El AppBar no lleva color propio: el panel de abajo pinta el
      // fondo de toda la zona superior, asi no hay costura entre los dos.
      appBar: AppBar(
        backgroundColor: Colores.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Selecciona tus Programas',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
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
                    'Cargando programas...',
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
                          'Error de conexión',
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
                        const Text(
                          'Asegúrate que el backend esté corriendo en:',
                          style: TextStyle(fontSize: 12, color: Colores.textoTenue),
                        ),
                        const Text(
                          'http://127.0.0.1:8000',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                              color: Colores.primario,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _cargarProgramas,
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
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      decoration: const BoxDecoration(
                        // Degradado sutil hacia la tinta profunda: da
                        // volumen al panel sin salirse del azul de marca.
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colores.primario, Superficies.tintaMedia],
                        ),
                        // Esquinas inferiores redondeadas: la cabecera deja
                        // de ser una franja pegada y pasa a leerse como un
                        // panel apoyado sobre el contenido.
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
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
                            style: TextStyle(color: Colores.primarioSuave, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _BadgeSlot(
                                label: 'Programa 1',
                                  nombre: _nombrePrograma1,
                                seleccionado: _programa1 != null,
                                  color: _programa1 != null
                                    ? (_metadatosUI[_programa1!.codigo]?['color'] as Color? ?? Colores.primario)
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
                                          ? Colores.acentoCian
                                          : Colores.primarioClaro,
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
                                    ? (_metadatosUI[_programa2!.codigo]?['color'] as Color? ?? Colores.primario)
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
                              const Icon(Icons.search, color: Colores.textoTenue),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colores.bordeSuave),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                  color: Colores.primario, width: 2),
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
                              {'icono': Icons.school_rounded, 'color': Colores.primario};
                          
                          final int creditos = _parseInt(programa['total_creditos']);
                          // total_semestres viene del backend; antes estaba
                          // hardcodeado como 10 para todos los programas
                          final int semestres = _parseInt(programa['total_semestres']);
                          
                          return Revelar(
                            indice: index,
                            child: _ProgramaCard(
                              nombre: programa['nombre'],
                              facultad: programa['facultad'],
                              semestres: semestres,
                              creditos: creditos,
                              icono: ui['icono'] as IconData,
                              color: ui['color'] as Color,
                              estado: estado,
                              onTap: () => _seleccionarPrograma(programa),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: BotonIsla(
                          texto: _ambosSeleccionados
                              ? 'Continuar con estos programas'
                              : 'Selecciona 2 programas',
                          color: _ambosSeleccionados
                              ? Colores.primario
                              : Colores.borde,
                          colorTexto: _ambosSeleccionados
                              ? Colors.white
                              : Colores.textoSecundario,
                          onTap: _ambosSeleccionados ? _continuar : null,
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
            ? (color ?? Colores.primario).withValues(alpha: 0.25)
            : Colores.primarioClaro,
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
            style: const TextStyle(color: Colores.primarioSuave, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: seleccionado ? Colors.white : Colores.textoTenue,
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
    final String etiqueta = estado == 1 ? 'Principal' : 'Secundario';

    // Toda la tarjeta responde al tacto, no solo el boton de la derecha:
    // un area tocable de 36px en la esquina obliga a apuntar.
    return Presionable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Movimiento.corta,
        curve: Movimiento.principal,
        margin: const EdgeInsets.only(bottom: 12),
        // Cascaron exterior del bisel.
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: seleccionado
              ? color.withValues(alpha: 0.12)
              : Superficies.brumaLavanda,
          borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
          border: Border.all(
            color: seleccionado
                ? color.withValues(alpha: 0.45)
                : Superficies.nieblaAzul.withValues(alpha: 0.6),
          ),
          // La sombra se enciende al seleccionar: la tarjeta se despega
          // del fondo en vez de solo cambiar de color.
          boxShadow: seleccionado ? Superficies.sutil : Superficies.ambiente,
        ),
        child: AnimatedContainer(
          duration: Movimiento.corta,
          curve: Movimiento.principal,
          // Nucleo interior con radio concentrico: el radio exterior
          // menos el grosor del marco, si no la curva se ve apretada.
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
                Superficies.radioInterno(Superficies.radioTarjeta, 5)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              // Icono en su propio bisel, mismo patron a menor escala.
              AnimatedContainer(
                duration: Movimiento.corta,
                curve: Movimiento.principal,
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: seleccionado ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: color.withValues(alpha: seleccionado ? 0.3 : 0.12)),
                ),
                child: Icon(icono, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.2,
                              letterSpacing: -0.2,
                                color: seleccionado ? color : Colores.textoTitulo,
                            ),
                          ),
                        ),
                        if (seleccionado) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                                color: color,
                              borderRadius: BorderRadius.circular(
                                  Superficies.radioPildora),
                            ),
                            child: Text(
                              etiqueta.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      facultad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colores.textoSecundario, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _infoChip(Icons.calendar_today_rounded,
                            '$semestres semestres'),
                        const SizedBox(width: 10),
                        _infoChip(Icons.menu_book_rounded, '$creditos cr'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Boton isla en miniatura: circulo, no cuadrado con radio.
              AnimatedContainer(
                duration: Movimiento.corta,
                // OJO: aqui NO va Movimiento.resorte. Esa curva sobrepasa
                // 1.0 y, al interpolar una sombra, extrapola el blurRadius
                // a negativo y Flutter lanza un assert. El rebote solo debe
                // manejar transform (ver la nota en movimiento.dart).
                curve: Movimiento.principal,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: seleccionado ? color : Colores.primario,
                  shape: BoxShape.circle,
                  // Se interpola contra una sombra de blur 0 y no contra
                  // null: asi las dos listas tienen la misma forma y el
                  // lerp no tiene que inventar el estado ausente.
                  boxShadow:
                      seleccionado ? Superficies.sutil : Superficies.ninguna,
                ),
                child: AnimatedSwitcher(
                  duration: Movimiento.instante,
                  child: Icon(
                    seleccionado ? Icons.check_rounded : Icons.add_rounded,
                    key: ValueKey(seleccionado),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colores.textoTenue),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: Colores.textoTenue,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
