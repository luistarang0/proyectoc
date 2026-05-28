/// @file: sam_response_model.dart
/// @project: Control de Accesos - GAMA
/// @description: Modelos de serialización para las respuestas del web
///   service SAM. Encapsula el parsing del JSON que retorna
///   obtenerDatosMaster y los datos de sesión del flujo de login.
///   Referencia: Sección 5.1 del Manual de Programación Flutter (MPF).
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

/// Modelo inmutable con la información del empleado obtenida de SAM.
///
/// Combina los datos básicos del login (rol, usuario) con el perfil
/// completo devuelto por el endpoint `obtenerDatosMaster`.
class SamUserModel {
  const SamUserModel({
    required this.username,
    required this.samRole,
    required this.correo,
    required this.nombre,
    required this.puesto,
    required this.departamento,
    required this.edificio,
    this.sistemaUrl = '',
    this.jefeSamId,
    this.empleadoSamId,
    this.credenciales = '',
  });

  // ── Atributos ─────────────────────────────────────────────────────────────

  /// Nombre de usuario con el que se autenticó en SAM.
  final String username;

  /// Rol SAM: 'master' para jefes/admin, 'empleado' para personal.
  final String samRole;

  /// Correo institucional del empleado (clave de identificación en la BD).
  final String correo;

  /// Nombre completo del empleado.
  final String nombre;

  /// Puesto o cargo del empleado según SAM.
  final String puesto;

  /// Departamento al que pertenece el empleado.
  final String departamento;

  /// Edificio asignado al empleado.
  final String edificio;

  /// URL del sistema asignado (puede estar vacía).
  final String sistemaUrl;

  /// ID entero del jefe directo en SAM (campo 'jefe' de obtenerDatosMaster).
  /// Se almacena en autorizador_id al crear una solicitud.
  final int? jefeSamId;

  /// ID entero del propio empleado en SAM (campo 'idEmpleado' o equivalente).
  /// El Autorizador lo usa para filtrar las solicitudes que le corresponden.
  final int? empleadoSamId;

  /// Credenciales del empleado en SAM (campo 'credenciales' de empleados).
  /// Valores confirmados en el ITT: "Administrativo" o "Docente".
  /// Es el campo correcto para determinar el rol en la aplicación.
  final String credenciales;

  // ── Serialización ─────────────────────────────────────────────────────────

  /// Construye un [SamUserModel] desde la respuesta del endpoint
  /// `GET /app/empleado.do?accion=perfil` (nuevo endpoint SAM ITT).
  ///
  /// Ejemplo de respuesta:
  /// ```json
  /// { "status": "0", "usuario": "gama", "nombre": "Juan",
  ///   "apellidoPa": "García", "apellidoMa": "López",
  ///   "correo": "jgarcia@toluca.tecnm.mx",
  ///   "credenciales": "Administrativo",
  ///   "jefe": "5", "puesto": "Jefe de Departamento" }
  /// ```
  factory SamUserModel.fromPerfilResponse(
    Map<String, dynamic> json,
    String samRole,
  ) {
    int? parseIntField(dynamic raw) => raw is int
        ? raw
        : raw is String
        ? int.tryParse(raw)
        : null;

    final nombre = json['nombre'] as String? ?? '';
    final ap = json['apellidoPa'] as String? ?? '';
    final am = json['apellidoMa'] as String? ?? '';
    final fullName = [nombre, ap, am].where((s) => s.isNotEmpty).join(' ');

    return SamUserModel(
      username: json['usuario'] as String? ?? '',
      samRole: samRole,
      correo: json['correo'] as String? ?? '',
      nombre: fullName,
      puesto: json['puesto'] as String? ?? '',
      // SAM envía "departamento" (nombre del depto) y "edificio" (código: A, B…)
      departamento: json['departamento'] as String? ?? '',
      edificio: json['edificio'] as String? ?? '',
      credenciales: json['credenciales'] as String? ?? '',
      jefeSamId: parseIntField(json['jefe']),
      empleadoSamId: parseIntField(
        json['id_empleado'] ?? json['idEmpleado'] ?? json['id'],
      ),
    );
  }

  /// Construye un [SamUserModel] a partir de la respuesta JSON de
  /// `obtenerDatosMaster` (endpoint legacy, mantenido por compatibilidad).
  factory SamUserModel.fromObtenerDatosMaster(
    Map<String, dynamic> json,
    String username,
    String samRole,
  ) {
    final obj = json['responseObject'] as Map<String, dynamic>? ?? {};

    final nombre = obj['nombre'] as String? ?? '';
    final ap = obj['apellidoPa'] as String? ?? '';
    final am = obj['apellidoMa'] as String? ?? '';
    final fullName = [nombre, ap, am].where((s) => s.isNotEmpty).join(' ');

    int? parseIntField(dynamic raw) => raw is int
        ? raw
        : raw is String
        ? int.tryParse(raw)
        : null;

    return SamUserModel(
      username: username,
      samRole: samRole,
      correo: obj['correo'] as String? ?? '',
      nombre: fullName,
      puesto: obj['nombre_puesto_empleado'] as String? ?? '',
      departamento: obj['nombre_departamento_empleado'] as String? ?? '',
      edificio: obj['edificio_empleado'] as String? ?? '',
      sistemaUrl: obj['url'] as String? ?? '',
      jefeSamId: parseIntField(obj['jefe']),
      empleadoSamId: parseIntField(
        obj['idEmpleado'] ?? obj['id_empleado'] ?? obj['id'],
      ),
      credenciales: obj['credenciales'] as String? ?? '',
    );
  }

  /// Construye un [SamUserModel] mínimo para usuarios 'master'.
  factory SamUserModel.masterMinimal(String username) {
    return SamUserModel(
      username: username,
      samRole: 'master',
      correo: '',
      nombre: username,
      puesto: '',
      departamento: '',
      edificio: '',
    );
  }

  /// Reconstruye un [SamUserModel] desde el JSON producido por [toJson].
  /// Usado para restaurar la sesión persistida en SharedPreferences.
  factory SamUserModel.fromJson(Map<String, dynamic> json) {
    return SamUserModel(
      username: json['username'] as String? ?? '',
      samRole: json['sam_role'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      puesto: json['puesto'] as String? ?? '',
      departamento: json['departamento'] as String? ?? '',
      edificio: json['edificio'] as String? ?? '',
      sistemaUrl: json['sistema_url'] as String? ?? '',
      jefeSamId: json['jefe_sam_id'] as int?,
      empleadoSamId: json['empleado_sam_id'] as int?,
      credenciales: json['credenciales'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'sam_role': samRole,
    'correo': correo,
    'nombre': nombre,
    'puesto': puesto,
    'departamento': departamento,
    'edificio': edificio,
    'sistema_url': sistemaUrl,
    if (jefeSamId != null) 'jefe_sam_id': jefeSamId,
    if (empleadoSamId != null) 'empleado_sam_id': empleadoSamId,
    if (credenciales.isNotEmpty) 'credenciales': credenciales,
  };
}

/// Resultado interno del flujo de login SAM.
class SamLoginResult {
  const SamLoginResult({
    required this.samRole,
    this.token,
    this.sistemaUrl,
  });

  final String samRole;
  final String? token;
  final String? sistemaUrl;

  bool get hasToken => token != null && token!.isNotEmpty;
}
