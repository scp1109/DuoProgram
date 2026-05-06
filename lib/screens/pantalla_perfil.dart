// ============================================================
//  pantalla_perfil.dart
//  Pantalla de perfil de usuario completa
//  Permite: Ver datos, editar perfil, cambiar contraseña,
//           ver historial, cerrar sesión
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import '../services/api_service.dart';
import 'pantalla_inicio.dart';
import 'pantalla_editar_perfil.dart';
import 'pantalla_cambiar_password.dart';
import 'pantalla_mis_planes.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class PantallaPerfil extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const PantallaPerfil({
    super.key,
    required this.token,
    required this.userData,
  });

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final ApiService _apiService = ApiService();
  late Map<String, dynamic> _userData;
  String? _fotoPath;      // ruta local (movil/desktop)
  Uint8List? _fotoBytes;  // bytes en memoria (web, Image.file no soportado)
  List<dynamic> _historial = [];
  bool _isLoading = true;
  bool _isLoadingHistorial = true;
  List<dynamic> _planesGuardados = [];
  bool _isLoadingPlanes = true;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _cargarFotoGuardada();
    _cargarDatosCompletos();
  }

  // Carga la ruta de foto guardada en SharedPreferences al abrir el perfil
  Future<void> _cargarFotoGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final fotoGuardada = prefs.getString('foto_perfil_${_userData['id']}');
    if (fotoGuardada != null && File(fotoGuardada).existsSync()) {
      setState(() => _fotoPath = fotoGuardada);
    }
  }

  Future<void> _cargarPlanesGuardados() async {
  setState(() => _isLoadingPlanes = true);
  try {
    final planes = await _apiService.getMisPlanes(widget.token);
    setState(() {
      _planesGuardados = planes;
      _isLoadingPlanes = false;
    });
  } catch (e) {
    setState(() => _isLoadingPlanes = false);
    print('Error cargando planes: $e');
    }
  }

  Future<void> _cargarDatosCompletos() async {
    await Future.wait([
      _cargarPerfil(),
      _cargarHistorial(),
      _cargarPlanesGuardados(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _cargarPerfil() async {
    try {
      final perfil = await _apiService.getPerfil(widget.token);
      setState(() {
        _userData = perfil;
      });
    } catch (e) {
      print('Error cargando perfil: $e');
    }
  }

  Future<void> _cargarHistorial() async {
    setState(() => _isLoadingHistorial = true);
    try {
      final historial = await _apiService.getHistorial(widget.token);
      setState(() {
        _historial = historial;
        _isLoadingHistorial = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistorial = false);
      print('Error cargando historial: $e');
    }
  }

  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const PantallaInicio()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void _editarPerfil() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaEditarPerfil(
          token: widget.token,
          userData: _userData,
        ),
      ),
    );
    if (result == true) {
      _cargarPerfil();
    }
  }

  void _cambiarPassword() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaCambiarPassword(token: widget.token),
      ),
    );
    if (result == true) {
      _mostrarSnackbar('Contraseña actualizada correctamente', isError: false);
    }
  }

  void _mostrarSnackbar(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1FC8),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A1FC8)),
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
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1FC8),
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
                                      color: Colors.black.withOpacity(0.2),
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
                                          : _userData['foto_url'] != null
                                              // Foto remota del servidor
                                              ? Image.network(
                                                  _userData['foto_url'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: const Color(0xFF00D4FF),
                                                    child: const Icon(Icons.person, size: 50, color: Colors.white),
                                                  ),
                                                )
                                              : Container(
                                                  color: const Color(0xFF00D4FF),
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
                                      color: const Color(0xFF4ADE00),
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
                            _userData['nombre_completo'] ?? 'Usuario',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userData['email'] ?? 'usuario@utb.edu.co',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFADB5FF),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Miembro desde ${_formatearFecha(_userData['created_at'])}',
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
                              color: const Color(0xFF1A1FC8),
                              onTap: _editarPerfil,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.lock_rounded,
                              label: 'Cambiar contraseña',
                              color: const Color(0xFF00D4FF),
                              onTap: _cambiarPassword,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Información de cuenta
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
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
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _buildInfoRow(
                            icon: Icons.person_outline,
                            label: 'Nombre completo',
                            value: _userData['nombre_completo'] ?? 'No especificado',
                            onTap: _editarPerfil,
                          ),
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            label: 'Correo electrónico',
                            value: _userData['email'] ?? 'No especificado',
                            onTap: _editarPerfil,
                          ),
                          _buildInfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Fecha de registro',
                            value: _formatearFecha(_userData['created_at']),
                          ),
                          _buildInfoRow(
                            icon: Icons.school_rounded,
                            label: 'Planes guardados',
                            value: _isLoadingPlanes ? '...' : '${_planesGuardados.length}',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PantallaMisPlanes(token: widget.token),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Planes guardados recientes
                    if (_planesGuardados.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
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
                                  color: Color(0xFF1A1A2E),
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
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
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
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _buildHistorialList(),
                        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1FC8).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: const Color(0xFF1A1FC8),
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
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanesLista() {
    if (_isLoadingPlanes) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A1FC8)),
        ),
      );
    }

    if (_planesGuardados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.folder_open, size: 48, color: Color(0xFFD1D5DB)),
              SizedBox(height: 12),
              Text(
                'No hay planes guardados',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
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
          leading: const Icon(Icons.school_rounded, color: Color(0xFF1A1FC8)),
          title: Text(
                  plan['nombre'] != null && plan['nombre'].toString().trim().isNotEmpty
                      ? '${plan['id']}. ${plan['nombre']}'
                      : '${plan['id']}. ${plan['programa_principal']} + ${plan['programa_secundario'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
          subtitle: Text('Creado: ${_formatearFecha(plan['created_at'])}'),
          // trailing: const Icon(Icons.visibility_rounded, color: Color(0xFF1A1FC8)),
          onTap: () {
            // Ver plan guardado
          },
        );
      }).toList(),
    );
  }

  Widget _buildHistorialList() {
    if (_isLoadingHistorial) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A1FC8)),
        ),
      );
    }

    if (_historial.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 48, color: Color(0xFFD1D5DB)),
              SizedBox(height: 12),
              Text(
                'No hay actividad reciente',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
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
              color: _getAccionColor(item['accion']).withOpacity(0.1),
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
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
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
          // En web Image.file no funciona, se leen los bytes directamente
          final bytes = await image.readAsBytes();
          setState(() => _fotoBytes = bytes);
        } else {
          // En movil/desktop se guarda la ruta y se persiste
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('foto_perfil_${_userData['id']}', image.path);
          setState(() => _fotoPath = image.path);
        }
      }
    } catch (e) {
      _mostrarSnackbar('Error al seleccionar imagen', isError: true);
    }
  }

  void _eliminarFoto() async {
    // Borra la ruta persistida ademas de limpiar el estado
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('foto_perfil_${_userData['id']}');
    setState(() {
      _fotoPath = null;
      _fotoBytes = null;
      _userData['foto_url'] = null;
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
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar foto', style: TextStyle(color: Colors.red)),
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
      default:
        return Icons.circle_notifications_rounded;
    }
  }

  Color _getAccionColor(String accion) {
    switch (accion) {
      case 'login':
        return const Color(0xFF4ADE00);
      case 'registro':
        return const Color(0xFF1A1FC8);
      case 'generar_plan':
        return const Color(0xFF00D4FF);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getAccionTexto(String accion) {
    switch (accion) {
      case 'login':
        return 'Inicio de sesión';
      case 'registro':
        return 'Registro de cuenta';
      case 'generar_plan':
        return 'Generación de plan';
      default:
        return accion;
    }
  }
}