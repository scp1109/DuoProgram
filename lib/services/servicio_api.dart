// ============================================================
//  servicio_api.dart
//  Unico punto de contacto de la app con el backend (FastAPI).
//
//  Todas las peticiones pasan por _enviar(), que centraliza lo
//  que antes se repetia copiado en cada metodo: armar headers,
//  poner el Bearer, aplicar timeout, traducir el 401 a
//  SesionExpiradaException, verificar el 200 y decodificar el
//  cuerpo. Los metodos publicos quedan como envoltorios finos
//  que solo dicen ruta, cuerpo y que mensaje mostrar si falla.
// ============================================================

import 'dart:async'; // necesario para TimeoutException
import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint / kDebugMode
import 'package:http/http.dart' as http;

// Excepcion especial para token expirado (401).
// Se lanza desde cualquier endpoint que requiera autenticacion.
class SesionExpiradaException implements Exception {
  const SesionExpiradaException();
  @override
  String toString() => 'La sesion ha expirado. Por favor recarga la pagina para continuar.';
}

// Firma de la funcion que arma el mensaje de error cuando el backend
// responde algo distinto de 200. Cada endpoint tiene su propio texto
// (unos usan el `detail` de FastAPI, otros un mensaje fijo).
typedef _ConstructorMensajeError = String Function(http.Response respuesta);

