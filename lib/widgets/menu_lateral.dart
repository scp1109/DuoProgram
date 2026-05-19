// ============================================================
//  widgets/menu_lateral.dart
//  Menú lateral disponible en toda la app
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/pantalla_perfil.dart';
import '../screens/pantalla_mis_planes.dart';
import '../screens/pantalla_seleccion.dart';
import '../utils/sesion_helper.dart';

// Este widget crea el menu lateral que aparece en varias pantallas de la app.
// Es StatefulWidget porque necesita cargar la foto guardada del usuario.
class MenuLateral extends StatefulWidget {
  // Token del usuario logueado. Sirve para abrir pantallas que necesitan sesion.
  final String token;

  // Datos basicos del usuario: id, nombre, correo y posiblemente foto_url.
  final Map<String, dynamic> datosUsuario;

  const MenuLateral({
    super.key,
    required this.token,
    required this.datosUsuario,
  });

  @override
  State<MenuLateral> createState() => _MenuLateralState();
}

class _MenuLateralState extends State<MenuLateral> {
  // Ruta local de la foto en celular/escritorio.
  // Se guarda cuando el usuario elige una imagen desde Mi Perfil.
  String? _fotoPath;

  // Bytes de la foto cuando la app corre en web.
  // En web no se usa Image.file, por eso se guarda la imagen en memoria.
  Uint8List? _fotoBytes;

  @override
  void initState() {
    super.initState();
    // Al abrir el drawer, se intenta cargar la foto guardada.
    _cargarFotoGuardada();
  }

  @override
  void didUpdateWidget(covariant MenuLateral widgetAnterior) {
    super.didUpdateWidget(widgetAnterior);
    // Si cambian los datos del usuario, se vuelve a buscar la foto correcta.
    _cargarFotoGuardada();
  }

  // Busca la foto del usuario en SharedPreferences.
  // Usa una clave distinta para web y para movil/escritorio.
  Future<void> _cargarFotoGuardada() async {
    // El id permite que cada usuario tenga su propia foto guardada.
    final userId = widget.datosUsuario['id'];
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _fotoPath = null;
        _fotoBytes = null;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) { // kIsWeb: constante de Flutter que indica si la app está corriendo en navegador web
      // En web la foto se guardo como texto base64.
      final base64Str = prefs.getString('foto_perfil_web_$userId');
      if (!mounted) return;
      setState(() {
        // Si existe una foto, se convierte de base64 a bytes para mostrarla.
        _fotoBytes = base64Str != null ? base64Decode(base64Str) : null;
        _fotoPath = null;
      });
    } else {
      // En celular/escritorio se guarda la ruta del archivo.
      final fotoGuardada = prefs.getString('foto_perfil_$userId');
      // Antes de mostrarla se revisa que el archivo exista.
      final existe = fotoGuardada != null && File(fotoGuardada).existsSync();
      if (!mounted) return;
      setState(() {
        _fotoPath = existe ? fotoGuardada : null;
        _fotoBytes = null;
      });
    }
  }

  // Avatar por defecto cuando el usuario no tiene foto o la foto falla.
  Widget _avatarFallback() {
    return Container(
      color: const Color(0xFF00D4FF),
      child: const Icon(
        Icons.person,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  // Decide que imagen mostrar en el circulo del drawer.
  // Prioridad: foto web, foto local, foto del servidor y por ultimo icono default.
  Widget _avatarImagen() {
    // foto_url seria una imagen remota si algun dia viene desde el backend.
    final fotoUrl = widget.datosUsuario['foto_url'];

    // Caso web: se muestra desde bytes guardados.
    if (_fotoBytes != null) {
      return Image.memory(_fotoBytes!, fit: BoxFit.cover);
    }

    // Caso movil/escritorio: se muestra desde una ruta local.
    if (_fotoPath != null) {
      return Image.file(
        File(_fotoPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _avatarFallback(),
      );
    }

    // Caso servidor: se muestra una URL si existe en los datos del usuario.
    if (fotoUrl is String && fotoUrl.isNotEmpty) {
      return Image.network(
        fotoUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _avatarFallback(),
      );
    }

    // Si no hay ninguna foto disponible, se muestra el icono normal.
    return _avatarFallback();
  }

  @override
  Widget build(BuildContext context) {
    // Drawer es el panel lateral que se abre desde el menu hamburguesa.
    return Drawer(
      child: Container(
        color: const Color(0xFF1A1FC8),
        child: Column(
          children: [
            // Header del drawer: muestra foto, nombre y correo del usuario.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1FC8),
              ),
              child: Column(
                children: [
                  // Avatar circular del usuario.
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _avatarImagen(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.datosUsuario['nombre_completo'] ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.datosUsuario['email'] ?? 'usuario@utb.edu.co',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFADB5FF),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2D33D4), thickness: 1),
            // Opciones del menú
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.home_rounded,
                    title: 'Inicio',
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PantallaSeleccion(
                            token: widget.token,
                            datosUsuario: widget.datosUsuario,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.person_rounded,
                    title: 'Mi Perfil',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PantallaPerfil(
                            token: widget.token,
                            datosUsuario: widget.datosUsuario,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.school_rounded,
                    title: 'Mis Planes',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PantallaMisPlanes(token: widget.token),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Color(0xFF2D33D4), thickness: 1),
                  _buildMenuItem(
                    context,
                    icon: Icons.logout_rounded,
                    title: 'Cerrar sesión',
                    isDestructive: true,
                    onTap: () {
                      _confirmarCerrarSesion(context);
                    },
                  ),
                ],
              ),
            ),
            // Footer con versión
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'DuoProgram v1.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : const Color(0xFF00D4FF),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Cerrar drawer
        onTap();
      },
      hoverColor: const Color(0xFF2D33D4),
      splashColor: const Color(0xFF2D33D4),
    );
  }

  void _confirmarCerrarSesion(BuildContext context) {
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
            onPressed: () async {
              Navigator.pop(context);
              await SesionHelper.cerrarSesion(context);
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
}
