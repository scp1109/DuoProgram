// ============================================================
//  pantalla_perfil.dart
//  Pantalla de perfil de usuario completa
//  Permite: Ver datos, editar perfil, cambiar contraseña,
//           ver historial, cerrar sesión
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'dart:convert'; // base64
import '../services/servicio_api.dart';
import '../utils/sesion_helper.dart';
import '../config/claves_prefs.dart';
import '../theme/colores.dart';
import 'pantalla_editar_perfil.dart';
import 'pantalla_cambiar_contrasena.dart';
import 'pantalla_mis_planes.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../theme/transiciones.dart';
import '../widgets/superficie.dart';

class PantallaPerfil extends StatefulWidget {
  final String token;
  final Map<String, dynamic> datosUsuario;

  const PantallaPerfil({
    super.key,
    required this.token,
    required this.datosUsuario,
  });

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final ServicioApi _servicioApi = ServicioApi();
  late Map<String, dynamic> _datosUsuario;
  String? _fotoPath;      // ruta local (movil/desktop)
  Uint8List? _fotoBytes;  // bytes en memoria (web, Image.file no soportado)
  List<dynamic> _historial = [];
  bool _cargando = true;
  bool _cargandoHistorial = true;
  List<dynamic> _planesGuardados = [];
  bool _cargandoPlanes = true;

  @override
  void initState() {
    super.initState();
    _datosUsuario = widget.datosUsuario;
    _cargarFotoGuardada();
    _cargarDatosCompletos();
  }