class ServicioApi {
  // URL de la API. El default apunta al backend LOCAL porque el
  // despliegue de Railway esta pausado (trial vencido); mientras siga
  // asi, un default remoto solo produce timeouts en cada arranque.
  //
  // Se sobreescribe al compilar, sin editar este archivo:
  //
  //   flutter run   --dart-define=API_URL=http://localhost:8000
  //   flutter build web --dart-define=API_URL=https://mi-api.example.com
  //
  // Valores utiles segun donde corra la app:
  //   Chrome / escritorio  http://localhost:8000
  //   Emulador Android     http://10.0.2.2:8000
  //   Dispositivo fisico   http://<ip-de-tu-pc>:8000  (API con --host 0.0.0.0)
  //
  // Para volver a produccion, pasar el --dart-define o cambiar este
  // default por la URL de despliegue:
  //   https://web-production-52f53.up.railway.app
  static const String urlBase = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );

  // ── Timeouts ────────────────────────────────────────────────
  // Antes cada metodo tenia el suyo (5s, 10s, 30s) y siete no tenian
  // ninguno, asi que se colgaban para siempre si el server no respondia.
  // Ahora hay dos valores y todos los metodos usan uno de los dos.

  // Timeout normal. Son 15s y no 5s porque Railway apaga el contenedor
  // cuando no hay trafico y el primer request tras el arranque en frio
  // tarda varios segundos en contestar.
  static const Duration _tiempoNormal = Duration(seconds: 15);

  // Timeout largo, solo para /plan/planificar: ese endpoint corre el
  // motor CPM completo y es el unico que legitimamente demora.
  static const Duration _tiempoLargo = Duration(seconds: 30);

  // ============================================================
  // HELPERS PRIVADOS
  // ============================================================

  // Headers comunes. El Bearer solo se agrega si hay token, porque los
  // endpoints publicos (/programas, /auth/login, /auth/registro) se
  // llaman sin sesion.
  Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // Decodifica el cuerpo de una respuesta exitosa.
  // Los endpoints que no devuelven datos (PUT /auth/perfil,
  // DELETE /plan/plan/{id}) igual mandan un JSON con {"message": ...},
  // pero si alguna vez llegara un 200 con cuerpo vacio (un proxy, por
  // ejemplo) json.decode reventaria, asi que en ese caso se devuelve null.
  //
  // Se decodifica desde bodyBytes con utf8.decode y NO desde .body:
  // FastAPI responde 'application/json' SIN declarar charset, y ante esa
  // ausencia el paquete http de Dart asume latin-1 (es lo que manda el
  // estandar HTTP). Como el cuerpo viene en UTF-8 crudo, los nombres de
  // la malla llegaban corruptos: "Calculo Diferencial" con tilde se veia
  // como "CÃ¡lculo". allowMalformed evita que una respuesta con bytes
  // rotos tumbe la pantalla; en ese caso se ven simbolos de reemplazo.
  dynamic _decodificar(http.Response respuesta) {
    if (respuesta.bodyBytes.isEmpty) return null;
    return json.decode(utf8.decode(respuesta.bodyBytes, allowMalformed: true));
  }

  // Saca el campo `detail` con el que FastAPI explica sus errores.
  //
  // El parseo va en su PROPIO try/catch a proposito: si se hace dentro
  // del mismo try que lanza la excepcion, ese catch termina atrapando su
  // propio throw y lo reemplaza por el mensaje generico. Ese era el bug
  // de cambiarContrasena: el backend devolvia "La contrasena actual es
  // incorrecta" y el usuario siempre veia "Error al cambiar contrasena".
  String _detalleBackend(http.Response respuesta, String porDefecto) {
    try {
      // Mismo motivo que en _decodificar: UTF-8 explicito, no .body
      final error = json.decode(utf8.decode(respuesta.bodyBytes, allowMalformed: true));
      final detalle = error is Map ? error['detail'] : null;
      if (detalle != null) return detalle.toString();
    } catch (_) {
      // El cuerpo no era JSON (pagina de error del proxy, HTML, vacio):
      // no hay nada que rescatar, se cae al mensaje por defecto.
    }
    return porDefecto;
  }

  // Ejecuta la peticion y devuelve el cuerpo ya decodificado.
  //
  // - `tiempoLimite`: por defecto el normal; planificar pasa el largo.
  // - `mensajeError`: como describir un status != 200. Si no se pasa,
  //   se usa 'Error HTTP: <codigo>'.
  // - `tolerarFallo`: si es true, un status != 200 devuelve null en vez
  //   de lanzar (el 401 con token sigue subiendo como sesion expirada).
  //   Lo usan los endpoints cuyo fallo no debe romper la pantalla
  //   (historial, lista de planes), que muestran una lista vacia y siguen.
  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    String? token,
    Object? cuerpo,
    Duration tiempoLimite = _tiempoNormal,
    _ConstructorMensajeError? mensajeError,
    bool tolerarFallo = false,
  }) async {
    final uri = Uri.parse('$urlBase$ruta');
    final headers = _headers(token: token);
    final cuerpoCodificado = cuerpo == null ? null : json.encode(cuerpo);

    final respuesta = await switch (metodo) {
      'GET' => http.get(uri, headers: headers),
      'POST' => http.post(uri, headers: headers, body: cuerpoCodificado),
      'PUT' => http.put(uri, headers: headers, body: cuerpoCodificado),
      'DELETE' => http.delete(uri, headers: headers),
      _ => throw ArgumentError('Metodo HTTP no soportado: $metodo'),
    }.timeout(tiempoLimite);

    // Un 401 se traduce a excepcion propia para que las pantallas manden
    // al login sin andar mirando codigos HTTP, pero SOLO si mandamos
    // token: si no hay sesion no hay nada que pueda expirar. La
    // distincion importa porque /auth/login tambien responde 401 cuando
    // la contrasena esta mala, y ahi el usuario tiene que leer "Email o
    // contrasena incorrectos", no "tu sesion vencio".
    if (respuesta.statusCode == 401 && token != null) {
      throw const SesionExpiradaException();
    }

    if (respuesta.statusCode != 200) {
      if (tolerarFallo) return null;
      throw Exception(
        mensajeError != null
            ? mensajeError(respuesta)
            : 'Error HTTP: ${respuesta.statusCode}',
      );
    }

    return _decodificar(respuesta);
  }

  // Atajos por verbo. Cada uno expone solo las opciones que sus
  // endpoints usan de verdad (por eso _delete no recibe cuerpo y solo
  // _post permite cambiar el timeout, que lo necesita planificar).

  Future<dynamic> _get(
    String ruta, {
    String? token,
    _ConstructorMensajeError? mensajeError,
    bool tolerarFallo = false,
  }) =>
      _enviar('GET', ruta,
          token: token, mensajeError: mensajeError, tolerarFallo: tolerarFallo);

  Future<dynamic> _post(
    String ruta, {
    String? token,
    Object? cuerpo,
    Duration tiempoLimite = _tiempoNormal,
    _ConstructorMensajeError? mensajeError,
  }) =>
      _enviar('POST', ruta,
          token: token,
          cuerpo: cuerpo,
          tiempoLimite: tiempoLimite,
          mensajeError: mensajeError);

  Future<dynamic> _put(
    String ruta, {
    String? token,
    Object? cuerpo,
    _ConstructorMensajeError? mensajeError,
  }) =>
      _enviar('PUT', ruta,
          token: token, cuerpo: cuerpo, mensajeError: mensajeError);

  Future<dynamic> _delete(
    String ruta, {
    String? token,
    _ConstructorMensajeError? mensajeError,
  }) =>
      _enviar('DELETE', ruta, token: token, mensajeError: mensajeError);

  // ============================================================
  // PROGRAMAS
  // ============================================================

  Future<List<Map<String, dynamic>>> obtenerProgramas() async {
    final data = await _get('/programas') as Map<String, dynamic>;
    return data.entries.map((entry) => {
      'codigo': entry.key,
      'nombre': entry.value['nombre'],
      'facultad': entry.value['facultad'],
      'total_creditos': entry.value['total_creditos'],
      'total_semestres': entry.value['total_semestres'],
    }).toList();
  }

  // Obtiene la malla completa de un programa desde la BD (materias, prereqs, electivas).
  // Reemplaza el acceso directo a programasDisponibles de datos_programa.dart.
  Future<Map<String, dynamic>> obtenerDetallePrograma(String codigo) async {
    return await _get('/programas/$codigo') as Map<String, dynamic>;
  }

  // ============================================================
  // AUTENTICACIÓN
  // ============================================================

  Future<Map<String, dynamic>> registro({
    required String nombreCompleto,
    required String correo,
    required String contrasena,
  }) async {
    return await _post(
      '/auth/registro',
      cuerpo: {
        'nombre_completo': nombreCompleto,
        'email': correo,
        'password': contrasena,
      },
      // El backend explica el motivo real ("El email ya esta registrado"),
      // asi que se muestra ese texto y no uno generico.
      mensajeError: (r) => _detalleBackend(r, 'Error en el registro'),
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    return await _post(
      '/auth/login',
      cuerpo: {
        'email': correo,
        'password': contrasena,
      },
      mensajeError: (r) => _detalleBackend(r, 'Error en el inicio de sesión'),
    ) as Map<String, dynamic>;
  }

  // ============================================================
  // PERFIL
  // ============================================================

  Future<Map<String, dynamic>> obtenerPerfil(String token) async {
    return await _get(
      '/auth/perfil',
      token: token,
      mensajeError: (_) => 'Error al obtener perfil',
    ) as Map<String, dynamic>;
  }

  Future<void> actualizarPerfil(String token, {
    required String nombreCompleto,
    required String correo,
  }) async {
    await _put(
      '/auth/perfil',
      token: token,
      cuerpo: {
        'nombre_completo': nombreCompleto,
        'email': correo,
      },
      // El backend responde 400 con detail "El email ya esta en uso".
      // Antes se descartaba y el usuario veia un generico que no le decia
      // como arreglarlo. Mismo caso que cambiarContrasena.
      mensajeError: (r) => _detalleBackend(r, 'Error al actualizar perfil'),
    );
  }

  Future<void> cambiarContrasena(String token, {
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    // El backend responde 400 con detail "La contrasena actual es
    // incorrecta", que es justo lo que el usuario necesita leer.
    // Antes ese mensaje se perdia (ver el comentario de _detalleBackend).
    await _post(
      '/auth/cambiar-password',
      token: token,
      cuerpo: {
        'old_password': contrasenaActual,
        'new_password': contrasenaNueva,
      },
      mensajeError: (r) => _detalleBackend(r, 'Error al cambiar contrasena'),
    );
  }

  // ============================================================
  // HISTORIAL
  // ============================================================

  Future<List<dynamic>> obtenerHistorial(String token) async {
    try {
      // El historial es informativo: si el server falla se muestra vacio
      // en vez de tumbar la pantalla de perfil.
      final data = await _get('/auth/historial', token: token, tolerarFallo: true);
      return (data as List<dynamic>?) ?? [];
    } on SesionExpiradaException {
      // El 401 si sube: hay que mandar al usuario al login.
      rethrow;
    } catch (e) {
      // Aqui caen los errores de red y los timeouts. Como el error no se
      // propaga, este es el unico lugar donde el log si aporta algo.
      if (kDebugMode) debugPrint('Error en obtenerHistorial: $e');
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
    // Ya no se manda `practica_unica`: el flag no hacia nada (la practica
    // del programa secundario siempre se descartaba, lo mandara el usuario
    // en true o en false) y el backend lo elimino del modelo.
    // `practicaSola` si funciona: deja el ultimo semestre solo con practica.
    bool practicaSola = false,
  }) async {
    try {
      return await _post(
        '/plan/planificar',
        token: token,
        cuerpo: {
          'codigo_programa_principal': programaPrincipal,
          'codigo_programa_secundario': programaSecundario,
          'aprobadas': aprobadas,
          'niveles_ingles_homologados': nivelesInglesHomologados,
          'promedio': promedio,
          'semestres_cursados': semestresCursados,
          'homologaciones_externas': homologacionesExternas,
          'practica_sola': practicaSola,
        },
        tiempoLimite: _tiempoLargo,
      ) as Map<String, dynamic>;
    } on TimeoutException {
      // El mensaje se arma con la constante para que no vuelva a quedar
      // desfasado: antes decia ">60s" cuando el timeout real era de 30s.
      throw Exception(
        'El servidor no respondio a tiempo (>${_tiempoLargo.inSeconds}s). '
        'Verifica que el backend esta corriendo en $urlBase.',
      );
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
    return await _post(
      '/plan/guardar-plan',
      token: token,
      cuerpo: {
        'nombre': nombre,
        'programa_principal': programaPrincipal,
        'programa_secundario': programaSecundario,
        'semestres_cursados': semestresCursados,
        'promedio': promedio,
        'materias_aprobadas': materiasAprobadas,
        'homologaciones': homologaciones,
        'plan_generado': planGenerado,
      },
      mensajeError: (r) => 'Error al guardar plan: ${r.statusCode}',
    ) as Map<String, dynamic>;
  }

  // Obtener todos los planes del usuario
  Future<List<dynamic>> obtenerMisPlanes(String token) async {
    // tolerarFallo: si el listado falla se muestra "no tienes planes"
    // en vez de un error, que es como se comportaba antes.
    final data = await _get('/plan/mis-planes', token: token, tolerarFallo: true);
    if (data == null) return [];
    return (data as Map<String, dynamic>)['planes'] as List<dynamic>? ?? [];
  }

  // Obtener un plan específico por ID
  Future<Map<String, dynamic>> obtenerPlan(String token, int planId) async {
    return await _get(
      '/plan/plan/$planId',
      token: token,
      mensajeError: (_) => 'Error al obtener el plan',
    ) as Map<String, dynamic>;
  }

  // Eliminar un plan
  Future<void> eliminarPlanGuardado(String token, int planId) async {
    await _delete(
      '/plan/plan/$planId',
      token: token,
      mensajeError: (_) => 'Error al eliminar el plan',
    );
  }
}
