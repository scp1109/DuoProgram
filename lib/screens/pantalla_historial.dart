// ============================================================
//  pantalla_historial.dart
//  Wizard de 3 pasos: Inglés → Homologaciones → Historial
//  El promedio ya no se pregunta una sola vez al inicio: se pide
//  dentro de cada semestre, porque el cupo de creditos depende del
//  promedio con que el estudiante llego a matricular ese semestre.
//  Conectado al backend FastAPI
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/datos_programa.dart';
import '../services/servicio_api.dart';
import '../models/modelo_plan.dart';
import 'pantalla_planificacion.dart';
import '../widgets/menu_lateral.dart';
import '../utils/sesion_helper.dart';
import '../theme/colores.dart';
import '../theme/movimiento.dart';
import '../theme/transiciones.dart';
import '../widgets/superficie.dart';
import '../widgets/historial/fila_materia.dart';
import '../widgets/numero_rodante.dart';

String _norm(String s) {
  const map = <String, String>{
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n',
  };
  return s.toLowerCase().replaceAllMapped(
    RegExp(r'[áéíóúñ]'),
    (m) => map[m[0]!] ?? m[0]!,
  );
}

class RegistroMateria {
  final String codigo;
  final int semestre;
  final bool aprobada;
  const RegistroMateria({
    required this.codigo,
    required this.semestre,
    required this.aprobada,
  });
}

class PantallaHistorial extends StatefulWidget {
  final Programa programa;
  final Programa? programaSecundario;
  final List<Map<String, dynamic>>? programas;
  final String token;
  final Map<String, dynamic> datosUsuario;