  // Carga la foto guardada en SharedPreferences al abrir el perfil
  Future<void> _cargarFotoGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    // El usuario pudo navegar hacia atras mientras leiamos las prefs; sin esta
    // guarda setState revienta con "called after dispose".
    if (!mounted) return;
    if (kIsWeb) {
      // En web se guarda como base64 porque Image.file no existe
      final base64Str = prefs.getString(ClavesPrefs.fotoPerfilWeb(_datosUsuario['id']));
      if (base64Str != null) {
        setState(() => _fotoBytes = base64Decode(base64Str));
      }
    } else {
      // En movil/desktop se guarda la ruta del archivo
      final fotoGuardada = prefs.getString(ClavesPrefs.fotoPerfil(_datosUsuario['id']));
      if (fotoGuardada != null && File(fotoGuardada).existsSync()) {
        setState(() => _fotoPath = fotoGuardada);
      }
    }
  }

  Future<void> _cargarPlanesGuardados() async {
  setState(() => _cargandoPlanes = true);
  try {
    final planes = await _servicioApi.obtenerMisPlanes(widget.token);
    // Guarda tras el await: la pantalla pudo cerrarse durante la peticion.
    if (!mounted) return;
    setState(() {
      _planesGuardados = planes;
      _cargandoPlanes = false;
    });
  } on SesionExpiradaException {
    if (mounted) await SesionHelper.manejarSesionExpirada(context);
  } catch (e) {
    if (!mounted) return;
    setState(() => _cargandoPlanes = false);
    if (kDebugMode) {
      debugPrint('Error cargando planes: $e');
    }
    }
  }

  Future<void> _cargarDatosCompletos() async {
    await Future.wait([
      _cargarPerfil(),
      _cargarHistorial(),
      _cargarPlanesGuardados(),
    ]);
    // Guarda tras esperar las tres peticiones.
    if (!mounted) return;
    setState(() => _cargando = false);
  }

  Future<void> _cargarPerfil() async {
    try {
      final perfil = await _servicioApi.obtenerPerfil(widget.token);
      if (!mounted) return;
      setState(() {
        _datosUsuario = perfil;
      });
    } on SesionExpiradaException {
      if (mounted) await SesionHelper.manejarSesionExpirada(context);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cargando perfil: $e');
      }
    }
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargandoHistorial = true);
    try {
      final historial = await _servicioApi.obtenerHistorial(widget.token);
      if (!mounted) return;
      setState(() {
        _historial = historial;
        _cargandoHistorial = false;
      });
    } on SesionExpiradaException {
      if (mounted) await SesionHelper.manejarSesionExpirada(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoHistorial = false);
      if (kDebugMode) {
        debugPrint('Error cargando historial: $e');
      }
    }
  }

  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Superficies.radioTarjeta)),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await SesionHelper.cerrarSesion(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colores.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void _editarPerfil() async {
    final resultado = await Navigator.push(
      context,
      RutaModal(
        pagina: PantallaEditarPerfil(
          token: widget.token,
          datosUsuario: _datosUsuario,
        ),
      ),
    );
    if (resultado == true) {
      _cargarPerfil();
      _cargarHistorial(); // refrescar historial para mostrar la accion recien registrada
    }
  }

  void _cambiarContrasena() async {
    final resultado = await Navigator.push(
      context,
      RutaModal(
        pagina: PantallaCambiarContrasena(token: widget.token),
      ),
    );
    if (resultado == true) {
      _mostrarSnackbar('Contraseña actualizada correctamente', isError: false);
    }
  }

  void _mostrarSnackbar(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colores.error : Colores.exitoOscuro,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colores.fondoApp,
      appBar: AppBar(
        backgroundColor: Colores.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: _editarPerfil,
            tooltip: 'Editar perfil',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Colores.primario),
            )
          : RefreshIndicator(
              onRefresh: _cargarDatosCompletos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header con foto de perfil
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      // Esquinas inferiores redondeadas, igual que en
                      // seleccion e historial: la cabecera se lee como panel
                      // apoyado sobre el contenido, no como franja pegada.
                      decoration: const BoxDecoration(
                        color: Colores.primario,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Avatar con opción de cambiar foto
                          Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colores.primario.withValues(alpha: 0.22),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _fotoBytes != null
                                      // Web: bytes en memoria
                                      ? Image.memory(_fotoBytes!, fit: BoxFit.cover)
                                      : _fotoPath != null
                                          // Movil/desktop: archivo local
                                          ? Image.file(File(_fotoPath!), fit: BoxFit.cover)
                                          : _datosUsuario['foto_url'] != null
                                              // Foto remota del servidor
                                              ? Image.network(
                                                  _datosUsuario['foto_url'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => Container(
                                                    color: Colores.acentoCian,
                                                    child: const Icon(Icons.person, size: 50, color: Colors.white),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colores.acentoCian,
                                                  child: const Icon(Icons.person, size: 50, color: Colors.white),
                                                ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _cambiarFoto,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colores.exito,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _datosUsuario['nombre_completo'] ?? 'Usuario',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _datosUsuario['email'] ?? 'usuario@utb.edu.co',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colores.primarioSuave,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Miembro desde ${_formatearFecha(_datosUsuario['created_at'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botones de acción rápidos
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.edit_rounded,
                              label: 'Editar perfil',
                              color: Colores.primario,
                              onTap: _editarPerfil,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.lock_rounded,
                              label: 'Cambiar contraseña',
                              // El oscuro y no acentoCian: este color pinta
                              // texto e icono sobre un fondo tintado muy
                              // claro, y ahi el claro daba 1.6:1. Con este
                              // sube a 5.5:1.
                              color: Colores.acentoCianOscuro,
                              onTap: _cambiarContrasena,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Información de cuenta
                    Revelar(
                      indice: 0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
                          boxShadow: [
                            BoxShadow(
                              // Tinta azulada, no negra: sobre un fondo con
                              // color el negro deja un halo gris sucio.
                              color: Colores.primario.withValues(alpha: 0.07),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Información de la cuenta',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colores.textoTitulo,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            _buildInfoRow(
                              icon: Icons.person_outline,
                              label: 'Nombre completo',
                              value: _datosUsuario['nombre_completo'] ?? 'No especificado',
                              onTap: _editarPerfil,
                            ),
                            _buildInfoRow(
                              icon: Icons.email_outlined,
                              label: 'Correo electrónico',
                              value: _datosUsuario['email'] ?? 'No especificado',
                              onTap: _editarPerfil,
                            ),
                            _buildInfoRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'Fecha de registro',
                              value: _formatearFecha(_datosUsuario['created_at']),
                            ),
                            _buildInfoRow(
                              icon: Icons.school_rounded,
                              label: 'Planes guardados',
                              value: _cargandoPlanes ? '...' : '${_planesGuardados.length}',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  RutaDesvanecido(
                                    pagina: PantallaMisPlanes(token: widget.token),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Planes guardados recientes
                    if (_planesGuardados.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
                          boxShadow: [
                            BoxShadow(
                              // Tinta azulada, no negra: sobre un fondo con
                              // color el negro deja un halo gris sucio.
                              color: Colores.primario.withValues(alpha: 0.07),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Últimos planes guardados',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colores.textoTitulo,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            _buildPlanesLista(),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Historial de actividades
                    Revelar(
                      indice: 1,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
                          boxShadow: [
                            BoxShadow(
                              // Tinta azulada, no negra: sobre un fondo con
                              // color el negro deja un halo gris sucio.
                              color: Colores.primario.withValues(alpha: 0.07),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Actividad reciente',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colores.textoTitulo,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            _buildHistorialList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Presionable en vez de InkWell: el destello de Material se ve
    // generico; hundir el boton da respuesta fisica al dedo.
    return Presionable(
      onTap: onTap,
      escala: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(Superficies.radioInterior),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            // El icono en su propio circulo, mismo patron que el resto
            // de la app en vez de un icono suelto.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Presionable(
      onTap: onTap,
      escala: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colores.primario.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: Colores.primario.withValues(alpha: 0.16)),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Colores.primario,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colores.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colores.textoTitulo,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colores.textoTenue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanesLista() {
    if (_cargandoPlanes) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: Colores.primario),
        ),
      );
    }

    if (_planesGuardados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.folder_open, size: 48, color: Colores.borde),
              SizedBox(height: 12),
              Text(
                'No hay planes guardados',
                style: TextStyle(fontSize: 14, color: Colores.textoTenue),
              ),
            ],
          ),
        ),
      );
    }

    final ultimosPlanes = _planesGuardados.take(3).toList();
    return Column(
      children: ultimosPlanes.map((plan) {
        return ListTile(
          leading: const Icon(Icons.school_rounded, color: Colores.primario),
          title: Text(
                  plan['nombre'] != null && plan['nombre'].toString().trim().isNotEmpty
                      ? '${plan['id']}. ${plan['nombre']}'
                      : '${plan['id']}. ${plan['programa_principal']} + ${plan['programa_secundario'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colores.textoTitulo,
                  ),
                ),
          subtitle: Text('Creado: ${_formatearFecha(plan['created_at'])}'),
          // trailing: const Icon(Icons.visibility_rounded, color: Colores.primario),
          onTap: () {
            // Ver plan guardado
          },
        );
      }).toList(),
    );
  }

  Widget _buildHistorialList() {
    if (_cargandoHistorial) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: Colores.primario),
        ),
      );
    }

    if (_historial.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 48, color: Colores.borde),
              SizedBox(height: 12),
              Text(
                'No hay actividad reciente',
                style: TextStyle(fontSize: 14, color: Colores.textoTenue),
              ),
            ],
          ),
        ),
      );
    }

    final ultimasActividades = _historial.take(5).toList();
    return Column(
      children: ultimasActividades.map((item) {
        return ListTile(
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getAccionColor(item['accion']).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getAccionIcon(item['accion']),
              size: 18,
              color: _getAccionColor(item['accion']),
            ),
          ),
          title: Text(_getAccionTexto(item['accion'])),
          subtitle: item['detalles'] != null
              ? Text(item['detalles'], maxLines: 1)
              : null,
          trailing: Text(
            _formatearHora(item['fecha']),
            style: const TextStyle(fontSize: 11, color: Colores.textoTenue),
          ),
        );
      }).toList(),
    );
  }

