// ============================================================
//  pantalla_inicio.dart
//  Pantalla de inicio de sesión
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/servicio_api.dart';
import '../utils/sesion_helper.dart';
import 'pantalla_registro.dart';
import 'pantalla_seleccion.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  final ServicioApi _servicioApi = ServicioApi();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  bool _ocultarContrasena = true;
  bool _cargando = false;
  bool _verificandoSesion = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _intentarRestaurarSesion());
  }

  Future<void> _intentarRestaurarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) setState(() => _verificandoSesion = false);
      return;
    }

    try {
      final perfil = await _servicioApi.obtenerPerfil(token);
      await prefs.setString('user_data', jsonEncode(perfil));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaSeleccion(
            token: token,
            datosUsuario: perfil,
          ),
        ),
      );
    } on SesionExpiradaException {
      await SesionHelper.limpiarCredenciales();
      if (mounted) setState(() => _verificandoSesion = false);
    } catch (_) {
      if (mounted) setState(() => _verificandoSesion = false);
    }
  }

  @override
  void dispose() {
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (_correoController.text.isEmpty || _contrasenaController.text.isEmpty) {
      _mostrarSnackbar('Por favor, completa todos los campos');
      return;
    }

    setState(() => _cargando = true);

    try {
      final resultado = await _servicioApi.iniciarSesion(
        correo: _correoController.text.trim(),
        contrasena: _contrasenaController.text,
      );

      final token = resultado['access_token'];
      final datosUsuario = resultado['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('user_data', jsonEncode(datosUsuario));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaSeleccion(
              token: token,
              datosUsuario: datosUsuario,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackbar('Error: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarSnackbar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoSesion) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F2FF),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A1FC8)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              Image.asset(
                'assets/images/logo_utb.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    child: const Icon(
                      Icons.school_rounded,
                      size: 60,
                      color: Color(0xFF1A1FC8),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              const Text(
                'DuoProgram',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1FC8),
                ),
              ),
              
              const SizedBox(height: 6),
              
              const Text(
                'Planifica tu doble programa académico',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 50),
              
              TextField(
                controller: _correoController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo institucional',
                  hintText: 'ejemplo@utb.edu.co',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1A1FC8)),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1A1FC8), width: 2),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextField(
                controller: _contrasenaController,
                obscureText: _ocultarContrasena,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1A1FC8)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _ocultarContrasena ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF9CA3AF),
                    ),
                    onPressed: () => setState(() => _ocultarContrasena = !_ocultarContrasena),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1A1FC8), width: 2),
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    _mostrarSnackbar('Función en desarrollo. Contacta a soporte.');
                  },
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(color: Color(0xFF1A1FC8)),
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1FC8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _cargando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Iniciar sesión', style: TextStyle(fontSize: 16)),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'o',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿No tienes cuenta?',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PantallaRegistro()),
                    ),
                    child: const Text(
                      'Regístrate',
                      style: TextStyle(
                        color: Color(0xFF1A1FC8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}