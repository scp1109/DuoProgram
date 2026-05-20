import 'dart:async'; // necesario para TimeoutException
import 'dart:convert';
import 'package:http/http.dart' as http;

// Excepcion especial para token expirado (401).
// Se lanza desde cualquier endpoint que requiera autenticacion.
class SesionExpiradaException implements Exception {
  const SesionExpiradaException();
  @override
  String toString() => 'La sesion ha expirado. Por favor recarga la pagina para continuar.';
}

class ServicioApi {
  // URL de la API en produccion (Railway)
  static const String urlBase = 'https://web-production-52f53.up.railway.app';

  // ============================================================
  // PROGRAMAS
  // ============================================================

  Future<List<Map<String, dynamic>>> obtenerProgramas() async {
    try {
      final respuesta = await http.get(
        Uri.parse('$urlBase/programas'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (respuesta.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(respuesta.body);
        return data.entries.map((entry) => {
          'codigo': entry.key,
          'nombre': entry.value['nombre'],
          'facultad': entry.value['facultad'],
          'total_creditos': entry.value['total_creditos'],
          'total_semestres': entry.value['total_semestres'],
        }).toList();
      } else {
        throw Exception('Error HTTP: ${respuesta.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerProgramas: $e');
      rethrow;
    }
  }

  // Obtiene la malla completa de un programa desde la BD (materias, prereqs, electivas).
  // Reemplaza el acceso directo a programasDisponibles de datos_programa.dart.
  Future<Map<String, dynamic>> obtenerDetallePrograma(String codigo) async {
    try {
      final respuesta = await http.get(
        Uri.parse('$urlBase/programas/$codigo'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (respuesta.statusCode == 200) {
        return json.decode(respuesta.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error HTTP: ${respuesta.statusCode}');
      }
    } catch (e) {
      print('Error en obtenerDetallePrograma: $e');
      rethrow;
    }
  }

  // ============================================================
  // AUTENTICACIÓN
  // ============================================================

  Future<Map<String, dynamic>> registro({
    required String nombreCompleto,
    required String correo,
    required String contrasena,
  }) async {
    try {
      final body = {
        'nombre_completo': nombreCompleto,
        'email': correo,
        'password': contrasena,
      };

      final respuesta = await http.post(
        Uri.parse('$urlBase/auth/registro'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (respuesta.statusCode == 200) {
        return json.decode(respuesta.body);
      } else {
        final error = json.decode(respuesta.body);
        throw Exception(error['detail'] ?? 'Error en el registro');
      }
    } catch (e) {
      print('Error en registro: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    try {
      final body = {
        'email': correo,
        'password': contrasena,
      };

      final respuesta = await http.post(
        Uri.parse('$urlBase/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (respuesta.statusCode == 200) {
        return json.decode(respuesta.body);
      } else {
        final error = json.decode(respuesta.body);
        throw Exception(error['detail'] ?? 'Error en el inicio de sesión');
      }
    } catch (e) {
      print('Error en iniciarSesion: $e');
      rethrow;
    }
  }

  // ============================================================
  // PERFIL
  // ============================================================

  Future<Map<String, dynamic>> obtenerPerfil(String token) async {
    final respuesta = await http.get(
      Uri.parse('$urlBase/auth/perfil'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (respuesta.statusCode == 200) {
      return json.decode(respuesta.body);
    } else if (respuesta.statusCode == 401) {
      throw const SesionExpiradaException();
    } else {
      throw Exception('Error al obtener perfil');
    }
  }

  Future<void> actualizarPerfil(String token, {
    required String nombreCompleto,
    required String correo,
  }) async {
    final respuesta = await http.put(
      Uri.parse('$urlBase/auth/perfil'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'nombre_completo': nombreCompleto,
        'email': correo,
      }),
    );
    
    if (respuesta.statusCode == 401) {
      throw const SesionExpiradaException();
    } else if (respuesta.statusCode != 200) {
      throw Exception('Error al actualizar perfil');
    }
  }

  Future<void> cambiarContrasena(String token, {
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    final respuesta = await http.post(
      Uri.parse('$urlBase/auth/cambiar-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'old_password': contrasenaActual,
        'new_password': contrasenaNueva,
      }),
    );

    if (respuesta.statusCode == 401) {
      throw const SesionExpiradaException();
    }
    if (respuesta.statusCode != 200) {
      try {
        final error = json.decode(respuesta.body);
        throw Exception(error['detail'] ?? 'Error al cambiar contrasena');
      } catch (e) {
        if (e is SesionExpiradaException) rethrow;
        throw Exception('Error al cambiar contrasena');
      }
    }
  }

  // ============================================================
  // HISTORIAL
  // ============================================================

  Future<List<dynamic>> obtenerHistorial(String token) async {
    try {
      final respuesta = await http.get(
        Uri.parse('$urlBase/auth/historial'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (respuesta.statusCode == 200) {
        return json.decode(respuesta.body);
      } else if (respuesta.statusCode == 401) {
        throw const SesionExpiradaException();
      } else {
        return [];
      }
    } on SesionExpiradaException {
      rethrow;
    } catch (e) {
      print('Error en obtenerHistorial: $e');
      return [];
    }
  }

  // ============================================================
  // PLANES
  // ============================================================

  Future<Map<String, dynamic>> planificar({
    required String token,
    required String programaPrincipal,
    String? programaSecundario,
    required List<String> aprobadas,
    required List<int> nivelesInglesHomologados,
    required double promedio,
    required int semestresCursados,
    required List<Map<String, String>> homologacionesExternas,
    required bool practicaUnica,
  }) async {
    try {
      final body = {
        'codigo_programa_principal': programaPrincipal,
        'codigo_programa_secundario': programaSecundario,
        'aprobadas': aprobadas,
        'niveles_ingles_homologados': nivelesInglesHomologados,
        'promedio': promedio,
        'semestres_cursados': semestresCursados,
        'homologaciones_externas': homologacionesExternas,
        'practica_unica': practicaUnica,
      };

      final respuesta = await http.post(
        Uri.parse('$urlBase/plan/planificar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (respuesta.statusCode == 200) {
        return json.decode(respuesta.body);
      } else if (respuesta.statusCode == 401) {
        throw const SesionExpiradaException();
      } else {
        throw Exception('Error HTTP: ${respuesta.statusCode}');
      }
    } on TimeoutException {
      throw Exception(
        'El servidor no respondio a tiempo (>60s). '
        'Verifica que el backend esta corriendo en $urlBase.',
      );
    } on SesionExpiradaException {
      rethrow;
    } catch (e) {
      print('Error en planificar: $e');
      rethrow;
    }
  }

// ============================================================
// MÉTODOS PARA PLANES GUARDADOS
// ============================================================

  // Guardar plan generado
  Future<Map<String, dynamic>> guardarPlan({
    required String token,
    String? nombre,
    required String programaPrincipal,
    String? programaSecundario,
    required int semestresCursados,
    required double promedio,
    required List<String> materiasAprobadas,
    required List<Map<String, String>> homologaciones,
    required Map<String, dynamic> planGenerado,
  }) async {
    final respuesta = await http.post(
      Uri.parse('$urlBase/plan/guardar-plan'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'nombre': nombre,
        'programa_principal': programaPrincipal,
        'programa_secundario': programaSecundario,
        'semestres_cursados': semestresCursados,
        'promedio': promedio,
        'materias_aprobadas': materiasAprobadas,
        'homologaciones': homologaciones,
        'plan_generado': planGenerado,
      }),
    );
    
    if (respuesta.statusCode == 401) {
      throw const SesionExpiradaException();
    } else if (respuesta.statusCode != 200) {
      throw Exception('Error al guardar plan: ${respuesta.statusCode}');
    }
    
    return json.decode(respuesta.body);
  }

  // Obtener todos los planes del usuario
  Future<List<dynamic>> obtenerMisPlanes(String token) async {
    final respuesta = await http.get(
      Uri.parse('$urlBase/plan/mis-planes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (respuesta.statusCode == 200) {
      final data = json.decode(respuesta.body);
      return data['planes'];
    } else if (respuesta.statusCode == 401) {
      throw const SesionExpiradaException();
    }
    return [];
  }

  // Obtener un plan específico por ID
  Future<Map<String, dynamic>> obtenerPlan(String token, int planId) async {
    final respuesta = await http.get(
      Uri.parse('$urlBase/plan/plan/$planId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (respuesta.statusCode == 200) {
      return json.decode(respuesta.body);
    } else if (respuesta.statusCode == 401) {
      throw const SesionExpiradaException();
    }
    throw Exception('Error al obtener el plan');
  }

  // Eliminar un plan
  Future<void> eliminarPlanGuardado(String token, int planId) async {
    final respuesta = await http.delete(
      Uri.parse('$urlBase/plan/plan/$planId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (respuesta.statusCode == 401) {
      throw const SesionExpiradaException();
    } else if (respuesta.statusCode != 200) {
      throw Exception('Error al eliminar el plan');
    }
  }
}
