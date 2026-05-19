// ============================================================
//  pantalla_registro.dart
//  Pantalla de registro de nuevo usuario
// ============================================================

import 'package:flutter/material.dart';
import '../services/servicio_api.dart';
import 'pantalla_seleccion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';  // Para jsonEncode

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmarContrasenaController = TextEditingController();
  
  final ServicioApi _servicioApi = ServicioApi();
  
  bool _ocultarContrasena = true;
  bool _ocultarConfirmarContrasena = true;
  bool _aceptaTerminos = false;
  bool _cargando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _confirmarContrasenaController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
  if (!_formKey.currentState!.validate()) return;
  if (!_aceptaTerminos) {
    _mostrarSnackbar('Debes aceptar los términos y condiciones', isError: true);
    return;
  }

  setState(() => _cargando = true);

  try {
    final resultado = await _servicioApi.registro(
      nombreCompleto: _nombreController.text.trim(),
      correo: _correoController.text.trim(),
      contrasena: _contrasenaController.text,
    );

    final token = resultado['access_token'];
    final datosUsuario = resultado['user'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user_data', jsonEncode(datosUsuario));

    if (mounted) {
      _mostrarSnackbar('Registro exitoso. ¡Bienvenido!');
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
      _mostrarSnackbar(' Error: ${e.toString().replaceFirst('Exception: ', '')}', isError: true);
    }
  } finally {
    if (mounted) setState(() => _cargando = false);
  }
}

  void _mostrarSnackbar(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1FC8)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crear cuenta',
          style: TextStyle(
            color: Color(0xFF1A1FC8),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Image.asset(
                    'assets/images/logo_utb.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1FC8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),

                const Text(
                  'Regístrate',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1FC8),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Completa tus datos para comenzar',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 32),

                // Nombre completo
                TextFormField(
                  controller: _nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    hintText: 'Juan Pérez',
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1A1FC8)),
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingresa tu nombre completo';
                    if (value.length < 3) return 'Nombre muy corto';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Correo institucional
                TextFormField(
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingresa tu correo';
                    if (!value.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contraseña
                TextFormField(
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingresa una contraseña';
                    if (value.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirmar contraseña
                TextFormField(
                  controller: _confirmarContrasenaController,
                  obscureText: _ocultarConfirmarContrasena,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1A1FC8)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _ocultarConfirmarContrasena ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF9CA3AF),
                      ),
                      onPressed: () => setState(() => _ocultarConfirmarContrasena = !_ocultarConfirmarContrasena),
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Confirma tu contraseña';
                    if (value != _contrasenaController.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Términos y condiciones
                Row(
                  children: [
                    Checkbox(
                      value: _aceptaTerminos,
                      onChanged: (value) => setState(() => _aceptaTerminos = value ?? false),
                      activeColor: const Color(0xFF1A1FC8),
                      checkColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _aceptaTerminos = !_aceptaTerminos),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                            children: [
                              const TextSpan(text: 'Acepto los '),
                              TextSpan(
                                text: 'términos y condiciones',
                                style: const TextStyle(
                                  color: Color(0xFF1A1FC8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const TextSpan(text: ' y la '),
                              TextSpan(
                                text: 'política de privacidad',
                                style: const TextStyle(
                                  color: Color(0xFF1A1FC8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Botón registrar
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _registrar,
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
                        : const Text('Registrarse', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),

                // Enlace a iniciar sesión
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes cuenta?',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Iniciar sesión',
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
      ),
    );
  }
}