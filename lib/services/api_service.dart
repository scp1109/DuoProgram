import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  //Para que funcione en edge: 'http://127.0.0.1:8000'
  //Para que funcione en el emulador: 'http://10.0.2.2:8000'

  static const String baseUrl = 'http://127.0.0.1:8000';

  // ============================================================
  // PROGRAMAS
  // ============================================================

  Future<List<Map<String, dynamic>>> getProgramas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/programas'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data.entries.map((entry) => {
          'codigo': entry.key,
          'nombre': entry.value['nombre'],
          'facultad': entry.value['facultad'],
          'total_creditos': entry.value['total_creditos'],
        }).toList();
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getProgramas: $e');
      rethrow;
    }
  }

  // Obtiene la malla completa de un programa desde la BD (materias, prereqs, electivas).
  // Reemplaza el acceso directo a programasDisponibles de datos_programa.dart.
  Future<Map<String, dynamic>> getProgramaDetalle(String codigo) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/programas/$codigo'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getProgramaDetalle: $e');
      rethrow;
    }
  }

  // ============================================================
  // AUTENTICACIÓN
  // ============================================================

  Future<Map<String, dynamic>> registro({
    required String nombreCompleto,
    required String email,
    required String password,
  }) async {
    try {
      final body = {
        'nombre_completo': nombreCompleto,
        'email': email,
        'password': password,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/auth/registro'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error en el registro');
      }
    } catch (e) {
      print('Error en registro: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final body = {
        'email': email,
        'password': password,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error en el inicio de sesión');
      }
    } catch (e) {
      print('Error en login: $e');
      rethrow;
    }
  }

  // ============================================================
  // PERFIL
  // ============================================================

  Future<Map<String, dynamic>> getPerfil(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/perfil'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener perfil');
    }
  }

  Future<void> actualizarPerfil(String token, {
    required String nombreCompleto,
    required String email,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/auth/perfil'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'nombre_completo': nombreCompleto,
        'email': email,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar perfil');
    }
  }

  Future<void> cambiarPassword(String token, {
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/cambiar-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Error al cambiar contraseña');
    }
  }

  // ============================================================
  // HISTORIAL
  // ============================================================

  Future<List<dynamic>> getHistorial(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/historial'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print('Error en getHistorial: $e');
      return [];
    }
  }

  // ============================================================
  // PLANES
  // ============================================================

  Future<Map<String, dynamic>> planificar({
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

      final response = await http.post(
        Uri.parse('$baseUrl/plan/planificar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en planificar: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getPlanesGuardados(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/planes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print('Error en getPlanesGuardados: $e');
      return [];
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
  final response = await http.post(
    Uri.parse('$baseUrl/plan/guardar-plan'),
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
  
  if (response.statusCode != 200) {
    throw Exception('Error al guardar plan: ${response.statusCode}');
  }
  
  return json.decode(response.body);
}

// Obtener todos los planes del usuario
Future<List<dynamic>> getMisPlanes(String token) async {
  final response = await http.get(
    Uri.parse('$baseUrl/plan/mis-planes'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['planes'];
  }
  return [];
}

// Obtener un plan específico por ID
Future<Map<String, dynamic>> getPlan(String token, int planId) async {
  final response = await http.get(
    Uri.parse('$baseUrl/plan/plan/$planId'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  }
  throw Exception('Error al obtener el plan');
}

// Eliminar un plan
Future<void> eliminarPlan(String token, int planId) async {
  final response = await http.delete(
    Uri.parse('$baseUrl/plan/plan/$planId'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode != 200) {
    throw Exception('Error al eliminar el plan');
  }
}

}