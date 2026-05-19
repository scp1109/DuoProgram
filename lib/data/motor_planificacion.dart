// ============================================================
//  motor_planificacion.dart
//  NOTA: Este archivo ya no se usa en la app.
//  El motor de planificacion fue migrado al backend (FastAPI).
//  Todo el calculo de planes se hace via POST /plan/planificar.
//  Se conserva como referencia historica del algoritmo CPM
//  que existia antes de la migracion al backend.
// ============================================================

import 'datos_programa.dart';

const List<String> codigosIngles = [
  'CHUL_LE1A', 'CHUL_LE2A', 'CHUL_LE3A', 'CHUL_LE4A', 'CHUL_LE5A',
];

const Map<String, String> _codigosPractica = {
  'ISCO': 'ISCO_P03A',
  'IIND': 'IIND_P03A',
};

const Materia _practicaGenerica = Materia(
  codigo: 'PRACTICA_UNICA',
  nombre: 'Prácticas Profesionales',
  creditos: 9,
  nivel: 10,
  prerrequisitos: [],
);

// ── Modelos públicos ─────────────────────────────────────────

class HomologacionExterna {
  final String codigoMateria;
  final String nombrePrograma;
  const HomologacionExterna({
    required this.codigoMateria,
    required this.nombrePrograma,
  });
}

class MateriaAdelantada {
  final String codigo;
  final int semestreEnQueSeCurso;
  const MateriaAdelantada({
    required this.codigo,
    required this.semestreEnQueSeCurso,
  });
}

class ParametrosPlan {
  final Set<String> aprobadas;
  final Set<int> nivelesInglesHomologados;
  final double promedio;
  final List<MateriaAdelantada> adelantadas;
  final Programa? programaSecundario;
  final int semestresCursados;
  final List<HomologacionExterna> homologacionesExternas;
  // Créditos mínimos por semestre para evitar semestres vacíos
  final int minCreditos;

  const ParametrosPlan({
    required this.aprobadas,
    this.nivelesInglesHomologados = const {},
    required this.promedio,
    this.adelantadas = const [],
    this.programaSecundario,
    this.semestresCursados = 0,
    this.homologacionesExternas = const [],
    this.minCreditos = 10,
  });

  int get maxCreditos => promedio >= 4.0 ? 20 : 18;
}

class MateriaPlan {
  final Materia materia;
  final String origen; // 'principal'|'secundario'|'compartida'|'practica'
  final bool sirveParaAmbas;

  const MateriaPlan({
    required this.materia,
    required this.origen,
    this.sirveParaAmbas = false,
  });
}

class SemestrePlan {
  final int numero;
  final List<MateriaPlan> materias;
  final bool esPrimero;
  final bool esUltimo;

  const SemestrePlan({
    required this.numero,
    required this.materias,
    this.esPrimero = false,
    this.esUltimo = false,
  });

  int get totalCreditos =>
      materias.fold(0, (s, m) => s + m.materia.creditos);
}

// ── Motor principal ──────────────────────────────────────────
class MotorPlanificacion {

