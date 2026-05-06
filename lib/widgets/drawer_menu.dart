// ============================================================
//  widgets/drawer_menu.dart
//  Menú lateral disponible en toda la app
// ============================================================

import 'package:flutter/material.dart';
import '../screens/pantalla_perfil.dart';
import '../screens/pantalla_mis_planes.dart';
import '../screens/pantalla_seleccion.dart';
import '../screens/pantalla_inicio.dart';

class DrawerMenu extends StatelessWidget {
  final String token;
  final Map<String, dynamic> userData;

  const DrawerMenu({
    super.key,
    required this.token,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFF1A1FC8),
        child: Column(
          children: [
            // Header del drawer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1FC8),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: userData['foto_url'] != null
                          ? Image.network(
                              userData['foto_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFF00D4FF),
                                  child: const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: const Color(0xFF00D4FF),
                              child: const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userData['nombre_completo'] ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userData['email'] ?? 'usuario@utb.edu.co',
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
                            token: token,
                            userData: userData,
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
                            token: token,
                            userData: userData,
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
                          builder: (_) => PantallaMisPlanes(token: token),
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
}