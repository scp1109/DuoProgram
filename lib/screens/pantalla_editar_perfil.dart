import 'package:flutter/material.dart';
import '../services/servicio_api.dart';
import '../utils/sesion_helper.dart';
import '../theme/colores.dart';
import '../widgets/superficie.dart';

class PantallaEditarPerfil extends StatefulWidget {
  final String token;
  final Map<String, dynamic> datosUsuario;

  const PantallaEditarPerfil({
    super.key,
    required this.token,
    required this.datosUsuario,
  });

  @override
  State<PantallaEditarPerfil> createState() => _PantallaEditarPerfilState();
}

class _PantallaEditarPerfilState extends State<PantallaEditarPerfil> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final ServicioApi _servicioApi = ServicioApi();
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _nombreController.text = widget.datosUsuario['nombre_completo'] ?? '';
    _correoController.text = widget.datosUsuario['email'] ?? '';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      await _servicioApi.actualizarPerfil(
        widget.token,
        nombreCompleto: _nombreController.text.trim(),
        correo: _correoController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
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
        title: const Text('Editar perfil',
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
                const Revelar(child: Cejilla('Tus datos')),
                const SizedBox(height: 12),
                const Revelar(
                  indice: 1,
                  child: Text(
                    'Actualiza tu información',
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
                    'Estos datos son los que aparecen en tus planes guardados.',
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
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline_rounded,
                                size: 20, color: Colores.primario),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _correoController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
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
                      texto: 'Guardar cambios',
                      icono: Icons.check_rounded,
                      cargando: _cargando,
                      onTap: _cargando ? null : _guardarCambios,
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