/*
  void _cambiarFoto() {
    // Implementar cambio de foto
    _mostrarSnackbar('Función en desarrollo', isError: true);
  }
*/

  Future<void> _seleccionarImagen(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        if (kIsWeb) {
          // En web Image.file no funciona, se guardan los bytes como base64
          final bytes = await image.readAsBytes();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(ClavesPrefs.fotoPerfilWeb(_datosUsuario['id']), base64Encode(bytes));
          // Guarda tras el await: el picker y la escritura en prefs son lentos
          // y el usuario pudo cerrar la pantalla mientras tanto.
          if (!mounted) return;
          setState(() => _fotoBytes = bytes);
        } else {
          // En movil/desktop se guarda la ruta y se persiste
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(ClavesPrefs.fotoPerfil(_datosUsuario['id']), image.path);
          if (!mounted) return;
          setState(() => _fotoPath = image.path);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackbar('Error al seleccionar imagen', isError: true);
    }
  }

  void _eliminarFoto() async {
    final prefs = await SharedPreferences.getInstance();
    // Se limpia la clave correcta segun la plataforma
    if (kIsWeb) {
      await prefs.remove(ClavesPrefs.fotoPerfilWeb(_datosUsuario['id']));
    } else {
      await prefs.remove(ClavesPrefs.fotoPerfil(_datosUsuario['id']));
    }
    // Guarda tras los awaits sobre prefs.
    if (!mounted) return;
    setState(() {
      _fotoPath = null;
      _fotoBytes = null;
      _datosUsuario['foto_url'] = null;
    });
    _mostrarSnackbar('Foto eliminada correctamente');
  }

  void _cambiarFoto() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colores.error),
              title: const Text('Eliminar foto',
                  style: TextStyle(color: Colores.error)),
              onTap: () {
                Navigator.pop(context);
                _eliminarFoto();
              },
            ),
          ],
        ),
      ),
    );
  }


  String _formatearFecha(String? fecha) {
    if (fecha == null) return 'fecha desconocida';
    try {
      final date = DateTime.parse(fecha);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return fecha.split('T')[0];
    }
  }

  String _formatearHora(String? fecha) {
    if (fecha == null) return '';
    try {
      final date = DateTime.parse(fecha);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) return 'hace ${diff.inDays} días';
      if (diff.inHours > 0) return 'hace ${diff.inHours} h';
      if (diff.inMinutes > 0) return 'hace ${diff.inMinutes} min';
      return 'ahora';
    } catch (e) {
      return '';
    }
  }

  IconData _getAccionIcon(String accion) {
    switch (accion) {
      case 'login':
        return Icons.login_rounded;
      case 'registro':
        return Icons.person_add_rounded;
      case 'generar_plan':
        return Icons.school_rounded;
      case 'actualizar_perfil':
        return Icons.edit_rounded;
      default:
        return Icons.circle_notifications_rounded;
    }
  }

  Color _getAccionColor(String accion) {
    switch (accion) {
      case 'login':
        return Colores.exito;
      case 'registro':
        return Colores.primario;
      case 'generar_plan':
        return Colores.acentoCian;
      case 'actualizar_perfil':
        return Colores.advertenciaFuerte;
      default:
        return Colores.textoSecundario;
    }
  }

  String _getAccionTexto(String accion) {
    switch (accion) {
      case 'login':
        return 'Inicio de sesion';
      case 'registro':
        return 'Registro de cuenta';
      case 'generar_plan':
        return 'Generacion de plan';
      case 'actualizar_perfil':
        return 'Actualizacion de perfil';
      default:
        return accion;
    }
  }
}