  const PantallaHistorial({
    super.key,
    required this.programa,
    this.programaSecundario,
    this.programas,
    required this.token,
    required this.datosUsuario,
  });

  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class FormatoDecimal extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue valorAnterior,
    TextEditingValue valorNuevo,
  ) {
    final estaBorrando = valorNuevo.text.length < valorAnterior.text.length;
    String texto = valorNuevo.text;
    if (estaBorrando) return valorNuevo;
    texto = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (texto.isEmpty) return const TextEditingValue(text: '');
    if (texto.length > 3) texto = texto.substring(0, 3);
    String formateado;
    if (texto.length == 1) {
      formateado = '$texto.';
    } else if (texto.length == 2) {
      formateado = '${texto[0]}.${texto[1]}';
    } else {
      formateado = '${texto[0]}.${texto.substring(1)}';
    }
    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  final ServicioApi _servicioApi = ServicioApi();
  bool _isGeneratingPlan = false;
  int _paso = 0;
  // Se elimino _practicaUnica: el backend ya no acepta `practica_unica`
  // porque el flag no tenia ningun efecto (una rama muerta descartaba
  // siempre la practica del programa secundario).
  bool _practicaSola = false;
  // ── Promedio POR SEMESTRE ────────────────────────────────────
  // Antes habia un unico _promedio global, lo que asumia que el
  // estudiante mantuvo la misma nota toda la carrera. En la practica
  // sube y baja: un semestre con 3.8 daba derecho a 18 creditos y el
  // siguiente con 4.2 a 20. Con un solo valor, la validacion del
  // historial quedaba mal en casi todos los semestres.
  //
  // Regla UTB: el cupo de creditos de un semestre lo define el promedio
  // con el que el estudiante llego a matricularlo, es decir el del
  // semestre ANTERIOR. Por eso el promedio del semestre N habilita al
  // N+1, y el semestre 1 usa un tope fijo (no hay promedio previo).
  final Map<int, double> _promediosPorSemestre = {};
  final Map<int, TextEditingController> _ctrlPromedioSem = {};

  final Set<int> _inglesHomologados = {};
  final List<HomologacionExterna> _homologacionesExternas = [];
  String _busqHomolog = '';
  final _ctrlHomolog = TextEditingController();

  final List<RegistroMateria> _registros = [];
  int _semestresCursados = 1;
  int? _semestreExpandido = 1;

  // Semestre cuyo encabezado esta pulsado ahora mismo. Es estado de
  // presentacion puro: la escala de presion se aplica a la tarjeta entera,
  // no solo a la fila que recibe el toque, asi que no puede vivir dentro
  // de un Presionable local.
  int? _semestrePresionado;

  // ── Cache de materias (inmutable durante esta pantalla) ────────────────────
  // Se construyen una vez en initState; los programas no cambian en esta pantalla.
  late final List<Materia> _cacheMaterias;
  late final List<Materia> _cacheMateriasYElectivas;
  late final Map<String, Materia> _indexMaterias;

  // ── Cache de aprobadas por semestre ───────────────────────────
  // Se recalcula SOLO cuando cambian _registros, _inglesHomologados o
  // _homologacionesExternas; no en cada setState del wizard.
  Map<int, Set<String>> _cacheAprobadas = {};
  Map<int, Set<String>> _cacheAprobadasRegistradas = {};

  @override
  void initState() {
    super.initState();
    // Construir lista unificada principal + secundario.
    //
    // Una misma materia puede exigir prerrequisitos distintos en cada
    // programa. Antes se descartaba el duplicado y ganaba la version del
    // principal, perdiendo los prerrequisitos del secundario. Ahora se
    // combinan con Materia.combinar, que compara lo que pide cada programa
    // con la cadena de prerrequisitos del otro: si uno queda dentro de la
    // cadena del otro se exigen ambas listas, y si no, son caminos
    // alternativos y basta con uno.
    final lista = [...widget.programa.materias];
    if (widget.programaSecundario != null) {
      final grafoP = Materia.grafoDe(widget.programa.materias);
      final grafoS = Materia.grafoDe(widget.programaSecundario!.materias);
      final memoP = <String, Set<String>>{};
      final memoS = <String, Set<String>>{};
      for (final m in widget.programaSecundario!.materias) {
        final i = lista.indexWhere((x) => x.codigo == m.codigo);
        if (i < 0) {
          lista.add(m);
          continue;
        }
        lista[i] = Materia.combinar(
          lista[i],
          m,
          cierreA: Materia.cierre(m.codigo, grafoP, memoP),
          cierreB: Materia.cierre(m.codigo, grafoS, memoS),
        );
      }
    }
    _cacheMaterias = List.unmodifiable(lista);

    // Agregar opciones de electivas
    final listaConElectivas = [...lista];
    for (final prog in [widget.programa, widget.programaSecundario]) {
      if (prog == null) continue;
      for (final grupo in prog.gruposElectivas) {
        for (final opcion in grupo.opciones) {
          if (!listaConElectivas.any((m) => m.codigo == opcion.codigo)) {
            listaConElectivas.add(opcion);
          }
        }
      }
    }
    _cacheMateriasYElectivas = List.unmodifiable(listaConElectivas);
    _indexMaterias = {for (final m in listaConElectivas) m.codigo: m};

    _recalcularAprobadas();
    final max = _maxSemestresCursados;
    if (_semestresCursados > max) {
      _semestresCursados = max;
      _semestreExpandido = max;
      _recalcularAprobadas();
    }
  }

  @override
  void dispose() {
    // La pantalla no liberaba ningun controlador. Con uno de promedio por
    // semestre son varios mas, asi que se cierran todos aqui.
    _ctrlHomolog.dispose();
    for (final c in _ctrlAdicional.values) {
      c.dispose();
    }
    for (final c in _ctrlPromedioSem.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Recalcula el cache de aprobadas para todos los semestres de una vez.
  // O(semestres × registros) total en lugar de O(semestres² × registros) por build.
  void _recalcularAprobadas() {
    final nuevoAprobadas = <int, Set<String>>{};
    final nuevoRegistradas = <int, Set<String>>{};
    for (int sem = 1; sem <= _semestresCursados + 2; sem++) {
      final validas = _aprobadasExternas();
      final registradasValidas = <String>{};
      for (int s = 1; s < sem; s++) {
        final validasAntes = Set<String>.from(validas);
        final nuevas = <String>{};
        for (final r in _registros.where((r) => r.semestre == s && r.aprobada)) {
          if (validas.contains(r.codigo)) continue;
          // Usar indexMaterias para lookup O(1)
          final mat = _indexMaterias[r.codigo];
          if (mat == null ||
              mat.requisitosCumplidos(validasAntes.contains)) {
            nuevas.add(r.codigo);
            registradasValidas.add(r.codigo);
          }
        }
        validas.addAll(nuevas);
      }
      nuevoAprobadas[sem] = validas;
      nuevoRegistradas[sem] = Set<String>.from(registradasValidas);
    }
    _cacheAprobadas = nuevoAprobadas;
    _cacheAprobadasRegistradas = nuevoRegistradas;
  }

  final Map<int, String> _busqAdicional = {};
  final Map<int, TextEditingController> _ctrlAdicional = {};
  final Map<int, bool> _mostrarAdicional = {};

  // ── Helpers ──────────────────────────────────────────────

  // Retorna la lista cacheada (no reconstruye en cada llamada)
  // List<Materia> get _todasLasMaterias => _cacheMaterias;

  /// Maximo de semestres cursados segun la malla (max nivel en ambos programas).
  int get _maxSemestresCursados {
    int maxNivel = 0;
    for (final m in _cacheMaterias) {
      if (m.nivel > maxNivel) maxNivel = m.nivel;
    }
    return maxNivel > 0 ? maxNivel : 10;
  }

  // Retorna la lista cacheada con electivas incluidas
  List<Materia> get _todasLasMateriasYElectivas => _cacheMateriasYElectivas;

  /// Red de seguridad para codigos cuyo prerrequisito no esta declarado en
  /// NINGUN programa de la BD. Ya no es la via principal: la union de
  /// prerrequisitos entre ambas mallas (ver initState) cubre el caso normal
  /// de que un programa lo declare y el otro no.
  static const Map<String, List<String>> _prerequisitosCanonicos = {
    'CBAS_E02A': ['CBAS_E01A'],
  };

  /// Fusiona prerrequisitos de todas las apariciones del codigo en ambas mallas.
  Materia? _materiaUnificada(String codigo) {
    final base = _indexMaterias[codigo];
    if (base == null) return null;
    // Merge prereqs del canonico si aplica
    final prereqsExtra = _prerequisitosCanonicos[codigo] ?? const [];
    if (prereqsExtra.isEmpty) return base;
    // El extra se suma a la lista y tambien a cada camino alternativo, para
    // no perder las alternativas al aplicar la red de seguridad.
    return base.conPrerrequisitos(
      {...base.prerrequisitos, ...prereqsExtra}.toList(),
      [
        for (final camino in base.alternativas)
          {...camino, ...prereqsExtra}.toList(),
      ],
    );
  }

  /// Prerrequisito aprobado en semestres anteriores validos.
  bool _prereqCumplido(String prereq, int semestre) {
    if (_aprobadasValidasAntesDeSemestre(semestre).contains(prereq)) return true;
    return _registros.any(
      (r) => r.codigo == prereq && r.semestre < semestre && r.aprobada,
    );
  }

  bool _prerrequisitosCumplidos(String codigo, int semestre) {
    final mat = _materiaUnificada(codigo);
    if (mat == null) return true;
    return mat.requisitosCumplidos((p) => _prereqCumplido(p, semestre));
  }

  Set<String> get _aprobadas =>
      _aprobadasRegistradasValidasAntesDeSemestre(_semestresCursados + 1);

  Set<String> get _todasAprobadas {
    final set = _aprobadas;
    for (final h in _homologacionesExternas) {
      set.add(h.codigoMateria);
    }
    for (final n in _inglesHomologados) {
      if (n >= 1 && n <= codigosIngles.length) set.add(codigosIngles[n - 1]);
    }
    return set;
  }

  List<RegistroMateria> _registrosDeSemestre(int sem) =>
      _registros.where((r) => r.semestre == sem).toList();

  Set<String> _aprobadasExternas() {
    return {
      ..._homologacionesExternas.map((h) => h.codigoMateria),
      ..._inglesHomologados
          .where((n) => n >= 1 && n <= codigosIngles.length)
          .map((n) => codigosIngles[n - 1]),
    };
  }

  // Retorna del cache. El cache se recalcula en _recalcularAprobadas()
  // cada vez que cambian los registros, no durante el build.
  Set<String> _aprobadasValidasAntesDeSemestre(int semestre) {
    return _cacheAprobadas[semestre] ?? _aprobadasExternas();
  }

  Set<String> _aprobadasRegistradasValidasAntesDeSemestre(int semestre) {
    return _cacheAprobadasRegistradas[semestre] ?? <String>{};
  }

  // Calcula en que semestre debe aparecer cada ingles pendiente.
  // Regla: el primer ingles no homologado arranca en semestre 2,
  // pero si se pierde, el siguiente no aparece hasta que el anterior este aprobado.
  // Se calcula dinamicamente basado en los registros reales del estudiante.
  Map<String, int> _inglesNivelAjustadoParaSemestre(int semestre, Set<String> aprobadasAntes) {
    final ajustados = <String, int>{};
    // El primer ingles pendiente arranca en semestre 2
    int semBase = 2;
    for (int i = 0; i < codigosIngles.length; i++) {
      final codigo = codigosIngles[i];
      final nivel = i + 1;
      if (_inglesHomologados.contains(nivel)) continue;
      // Este ingles aparece solo si el anterior ya fue aprobado
      // (o es el primero de la cadena)
      if (i > 0) {
        final anterior = codigosIngles[i - 1];
        // Si el anterior no esta aprobado, este no aparece aun
        if (!aprobadasAntes.contains(anterior)) break;
        // El semestre de este ingles es el siguiente al que fue aprobado el anterior
        final semAprobadoAnterior = _registros
            .where((r) => r.codigo == anterior && r.aprobada)
            .map((r) => r.semestre)
            .fold<int>(0, (prev, s) => s > prev ? s : prev);
        if (semAprobadoAnterior > 0) {
          semBase = semAprobadoAnterior + 1;
        }
      }
      ajustados[codigo] = semBase;
      semBase++;
    }
    return ajustados;
  }

  // Calcula los creditos totales cursados en un semestre
  // (malla + adicionales, sin importar si aprobo o perdio)
  int _creditosSemestre(int semestre) {
    int total = 0;
    for (final r in _registrosDeSemestre(semestre)) {
      final mat = _indexMaterias[r.codigo];
      total += mat?.creditos ?? 0;
    }
    return total;
  }

  // ── Topes de creditos por semestre (reglamento UTB) ───────
  // Regla general: un estudiante con buen promedio puede matricular mas
  // creditos que uno que va justo.
  static const double _promedioParaCupoAmpliado = 4.0;
  static const int _maxCreditosPromedioAlto = 20;
  static const int _maxCreditosPromedioBajo = 18;

  // El semestre 1 no tiene promedio previo con que calcular el cupo, asi
  // que usa un tope fijo. 18 alcanza para el primer semestre de las cuatro
  // mallas (la mas cargada es IMEC con 18 cr).
  static const int _maxCreditosPrimerSemestre = 18;

  // Rango valido de una nota en la UTB.
  static const double _promedioMinimo = 3.0;
  static const double _promedioMaximo = 5.0;

  /// Creditos que la malla del programa principal asigna a ese nivel.
  ///
  /// Sirve de PISO del tope: si la propia universidad matricula 21 creditos
  /// en un semestre, no tiene sentido marcarlo como excedido porque el
  /// estudiante no puede quitar materias obligatorias. Antes esto estaba
  /// parchado a mano solo para CDAT semestre 4; la regla general tambien
  /// cubre IIND semestre 2 e IMEC semestre 3, que traen 19 creditos y con
  /// promedio bajo quedaban marcados como excedidos sin arreglo posible.
  int _creditosMallaDelNivel(int semestre) => widget.programa.materias
      .where((m) => m.nivel == semestre)
      .fold(0, (total, m) => total + m.creditos);

  /// Promedio que habilito el cupo de ese semestre: el del semestre anterior.
  /// Null en el semestre 1 (no hay previo) o si aun no se ha ingresado.
  double? _promedioQueHabilita(int semestre) =>
      semestre <= 1 ? null : _promediosPorSemestre[semestre - 1];

  bool _promedioValido(double? p) =>
      p != null && p >= _promedioMinimo && p <= _promedioMaximo;

  /// Tope de creditos del semestre indicado.
  int _maxCreditosParaSemestre(int semestre) {
    final int base;
    if (semestre <= 1) {
      base = _maxCreditosPrimerSemestre;
    } else {
      final previo = _promedioQueHabilita(semestre);
      if (!_promedioValido(previo)) {
        // Todavia no sabemos el promedio previo. Se asume el cupo alto para
        // no marcar el semestre en rojo antes de que el usuario lo escriba;
        // igual no se puede generar el plan sin completarlos todos.
        base = _maxCreditosPromedioAlto;
      } else {
        base = previo! >= _promedioParaCupoAmpliado
            ? _maxCreditosPromedioAlto
            : _maxCreditosPromedioBajo;
      }
    }
    final piso = _creditosMallaDelNivel(semestre);
    return base > piso ? base : piso;
  }

  List<int> get _semestresExcedidos {
    final excedidos = <int>[];
    for (int semestre = 1; semestre <= _semestresCursados; semestre++) {
      if (_creditosSemestre(semestre) > _maxCreditosParaSemestre(semestre)) {
        excedidos.add(semestre);
      }
    }
    return excedidos;
  }

  bool get _haySemestresExcedidos => _semestresExcedidos.isNotEmpty;

  /// Semestres cursados a los que todavia les falta el promedio.
  /// Se piden TODOS: los intermedios habilitan el cupo del siguiente y el
  /// ultimo define con cuanto cupo arranca el plan futuro.
  List<int> get _semestresSinPromedio => [
        for (int s = 1; s <= _semestresCursados; s++)
          if (!_promedioValido(_promediosPorSemestre[s])) s,
      ];

  /// Promedio que se manda al backend para topear los semestres futuros:
  /// el del ultimo semestre cursado, que es el que la UTB mira al matricular
  /// el siguiente.
  double get _promedioParaPlanFuturo =>
      _promediosPorSemestre[_semestresCursados] ?? _promedioParaCupoAmpliado;

  List<Materia> _materiasDelNivel(int nivel) =>
      widget.programa.materias.where((m) => m.nivel == nivel).toList();

  bool _estaHomologadaExterna(String codigo) =>
      _homologacionesExternas.any((h) => h.codigoMateria == codigo);

  bool _estaInglesHomologado(String codigo) {
    final idx = codigosIngles.indexOf(codigo);
    if (idx < 0) return false;
    return _inglesHomologados.contains(idx + 1);
  }

  bool _fueRegistrada(String codigo, int semestre) =>
      _registros.any((r) => r.codigo == codigo && r.semestre == semestre);

  double get _avance {
    final totalMaterias = widget.programa.materias.length;
    if (totalMaterias == 0) return 0;
    final aprobadas = _todasAprobadas
        .where((c) => widget.programa.materias.any((m) => m.codigo == c))
        .length;
    return aprobadas / totalMaterias;
  }

  int get _creditosAprobados {
    int creditos = 0;
    for (final m in widget.programa.materias) {
      if (_todasAprobadas.contains(m.codigo)) creditos += m.creditos;
    }
    return creditos;
  }

  void _registrar(String codigo, int semestre, bool aprobada) {
    if (aprobada && !_prerrequisitosCumplidos(codigo, semestre)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes marcar esta materia como aprobada: faltan prerrequisitos aprobados.',
          ),
          backgroundColor: Colores.error,
        ),
      );
      return;
    }
    setState(() {
      final idx = _registros
          .indexWhere((r) => r.codigo == codigo && r.semestre == semestre);
      if (idx >= 0) {
        _registros[idx] =
            RegistroMateria(codigo: codigo, semestre: semestre, aprobada: aprobada);
      } else {
        _registros.add(
            RegistroMateria(codigo: codigo, semestre: semestre, aprobada: aprobada));
      }
      // Recalcular el cache DESPUES de modificar _registros
      _recalcularAprobadas();
    });
  }

  void _quitarRegistro(String codigo, int semestre) {
    setState(() {
      _registros.removeWhere((r) => r.codigo == codigo && r.semestre == semestre);
      _recalcularAprobadas();
    });
  }

  List<Materia> _buscarMaterias(String query,
      {int? excluirSemestre, Set<String>? aprobadas}) {
    if (query.trim().isEmpty) return [];
    final q = _norm(query);
    return _todasLasMateriasYElectivas.where((m) {
      if (excluirSemestre != null && _fueRegistrada(m.codigo, excluirSemestre)) {
        return false;
      }
      if (excluirSemestre != null &&
          !_prerrequisitosCumplidos(m.codigo, excluirSemestre)) {
        return false;
      }
      if (aprobadas != null &&
          !(_materiaUnificada(m.codigo) ?? m)
              .requisitosCumplidos(aprobadas.contains)) {
        return false;
      }
      // No mostrar materias de la malla cuyo nivel sea <= al semestre actual.
      // Solo se pueden adelantar materias de nivel estrictamente mayor.
      // Esto evita buscar E02A (nivel 4) en semestre 3 aunque E01A ya este aprobada.
      if (excluirSemestre != null) {
        final matMalla = [
          ...widget.programa.materias,
          ...?widget.programaSecundario?.materias
        ].where((mat) => mat.codigo == m.codigo).firstOrNull;
        if (matMalla != null && matMalla.nivel <= excluirSemestre) return false;
      }
      return _norm(m.nombre).contains(q) || _norm(m.codigo).contains(q);
    }).toList();
  }

  Future<void> _irAPlanificacion() async {
    // Sin el promedio de cada semestre no se puede validar el historial ni
    // saber con cuanto cupo arranca el plan futuro.
    final sinPromedio = _semestresSinPromedio;
    if (sinPromedio.isNotEmpty) {
      final lista = sinPromedio.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(_aviso(sinPromedio.length == 1
          ? 'Falta el promedio del semestre $lista.'
          : 'Faltan los promedios de los semestres $lista.'));
      setState(() => _semestreExpandido = sinPromedio.first);
      return;
    }

    if (_haySemestresExcedidos) {
      final semestres = _semestresExcedidos.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(_aviso(
          'Corrige los semestres $semestres: superan el límite de créditos permitido.'));
      return;
    }

    setState(() => _isGeneratingPlan = true);
    try {
      final homologacionesList = _homologacionesExternas
          .map((h) => {
                'codigo_materia': h.codigoMateria,
                'nombre_programa': h.nombrePrograma,
              })
          .toList();

      final respuesta = await _servicioApi.planificar(
        token: widget.token,
        programaPrincipal: widget.programa.codigo,
        programaSecundario: widget.programaSecundario?.codigo,
        aprobadas: _aprobadas.toList(),
        nivelesInglesHomologados: _inglesHomologados.toList(),
        promedio: _promedioParaPlanFuturo,
        semestresCursados: _semestresCursados,
        homologacionesExternas: homologacionesList,
        practicaSola: _practicaSola,
      );

      final respuestaPlan = RespuestaPlan.fromJson(respuesta);

      if (mounted) {
        setState(() => _isGeneratingPlan = false);
        Navigator.push(
          context,
          RutaProfundidad(
            pagina: PantallaPlanificacion(
              respuestaPlan: respuestaPlan,
              programaPrincipal: widget.programa,
              programaSecundario: widget.programaSecundario,
              token: widget.token,
              datosUsuario: widget.datosUsuario,
              datosPlan: respuesta,
              semestresCursados: _semestresCursados,
              promedio: _promedioParaPlanFuturo,
              materiasAprobadas: _aprobadas.toList(),
              homologaciones: homologacionesList,
            ),
          ),
        );
      }
    } on SesionExpiradaException {
      if (mounted) {
        setState(() => _isGeneratingPlan = false);
        await SesionHelper.manejarSesionExpirada(context);
      }
    } catch (e) {
      // Las otras dos ramas ya comprobaban `mounted`; esta se habia quedado
      // sin guarda y crasheaba si el usuario salia mientras se generaba
      // el plan (setState y ScaffoldMessenger tras el await).
      if (!mounted) return;
      setState(() => _isGeneratingPlan = false);
      ScaffoldMessenger.of(context).showSnackBar(_aviso(
          'Error al generar el plan: ${e.toString().replaceAll('Exception: ', '')}'));
    }
  }

  /// SnackBar del sistema: flotante, con el radio de tarjeta y la tinta de
  /// error de la paleta. Antes cada aviso repetia su propio estilo y uno
  /// de ellos usaba Colors.red, que no pertenece a la paleta.
  SnackBar _aviso(String mensaje) => SnackBar(
        content: Text(mensaje,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colores.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Superficies.radioInterior),
        ),
        // 4 s alcanzan para un aviso corto, no para "no se pudo armar el
        // plan" con la lista de materias: ~15 caracteres por segundo, hasta 12.
        duration: Duration(seconds: (mensaje.length / 15).ceil().clamp(4, 12)),
      );

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colores.fondoApp,
      drawer: MenuLateral(token: widget.token, datosUsuario: widget.datosUsuario),
      // El AppBar no pinta una franja propia: comparte el azul con el panel
      // de pasos que va debajo, asi no queda costura entre los dos.
      appBar: AppBar(
        backgroundColor: Colores.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Mi Historial Académico',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildIndicador(),
          Expanded(child: _buildPaso()),
        ],
      ),
    );
  }

  Widget _buildIndicador() {
    // El paso 'Promedio' desaparecio: ahora se pregunta dentro de cada
    // semestre del historial, no una vez para toda la carrera.
    const labels = ['Inglés', 'Homologaciones', 'Historial'];
    const iconos = [
      Icons.language_rounded,
      Icons.verified_rounded,
      Icons.checklist_rounded,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 22),
      decoration: const BoxDecoration(
        // Azul de marca solido, mismo criterio que la cabecera de seleccion.
        color: Colores.primario,
        // Esquinas inferiores redondeadas: deja de ser una franja pegada de
        // lado a lado y pasa a leerse como panel apoyado sobre el contenido.
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(labels.length, (i) {
          final activo = i == _paso;
          final completado = i < _paso;
          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      // El paso activo se agranda un poco. La escala es lo
                      // unico que aguanta la curva de resorte; la decoracion
                      // se anima aparte con la curva principal.
                      AnimatedScale(
                        scale: activo ? 1.08 : 1,
                        duration: Movimiento.corta,
                        curve: Movimiento.resorte,
                        child: AnimatedContainer(
                          duration: Movimiento.corta,
                          curve: Movimiento.principal,
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: completado
                                ? Colores.exito
                                : activo
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.12),
                            // Radio concentrico respecto al panel: la ficha
                            // se curva menos que el contenedor que la rodea.
                            borderRadius: BorderRadius.circular(
                                Superficies.radioInterno(
                                    Superficies.radioTarjeta, 12)),
                            border: Border.all(
                              color: completado || activo
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.18),
                            ),
                            boxShadow:
                                activo ? Superficies.sutil : Superficies.ninguna,
                          ),
                          child: Icon(
                            completado ? Icons.check_rounded : iconos[i],
                            size: 17,
                            color: completado
                                ? Colors.black
                                : activo
                                    ? Colores.primario
                                    : Colores.primarioSuave,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.2,
                          color: activo
                              ? Colors.white
                              : completado
                                  ? Colores.exito
                                  : Colores.primarioSuave
                                      .withValues(alpha: 0.75),
                          fontWeight:
                              activo ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // El conector solo va ENTRE pasos. Antes la condicion era
                // `i < 3` con tres etiquetas, asi que dibujaba tambien una
                // linea suelta despues del ultimo.
                if (i < labels.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: AnimatedContainer(
                      duration: Movimiento.corta,
                      curve: Movimiento.principal,
                      width: 18,
                      height: 2,
                      decoration: BoxDecoration(
                        color: i < _paso
                            ? Colores.exito
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius:
                            BorderRadius.circular(Superficies.radioPildora),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }













  Widget _buildPaso() {
    switch (_paso) {
      case 0: return _buildIngles();
      case 1: return _buildHomologExternas();
      case 2: return _buildHistorial();
      default: return const SizedBox();
    }
  }

  // ── PASO 0: Inglés ────────────────────────────────────────
  Widget _buildIngles() {
    const nombres = [
      'Lengua Extranjera I', 'Lengua Extranjera II',
      'Lengua Extranjera III', 'Lengua Extranjera IV', 'Lengua Extranjera V',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Revelar(child: Cejilla('Paso 1 de 3 · Inglés')),
          const SizedBox(height: 16),
          const Revelar(
            indice: 1,
            child: Text(
              'Niveles de inglés homologados',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                // Tracking negativo: en titulares grandes el espaciado por
                // defecto se ve suelto y abarata el conjunto.
                letterSpacing: -1,
                height: 1.1,
                color: Colores.textoTitulo,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Revelar(
            indice: 2,
            child: Text(
              'Marca los niveles que ya tienes homologados por examen. '
              'Estos no aparecerán en tu historial ni en el plan futuro.',
              style: TextStyle(
                  fontSize: 14, height: 1.45, color: Colores.textoSecundario),
            ),
          ),
          const SizedBox(height: 28),
          ...List.generate(5, (i) {
            final nivel = i + 1;
            final marcado = _inglesHomologados.contains(nivel);
            return Revelar(
              indice: i + 3,
              child: _filaIngles(nivel, nombres[i], marcado),
            );
          }),
          if (_inglesHomologados.isNotEmpty) ...[
            const SizedBox(height: 10),
            Revelar(
              indice: 8,
              child: TarjetaBisel(
                padding: const EdgeInsets.all(14),
                acento: Colores.primario,
                sombra: Superficies.sutil,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 18, color: Colores.primario),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_inglesHomologados.length} nivel(es) homologado(s). '
                        'En tu historial aparecerán marcados automáticamente '
                        'y no tendrás que registrarlos.',
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Colores.primario,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 34),
          Row(children: [
            // Ingles es ahora el PRIMER paso (antes lo era Promedio), asi que
            // el boton de atras sale de la pantalla en vez de retroceder.
            _btnSecundario(() => Navigator.pop(context)),
            const SizedBox(width: 12),
            Expanded(
              child: BotonIsla(
                texto: 'Siguiente',
                onTap: () => setState(() => _paso = 1),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// Fila seleccionable de un nivel de ingles, con el mismo bisel doble que
  /// las tarjetas de programa: marco tenue afuera, nucleo blanco adentro y
  /// radios concentricos entre los dos.
  Widget _filaIngles(int nivel, String nombre, bool marcado) {
    return Presionable(
      onTap: () => setState(() {
        if (marcado) {
          for (int n = nivel; n <= 5; n++) {
            _inglesHomologados.remove(n);
          }
        } else {
          for (int n = 1; n <= nivel; n++) {
            _inglesHomologados.add(n);
          }
        }
        // Ingles homologado afecta las aprobadas externas
        _recalcularAprobadas();
      }),
      child: AnimatedContainer(
        duration: Movimiento.corta,
        curve: Movimiento.principal,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: marcado
              ? Colores.primario.withValues(alpha: 0.12)
              : Superficies.brumaLavanda,
          borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
          border: Border.all(
            color: marcado
                ? Colores.primario.withValues(alpha: 0.45)
                : Superficies.nieblaAzul.withValues(alpha: 0.6),
          ),
          boxShadow: marcado ? Superficies.sutil : Superficies.ambiente,
        ),
        child: AnimatedContainer(
          duration: Movimiento.corta,
          curve: Movimiento.principal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
                Superficies.radioInterno(Superficies.radioTarjeta, 5)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Movimiento.corta,
                curve: Movimiento.principal,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: marcado
                      ? Colores.primario
                      : Colores.primario.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(
                      Superficies.radioInterno(Superficies.radioTarjeta, 12)),
                  border: Border.all(
                    color: Colores.primario
                        .withValues(alpha: marcado ? 0.45 : 0.14),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$nivel',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.3,
                      color: marcado ? Colors.white : Colores.primario,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                    fontWeight: marcado ? FontWeight.w700 : FontWeight.w500,
                    color: marcado ? Colores.primario : Colores.textoOscuro,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Circulo de estado: se enciende, no aparece de la nada.
              AnimatedContainer(
                duration: Movimiento.corta,
                curve: Movimiento.principal,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: marcado
                      ? Colores.primario
                      : Superficies.nieblaAzul.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: marcado
                      ? Colors.white
                      : Colores.textoTenue.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PASO 1: Homologaciones externas ──────────────────────
  Widget _buildHomologExternas() {
    final resultados = _buscarMaterias(_busqHomolog);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Revelar(
                  child: Cejilla('Paso 2 de 3 · Homologaciones',
                      color: Colores.acentoMorado)),
              const SizedBox(height: 16),
              const Revelar(
                indice: 1,
                child: Text(
                  'Homologaciones externas',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1.1,
                    color: Colores.textoTitulo,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Revelar(
                indice: 2,
                child: Text(
                  'Busca materias homologadas mediante Talento Tech, '
                  'acuerdos con directores u otros programas. '
                  'Si no tienes, pasa al siguiente paso.',
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colores.textoSecundario),
                ),
              ),
              const SizedBox(height: 22),
              if (_homologacionesExternas.isNotEmpty) ...[
                TarjetaBisel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  acento: Colores.acentoMorado,
                  sombra: Superficies.sutil,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Cejilla('Ya homologadas',
                          color: Colores.acentoMorado),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _homologacionesExternas.map((h) {
                          final mat = _todasLasMateriasYElectivas.firstWhere(
                              (m) => m.codigo == h.codigoMateria,
                              orElse: () => Materia(
                                  codigo: h.codigoMateria,
                                  nombre: h.codigoMateria,
                                  creditos: 0,
                                  nivel: 0));
                          return Chip(
                            label: Text('${mat.nombre} · ${h.nombrePrograma}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colores.acentoMorado)),
                            backgroundColor:
                                Colores.acentoMorado.withValues(alpha: 0.10),
                            side: BorderSide(
                                color: Colores.acentoMorado
                                    .withValues(alpha: 0.35)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  Superficies.radioPildora),
                            ),
                            deleteIcon: const Icon(Icons.close_rounded,
                                size: 14, color: Colores.acentoMorado),
                            onDeleted: () => setState(() =>
                                _homologacionesExternas.removeWhere(
                                    (x) => x.codigoMateria == h.codigoMateria)),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _ctrlHomolog,
                decoration: _inputDeco(
                    'Busca la materia (sin tildes también funciona)',
                    icon: Icons.search),
                onChanged: (v) => setState(() => _busqHomolog = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _busqHomolog.isEmpty
              ? _vacio(Icons.verified_outlined, 'Escribe para buscar materias',
                  'Las materias homologadas quedan marcadas en todo tu historial.')
              : resultados.isEmpty
                  ? _vacio(Icons.search_off_rounded,
                      'No se encontraron materias', 'Prueba con otro nombre.')
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      itemCount: resultados.length > 6 ? 6 : resultados.length,
                      itemBuilder: (_, i) {
                        final m = resultados[i];
                        final yaHom = _estaHomologadaExterna(m.codigo);
                        return Revelar(
                          indice: i,
                          child: CardHomologacion(
                            materia: m,
                            yaAgregada: yaHom,
                            onAgregar: (prog) {
                              setState(() {
                                _homologacionesExternas.removeWhere(
                                    (h) => h.codigoMateria == m.codigo);
                                _homologacionesExternas.add(HomologacionExterna(
                                  codigoMateria: m.codigo,
                                  nombrePrograma: prog,
                                ));
                                _busqHomolog = '';
                                _ctrlHomolog.clear();
                                // Homologaciones externas afectan las aprobadas
                                _recalcularAprobadas();
                              });
                            },
                            onQuitar: () => setState(() {
                              _homologacionesExternas.removeWhere(
                                  (h) => h.codigoMateria == m.codigo);
                              _recalcularAprobadas();
                            }),
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(children: [
            _btnSecundario(() => setState(() => _paso = 0)),
            const SizedBox(width: 12),
            Expanded(
              child: BotonIsla(
                texto: 'Ir al historial',
                onTap: () => setState(() => _paso = 2),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  /// Estado vacio con la misma respiracion que el resto: icono en su propia
  /// ficha, titular y una linea de contexto. Antes era un icono gris suelto.
  Widget _vacio(IconData icono, String titulo, String detalle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Superficies.brumaLavanda,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Superficies.nieblaAzul.withValues(alpha: 0.8)),
              ),
              child: Icon(icono,
                  size: 30, color: Colores.primario.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: Colores.textoOscuro,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.4, color: Colores.textoTenue),
            ),
          ],
        ),
      ),
    );
  }

  // ── PASO 2: Historial ─────────────────────────────────────
  Widget _buildHistorial() {
    final semestresExcedidos = _semestresExcedidos;
    final hayExcedidos = semestresExcedidos.isNotEmpty;

    return Column(
      children: [
        _panelEstadisticas(semestresExcedidos, hayExcedidos),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            // Nota de contexto + un item por semestre + pie con los
            // controles. Se mantiene el builder para no construir de golpe
            // los diez semestres de la malla.
            itemCount: _semestresCursados + 2,
            itemBuilder: (_, i) {
              if (i == 0) return _notaHistorial();
              if (i <= _semestresCursados) {
                return Revelar(indice: i - 1, child: _buildSemestre(i));
              }
              return _pieHistorial();
            },
          ),
        ),
        _barraGenerarPlan(hayExcedidos),
      ],
    );
  }

  /// Resumen de avance. Va como tarjeta apoyada sobre el fondo y no como
  /// franja azul de lado a lado: mismo azul de marca que la cabecera, pero
  /// con las cuatro esquinas curvadas y sombra tintada.
  Widget _panelEstadisticas(List<int> excedidos, bool hayExcedidos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: Colores.primario,
          borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
          boxShadow: Superficies.elevada,
        ),
        child: Column(
          children: [
            Row(children: [
              _stat('Aprobadas', _todasAprobadas.length),
              _divV(),
              _stat('Créditos', _creditosAprobados),
              _divV(),
              _stat('Avance', (_avance * 100).round(), sufijo: '%'),
              _divV(),
              // Antes decia 'Semestres' con el valor '3 cursados', que a
              // 14px ya se desbordaba. La palabra se movio a la etiqueta.
              _stat('Cursados', _semestresCursados),
            ]),
            const SizedBox(height: 14),
            // La barra usa la MISMA duracion y curva que las cifras, para
            // que el relleno y el conteo de 'Avance' lleguen juntos al
            // final. Con duraciones distintas se nota el desfase.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _avance),
              duration: _duracionContador,
              curve: Movimiento.principal,
              builder: (context, valor, child) => ClipRRect(
                borderRadius:
                    BorderRadius.circular(Superficies.radioPildora),
                child: LinearProgressIndicator(
                  value: valor,
                  minHeight: 9,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colores.exito),
                ),
              ),
            ),
            if (hayExcedidos) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: Colores.error.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(
                      Superficies.radioInterno(Superficies.radioTarjeta, 8)),
                  border:
                      Border.all(color: Colores.error.withValues(alpha: 0.7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_rounded,
                        color: Colores.errorSuave, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Semestres ${excedidos.join(', ')} superan el límite de créditos permitido. Quita materias para generar el plan.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Nota de contexto del paso. Antes era otra franja de borde a borde;
  /// ahora es un bloque con la misma inserccion lateral que las tarjetas.
  Widget _notaHistorial() => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colores.fondoPrimarioSuave,
          borderRadius: BorderRadius.circular(Superficies.radioInterior),
          border:
              Border.all(color: Superficies.nieblaAzul.withValues(alpha: 0.8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: Colores.primario),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Registra qué materias cursaste en cada semestre. '
                'Los ingleses homologados y las homologaciones externas '
                'ya aparecen marcados automáticamente.',
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: Colores.textoOscuro),
              ),
            ),
          ],
        ),
      );

  /// Pie de la lista: agregar/quitar semestre y la opcion de practica sola.
  /// Viven dentro del scroll para que la lista de semestres se quede con
  /// todo el alto util de la pantalla.
  Widget _pieHistorial() {
    final puedeAgregar = _semestresCursados < _maxSemestresCursados;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              if (_semestresCursados > 1) ...[
                Presionable(
                  onTap: () => setState(() => _semestresCursados--),
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colores.error.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(Superficies.radioInterior),
                      border: Border.all(
                          color: Colores.error.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.remove_rounded,
                        size: 20, color: Colores.error),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Presionable(
                  onTap: puedeAgregar
                      ? () {
                          setState(() => _semestresCursados++);
                          WidgetsBinding.instance.addPostFrameCallback((_) =>
                              setState(() =>
                                  _semestreExpandido = _semestresCursados));
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: Movimiento.corta,
                    curve: Movimiento.principal,
                    height: 52,
                    decoration: BoxDecoration(
                      color: puedeAgregar
                          ? Colores.primario.withValues(alpha: 0.07)
                          : Colores.fondoNeutro,
                      borderRadius:
                          BorderRadius.circular(Superficies.radioInterior),
                      border: Border.all(
                        color: puedeAgregar
                            ? Colores.primario.withValues(alpha: 0.35)
                            : Superficies.nieblaAzul,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          puedeAgregar
                              ? Icons.add_rounded
                              : Icons.check_rounded,
                          size: 19,
                          color: puedeAgregar
                              ? Colores.primario
                              : Colores.textoTenue,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            puedeAgregar
                                ? 'Agregar semestre ${_semestresCursados + 1}'
                                : 'Máximo $_maxSemestresCursados semestres',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: puedeAgregar
                                  ? Colores.primario
                                  : Colores.textoTenue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TarjetaBisel(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            acento: _practicaSola ? Colores.acentoNaranja : null,
            sombra: Superficies.ambiente,
            child: SwitchListTile(
              title: const Text(
                'Semestre dedicado solo a Prácticas',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: Colores.textoTitulo),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'El último semestre estará dedicado únicamente a Prácticas '
                  'Profesionales, sin otras materias.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colores.textoSecundario),
                ),
              ),
              value: _practicaSola,
              onChanged: (value) => setState(() => _practicaSola = value),
              activeThumbColor: Colores.primario,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// Barra fija con el CTA del wizard.
  Widget _barraGenerarPlan(bool hayExcedidos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Row(
        children: [
          _btnSecundario(() => setState(() => _paso = 1)),
          const SizedBox(width: 12),
          Expanded(
            child: BotonIsla(
              texto: _isGeneratingPlan
                  ? 'Generando plan...'
                  : hayExcedidos
                      ? 'Corrige créditos excedidos'
                      : 'Generar mi plan',
              icono: hayExcedidos
                  ? Icons.warning_rounded
                  : Icons.auto_awesome_rounded,
              color: hayExcedidos ? Colores.error : Colores.exito,
              // Negro sobre el verde de exito: es el par con contraste
              // suficiente, el blanco sobre ese verde no lo tiene.
              colorTexto: hayExcedidos ? Colors.white : Colors.black,
              cargando: _isGeneratingPlan,
              onTap: (_isGeneratingPlan || hayExcedidos)
                  ? null
                  : _irAPlanificacion,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemestre(int semestre) {
    final esPrimero = semestre == 1;
    final expandido = _semestreExpandido == semestre;
    final creditosSemestre = _creditosSemestre(semestre);
    final creditosMax = _maxCreditosParaSemestre(semestre);
    final excedeCreditos = creditosSemestre > creditosMax;
    final faltaPromedio = !_promedioValido(_promediosPorSemestre[semestre]);

    // Aprobadas ANTES de este semestre — no incluye lo registrado en el mismo semestre.
    // Se usa para filtrar prereqs al inicio del semestre, no durante el redibujado.
    final aprobadasAntesDeSemestre =
        _aprobadasValidasAntesDeSemestre(semestre);

    // Materias del nivel filtradas por:
    // - ingles homologado (no aparece)
    // - prereqs no cumplidos al inicio del semestre (no aparece)
    final materiasDelNivel = _materiasDelNivel(semestre)
        .where((m) => !_estaInglesHomologado(m.codigo))
        .where((m) => _prerrequisitosCumplidos(m.codigo, semestre))
        .toList();

    // Materias perdidas en semestres anteriores que deben reaparecer.
    // Se verifica que sus prereqs esten cumplidos Y que no haya una version
    // posterior aprobada sin haber aprobado esta (ej. no vale aprobar E02A
    // si E01A esta perdida, E01A debe reaparecer como pendiente)
    final perdidasAntes = _registros
        .where((r) => r.semestre < semestre && !r.aprobada)
        .map((r) => r.codigo)
        .toSet();
    for (final codigo in perdidasAntes) {
      final yaAprobada = _registros.any(
          (r) => r.codigo == codigo && r.semestre < semestre && r.aprobada);
      if (!yaAprobada && !materiasDelNivel.any((m) => m.codigo == codigo)) {
        final mat = _materiaUnificada(codigo) ??
            Materia(codigo: codigo, nombre: codigo, creditos: 0, nivel: semestre);
        if (_prerrequisitosCumplidos(codigo, semestre)) {
          materiasDelNivel.add(mat);
        }
      }
    }

    // Materias de nivel < semestre cuyos prereqs recien se cumplieron
    // (ej. Dinamica nivel 4 aparece en sem 5 si Estatica se aprobo en sem 4)
    // Solo programa principal para no mezclar con el secundario
    for (final mat in widget.programa.materias) {
      if (mat.nivel >= semestre) continue;
      if (materiasDelNivel.any((m) => m.codigo == mat.codigo)) continue;
      if (_estaInglesHomologado(mat.codigo)) continue;
      if (_registros.any((r) => r.codigo == mat.codigo)) continue;
      if (_prerrequisitosCumplidos(mat.codigo, semestre)) {
        materiasDelNivel.add(mat);
      }
    }

    // Agregar ingles ajustado al semestre correspondiente.
    // Se calcula dinamicamente para que el siguiente ingles no aparezca
    // hasta que el anterior este aprobado.
    final inglesAjustado = _inglesNivelAjustadoParaSemestre(semestre, aprobadasAntesDeSemestre);
    for (final entry in inglesAjustado.entries) {
      if (entry.value == semestre) {
        final mat = widget.programa.materias.firstWhere(
          (m) => m.codigo == entry.key,
          orElse: () =>
              widget.programaSecundario?.materias.firstWhere(
                (m) => m.codigo == entry.key,
                orElse: () => Materia(
                    codigo: entry.key, nombre: entry.key, creditos: 2, nivel: semestre),
              ) ??
              Materia(codigo: entry.key, nombre: entry.key, creditos: 2, nivel: semestre),
        );
        if (!materiasDelNivel.any((m) => m.codigo == mat.codigo)) {
          materiasDelNivel.add(mat);
        }
      }
    }

    final registros = _registrosDeSemestre(semestre);
    // Cuenta aprobadas de malla + adicionales del semestre
    final aprobCount = registros.where((r) => r.aprobada).length;
    final totalReg = registros.length;

    _ctrlAdicional.putIfAbsent(semestre, () => TextEditingController());

    if (esPrimero) {
      for (final m in materiasDelNivel) {
        if (!_fueRegistrada(m.codigo, 1)) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _registrar(m.codigo, 1, true));
        }
      }
    }

    // Tinte del marco. Misma prioridad que tenia el borde anterior
    // (excedido > con aprobadas > neutro), solo que ahora tambien tinta el
    // relleno del marco exterior.
    final Color acento = excedeCreditos
        ? Colores.error
        : aprobCount > 0
            ? Colores.exito
            : Superficies.nieblaAzul;
    final bool destacado = excedeCreditos || aprobCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnimatedScale(
        // El resorte solo toca la escala. En una decoracion extrapolaria el
        // blur a negativo y Flutter lanza el assert (ver movimiento.dart).
        scale: _semestrePresionado == semestre ? 0.985 : 1,
        duration: Movimiento.instante,
        curve: Movimiento.resorte,
        child: AnimatedContainer(
          duration: Movimiento.corta,
          curve: Movimiento.principal,
          // Marco exterior del bisel doble.
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: destacado
                ? acento.withValues(alpha: 0.10)
                : Superficies.brumaLavanda,
            borderRadius: BorderRadius.circular(Superficies.radioTarjeta),
            border: Border.all(
              color: destacado
                  ? acento.withValues(alpha: 0.45)
                  : Superficies.nieblaAzul.withValues(alpha: 0.6),
            ),
            // Abierta, la tarjeta se despega del fondo; cerrada vuelve a la
            // sombra ambiental. Se interpola con la curva principal, que se
            // queda dentro de [0, 1].
            boxShadow: expandido ? Superficies.elevada : Superficies.ambiente,
          ),
          child: AnimatedContainer(
            duration: Movimiento.corta,
            curve: Movimiento.principal,
            // Las filas de materia llegan de borde a borde, asi que el
            // nucleo recorta para que no pisen la curva.
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              // Radio concentrico: el exterior menos el grosor del marco.
              borderRadius: BorderRadius.circular(
                  Superficies.radioInterno(Superficies.radioTarjeta, 6)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) =>
                      setState(() => _semestrePresionado = semestre),
                  onTapUp: (_) => setState(() => _semestrePresionado = null),
                  onTapCancel: () =>
                      setState(() => _semestrePresionado = null),
                  onTap: () => setState(
                      () => _semestreExpandido = expandido ? null : semestre),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                    child: Row(
                      children: [
                        // Ficha del numero: el mismo bisel de la tarjeta,
                        // a menor escala.
                        AnimatedContainer(
                          duration: Movimiento.corta,
                          curve: Movimiento.principal,
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: aprobCount > 0
                                ? Colores.exito
                                : Superficies.brumaLavanda,
                            borderRadius: BorderRadius.circular(
                                Superficies.radioInterno(
                                    Superficies.radioTarjeta, 12)),
                            border: Border.all(
                              color: aprobCount > 0
                                  ? Colores.exito
                                  : Superficies.nieblaAzul,
                            ),
                          ),
                          child: Center(
                            child: Text('$semestre',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: -0.3,
                                    color: aprobCount > 0
                                        ? Colors.black
                                        : Colores.textoSecundario)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Wrap y no Row: con tres etiquetas el
                              // encabezado se desbordaba en pantallas
                              // angostas.
                              Wrap(
                                spacing: 6,
                                runSpacing: 5,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('Semestre $semestre',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: -0.3,
                                          color: Colores.textoTitulo)),
                                  if (esPrimero)
                                    _pill('Auto', Colores.primario),
                                  if (excedeCreditos)
                                    _pill('Excede', Colores.error),
                                  if (faltaPromedio)
                                    _pill('Falta promedio',
                                        Colores.advertencia,
                                        colorTexto: Colores.advertenciaOscura),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalReg == 0
                                    ? 'Sin materias registradas'
                                    : excedeCreditos
                                        ? '$aprobCount aprobadas · $totalReg cursadas · $creditosSemestre/$creditosMax cr'
                                        : '$aprobCount aprobadas · $totalReg cursadas · $creditosSemestre cr',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: excedeCreditos
                                        ? Colores.error
                                        : Colores.textoSecundario,
                                    fontWeight: excedeCreditos
                                        ? FontWeight.w700
                                        : FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // El chevron gira en vez de cambiar de icono: el
                        // movimiento explica que es la misma pieza.
                        AnimatedRotation(
                          turns: expandido ? 0.5 : 0,
                          duration: Movimiento.corta,
                          curve: Movimiento.principal,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Superficies.brumaLavanda,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Superficies.nieblaAzul),
                            ),
                            child: const Icon(Icons.expand_more_rounded,
                                size: 18, color: Colores.primario),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // El cuerpo crece y se encoge en vez de aparecer de golpe.
                AnimatedSize(
                  duration: Movimiento.corta,
                  curve: Movimiento.principal,
                  alignment: Alignment.topCenter,
                  child: !expandido
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 1,
                              color: Superficies.nieblaAzul
                                  .withValues(alpha: 0.7),
                            ),
                            _buildPromedioSemestre(semestre),
                            if (materiasDelNivel.isNotEmpty)
                              _seccion('Materias de la malla'),
                            ...materiasDelNivel.map((m) {
                              final reg = _registros.firstWhere(
                                  (r) =>
                                      r.codigo == m.codigo &&
                                      r.semestre == semestre,
                                  orElse: () => RegistroMateria(
                                      codigo: '',
                                      semestre: 0,
                                      aprobada: false));
                              final tieneReg = reg.codigo.isNotEmpty;
                              final aprobadaAntes = semestre > 1 &&
                                  _registros.any((r) =>
                                      r.codigo == m.codigo &&
                                      r.semestre < semestre &&
                                      r.aprobada);
                              final homologadaExt =
                                  _estaHomologadaExterna(m.codigo);

                              return FilaMateria(
                                nombre: m.nombre,
                                estado: homologadaExt
                                    ? EstadoMateria.homologada
                                    : aprobadaAntes
                                        ? EstadoMateria.aprobadaAntes
                                        : !tieneReg
                                            ? EstadoMateria.sinRegistrar
                                            : reg.aprobada
                                                ? EstadoMateria.aprobada
                                                : EstadoMateria.perdida,
                                bloqueada: esPrimero ||
                                    aprobadaAntes ||
                                    homologadaExt,
                                etiquetaExtra: homologadaExt
                                    ? _homologacionesExternas
                                        .firstWhere(
                                            (h) => h.codigoMateria == m.codigo)
                                        .nombrePrograma
                                    : null,
                                onAprobada: (esPrimero ||
                                        aprobadaAntes ||
                                        homologadaExt)
                                    ? null
                                    : () =>
                                        _registrar(m.codigo, semestre, true),
                                onPerdida: (esPrimero ||
                                        aprobadaAntes ||
                                        homologadaExt)
                                    ? null
                                    : () =>
                                        _registrar(m.codigo, semestre, false),
                                onQuitar: (esPrimero ||
                                        aprobadaAntes ||
                                        homologadaExt ||
                                        !tieneReg)
                                    ? null
                                    : () =>
                                        _quitarRegistro(m.codigo, semestre),
                              );
                            }),
                            () {
                              final adicionales = _registrosDeSemestre(semestre)
                                  .where((r) => !materiasDelNivel
                                      .any((m) => m.codigo == r.codigo))
                                  .toList();
                              if (adicionales.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _seccion('Materias adicionales'),
                                  ...adicionales.map((r) {
                                    final mat = _todasLasMateriasYElectivas
                                        .firstWhere(
                                            (m) => m.codigo == r.codigo,
                                            orElse: () => Materia(
                                                codigo: r.codigo,
                                                nombre: r.codigo,
                                                creditos: 0,
                                                nivel: 0));
                                    return FilaMateria(
                                      nombre: mat.nombre,
                                      estado: r.aprobada
                                          ? EstadoMateria.aprobada
                                          : EstadoMateria.perdida,
                                      bloqueada: false,
                                      onAprobada: () => _registrar(
                                          mat.codigo, semestre, true),
                                      onPerdida: () => _registrar(
                                          mat.codigo, semestre, false),
                                      onQuitar: () => _quitarRegistro(
                                          mat.codigo, semestre),
                                    );
                                  }),
                                ],
                              );
                            }(),
                            _buildBuscadorAdicionales(
                                semestre, aprobadasAntesDeSemestre),
                            const SizedBox(height: 14),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Campo de promedio de UN semestre.
  ///
  /// El valor no limita a su propio semestre sino al siguiente: en la UTB el
  /// cupo de creditos se define con el promedio que el estudiante traia al
  /// matricular. Por eso el texto de ayuda habla siempre del semestre N+1,
  /// y en el ultimo semestre cursado habla del plan que se va a generar.
  Widget _buildPromedioSemestre(int semestre) {
    final ctrl = _ctrlPromedioSem.putIfAbsent(semestre, () {
      final guardado = _promediosPorSemestre[semestre];
      return TextEditingController(
        text: guardado == null ? '' : guardado.toStringAsFixed(1),
      );
    });

    final valor = _promediosPorSemestre[semestre];
    final escrito = ctrl.text.trim().isNotEmpty;
    final valido = _promedioValido(valor);
    final invalido = escrito && !valido;
    final esUltimo = semestre == _semestresCursados;

    // Cupo que este promedio habilita para el semestre siguiente.
    final cupo = (valor != null && valor >= _promedioParaCupoAmpliado)
        ? _maxCreditosPromedioAlto
        : _maxCreditosPromedioBajo;

    final Color color;
    final String mensaje;
    if (invalido) {
      color = Colores.error;
      mensaje = 'La nota debe estar entre '
          '${_promedioMinimo.toStringAsFixed(1)} y '
          '${_promedioMaximo.toStringAsFixed(1)}.';
    } else if (!valido) {
      color = Colores.textoSecundario;
      mensaje = esUltimo
          ? 'Con este promedio se calcula cuantos creditos puedes tomar en tu plan.'
          : 'Con este promedio se calcula el cupo del semestre ${semestre + 1}.';
    } else if (valor! >= _promedioParaCupoAmpliado) {
      color = Colores.exitoOscuro;
      mensaje = esUltimo
          ? 'Promedio >= ${_promedioParaCupoAmpliado.toStringAsFixed(1)} -> tu plan usara hasta $cupo creditos por semestre.'
          : 'Promedio >= ${_promedioParaCupoAmpliado.toStringAsFixed(1)} -> en el semestre ${semestre + 1} pudiste matricular hasta $cupo creditos.';
    } else {
      color = Colores.advertenciaOscura;
      mensaje = esUltimo
          ? 'Promedio < ${_promedioParaCupoAmpliado.toStringAsFixed(1)} -> tu plan usara hasta $cupo creditos por semestre.'
          : 'Promedio < ${_promedioParaCupoAmpliado.toStringAsFixed(1)} -> en el semestre ${semestre + 1} solo pudiste matricular hasta $cupo creditos.';
    }

    // Pregunta: icono en su propia ficha + titular.
    final titulo = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colores.primario.withValues(alpha: 0.09),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bar_chart_rounded,
              size: 16, color: Colores.primario),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '¿Con qué promedio terminaste el semestre $semestre?',
              style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.3,
                  letterSpacing: -0.2,
                  fontWeight: FontWeight.w700,
                  color: Colores.textoTitulo),
            ),
          ),
        ),
      ],
    );

    final campo = TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      // maxLength 4 evita que 2.9999 se redondee a 3.0 por float
      maxLength: 4,
      inputFormatters: [FormatoDecimal()],
      style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3),
      decoration: InputDecoration(
        counterText: '',
        hintText: '4.0',
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Superficies.radioInterior),
          borderSide: BorderSide(
              color: invalido ? Colores.error : Superficies.nieblaAzul),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Superficies.radioInterior),
          borderSide: const BorderSide(color: Colores.primario, width: 1.5),
        ),
      ),
      onChanged: (texto) {
        setState(() {
          final p = double.tryParse(texto.trim());
          if (p == null) {
            _promediosPorSemestre.remove(semestre);
          } else {
            // Se recorta a 2 decimales igual que antes, para que
            // 3.999 no cuente como 4.0 por precision de float.
            _promediosPorSemestre[semestre] =
                double.parse(p.toStringAsFixed(2));
          }
        });
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: AnimatedContainer(
        duration: Movimiento.corta,
        curve: Movimiento.principal,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: invalido
              ? Colores.error.withValues(alpha: 0.06)
              : Superficies.brumaLavanda,
          borderRadius: BorderRadius.circular(Superficies.radioInterior),
          border: Border.all(
            color: invalido
                ? Colores.error.withValues(alpha: 0.5)
                : Superficies.nieblaAzul,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, cons) {
            // Con el campo al lado del titulo, en un movil de 360dp al
            // titular le quedan menos de 160px y parte la pregunta en
            // cuatro lineas. Por debajo de ese ancho el campo baja a su
            // propia fila y el titulo se lee de corrido.
            final apretado = cons.maxWidth < 340;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (apretado) ...[
                  titulo,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(width: 104, child: campo),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Nota final del semestre, sobre 5.0',
                          style: TextStyle(
                              fontSize: 11.5, color: Colores.textoTenue),
                        ),
                      ),
                    ],
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: titulo),
                      const SizedBox(width: 14),
                      SizedBox(width: 96, child: campo),
                    ],
                  ),
                const SizedBox(height: 10),
                Text(mensaje,
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBuscadorAdicionales(int semestre, Set<String> aprobadas) {
    final mostrar = _mostrarAdicional[semestre] ?? false;
    final query = _busqAdicional[semestre] ?? '';
    final creditosUsados = _creditosSemestre(semestre);
    final creditosMax = _maxCreditosParaSemestre(semestre);
    final creditosDisponibles = creditosMax - creditosUsados;
    final limiteAlcanzado = creditosDisponibles <= 0;
    final resultados =
        _buscarMaterias(query, excluirSemestre: semestre, aprobadas: aprobadas);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Presionable(
            // Si el limite de creditos fue alcanzado no se puede abrir el buscador
            onTap: limiteAlcanzado
                ? null
                : () => setState(() => _mostrarAdicional[semestre] = !mostrar),
            child: AnimatedContainer(
              duration: Movimiento.corta,
              curve: Movimiento.principal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: limiteAlcanzado
                    ? Colores.fondoNeutro
                    : mostrar
                        ? Colores.acentoCian.withValues(alpha: 0.12)
                        : Colores.acentoCian.withValues(alpha: 0.06),
                borderRadius:
                    BorderRadius.circular(Superficies.radioPildora),
                border: Border.all(
                    color: limiteAlcanzado
                        ? Superficies.nieblaAzul
                        : Colores.acentoCian
                            .withValues(alpha: mostrar ? 0.9 : 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    limiteAlcanzado
                        ? Icons.block_rounded
                        : mostrar
                            ? Icons.remove_rounded
                            : Icons.add_rounded,
                    size: 15,
                    color: limiteAlcanzado
                        ? Colores.textoTenue
                        : Colores.acentoCianOscuro),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      limiteAlcanzado
                          ? 'Límite de $creditosMax créditos alcanzado'
                          : '¿Diste materias adicionales este semestre?',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: -0.1,
                          color: limiteAlcanzado
                              ? Colores.textoTenue
                              : Colores.acentoCianOscuro,
                          fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          if (mostrar) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _ctrlAdicional[semestre],
              decoration: _inputDeco(
                  'Busca por nombre (sin tildes también funciona)',
                  icon: Icons.search),
              onChanged: (v) => setState(() => _busqAdicional[semestre] = v),
            ),
            if (query.isNotEmpty)
              // Bucle con indice en vez de map: `Revelar` necesita la
              // posicion para escalonar la cascada.
              for (int i = 0; i < resultados.length && i < 5; i++)
                Revelar(
                  indice: i,
                  desplazamiento: 14,
                  child: _resultadoAdicional(
                      resultados[i], semestre, creditosDisponibles),
                ),
            if (query.isNotEmpty && resultados.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('No se encontraron materias',
                    style: TextStyle(fontSize: 12, color: Colores.textoTenue)),
              ),
          ],
        ],
      ),
    );
  }

  /// Una fila de resultado del buscador de materias adicionales.
  Widget _resultadoAdicional(
      Materia m, int semestre, int creditosDisponibles) {
    // Verificar si agregar esta materia excederia el limite de creditos
    final excederia = creditosDisponibles < m.creditos;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Superficies.brumaLavanda,
        borderRadius: BorderRadius.circular(Superficies.radioInterior),
        border: Border.all(
          color: excederia
              ? Colores.error.withValues(alpha: 0.3)
              : Superficies.nieblaAzul,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.nombre,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: excederia
                            ? Colores.textoTenue
                            : Colores.textoTitulo)),
                const SizedBox(height: 2),
                Text(
                    excederia
                        ? '${m.creditos} cr · excede el límite ($creditosDisponibles disponibles)'
                        : '${m.creditos} cr · quedan $creditosDisponibles disponibles',
                    style: TextStyle(
                        fontSize: 11,
                        color: excederia
                            ? Colores.error
                            : Colores.textoTenue)),
              ],
            ),
          ),
          if (!excederia) ...[
            const SizedBox(width: 8),
            _mini('Aprobé', Colores.exito, () {
              _registrar(m.codigo, semestre, true);
              setState(() {
                _busqAdicional[semestre] = '';
                _ctrlAdicional[semestre]!.clear();
                _mostrarAdicional[semestre] = false;
              });
            }),
            const SizedBox(width: 6),
            _mini('Perdí', Colores.error, () {
              _registrar(m.codigo, semestre, false);
              setState(() {
                _busqAdicional[semestre] = '';
                _ctrlAdicional[semestre]!.clear();
                _mostrarAdicional[semestre] = false;
              });
            }),
          ],
        ],
      ),
    );
  }

  // ── Widgets reutilizables ─────────────────────────────────
  // _btnPrimario desaparecio: los CTA del wizard ahora son BotonIsla, que
  // es el boton del sistema (icono anidado en su propio circulo).

  /// Boton de retroceso. Misma altura que BotonIsla para que la fila de
  /// acciones quede alineada.
  Widget _btnSecundario(VoidCallback onTap) => Presionable(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Superficies.brumaLavanda,
            borderRadius: BorderRadius.circular(Superficies.radioPildora),
            border: Border.all(
                color: Colores.primario.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.arrow_back_rounded,
              size: 20, color: Colores.primario),
        ),
      );

  Widget _mini(String label, Color color, VoidCallback onTap) => Presionable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(Superficies.radioPildora),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color == Colores.exito
                      ? Colores.exitoOscuro
                      : Colores.errorOscuro)),
        ),
      );

  /// Etiqueta de estado del encabezado de semestre. [colorTexto] existe
  /// porque el blanco sobre el amarillo de advertencia no tiene contraste.
  Widget _pill(String label, Color color,
          {Color colorTexto = Colors.white}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Superficies.radioPildora)),
        child: Text(label,
            style: TextStyle(
                color: colorTexto,
                fontSize: 9.5,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w800)),
      );

  /// Rotulo de seccion dentro de una tarjeta de semestre. Usa la Cejilla del
  /// sistema en vez de un texto gris suelto.
  Widget _seccion(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Cejilla(label),
        ),
      );

  /// Duracion del conteo de las cifras y del relleno de la barra.
  ///
  /// AJUSTA AQUI la velocidad del contador. Es la misma para las cifras y
  /// para la barra a proposito: son la misma informacion contada de dos
  /// formas y deben aterrizar a la vez, asi que un solo numero las gobierna.
  /// Mas milisegundos = mas lento. Por debajo de ~900 el rodado se percibe
  /// como un parpadeo; por encima de ~3000 el usuario ya esta esperando.
  static const Duration _duracionContador = Duration(milliseconds: 1900);

  /// Estilo de las cifras del panel. Se declara aparte porque el contador
  /// rodante lo necesita para medir la altura de la cinta de digitos.
  static const TextStyle _estiloCifra = TextStyle(
      color: Colors.white,
      fontSize: 19,
      letterSpacing: -0.6,
      fontWeight: FontWeight.w800);

  Widget _stat(String label, int valor, {String sufijo = ''}) => Expanded(
        child: Column(children: [
          NumeroRodante(
              valor: valor,
              sufijo: sufijo,
              estilo: _estiloCifra,
              duracion: _duracionContador),
          const SizedBox(height: 3),
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colores.primarioSuave,
                  fontSize: 9,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _divV() => Container(
        height: 26,
        width: 1,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(Superficies.radioPildora),
        ),
      );

  InputDecoration _inputDeco(String hint, {required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: Colores.textoTenue),
        prefixIcon: Icon(icon, color: Colores.textoTenue, size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Superficies.radioInterior),
          borderSide: const BorderSide(color: Superficies.nieblaAzul),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Superficies.radioInterior),
          borderSide: const BorderSide(color: Colores.primario, width: 2),
        ),
      );
}
