// ============================================================
//  pantalla_mis_planes.dart
//  Lista todos los planes guardados del usuario
// ============================================================

import 'package:flutter/material.dart';
import '../services/servicio_api.dart';
import '../utils/sesion_helper.dart';
import '../theme/colores.dart';
import 'pantalla_ver_plan.dart';
import '../theme/transiciones.dart';
import '../widgets/superficie.dart';

class PantallaMisPlanes extends StatefulWidget {
  final String token;

  const PantallaMisPlanes({super.key, required this.token});

  @override
  State<PantallaMisPlanes> createState() => _PantallaMisPlanesState();
}

class _PantallaMisPlanesState extends State<PantallaMisPlanes> {
  final ServicioApi _servicioApi = ServicioApi();
  List<dynamic> _planes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPlanes();
  }

  Future<void> _cargarPlanes() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final planes = await _servicioApi.obtenerMisPlanes(widget.token);
      // El usuario pudo navegar hacia atras mientras la peticion estaba en
      // vuelo; sin esta guarda setState revienta con "called after dispose".
      if (!mounted) return;
      setState(() {
        _planes = planes;
        _cargando = false;
      });
    } on SesionExpiradaException {
      if (mounted) await SesionHelper.manejarSesionExpirada(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _eliminarPlan(int planId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar plan'),
        content: const Text('¿Estás seguro de que deseas eliminar este plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colores.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _cargando = true);
      try {
        await _servicioApi.eliminarPlanGuardado(widget.token, planId);
        await _cargarPlanes();
        // Guarda tras los awaits: si el usuario salio de la pantalla no hay
        // ScaffoldMessenger al que pedirle el SnackBar.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan eliminado correctamente'),
            backgroundColor: Colores.exitoOscuro,
          ),
        );
      } on SesionExpiradaException {
        if (mounted) await SesionHelper.manejarSesionExpirada(context);
      } catch (e) {
        if (!mounted) return;
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colores.error,
          ),
        );
      }
    }
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return '';
    try {
      final date = DateTime.parse(fecha);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return fecha.split('T')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colores.fondoApp,
      appBar: AppBar(
        backgroundColor: Colores.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mis Planes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarPlanes,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colores.primario,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando tus planes...',
                    style: TextStyle(color: Colores.textoSecundario),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colores.error.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            size: 40,
                            color: Colores.error,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Error cargando planes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colores.textoTitulo,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colores.textoSecundario,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _cargarPlanes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colores.primario,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Reintentar',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _planes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colores.primario.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_open,
                              size: 50,
                              color: Colores.primario,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No hay planes guardados',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colores.textoTitulo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Genera un plan desde la pantalla principal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colores.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Volver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colores.primario,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarPlanes,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _planes.length,
                        itemBuilder: (context, index) {
                          final plan = _planes[index];
                          // Cascaron exterior del bisel. La sombra se tinta
                          // con el azul de marca en vez de negro: sobre un
                          // fondo con color, el negro deja un halo gris sucio.
                          return Revelar(
                            indice: index,
                            child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Superficies.brumaLavanda,
                              borderRadius: BorderRadius.circular(
                                  Superficies.radioTarjeta),
                              border: Border.all(
                                  color: Superficies.nieblaAzul
                                      .withValues(alpha: 0.6)),
                              boxShadow: Superficies.ambiente,
                            ),
                            // Nucleo interior con radio concentrico.
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                  Superficies.radioInterno(
                                      Superficies.radioTarjeta, 5)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                    Superficies.radioInterno(
                                        Superficies.radioTarjeta, 5)),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    RutaProfundidad(
                                      pagina: PantallaVerPlan(
                                        token: widget.token,
                                        planId: plan['id'],
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colores.primario.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.school_rounded,
                                              color: Colores.primario,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Titulo: "id. nombre" si tiene nombre personalizado,
                                                // o "id. PROG1 + PROG2" como default.
                                                Text(
                                                  plan['nombre'] != null && plan['nombre'].toString().trim().isNotEmpty
                                                      ? '${plan['id']}. ${plan['nombre']}'
                                                      : '${plan['id']}. ${plan['programa_principal']} + ${plan['programa_secundario'] ?? ''}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colores.textoTitulo,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colores.exito.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        'Promedio: ${plan['promedio']}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colores.exitoOscuro,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colores.primario.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        'Semestres: ${plan['semestres_cursados']}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colores.primario,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 14,
                                            color: Colores.textoTenue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatearFecha(plan['created_at']),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colores.textoTenue,
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                              color: Colores.error,
                                            ),
                                            onPressed: () => _eliminarPlan(plan['id']),
                                            tooltip: 'Eliminar',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}