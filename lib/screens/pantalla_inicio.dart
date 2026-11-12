// ============================================================
//  pantalla_inicio.dart
//  Pantalla de inicio de sesión
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/servicio_api.dart';
import '../utils/sesion_helper.dart';
import '../config/claves_prefs.dart';
import '../theme/colores.dart';
import 'pantalla_registro.dart';
import 'pantalla_seleccion.dart';
import '../theme/transiciones.dart';
import '../widgets/superficie.dart';

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
    final token = prefs.getString(ClavesPrefs.token);
    if (token == null) {
      if (mounted) setState(() => _verificandoSesion = false);
      return;
    }

    try {
      final perfil = await _servicioApi.obtenerPerfil(token);
      await prefs.setString(ClavesPrefs.datosUsuario, jsonEncode(perfil));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        RutaRaiz(
          pagina: PantallaSeleccion(
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
      await prefs.setString(ClavesPrefs.token, token);
      await prefs.setString(ClavesPrefs.datosUsuario, jsonEncode(datosUsuario));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          RutaRaiz(
            pagina: PantallaSeleccion(
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
        backgroundColor: Colores.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoSesion) {
      return const Scaffold(
        backgroundColor: Colores.fondoApp,
        body: Center(
          child: CircularProgressIndicator(color: Colores.primario),
        ),
      );
    }

    return Scaffold(
      // Lavanda solida en las dos pantallas de acceso, para que
      // login y registro se lean como la misma familia.
      backgroundColor: Superficies.brumaLavanda,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              // Respiracion amplia: el aire alrededor del formulario es
              // parte del acabado, no espacio desperdiciado.
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // -- Marca ------------------------------------
                  Revelar(
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Superficies.nieblaAzul.withValues(alpha: 0.7)),
                        boxShadow: Superficies.ambiente,
                      ),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: Superficies.brumaLavanda,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          'assets/images/logo_utb.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.school_rounded,
                                  size: 44, color: Colores.primario),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Revelar(
                    indice: 1,
                    child: Cejilla('UTB · Doble programa'),
                  ),

                  const SizedBox(height: 14),

                  const Revelar(
                    indice: 2,
                    child: Text(
                      'DuoProgram',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        // Tracking negativo: en titulares grandes el espaciado
                        // por defecto se ve suelto y abarata el conjunto.
                        letterSpacing: -1.4,
                        height: 1.05,
                        color: Colores.textoTitulo,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Revelar(
                    indice: 3,
                    child: Text(
                      'Planifica tu doble programa académico',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Colores.textoSecundario,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // -- Formulario en bisel doble ----------------
                  Revelar(
                    indice: 4,
                    child: TarjetaBisel(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                      child: Column(
                        children: [
                          TextField(
                            controller: _correoController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo institucional',
                              hintText: 'ejemplo@utb.edu.co',
                              prefixIcon: Icon(Icons.alternate_email_rounded,
                                  size: 20, color: Colores.primario),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _contrasenaController,
                            obscureText: _ocultarContrasena,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline_rounded,
                                  size: 20, color: Colores.primario),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultarContrasena
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: Colores.textoTenue,
                                ),
                                onPressed: () => setState(
                                    () => _ocultarContrasena = !_ocultarContrasena),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _mostrarSnackbar(
                                  'Función en desarrollo. Contacta a soporte.'),
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                    color: Colores.primario,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: BotonIsla(
                              texto: 'Iniciar sesión',
                              cargando: _cargando,
                              onTap: _cargando ? null : _iniciarSesion,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Revelar(
                    indice: 5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes cuenta?',
                          style: TextStyle(
                              color: Colores.textoSecundario, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            RutaProfundidad(pagina: const PantallaRegistro()),
                          ),
                          child: const Text(
                            'Regístrate',
                            style: TextStyle(
                              color: Colores.primario,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}