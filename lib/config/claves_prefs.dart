// ============================================================
//  claves_prefs.dart
//  Nombres de las claves que la app guarda en SharedPreferences.
//
//  Antes cada pantalla escribia el string a mano ('token',
//  'user_data', 'foto_perfil_$id'...). Eso ya habia causado que
//  una pantalla guardara con una clave y otra leyera con otra
//  ligeramente distinta, y ademas al cerrar sesion era facil
//  olvidar borrar alguna. Centralizar las claves aqui hace que
//  el compilador avise si alguien se equivoca al escribirla.
//
//  USO:
//    final prefs = await SharedPreferences.getInstance();
//    await prefs.setString(ClavesPrefs.token, token);
//    final foto = prefs.getString(ClavesPrefs.fotoPerfil(idUsuario));
// ============================================================

class ClavesPrefs {
  // Constructor privado: esta clase es solo un contenedor de
  // constantes, no tiene sentido instanciarla.
  ClavesPrefs._();

  // ── Sesion ────────────────────────────────────────────────
  // JWT que devuelve el backend en /auth/login y /auth/registro.
  static const String token = 'token';

  // JSON del usuario logueado (id, nombre_completo, email...).
  static const String datosUsuario = 'user_data';

  // Claves que se borran al cerrar sesion o al expirar el token.
  // Ojo: las fotos de perfil NO van aqui a proposito, porque
  // dependen del id del usuario y se conservan entre sesiones
  // para no volver a pedirle la imagen cada vez que entra.
  static const List<String> clavesDeSesion = [token, datosUsuario];

  // ── Foto de perfil ────────────────────────────────────────
  // La foto se guarda distinto segun la plataforma:
  //  - en web no hay rutas de archivo accesibles, asi que se
  //    guarda la imagen entera codificada en base64;
  //  - en movil/escritorio basta con guardar la ruta del archivo.
  // Por eso son dos claves separadas y no una sola.
  // Ambas llevan el id del usuario para que en un mismo
  // dispositivo dos cuentas no se pisen la foto.

  // Foto en base64 (plataforma web).
  static String fotoPerfilWeb(Object idUsuario) => 'foto_perfil_web_$idUsuario';

  // Ruta del archivo de la foto (movil y escritorio).
  static String fotoPerfil(Object idUsuario) => 'foto_perfil_$idUsuario';
}
