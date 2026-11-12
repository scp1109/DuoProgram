// ============================================================
//  pantalla_cambiar_contrasena.dart
//  Permite al usuario cambiar su contrasena desde Mi Perfil
// ============================================================
import 'package:flutter/material.dart';
import '../services/servicio_api.dart';
import '../utils/sesion_helper.dart';
import '../theme/colores.dart';
import '../widgets/superficie.dart';

class PantallaCambiarContrasena extends StatefulWidget {
  final String token;

  const PantallaCambiarContrasena({super.key, required this.token});

  @override
  State<PantallaCambiarContrasena> createState() => _PantallaCambiarContrasenaState();
}

class _PantallaCambiarContrasenaState extends State<PantallaCambiarContrasena> {
  final _formKey = GlobalKey<FormState>();
  final _contrasenaActualController = TextEditingController();
  final _contrasenaNuevaController = TextEditingController();
  final _confirmarContrasenaController = TextEditingController();
  final ServicioApi _servicioApi = ServicioApi();
  bool _cargando = false;
  bool _ocultarActual = true;
  bool _ocultarNueva = true;
  bool _ocultarConfirmar = true;

  @override
  void dispose() {
    _contrasenaActualController.dispose();
    _contrasenaNuevaController.dispose();
    _confirmarContrasenaController.dispose();
    super.dispose();
  }

  Future<void> _cambiarContrasena() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      await _servicioApi.cambiarContrasena(
        widget.token,
        contrasenaActual: _contrasenaActualController.text,
        contrasenaNueva: _contrasenaNuevaController.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada correctamente')),
        );
        Navigator.pop(context, true);
      }
    } on SesionExpiradaException {
      if (mounted) await SesionHelper.manejarSesionExpirada(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colores.fondoApp,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colores.primario,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Cambiar contraseña',
            style: TextStyle(
                color: Colores.textoTitulo,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: -0.3)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Revelar(child: Cejilla('Seguridad')),
                const SizedBox(height: 12),
                const Revelar(
                  indice: 1,
                  child: Text(
                    'Actualiza tu contraseña',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                      height: 1.1,
                      color: Colores.textoTitulo,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Revelar(
                  indice: 2,
                  child: Text(
                    'La nueva contraseña debe tener al menos 8 caracteres.',
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colores.textoSecundario),
                  ),
                ),
                const SizedBox(height: 28),
                Revelar(
                  indice: 3,
                  child: TarjetaBisel(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _contrasenaActualController,
                          obscureText: _ocultarActual,
                          decoration: InputDecoration(
                            labelText: 'Contraseña actual',
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                size: 20, color: Colores.primario),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _ocultarActual
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: Colores.textoTenue,
                              ),
                              onPressed: () =>
                                  setState(() => _ocultarActual = !_ocultarActual),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu contraseña actual';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _contrasenaNuevaController,
                          obscureText: _ocultarNueva,
                          decoration: InputDecoration(
                            labelText: 'Contraseña nueva',
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                size: 20, color: Colores.primario),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _ocultarNueva
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: Colores.textoTenue,
                              ),
                              onPressed: () =>
                                  setState(() => _ocultarNueva = !_ocultarNueva),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa una nueva contraseña';
                            }
                            if (value.length < 8) {
                              return 'La contraseña debe tener al menos 8 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmarContrasenaController,
                          obscureText: _ocultarConfirmar,
                          decoration: InputDecoration(
                            labelText: 'Repetir contraseña',
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                size: 20, color: Colores.primario),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _ocultarConfirmar
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: Colores.textoTenue,
                              ),
                              onPressed: () =>
                                  setState(() => _ocultarConfirmar = !_ocultarConfirmar),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirma tu nueva contraseña';
                            }
                            if (value != _contrasenaNuevaController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Revelar(
                  indice: 4,
                  child: SizedBox(
                    width: double.infinity,
                    child: BotonIsla(
                      texto: 'Cambiar contraseña',
                      icono: Icons.lock_reset_rounded,
                      cargando: _cargando,
                      onTap: _cargando ? null : _cambiarContrasena,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}