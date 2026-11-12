// ============================================================
//  datos_programa.dart
//  Modelos que parsean la respuesta del backend sobre programas
//  y mallas curriculares UTB (malla 201910).
//
//  Ya NO contiene datos: las mallas de ISCO e IIND vivian aqui
//  hardcodeadas, pero fueron migradas a MySQL y ahora se sirven
//  por GET /programas/{codigo}. Este archivo solo define las
//  clases (con sus fromJson) que convierten ese JSON en objetos
//  de Dart, mas la lista de codigos de ingles que la app usa
//  para mapear nivel -> codigo de materia.
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

  // Caminos alternativos, uno por programa. Solo se llena en doble programa,
  // cuando una materia compartida exige cosas que no se contienen entre si
  // (Estructura de Datos: POO en ISCO, Programacion para Ciencia de Datos en
  // CDAT). Si no esta vacia, basta con cumplir UNO de los caminos.
  final List<List<String>> alternativas;

  const Materia({
    required this.codigo,
    required this.nombre,
    required this.creditos,
    required this.nivel,
    this.prerrequisitos = const [],
    this.alternativas = const [],
  });

  /// Si los prerrequisitos estan cumplidos, segun [aprobada].
  ///
  /// Toda comprobacion de prerrequisitos debe pasar por aqui: si alguna usa
  /// `prerrequisitos.every(...)` directo, ignora las alternativas y vuelve a
  /// exigir los caminos de los dos programas a la vez.
  bool requisitosCumplidos(bool Function(String codigo) aprobada) {
    if (alternativas.isNotEmpty) {
      return alternativas.any((camino) => camino.every(aprobada));
    }
    return prerrequisitos.every(aprobada);
  }

  /// Grafo de prerrequisitos de una malla: codigo -> prerrequisitos directos.
  static Map<String, List<String>> grafoDe(List<Materia> materias) =>
      {for (final m in materias) m.codigo: m.prerrequisitos};

  /// Todos los prerrequisitos de [codigo] en [grafo], directos e indirectos.
  /// [memo] evita recalcular y corta ciclos si la BD trajera alguno.
  static Set<String> cierre(
    String codigo,
    Map<String, List<String>> grafo, [
    Map<String, Set<String>>? memo,
  ]) {
    final cache = memo ?? <String, Set<String>>{};
    final previo = cache[codigo];
    if (previo != null) return previo;
    cache[codigo] = <String>{};
    final total = <String>{};
    for (final pre in grafo[codigo] ?? const <String>[]) {
      total
        ..add(pre)
        ..addAll(cierre(pre, grafo, cache));
    }
    cache[codigo] = total;
    return total;
  }

  /// Copia de esta materia con otros prerrequisitos.
  Materia conPrerrequisitos(List<String> prereqs, List<List<String>> alts) =>
      Materia(
        codigo: codigo,
        nombre: nombre,
        creditos: creditos,
        nivel: nivel,
        prerrequisitos: prereqs,
        alternativas: alts,
      );

  /// Combina lo que dos programas exigen a la misma materia.
  ///
  /// Si ninguno domina, son caminos distintos y basta con uno: exigir la
  /// union de ambos bloqueaba, por ejemplo, Estructura de Datos a quien
  /// habia cursado el curso de programacion de su programa.
  ///
  /// Se compara la lista DIRECTA de un programa con el CIERRE transitivo del
  /// otro ([cierreA], [cierreB]). Si lo que pide uno ya esta en la cadena del
  /// otro, domina: se exigen ambas listas, sin alternativas. Asi sale bien
  /// Fisica Calor y Ondas (ISCO pide Mecanica, IIND pide Electricidad, que
  /// exige Mecanica). Cierre contra cierre fallaba con diferencias rio
  /// arriba: en IMEC+ISCO, Procesamiento Numerico dejaba de exigir POO
  /// porque IMEC declara Calculo Vectorial distinto. Es la misma regla que
  /// el backend (combinar_prerrequisitos en motor/planificador.py).
  static Materia combinar(
    Materia a,
    Materia b, {
    Set<String> cierreA = const {},
    Set<String> cierreB = const {},
  }) {
    final sa = {...a.prerrequisitos, ...cierreA};
    final sb = {...b.prerrequisitos, ...cierreB};
    final union = {...a.prerrequisitos, ...b.prerrequisitos}.toList();
    if (sb.containsAll(a.prerrequisitos) || sa.containsAll(b.prerrequisitos)) {
      return a.conPrerrequisitos(union, const []);
    }
    return a.conPrerrequisitos(union, [a.prerrequisitos, b.prerrequisitos]);
  }

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