  static List<SemestrePlan> generarPlan({
    required Programa programa,
    required ParametrosPlan params,
  }) {
    final sec = params.programaSecundario;

    // ── 1. Códigos de práctica ───────────────────────────────
    final cpPpal = _codigosPractica[programa.codigo];
    final cpSec  = sec != null ? _codigosPractica[sec.codigo] : null;
    final practicas = <String>{
      ?cpPpal,
      ?cpSec,
    };

    // ── 2. Construir mapa global de materias por código ──────
    final Map<String, Materia> porCodigo = {};
    for (final m in programa.materias) porCodigo[m.codigo] = m;
    if (sec != null) {
      for (final m in sec.materias) {
        porCodigo.putIfAbsent(m.codigo, () => m);
      }
    }
    porCodigo['PRACTICA_UNICA'] = _practicaGenerica;

    // ── 3. Construir set de "ya cubiertas" ───────────────────
    final Set<String> cubiertas = {...params.aprobadas};

    // Inglés homologado
    for (final n in params.nivelesInglesHomologados) {
      if (n >= 1 && n <= codigosIngles.length) {
        cubiertas.add(codigosIngles[n - 1]);
      }
    }

    // Homologaciones externas → cubrir slot de electiva
    for (final h in params.homologacionesExternas) {
      cubiertas.add(h.codigoMateria);
      _cubrirSlot(h.codigoMateria, programa, cubiertas);
      if (sec != null) _cubrirSlot(h.codigoMateria, sec, cubiertas);
    }

    // ── 4. Determinar qué materias quedan pendientes ─────────
    // Excluir: ya cubiertas + prácticas reales (van al final)
    final Set<String> pendientes = porCodigo.keys
        .where((c) =>
            c != 'PRACTICA_UNICA' &&
            !cubiertas.contains(c) &&
            !practicas.contains(c))
        .toSet();

    // ── 5. Funciones de origen ───────────────────────────────
    final codigosPpal = programa.materias.map((m) => m.codigo).toSet();
    final codigosSec  = sec?.materias.map((m) => m.codigo).toSet() ?? {};
    final opcionesSec = sec?.gruposElectivas
            .expand((g) => g.opciones)
            .map((m) => m.codigo)
            .toSet() ?? {};

    MateriaPlan mkPlan(String codigo) {
      final m = porCodigo[codigo]!;
      final enP = codigosPpal.contains(codigo);
      final enS = codigosSec.contains(codigo);
      String origen;
      if (codigo == 'PRACTICA_UNICA') {
        origen = 'practica';
      } else if (enP && enS) {
        origen = 'compartida';
      } else if (enS) {
        origen = 'secundario';
      } else {
        origen = 'principal';
      }
      final sirveParaAmbas = (enP && enS) ||
          (enP && opcionesSec.contains(codigo)) ||
          origen == 'practica';
      return MateriaPlan(materia: m, origen: origen, sirveParaAmbas: sirveParaAmbas);
    }

    // ── 6. CPM: calcular semestre mínimo de cada materia ─────
    // early[c] = semestre más temprano en que se puede cursar
    // (0-indexed internamente, se suma 1 al mostrar)
    final Map<String, int> early = {};

    // Calcular early de forma recursiva con memoización
    int calcEarly(String codigo, Set<String> visitando) {
      if (early.containsKey(codigo)) return early[codigo]!;

      // Detectar ciclos (no deberían existir en una malla bien formada)
      if (visitando.contains(codigo)) return 0;
      visitando.add(codigo);

      final mat = porCodigo[codigo];
      if (mat == null) {
        early[codigo] = 0;
        visitando.remove(codigo);
        return 0;
      }

      // Si no tiene prerrequisitos pendientes, puede ir al semestre 0
      final prereqsPendientes = mat.prerrequisitos
          .where((p) => !cubiertas.contains(p) && pendientes.contains(p))
          .toList();

      if (prereqsPendientes.isEmpty) {
        early[codigo] = 0;
      } else {
        // El semestre mínimo es 1 + el máximo early de sus prerrequisitos
        int maxPrereq = 0;
        for (final p in prereqsPendientes) {
          final e = calcEarly(p, visitando);
          if (e > maxPrereq) maxPrereq = e;
        }
        early[codigo] = maxPrereq + 1;
      }

      visitando.remove(codigo);
      return early[codigo]!;
    }

    // Calcular early para todas las materias pendientes
    for (final c in pendientes) {
      calcEarly(c, {});
    }

    // ── 7. Agrupar por semestre mínimo (early) ───────────────
    // Organizar pendientes por su semestre temprano
    final Map<int, List<String>> porSemestre = {};
    for (final c in pendientes) {
      final e = early[c] ?? 0;
      porSemestre.putIfAbsent(e, () => []).add(c);
    }

    // Ordenar materias dentro de cada semestre:
    // primero las de nivel más bajo, luego más créditos (llenar mejor)
    for (final lista in porSemestre.values) {
      lista.sort((a, b) {
        final ma = porCodigo[a]!;
        final mb = porCodigo[b]!;
        final nc = ma.nivel.compareTo(mb.nivel);
        return nc != 0 ? nc : mb.creditos.compareTo(ma.creditos);
      });
    }

    // ── 8. Bin packing respetando límite de créditos ─────────
    // Asignar materias a semestres reales respetando maxCreditos.
    // Si un early-bucket no cabe en un semestre, su exceso se
    // "derrama" al siguiente semestre.
    final List<SemestrePlan> plan = [];
    final Set<String> asignadas = {};

    // Semestre 1 fijo (R3)
    final nivel1Pendientes = programa.materias
        .where((m) => m.nivel == 1 && pendientes.contains(m.codigo))
        .toList();

    if (nivel1Pendientes.isNotEmpty) {
      final materiasSem1 = nivel1Pendientes.map((m) => mkPlan(m.codigo)).toList();
      plan.add(SemestrePlan(
        numero: 1,
        materias: materiasSem1,
        esPrimero: true,
      ));
      for (final mp in materiasSem1) {
        asignadas.add(mp.materia.codigo);
        cubiertas.add(mp.materia.codigo);
        pendientes.remove(mp.materia.codigo);
        porSemestre[0]?.remove(mp.materia.codigo);
      }
    }

    // Procesar los demás semestres
    // Cola de materias disponibles: las del semestre temprano actual
    // más las que desbordaron del semestre anterior
    List<String> cola = [];
    final int maxSemestre = early.values.isEmpty
        ? 0
        : early.values.reduce((a, b) => a > b ? a : b);

    for (int e = nivel1Pendientes.isNotEmpty ? 1 : 0;
        e <= maxSemestre + 1;
        e++) {
      // Agregar a la cola las materias cuyo early es este semestre
      // Y que sus prerrequisitos ya están cubiertos
      final disponibles = (porSemestre[e] ?? [])
          .where((c) => !asignadas.contains(c))
          .toList();
      cola.addAll(disponibles);

      // Filtrar cola: solo las que tienen todos sus prereqs cubiertos
      cola = cola.where((c) {
        final mat = porCodigo[c]!;
        return mat.prerrequisitos
            .every((p) => cubiertas.contains(p) || !pendientes.contains(p));
      }).toList();

      if (cola.isEmpty) continue;

      // Re-ordenar cola: nivel más bajo primero, luego más créditos
      cola.sort((a, b) {
        final ma = porCodigo[a]!;
        final mb = porCodigo[b]!;
        final nc = ma.nivel.compareTo(mb.nivel);
        return nc != 0 ? nc : mb.creditos.compareTo(ma.creditos);
      });

      // Llenar el semestre
      final List<MateriaPlan> semestre = [];
      int usados = 0;
      final List<String> sobrantes = [];

      for (final c in cola) {
        final creditos = porCodigo[c]!.creditos;
        if (usados + creditos <= params.maxCreditos) {
          semestre.add(mkPlan(c));
          usados += creditos;
        } else {
          sobrantes.add(c);
        }
      }

      if (semestre.isEmpty) {
        // No cabe nada (materias muy grandes) — forzar al menos 1
        semestre.add(mkPlan(cola.first));
        sobrantes.addAll(cola.skip(1));
      }

      plan.add(SemestrePlan(numero: plan.length + 1, materias: semestre));

      for (final mp in semestre) {
        asignadas.add(mp.materia.codigo);
        cubiertas.add(mp.materia.codigo);
        pendientes.remove(mp.materia.codigo);
      }

      // La cola del próximo semestre arranca con los sobrantes
      cola = sobrantes;
    }

    // Si aún quedan pendientes (por ciclos o prerreq. no resueltos)
    // ponerlos en semestres extra
    while (pendientes.isNotEmpty) {
      final disponibles = pendientes
          .where((c) => porCodigo[c]!.prerrequisitos
              .every((p) => cubiertas.contains(p)))
          .toList();
      if (disponibles.isEmpty) break;

      disponibles.sort((a, b) {
        final ma = porCodigo[a]!;
        final mb = porCodigo[b]!;
        final nc = ma.nivel.compareTo(mb.nivel);
        return nc != 0 ? nc : mb.creditos.compareTo(ma.creditos);
      });

      final List<MateriaPlan> semestre = [];
      int usados = 0;
      for (final c in disponibles) {
        final creditos = porCodigo[c]!.creditos;
        if (usados + creditos <= params.maxCreditos) {
          semestre.add(mkPlan(c));
          usados += creditos;
        }
      }
      if (semestre.isEmpty) break;

      plan.add(SemestrePlan(numero: plan.length + 1, materias: semestre));
      for (final mp in semestre) {
        cubiertas.add(mp.materia.codigo);
        pendientes.remove(mp.materia.codigo);
      }
    }

    // ── 9. R5: combinar semestres muy pequeños ───────────────
    // Si un semestre tiene menos de minCreditos y el siguiente
    // tiene espacio, fusionarlos (reduce semestres totales)
    _fusionarSemestresVacios(plan, params.maxCreditos, params.minCreditos, porCodigo);

    // ── 10. R1: Práctica al final con máx 1 materia extra ────
    final practicaPendiente =
        (cpPpal != null && !cubiertas.contains(cpPpal)) ||
        (cpSec  != null && !cubiertas.contains(cpSec));

    if (practicaPendiente) {
      final List<MateriaPlan> ultimoSem = [mkPlan('PRACTICA_UNICA')];

      // Buscar si el último semestre real tiene exactamente 1 materia
      // pequeña que se puede mover aquí
      if (plan.isNotEmpty) {
        final penultimo = plan.last;
        if (penultimo.materias.length == 1 &&
            penultimo.totalCreditos + 9 <= params.maxCreditos) {
          // Mover esa materia al semestre de prácticas
          ultimoSem.addAll(penultimo.materias);
          plan.removeLast();
        }
      }

      plan.add(SemestrePlan(
        numero: plan.length + 1,
        materias: ultimoSem,
        esUltimo: true,
      ));
    }

    // Renumerar correctamente
    for (int i = 0; i < plan.length; i++) {
      plan[i] = SemestrePlan(
        numero: i + 1,
        materias: plan[i].materias,
        esPrimero: plan[i].esPrimero,
        esUltimo: plan[i].esUltimo,
      );
    }

    return plan;
  }

