// ============================================================
//  modelo_plan.dart
//  Modelos para parsear la respuesta del API
//
//  Los fromJson usan casts explicitos con valor por defecto en vez
//  de leer el campo pelado (json['codigo']). Antes, si el backend
//  cambiaba el nombre de un campo o devolvia null, la app moria en
//  runtime con un TypeError ilegible tipo "Null is not a subtype of
//  String" sin decir cual materia ni cual campo. Con los defaults la
//  pantalla se dibuja igual y el dato faltante se ve vacio o en cero,
//  que es mucho mas facil de diagnosticar.
// ============================================================

class MateriaPlan {
  final String codigo;
  final String nombre;
  final int creditos;
  final String origen;
  final bool sirveParaAmbas;

  MateriaPlan({
    required this.codigo,
    required this.nombre,
    required this.creditos,
    required this.origen,
    required this.sirveParaAmbas,
  });

  factory MateriaPlan.fromJson(Map<String, dynamic> json) {
    return MateriaPlan(
      codigo: json['codigo'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      // Se castea a num y no a int porque JSON puede traer 3.0 en vez
      // de 3, y en ese caso un `as int` reventaria.
      creditos: (json['creditos'] as num?)?.toInt() ?? 0,
      origen: json['origen'] as String? ?? '',
      sirveParaAmbas: json['sirve_para_ambas'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'nombre': nombre,
      'creditos': creditos,
      'origen': origen,
      'sirve_para_ambas': sirveParaAmbas,
    };
  }
}

// Estructura de las cards

class SemestrePlan {
  final int numero;
  final List<MateriaPlan> materias;
  final int totalCreditos;
  final bool esPrimero;
  final bool esUltimo;

  SemestrePlan({
    required this.numero,
    required this.materias,
    required this.totalCreditos,
    required this.esPrimero,
    required this.esUltimo,
  });

  factory SemestrePlan.fromJson(Map<String, dynamic> json) {
    return SemestrePlan(
      numero: (json['numero'] as num?)?.toInt() ?? 0,
      // Si 'materias' viene null se usa lista vacia: un semestre sin
      // materias se muestra vacio, pero no tumba toda la pantalla.
      materias: (json['materias'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((m) => MateriaPlan.fromJson(m))
          .toList(),
      totalCreditos: (json['total_creditos'] as num?)?.toInt() ?? 0,
      esPrimero: json['es_primero'] as bool? ?? false,
      esUltimo: json['es_ultimo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'materias': materias.map((m) => m.toJson()).toList(),
      'total_creditos': totalCreditos,
      'es_primero': esPrimero,
      'es_ultimo': esUltimo,
    };
  }
}

class RespuestaPlan {
  final List<SemestrePlan> semestres;
  final int totalSemestresFuturos;
  final String mensaje;

  RespuestaPlan({
    required this.semestres,
    required this.totalSemestresFuturos,
    required this.mensaje,
  });

  factory RespuestaPlan.fromJson(Map<String, dynamic> json) {
    return RespuestaPlan(
      semestres: (json['semestres'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((s) => SemestrePlan.fromJson(s))
          .toList(),
      totalSemestresFuturos:
          (json['total_semestres_futuros'] as num?)?.toInt() ?? 0,
      mensaje: json['mensaje'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'semestres': semestres.map((s) => s.toJson()).toList(),
      'total_semestres_futuros': totalSemestresFuturos,
      'mensaje': mensaje,
    };
  }
}
