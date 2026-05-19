// ============================================================
//  pantalla_cambiar_contrasena.dart
//  Permite al usuario cambiar su contrasena desde Mi Perfil
// ============================================================
import 'package:flutter/material.dart';
import '../services/servicio_api.dart';
import '../utils/sesion_helper.dart';

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
      backgroundColor: const Color(0xFFF0F2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1FC8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Cambiar Contraseña'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _contrasenaActualController,
                      obscureText: _ocultarActual,
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_ocultarActual ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _ocultarActual = !_ocultarActual),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu contraseña actual';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contrasenaNuevaController,
                      obscureText: _ocultarNueva,
                      decoration: InputDecoration(
                        labelText: 'Contraseña nueva',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_ocultarNueva ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _ocultarNueva = !_ocultarNueva),
                        ),
                        border: const OutlineInputBorder(),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmarContrasenaController,
                      obscureText: _ocultarConfirmar,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nueva contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_ocultarConfirmar ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _ocultarConfirmar = !_ocultarConfirmar),
                        ),
                        border: const OutlineInputBorder(),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _cambiarContrasena,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1FC8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _cargando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Cambiar contraseña', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}