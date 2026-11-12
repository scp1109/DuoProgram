// ============================================================
//  pantalla_registro.dart
//  Pantalla de registro de nuevo usuario
// ============================================================

import 'package:flutter/material.dart';
import '../services/servicio_api.dart';
import '../config/claves_prefs.dart';
import '../theme/colores.dart';
import 'pantalla_seleccion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/transiciones.dart';
import '../widgets/superficie.dart';
import '../theme/movimiento.dart';
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
    await prefs.setString(ClavesPrefs.token, token);
    await prefs.setString(ClavesPrefs.datosUsuario, jsonEncode(datosUsuario));

    if (mounted) {
      _mostrarSnackbar('Registro exitoso. ¡Bienvenido!');
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
        backgroundColor: isError ? Colores.error : Colores.exitoOscuro,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Lavanda solida en las dos pantallas de acceso, para que
      // login y registro se lean como la misma familia.
      backgroundColor: Superficies.brumaLavanda,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colores.primario),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Revelar(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Superficies.nieblaAzul
                                  .withValues(alpha: 0.7)),
                          boxShadow: Superficies.ambiente,
                        ),
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: const BoxDecoration(
                            color: Superficies.brumaLavanda,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/images/logo_utb.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person_add_rounded,
                                    size: 34, color: Colores.primario),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),
                    const Revelar(indice: 1, child: Cejilla('Nueva cuenta')),
                    const SizedBox(height: 12),

                    const Revelar(
                      indice: 2,
                      child: Text(
                        'Regístrate',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.1,
                          height: 1.05,
                          color: Colores.textoTitulo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Revelar(
                      indice: 3,
                      child: Text(
                        'Completa tus datos para comenzar',
                        style: TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            color: Colores.textoSecundario),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Los campos ya no repiten bordes: los hereda del tema.
                    Revelar(
                      indice: 4,
                      child: TarjetaBisel(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nombreController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre completo',
                                hintText: 'Juan Pérez',
                                prefixIcon: Icon(Icons.person_outline_rounded,
                                    size: 20, color: Colores.primario),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa tu nombre completo';
                                }
                                if (value.length < 3) return 'Nombre muy corto';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _correoController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Correo institucional',
                                hintText: 'ejemplo@utb.edu.co',
                                prefixIcon: Icon(Icons.alternate_email_rounded,
                                    size: 20, color: Colores.primario),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa tu correo';
                                }
                                if (!value.contains('@')) {
                                  return 'Correo inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _contrasenaController,
                              obscureText: _ocultarContrasena,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: Colores.primario),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _ocultarContrasena
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: Colores.textoTenue,
                                  ),
                                  onPressed: () => setState(() =>
                                      _ocultarContrasena = !_ocultarContrasena),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa una contraseña';
                                }
                                if (value.length < 6) {
                                  return 'La contraseña debe tener al menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmarContrasenaController,
                              obscureText: _ocultarConfirmarContrasena,
                              decoration: InputDecoration(
                                // 'Repetir' y no 'Confirmar': con icono a
                                // ambos lados no hay ancho para la etiqueta
                                // larga y se cortaba en pantallas de 375px.
                                labelText: 'Repetir contraseña',
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: Colores.primario),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _ocultarConfirmarContrasena
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: Colores.textoTenue,
                                  ),
                                  onPressed: () => setState(() =>
                                      _ocultarConfirmarContrasena =
                                          !_ocultarConfirmarContrasena),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Confirma tu contraseña';
                                }
                                if (value != _contrasenaController.text) {
                                  return 'Las contraseñas no coinciden';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Los terminos van en su propio bloque tocable entero,
                    // no solo la casilla de 24px.
                    Revelar(
                      indice: 5,
                      child: Presionable(
                        onTap: () => setState(
                            () => _aceptaTerminos = !_aceptaTerminos),
                        escala: 0.99,
                        child: AnimatedContainer(
                          duration: Movimiento.corta,
                          curve: Movimiento.principal,
                          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                          decoration: BoxDecoration(
                            color: _aceptaTerminos
                                ? Colores.primario.withValues(alpha: 0.07)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(
                                Superficies.radioInterior),
                            border: Border.all(
                              color: _aceptaTerminos
                                  ? Colores.primario.withValues(alpha: 0.35)
                                  : Superficies.nieblaAzul,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _aceptaTerminos,
                                onChanged: (value) => setState(
                                    () => _aceptaTerminos = value ?? false),
                                activeColor: Colores.primario,
                                checkColor: Colors.white,
                                side: const BorderSide(
                                    color: Colores.borde, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              const Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: Colores.textoSecundario),
                                    children: [
                                      TextSpan(text: 'Acepto los '),
                                      TextSpan(
                                        text: 'términos y condiciones',
                                        style: TextStyle(
                                            color: Colores.primario,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      TextSpan(text: ' y la '),
                                      TextSpan(
                                        text: 'política de privacidad',
                                        style: TextStyle(
                                            color: Colores.primario,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    Revelar(
                      indice: 6,
                      child: SizedBox(
                        width: double.infinity,
                        child: BotonIsla(
                          texto: 'Registrarse',
                          cargando: _cargando,
                          onTap: _cargando ? null : _registrar,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Revelar(
                      indice: 7,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '¿Ya tienes cuenta?',
                            style: TextStyle(
                                color: Colores.textoSecundario, fontSize: 14),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Iniciar sesión',
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
          ),
        ],
      ),
    );
  }
}