// ============================================================
//  plan_model.dart
//  Modelos para parsear la respuesta del API
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
      codigo: json['codigo'],
      nombre: json['nombre'],
      creditos: json['creditos'],
      origen: json['origen'],
      sirveParaAmbas: json['sirve_para_ambas'],
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
      numero: json['numero'],
      materias: (json['materias'] as List)
          .map((m) => MateriaPlan.fromJson(m))
          .toList(),
      totalCreditos: json['total_creditos'],
      esPrimero: json['es_primero'],
      esUltimo: json['es_ultimo'],
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

class PlanResponse {
  final List<SemestrePlan> semestres;
  final int totalSemestresFuturos;
  final String mensaje;

  PlanResponse({
    required this.semestres,
    required this.totalSemestresFuturos,
    required this.mensaje,
  });

  factory PlanResponse.fromJson(Map<String, dynamic> json) {
    return PlanResponse(
      semestres: (json['semestres'] as List)
          .map((s) => SemestrePlan.fromJson(s))
          .toList(),
      totalSemestresFuturos: json['total_semestres_futuros'],
      mensaje: json['mensaje'],
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