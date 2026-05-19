// ============================================================
//  datos_programa.dart
//  Mallas curriculares UTB — Malla 201910
// ============================================================


// ─── Homologaciones externas ─────────────────────────────────
class HomologacionExterna {
  // Codigo de la materia que el estudiante quiere marcar como homologada.
  final String codigoMateria;

  // Nombre del programa o lugar desde donde se homologa esa materia.
  final String nombrePrograma;

  const HomologacionExterna({
    required this.codigoMateria,
    required this.nombrePrograma,
  });
}

// ─── Códigos de las materias de inglés ──────────────────────
final List<String> codigosIngles = [
  // La posicion en la lista representa el nivel de ingles.
  // Ejemplo: posicion 0 = nivel 1, posicion 1 = nivel 2, etc.
  "CHUL_LE1A",
  "CHUL_LE2A",
  "CHUL_LE3A",
  "CHUL_LE4A",
  "CHUL_LE5A",
];

// ── Modelo de Materia ────────────────────────────────────────
class Materia {
  // Codigo unico de la materia, por ejemplo CBAS_M01A.
  final String codigo;

  // Nombre que se muestra en pantalla.
  final String nombre;

  // Cantidad de creditos academicos de la materia.
  final int creditos;

  // Nivel o semestre sugerido dentro de la malla.
  final int nivel;

  // Lista de codigos de materias que deben aprobarse antes.
  final List<String> prerrequisitos;

  const Materia({
    required this.codigo,
    required this.nombre,
    required this.creditos,
    required this.nivel,
    this.prerrequisitos = const [],
  });

  // Convierte una materia que viene del backend en un objeto Materia de Dart.
  // Esto se usa cuando la app recibe la malla desde la BD por medio de la API.
  factory Materia.fromJson(Map<String, dynamic> json) {
    return Materia(
      codigo:         json['codigo']  as String,
      nombre:         json['nombre']  as String,
      creditos:       json['creditos'] as int,
      nivel:          json['nivel']    as int,
      prerrequisitos: List<String>.from(json['prerrequisitos'] ?? []),
    );
  }
}


// ── Grupo de electivas (slot con varias opciones) ────────────
// Un GrupoElectiva representa un slot en la malla (ej. "Electiva
// Complementaria I") que el estudiante debe cubrir eligiendo
// UNA de las opciones listadas.
class GrupoElectiva {
  // Codigo del espacio de electiva en la malla.
  final String slotCodigo;

  // Nombre del espacio de electiva que se muestra al usuario.
  final String slotNombre;

  // Materias que pueden servir para cubrir este espacio de electiva.
  final List<Materia> opciones;

  const GrupoElectiva({
    required this.slotCodigo,
    required this.slotNombre,
    required this.opciones,
  });

  // Convierte los grupos de electivas que vienen del backend.
  // El backend puede mandar un grupo con varios slots, entonces aqui se crea
  // un GrupoElectiva por cada slot para que la app pueda mostrarlos facil.
  static List<GrupoElectiva> fromJsonList(List<dynamic> jsonList) {
    // Aqui se van guardando todos los grupos ya convertidos.
    final List<GrupoElectiva> resultado = [];

    // Recorre cada grupo que llega desde la API.
    for (final g in jsonList) {
      // Convierte las opciones de electiva en objetos Materia.
      final opciones = (g['opciones'] as List)
          .map((o) => Materia.fromJson(o as Map<String, dynamic>))
          .toList();

      // Crea un grupo por cada slot de electiva.
      for (final slot in (g['slot_codigos'] as List)) {
        resultado.add(GrupoElectiva(
          slotCodigo: slot as String,
          slotNombre: g['nombre'] as String,
          opciones:   opciones,
        ));
      }
    }
    return resultado;
  }
}

// ── Modelo de Programa ───────────────────────────────────────
class Programa {
  // Codigo del programa, por ejemplo ISCO o IIND.
  final String codigo;

  // Nombre completo del programa.
  final String nombre;

  // Facultad a la que pertenece el programa.
  final String facultad;

  // Materias obligatorias o slots que forman la malla del programa.
  final List<Materia> materias;

  // Grupos de electivas con sus posibles materias.
  final List<GrupoElectiva> gruposElectivas;

  const Programa({
    required this.codigo,
    required this.nombre,
    required this.facultad,
    required this.materias,
    this.gruposElectivas = const [],
  });

  // Convierte el detalle de un programa que viene del backend en un Programa.
  // Esta es la parte que permite que Flutter use los datos de la BD.
  factory Programa.fromJson(Map<String, dynamic> json) {
    return Programa(
      codigo:          json['codigo']   as String,
      nombre:          json['nombre']   as String,
      facultad:        json['facultad'] as String,
      materias:        (json['materias'] as List)
                           .map((m) => Materia.fromJson(m as Map<String, dynamic>))
                           .toList(),
      gruposElectivas: GrupoElectiva.fromJsonList(
                           json['grupos_electivas'] as List),
    );
  }