  // ── Utilidades ───────────────────────────────────────────

  static int creditosAprobados({
    required Programa programa,
    required Set<String> aprobadas,
  }) =>
      programa.materias
          .where((m) => aprobadas.contains(m.codigo))
          .fold(0, (s, m) => s + m.creditos);

  static double porcentajeAvance({
    required Programa programa,
    required Set<String> aprobadas,
  }) {
    if (programa.totalCreditos == 0) return 0;
    return creditosAprobados(programa: programa, aprobadas: aprobadas) /
        programa.totalCreditos;
  }

  static List<Materia> materiasAdelantables(Programa programa) {
    final cp = _codigosPractica[programa.codigo] ?? '';
    return programa.materias
        .where((m) => m.prerrequisitos.isEmpty && m.codigo != cp)
        .toList();
  }

  static Set<String> materiasCompartidasEntre(Programa p1, Programa p2) {
    final c1 = p1.materias.map((m) => m.codigo).toSet();
    final c2 = p2.materias.map((m) => m.codigo).toSet();
    return c1.intersection(c2);
  }
}

// ── Fusionar semestres con pocos créditos ────────────────────
void _fusionarSemestresVacios(
  List<SemestrePlan> plan,
  int maxCr,
  int minCr,
  Map<String, Materia> porCodigo,
) {
  bool cambio = true;
  while (cambio) {
    cambio = false;
    for (int i = 0; i < plan.length - 1; i++) {
      final actual = plan[i];
      final siguiente = plan[i + 1];

      // No tocar el primer semestre fijo ni el último (prácticas)
      if (actual.esPrimero || actual.esUltimo) continue;
      if (siguiente.esUltimo) continue;

      // Si el semestre actual tiene pocos créditos Y caben en el siguiente
      if (actual.totalCreditos < minCr) {
        final totalJunto =
            actual.totalCreditos + siguiente.totalCreditos;
        if (totalJunto <= maxCr) {
          // Verificar que no haya conflicto de prerrequisitos
          // (una materia de "actual" no puede ser prereq de "siguiente")
          final codigosActual =
              actual.materias.map((m) => m.materia.codigo).toSet();
          final haConflicto = siguiente.materias.any((mp) =>
              mp.materia.prerrequisitos
                  .any((p) => codigosActual.contains(p)));

          if (!haConflicto) {
            // Fusionar: mover materias de "actual" al "siguiente"
            final fusionado = SemestrePlan(
              numero: siguiente.numero,
              materias: [...actual.materias, ...siguiente.materias],
              esPrimero: actual.esPrimero,
              esUltimo: siguiente.esUltimo,
            );
            plan[i + 1] = fusionado;
            plan.removeAt(i);
            cambio = true;
            break;
          }
        }
      }
    }
  }
}

// ── Helper: cubre el primer slot de electiva disponible ──────
void _cubrirSlot(
    String codigoOpcion, Programa programa, Set<String> cubiertas) {
  for (final grupo in programa.gruposElectivas) {
    if (!grupo.opciones.any((o) => o.codigo == codigoOpcion)) continue;
    if (cubiertas.contains(grupo.slotCodigo)) continue;
    cubiertas.add(grupo.slotCodigo);
    return;
  }
}