  // Suma los creditos de todas las materias del programa.
  int get totalCreditos =>
      materias.fold(0, (sum, m) => sum + m.creditos);
}

// ════════════════════════════════════════════════════════════
//  ELECTIVAS COMPARTIDAS ENTRE AMBOS PROGRAMAS
//  (mismo código -> motor las detecta como compartidas)
// ════════════════════════════════════════════════════════════

// ── Electivas de Humanidades (idénticas en ambos programas) ─
/*
Se obtienen las mallas desde el backend/BD.
Se conservan comentados como referencia.

const _electivasHumanidades = [
  Materia(codigo: 'CHUM_A01A', nombre: 'Apreciación del Arte',           creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_A02A', nombre: 'Apreciación Musical',            creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_A07A', nombre: 'Fotografía Creativa',            creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_A10A', nombre: 'Historia del Arte',              creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_C03A', nombre: 'Cátedra de Paz',                 creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_C07A', nombre: 'Escritura Etnográfica',          creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_C17A', nombre: 'Ciudadanías Bajo la Lupa',       creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_F01A', nombre: '¿Para qué Filosofía?',           creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_L01A', nombre: 'Taller de Escritura Creativa',   creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_L04A', nombre: 'Héroes y Dioses Literatura Gri', creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_L06A', nombre: 'Literatura Latinoamericana',     creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_L07A', nombre: 'Lectura Crítica y Escritura',    creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_L09A', nombre: 'Literatura y Ciencia',           creditos: 2, nivel: 0),
  Materia(codigo: 'CHUM_S04A', nombre: 'Historia del Mundo Contemporán', creditos: 2, nivel: 0),
];

// ── Electivas Empresariales compartidas ─────────────────────
const _electivasEmpresarialesCompartidas = [
  Materia(codigo: 'AEMP_O06A', nombre: 'Negocios Inclusivos',                    creditos: 3, nivel: 0),
  Materia(codigo: 'AEMP_O07A', nombre: 'Empresas Sostenibles',                   creditos: 3, nivel: 0),
  Materia(codigo: 'AEMP_O08A', nombre: 'Panorama Internal y Cambio Social',      creditos: 3, nivel: 0),
  Materia(codigo: 'AEMP_O12A', nombre: 'Tecnologías Aplicadas a la Administración', creditos: 3, nivel: 0),
];

// ── Electivas Empresariales exclusivas de Sistemas ──────────
const _electivasEmpresarialesSistemas = [
  Materia(codigo: 'AEMP_G11A', nombre: 'Innovación',              creditos: 3, nivel: 0),
  Materia(codigo: 'AEMP_O14A', nombre: 'Gestión de la Innovación', creditos: 3, nivel: 0),
];

// ── Electivas Complementarias de Sistemas ───────────────────
// Excluidas (según indicación): ISCO_A02A(9), ISCO_A03A(10),
// ISCO_A07A(11), ISCO_A08A(12), ISCO_P01A(15), ISCO_P02A(16),
// CHUM_H05A(32=Ciudadanía Global ya en malla)
const _electivasCompSistemas = [
  Materia(codigo: 'IAMB_A11A', nombre: 'Gestión Ambiental',          creditos: 3, nivel: 0),
  Materia(codigo: 'IELE_E08A', nombre: 'Energías Renovables',         creditos: 3, nivel: 0),
  Materia(codigo: 'IELE_F03A', nombre: 'Circuitos Eléctricos I',      creditos: 3, nivel: 0),
  Materia(codigo: 'IETR_C07A', nombre: 'Redes de Alta Velocidad',     creditos: 3, nivel: 0),
  Materia(codigo: 'IETR_F02A', nombre: 'Sistemas Digitales I',        creditos: 3, nivel: 0),
  Materia(codigo: 'IIND_A05A', nombre: 'Ingeniería Económica',        creditos: 3, nivel: 0),
  Materia(codigo: 'ISCO_A19A', nombre: 'Computación e Interfaces',    creditos: 3, nivel: 0),
  Materia(codigo: 'ISCO_A20A', nombre: 'Desarrollo Frontend',         creditos: 3, nivel: 0),
  Materia(codigo: 'ISCO_Z03A', nombre: 'Gerencia de Sistemas',        creditos: 3, nivel: 0),
];

// ── Electivas Complementarias de Industrial ──────────────────
// Excluida: CHUM_H05A (Ciudadanía Global, ya está en malla)
const _electivasCompIndustrial = [
  Materia(codigo: 'FNEG_N05A', nombre: 'Estrategias de Negociación',          creditos: 3, nivel: 0),
  Materia(codigo: 'FNEG_N06A', nombre: 'Comercio Exterior',                   creditos: 3, nivel: 0),
  Materia(codigo: 'IAMB_A11A', nombre: 'Gestión Ambiental',                   creditos: 3, nivel: 0),
  Materia(codigo: 'IIND_A09A', nombre: 'Gestión de Inn. y el Conocimiento',   creditos: 3, nivel: 0),
  Materia(codigo: 'IIND_R14A', nombre: 'Ciencia de los Datos',                creditos: 3, nivel: 0),
  Materia(codigo: 'IIND_R17A', nombre: 'Ergonomía',                           creditos: 3, nivel: 0),
  Materia(codigo: 'IIND_R20A', nombre: 'Producción Más Limpia',               creditos: 3, nivel: 0),
  Materia(codigo: 'IIND_R21A', nombre: 'Gestión de Ope. Emp de Servicios',    creditos: 3, nivel: 0),
];



// ── Datos: Ingeniería de Sistemas y Computación ──────────────
const ingenieriaSistemas = Programa(
  codigo: 'ISCO',
  nombre: 'Ingeniería de Sistemas y Computación',
  facultad: 'Facultad de Ingeniería',
  materias: [

    // ── NIVEL I ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUM_H01A',
      nombre: 'Taller de Comprensión Lectora',
      creditos: 3,
      nivel: 1,
    ),
    Materia(
      codigo: 'CBAS_M01A',
      nombre: 'Cálculo Diferencial',
      creditos: 4,
      nivel: 1,
    ),
    Materia(
      codigo: 'CBAS_M02A',
      nombre: 'Matemáticas Básicas',
      creditos: 2,
      nivel: 1,
    ),
    Materia(
      codigo: 'CBAS_Q01A',
      nombre: 'Química General',
      creditos: 3,
      nivel: 1,
    ),
    Materia(
      codigo: 'ECOU_U01A',
      nombre: 'Desarrollo Universitario',
      creditos: 0,
      nivel: 1,
    ),
    Materia(
      codigo: 'ISCO_C01A',
      nombre: 'Seminario de Ing. Sistemas y Computación',
      creditos: 1,
      nivel: 1,
    ),
    Materia(
      codigo: 'ISCO_C02A',
      nombre: 'Fundamentos de Programación',
      creditos: 3,
      nivel: 1,
    ),

    // ── NIVEL II ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE1A',
      nombre: 'Lengua Extranjera I',
      creditos: 2,
      nivel: 2,
    ),
    Materia(
      codigo: 'CBAS_F01A',
      nombre: 'Física Mecánica',
      creditos: 4,
      nivel: 2,
      prerrequisitos: ['CBAS_M01A'],
    ),
    Materia(
      codigo: 'CBAS_M03A',
      nombre: 'Cálculo Integral',
      creditos: 4,
      nivel: 2,
      prerrequisitos: ['CBAS_M01A'],
    ),
    Materia(
      codigo: 'CBAS_M04A',
      nombre: 'Álgebra Lineal',
      creditos: 3,
      nivel: 2,
      prerrequisitos: ['CBAS_M02A'],
    ),
    Materia(
      codigo: 'ISCO_C03A',
      nombre: 'Programación',
      creditos: 3,
      nivel: 2,
      prerrequisitos: ['ISCO_C02A'],
    ),

    // ── NIVEL III ────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE2A',
      nombre: 'Lengua Extranjera II',
      creditos: 2,
      nivel: 3,
      prerrequisitos: ['CHUL_LE1A'],
    ),
    Materia(
      codigo: 'CHUM_H02A',
      nombre: 'Taller de Escritura Académica',
      creditos: 3,
      nivel: 3,
    ),
    Materia(
      codigo: 'CBAS_F02A',
      nombre: 'Física Electricidad y Magnetismo',
      creditos: 4,
      nivel: 3,
      prerrequisitos: ['CBAS_F01A', 'CBAS_M03A'],
    ),
    Materia(
      codigo: 'CBAS_M05A',
      nombre: 'Cálculo Vectorial',
      creditos: 4,
      nivel: 3,
      prerrequisitos: ['CBAS_M03A'],
    ),
    Materia(
      codigo: 'ISCO_C04A',
      nombre: 'Programación Orientada a Objetos',
      creditos: 3,
      nivel: 3,
      prerrequisitos: ['ISCO_C03A'],
    ),

    // ── NIVEL IV ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE3A',
      nombre: 'Lengua Extranjera III',
      creditos: 2,
      nivel: 4,
      prerrequisitos: ['CHUL_LE2A'],
    ),
    Materia(
      codigo: 'CBAS_F03A',
      nombre: 'Física Calor y Ondas',
      creditos: 4,
      nivel: 4,
      prerrequisitos: ['CBAS_F01A'],
    ),
    Materia(
      codigo: 'CBAS_M06A',
      nombre: 'Ecuaciones Diferenciales y en Diferencia',
      creditos: 4,
      nivel: 4,
      prerrequisitos: ['CBAS_M05A'],
    ),
    Materia(
      codigo: 'ISCO_C05A',
      nombre: 'Estructura de Datos',
      creditos: 3,
      nivel: 4,
      prerrequisitos: ['ISCO_C04A'],
    ),
    Materia(
      codigo: 'ISCO_C06A',
      nombre: 'Matemática Discreta',
      creditos: 3,
      nivel: 4,
      prerrequisitos: ['ISCO_C04A'],
    ),

    // ── NIVEL V ──────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE4A',
      nombre: 'Lengua Extranjera IV',
      creditos: 2,
      nivel: 5,
      prerrequisitos: ['CHUL_LE3A'],
    ),
    Materia(
      codigo: 'CHUM_H03A',
      nombre: 'Constitución Política',
      creditos: 2,
      nivel: 5,
    ),
    Materia(
      codigo: 'CBAS_E01A',
      nombre: 'Estadística y Probabilidad',
      creditos: 3,
      nivel: 5,
      prerrequisitos: ['CBAS_M03A'],
    ),
    Materia(
      codigo: 'ISCO_A01A',
      nombre: 'Base de Datos',
      creditos: 3,
      nivel: 5,
      prerrequisitos: ['ISCO_C05A'],
    ),
    Materia(
      codigo: 'ISCO_A02A',
      nombre: 'Desarrollo de Software',
      creditos: 3,
      nivel: 5,
      prerrequisitos: ['ISCO_C04A'],
    ),
    Materia(
      codigo: 'ISCO_A03A',
      nombre: 'Algoritmo y Complejidad',
      creditos: 3,
      nivel: 5,
      prerrequisitos: ['ISCO_C05A', 'ISCO_C06A'],
    ),

    // ── NIVEL VI ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE5A',
      nombre: 'Lengua Extranjera V',
      creditos: 2,
      nivel: 6,
      prerrequisitos: ['CHUL_LE4A'],
    ),
    Materia(
      codigo: 'CBAS_E02A',
      nombre: 'Estadística Inferencial',
      creditos: 3,
      nivel: 6,
      prerrequisitos: ['CBAS_E01A'],
    ),
    Materia(
      codigo: 'AEMP_G04A',
      nombre: 'Creatividad y Emprendimiento',
      creditos: 3,
      nivel: 6,
    ),
    Materia(
      codigo: 'ISCO_A04A',
      nombre: 'Arquitectura de Software',
      creditos: 3,
      nivel: 6,
      prerrequisitos: ['ISCO_A02A'],
    ),
    Materia(
      codigo: 'ISCO_C07A',
      nombre: 'Procesamiento Numérico',
      creditos: 3,
      nivel: 6,
      prerrequisitos: ['ISCO_C04A', 'CBAS_M06A'],
    ),
    Materia(
      codigo: 'ISCO_C08A',
      nombre: 'Comunicaciones y Redes',
      creditos: 3,
      nivel: 6,
      prerrequisitos: ['ISCO_C05A'],
    ),

    // ── NIVEL VII ────────────────────────────────────────────
    Materia(
      codigo: 'CHUM_H05A',
      nombre: 'Ciudadanía Global',
      creditos: 2,
      nivel: 7,
    ),
    Materia(
      codigo: 'ECON_M12A',
      nombre: 'Formulación y Evaluación de Proyectos',
      creditos: 3,
      nivel: 7,
      prerrequisitos: ['CBAS_E01A'],
    ),
    Materia(
      codigo: 'ISCO_A05A',
      nombre: 'Ingeniería de Software',
      creditos: 3,
      nivel: 7,
      prerrequisitos: ['ISCO_A04A'],
    ),
    Materia(
      codigo: 'ISCO_C09A',
      nombre: 'Arquitectura del Computador',
      creditos: 3,
      nivel: 7,
      prerrequisitos: ['ISCO_C08A'],
    ),
    Materia(
      codigo: 'ISCO_C10A',
      nombre: 'Sistemas y Modelos',
      creditos: 3,
      nivel: 7,
      prerrequisitos: ['ISCO_C07A'],
    ),
    Materia(
      codigo: 'ISCO_P01A',
      nombre: 'Proyecto de Ingeniería I',
      creditos: 3,
      nivel: 7,
      prerrequisitos: ['ISCO_A02A', 'ISCO_A01A'],
    ),

    // ── NIVEL VIII ───────────────────────────────────────────
    Materia(
      codigo: 'CHUM_HU1A',
      nombre: 'Electiva de Humanidades I',  // opciones: ver gruposElectivas
      creditos: 2,
      nivel: 8,
    ),
    Materia(
      codigo: 'ISCO_A06A',
      nombre: 'Inteligencia Artificial',
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['CBAS_E01A', 'ISCO_A03A'],
    ),
    Materia(
      codigo: 'ISCO_A07A',
      nombre: 'Infraestructura para TI',
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['ISCO_C09A'],
    ),
    Materia(
      codigo: 'ISCO_C11A',
      nombre: 'Sistemas Operativos',
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['ISCO_C09A'],
    ),
    Materia(
      codigo: 'ISCO_EC1A',
      nombre: 'Electiva Complementaria I',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['ISCO_A02A'],
    ),
    Materia(
      codigo: 'ISCO_P02A',
      nombre: 'Proyecto de Ingeniería II',
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['ISCO_P01A'],
    ),

    // ── NIVEL IX ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUM_HU2A',
      nombre: 'Electiva de Humanidades II',  // opciones: ver gruposElectivas
      creditos: 2,
      nivel: 9,
      prerrequisitos: ['CHUM_HU1A'],
    ),
    Materia(
      codigo: 'ISCO_EE1A',
      nombre: 'Electiva Empresarial',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 9,
    ),
    Materia(
      codigo: 'ISCO_A08A',
      nombre: 'Computación en Paralelo',
      creditos: 3,
      nivel: 9,
      prerrequisitos: ['ISCO_A07A'],
    ),
    Materia(
      codigo: 'ISCO_C12A',
      nombre: 'Tóp. Esp. de Ciencias de la Computación',
      creditos: 3,
      nivel: 9,
      prerrequisitos: ['ISCO_C11A'],
    ),
    Materia(
      codigo: 'ISCO_EC2A',
      nombre: 'Electiva Complementaria II',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 9,
      prerrequisitos: ['ISCO_EC1A'],
    ),
    Materia(
      codigo: 'ISCO_EC3A',
      nombre: 'Electiva Complementaria III',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 9,
      prerrequisitos: ['ISCO_EC1A'],
    ),

    // ── NIVEL X ──────────────────────────────────────────────
    Materia(
      codigo: 'CHUM_H04A',
      nombre: 'Ética',
      creditos: 2,
      nivel: 10,
    ),
    Materia(
      codigo: 'ISCO_EC4A',
      nombre: 'Electiva Complementaria IV',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 10,
      prerrequisitos: ['ISCO_EC2A'],
    ),
    Materia(
      codigo: 'ISCO_P03A',
      nombre: 'Práctica Profesional',
      creditos: 9,
      nivel: 10,
      prerrequisitos: ['ISCO_P02A'],
    ),
  ],
  gruposElectivas: [
    GrupoElectiva(
      slotCodigo: 'CHUM_HU1A',
      slotNombre: 'Electiva de Humanidades I',
      opciones: _electivasHumanidades,
    ),
    GrupoElectiva(
      slotCodigo: 'CHUM_HU2A',
      slotNombre: 'Electiva de Humanidades II',
      opciones: _electivasHumanidades,
    ),
    GrupoElectiva(
      slotCodigo: 'ISCO_EE1A',
      slotNombre: 'Electiva Empresarial',
      opciones: [
        ..._electivasEmpresarialesCompartidas,
        ..._electivasEmpresarialesSistemas,
      ],
    ),
    GrupoElectiva(
      slotCodigo: 'ISCO_EC1A',
      slotNombre: 'Electiva Complementaria I',
      opciones: _electivasCompSistemas,
    ),
    GrupoElectiva(
      slotCodigo: 'ISCO_EC2A',
      slotNombre: 'Electiva Complementaria II',
      opciones: _electivasCompSistemas,
    ),
    GrupoElectiva(
      slotCodigo: 'ISCO_EC3A',
      slotNombre: 'Electiva Complementaria III',
      opciones: _electivasCompSistemas,
    ),
    GrupoElectiva(
      slotCodigo: 'ISCO_EC4A',
      slotNombre: 'Electiva Complementaria IV',
      opciones: _electivasCompSistemas,
    ),
  ],
);

// ── Datos: Ingeniería Industrial ─────────────────────────────
// UTB — Malla 201910  (58 materias, 169 créditos)
//
// NOTA DE CÓDIGOS COMPARTIDOS CON SISTEMAS:
// Las materias con prefijo CBAS_, CHUL_, CHUM_, ECOU_, AEMP_,
// ECON_ y ISCO_ son idénticas en ambos programas. Esto permite
// que el motor detecte homologaciones automáticamente cuando
// el estudiante curse ambas carreras en doble programa.
// ─────────────────────────────────────────────────────────────
const ingenieriaIndustrial = Programa(
  codigo: 'IIND',
  nombre: 'Ingeniería Industrial',
  facultad: 'Facultad de Ingeniería',
  materias: [

    // ── NIVEL I ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUM_H01A',
      nombre: 'Taller de Comprensión Lectora',
      creditos: 3,
      nivel: 1,
    ),
    Materia(
      codigo: 'CBAS_M01A',
      nombre: 'Cálculo Diferencial',
      creditos: 4,
      nivel: 1,
    ),
    Materia(
      codigo: 'CBAS_M02A',
      nombre: 'Matemáticas Básicas',
      creditos: 2,
      nivel: 1,
    ),
    Materia(
      codigo: 'CBAS_Q01A',
      nombre: 'Química General',
      creditos: 3,
      nivel: 1,
    ),
    Materia(
      codigo: 'ECOU_U01A',
      nombre: 'Desarrollo Universitario',
      creditos: 0,
      nivel: 1,
    ),
    Materia(
      codigo: 'IIND_A01A',
      nombre: 'Seminario de Ing. Industrial',
      creditos: 1,
      nivel: 1,
    ),
    Materia(
      codigo: 'ISCO_C02A',
      nombre: 'Fundamentos de Programación',
      creditos: 3,
      nivel: 1,
    ),

    // ── NIVEL II ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE1A',
      nombre: 'Lengua Extranjera I',
      creditos: 2,
      nivel: 2,
    ),
    Materia(
      codigo: 'CHUM_H02A',
      nombre: 'Taller de Escritura Académica',
      creditos: 3,
      nivel: 2,
    ),
    Materia(
      codigo: 'CBAS_F01A',
      nombre: 'Física Mecánica',
      creditos: 4,
      nivel: 2,
      prerrequisitos: ['CBAS_M01A'],
    ),
    Materia(
      codigo: 'CBAS_M03A',
      nombre: 'Cálculo Integral',
      creditos: 4,
      nivel: 2,
      prerrequisitos: ['CBAS_M01A'],
    ),
    Materia(
      codigo: 'CBAS_M04A',
      nombre: 'Álgebra Lineal',
      creditos: 3,
      nivel: 2,
      prerrequisitos: ['CBAS_M02A'],
    ),
    Materia(
      codigo: 'ISCO_C03A',
      nombre: 'Programación',
      creditos: 3,
      nivel: 2,
      prerrequisitos: ['ISCO_C02A'],
    ),

    // ── NIVEL III ────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE2A',
      nombre: 'Lengua Extranjera II',
      creditos: 2,
      nivel: 3,
      prerrequisitos: ['CHUL_LE1A'],
    ),
    Materia(
      codigo: 'CBAS_E01A',
      nombre: 'Estadística y Probabilidad',
      creditos: 3,
      nivel: 3,
      prerrequisitos: ['CBAS_M03A'],
    ),
    Materia(
      codigo: 'CBAS_F02A',
      nombre: 'Física Electricidad y Magnetismo',
      creditos: 4,
      nivel: 3,
      prerrequisitos: ['CBAS_F01A', 'CBAS_M03A'],
    ),
    Materia(
      codigo: 'CBAS_M05A',
      nombre: 'Cálculo Vectorial',
      creditos: 4,
      nivel: 3,
      prerrequisitos: ['CBAS_M03A'],
    ),
    Materia(
      codigo: 'IMEC_M01A',
      nombre: 'Materiales I',
      creditos: 3,
      nivel: 3,
      prerrequisitos: ['CBAS_F01A'],
    ),
    Materia(
      codigo: 'IIND_A02A',
      nombre: 'Administración Industrial',
      creditos: 2,
      nivel: 3,
    ),

    // ── NIVEL IV ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE3A',
      nombre: 'Lengua Extranjera III',
      creditos: 2,
      nivel: 4,
      prerrequisitos: ['CHUL_LE2A'],
    ),
    Materia(
      codigo: 'CBAS_E02A',
      nombre: 'Estadística Inferencial',
      creditos: 3,
      nivel: 4,
      prerrequisitos: ['CBAS_E01A'],
    ),
    Materia(
      codigo: 'CBAS_F03A',
      nombre: 'Física Calor y Onda',
      creditos: 4,
      nivel: 4,
      prerrequisitos: ['CBAS_F02A'],
    ),
    Materia(
      codigo: 'CBAS_M06A',
      nombre: 'Ecuaciones Diferenciales y en Diferencia',
      creditos: 4,
      nivel: 4,
      prerrequisitos: ['CBAS_M05A'],
    ),
    Materia(
      codigo: 'IIND_A03A',
      nombre: 'Estrategias de Operaciones',
      creditos: 2,
      nivel: 4,
      prerrequisitos: ['IIND_A02A'],
    ),
    Materia(
      codigo: 'IIND_R01A',
      nombre: 'Procesos de Fabricación',
      creditos: 3,
      nivel: 4,
      prerrequisitos: ['IMEC_M01A'],
    ),

    // ── NIVEL V ──────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE4A',
      nombre: 'Lengua Extranjera IV',
      creditos: 2,
      nivel: 5,
      prerrequisitos: ['CHUL_LE3A'],
    ),
    Materia(
      codigo: 'AEMP_G04A',
      nombre: 'Creatividad y Emprendimiento',
      creditos: 3,
      nivel: 5,
    ),
    Materia(
      codigo: 'IIND_A04A',
      nombre: 'Sistemas de Costeo',
      creditos: 3,
      nivel: 5,
      prerrequisitos: ['IIND_A02A'],
    ),
    Materia(
      codigo: 'IIND_R02A',
      nombre: 'Optimización',
      creditos: 3,
      nivel: 5,
      prerrequisitos: ['CBAS_M06A'],
    ),
    Materia(
      codigo: 'IIND_R03A',
      nombre: 'Procesos Industriales',
      creditos: 3,
      nivel: 5,
      prerrequisitos: ['IIND_R01A'],
    ),
    Materia(
      codigo: 'ISCO_C07A',
      nombre: 'Procesamiento Numérico',
      creditos: 3,
      nivel: 5,
      prerrequisitos: ['ISCO_C03A', 'CBAS_M06A'],
    ),

    // ── NIVEL VI ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUL_LE5A',
      nombre: 'Lengua Extranjera V',
      creditos: 2,
      nivel: 6,
      prerrequisitos: ['CHUL_LE4A'],
    ),
    Materia(
      codigo: 'CHUM_H03A',
      nombre: 'Constitución Política',
      creditos: 2,
      nivel: 6,
    ),
    Materia(
      codigo: 'CHUM_H05A',
      nombre: 'Ciudadanía Global',
      creditos: 2,
      nivel: 6,
    ),
    Materia(
      codigo: 'ECON_M12A',
      nombre: 'Formulación y Evaluación de Proyectos',
      creditos: 3,
      nivel: 6,
      prerrequisitos: ['CBAS_E01A'],
    ),
    Materia(
      codigo: 'IIND_R04A',
      nombre: 'Procesos Estocásticos',
      creditos: 3,
      nivel: 6,
      prerrequisitos: ['CBAS_E02A'],
    ),
    Materia(
      codigo: 'IIND_R13A',
      nombre: 'Diseño de Experimentos',
      creditos: 3,
      nivel: 6,
      prerrequisitos: ['CBAS_E02A'],
    ),
    Materia(
      codigo: 'IIND_R05A',
      nombre: 'Ingeniería de Productividad',
      creditos: 3,
      nivel: 6,
      prerrequisitos: ['IIND_R03A'],
    ),

    // ── NIVEL VII ────────────────────────────────────────────
    Materia(
      codigo: 'CHUM_HU1A',
      nombre: 'Electiva de Humanidades I',  // opciones: ver gruposElectivas
      creditos: 2,
      nivel: 7,
    ),
    Materia(
      codigo: 'IIND_A05A',
      nombre: 'Ingeniería Económica',
      creditos: 3,
      nivel: 7,
      prerrequisitos: ['IIND_A04A'],
    ),
    Materia(
      codigo: 'IIND_EC1A',
      nombre: 'Electiva Complementaria I',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 7,
    ),
    Materia(
      codigo: 'IIND_EE1A',
      nombre: 'Electiva Empresarial',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 7,
    ),
    Materia(
      codigo: 'IIND_R07A',
      nombre: 'Gestión Cadena de Suministro',
      creditos: 3,
      nivel: 7,
      prerrequisitos: ['IIND_R04A'],
    ),
    Materia(
      codigo: 'IIND_R08A',
      nombre: 'Diseño de Sistemas Productivos',
      creditos: 3,
      nivel: 7,
      prerrequisitos: ['IIND_R05A'],
    ),

    // ── NIVEL VIII ───────────────────────────────────────────
    Materia(
      codigo: 'IIND_A06A',
      nombre: 'Gestión del Talento Humano',
      creditos: 3,
      nivel: 8,
    ),
    Materia(
      codigo: 'IIND_A07A',
      nombre: 'Seguridad y Salud Laboral',
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['IIND_R05A'],
    ),
    Materia(
      codigo: 'IIND_EC2A',
      nombre: 'Electiva Complementaria II',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['IIND_EC1A'],
    ),
    Materia(
      codigo: 'IIND_P01A',
      nombre: 'Proyecto de Ingeniería I',
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['IIND_R07A'],
    ),
    Materia(
      codigo: 'IIND_R09A',
      nombre: 'Plan, Prog y Cont Producción',
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['IIND_R07A'],
    ),
    Materia(
      codigo: 'IIND_R10A',
      nombre: 'Control de Calidad',
      creditos: 3,
      nivel: 8,
      prerrequisitos: ['IIND_R08A'],
    ),

    // ── NIVEL IX ─────────────────────────────────────────────
    Materia(
      codigo: 'CHUM_H04A',
      nombre: 'Ética',
      creditos: 2,
      nivel: 9,
    ),
    Materia(
      codigo: 'CHUM_HU2A',
      nombre: 'Electiva de Humanidades II',  // opciones: ver gruposElectivas
      creditos: 2,
      nivel: 9,
      prerrequisitos: ['CHUM_HU1A'],
    ),
    Materia(
      codigo: 'IIND_EC3A',
      nombre: 'Electiva Complementaria III',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 9,
      prerrequisitos: ['IIND_EC2A'],
    ),
    Materia(
      codigo: 'IIND_P02A',
      nombre: 'Proyecto de Ingeniería II',
      creditos: 3,
      nivel: 9,
      prerrequisitos: ['IIND_P01A'],
    ),
    Materia(
      codigo: 'IIND_R11A',
      nombre: 'Distribución y Transporte',
      creditos: 3,
      nivel: 9,
      prerrequisitos: ['IIND_R09A'],
    ),
    Materia(
      codigo: 'IIND_R12A',
      nombre: 'Simulación',
      creditos: 3,
      nivel: 9,
      prerrequisitos: ['IIND_R10A'],
    ),

    // ── NIVEL X ──────────────────────────────────────────────
    Materia(
      codigo: 'IIND_EC4A',
      nombre: 'Electiva Complementaria IV',  // opciones: ver gruposElectivas
      creditos: 3,
      nivel: 10,
      prerrequisitos: ['IIND_EC3A'],
    ),
    Materia(
      codigo: 'IIND_P03A',
      nombre: 'Prácticas Profesionales',
      creditos: 9,
      nivel: 10,
      prerrequisitos: ['IIND_P02A'],
    ),
  ],
  gruposElectivas: [
    GrupoElectiva(
      slotCodigo: 'CHUM_HU1A',
      slotNombre: 'Electiva de Humanidades I',
      opciones: _electivasHumanidades,
    ),
    GrupoElectiva(
      slotCodigo: 'CHUM_HU2A',
      slotNombre: 'Electiva de Humanidades II',
      opciones: _electivasHumanidades,
    ),
    GrupoElectiva(
      slotCodigo: 'IIND_EE1A',
      slotNombre: 'Electiva Empresarial',
      opciones: _electivasEmpresarialesCompartidas,
    ),
    GrupoElectiva(
      slotCodigo: 'IIND_EC1A',
      slotNombre: 'Electiva Complementaria I',
      opciones: _electivasCompIndustrial,
    ),
    GrupoElectiva(
      slotCodigo: 'IIND_EC2A',
      slotNombre: 'Electiva Complementaria II',
      opciones: _electivasCompIndustrial,
    ),
    GrupoElectiva(
      slotCodigo: 'IIND_EC3A',
      slotNombre: 'Electiva Complementaria III',
      opciones: _electivasCompIndustrial,
    ),
    GrupoElectiva(
      slotCodigo: 'IIND_EC4A',
      slotNombre: 'Electiva Complementaria IV',
      opciones: _electivasCompIndustrial,
    ),
  ],
);

// ── Registro global de programas disponibles ─────────────────
final Map<String, Programa> programasDisponibles = {
  'ISCO': ingenieriaSistemas,
  'IIND': ingenieriaIndustrial,
};

// ── Materias compartidas entre Sistemas e Industrial ─────────
// Códigos idénticos en ambas mallas — el motor las detecta
// automáticamente como compartidas al planificar doble programa.
const Set<String> materiasCompartidas = {
  // Ciencias básicas
  'CHUM_H01A', 'CBAS_M01A', 'CBAS_M02A', 'CBAS_Q01A', 'ECOU_U01A',
  'ISCO_C02A', 'CHUL_LE1A', 'CHUL_LE2A', 'CHUL_LE3A', 'CHUL_LE4A',
  'CHUL_LE5A', 'CHUM_H02A', 'CBAS_F01A', 'CBAS_M03A', 'CBAS_M04A',
  'ISCO_C03A', 'CBAS_F02A', 'CBAS_M05A', 'CBAS_E01A', 'CBAS_F03A',
  'CBAS_M06A', 'CBAS_E02A', 'AEMP_G04A', 'CHUM_H03A', 'CHUM_H05A',
  'ECON_M12A', 'ISCO_C07A', 'CHUM_HU1A', 'CHUM_HU2A', 'CHUM_H04A',
  // Electivas compartidas
  'IAMB_A11A',  // Gestión Ambiental (comp. complementaria en ambos)
  // Empresariales compartidas
  'AEMP_O06A', 'AEMP_O07A', 'AEMP_O08A', 'AEMP_O12A',
  // Humanidades (todas compartidas)
  'CHUM_A01A', 'CHUM_A02A', 'CHUM_A07A', 'CHUM_A10A', 'CHUM_C03A',
  'CHUM_C07A', 'CHUM_C17A', 'CHUM_F01A', 'CHUM_L01A', 'CHUM_L04A',
  'CHUM_L06A', 'CHUM_L07A', 'CHUM_L09A', 'CHUM_S04A',
};
*/
