/// @file: request_db_model.dart
/// @project: Control de Accesos - GAMA
/// @description: Modelo de serialización para la tabla requests.
///   Columnas clave: Email_Host (correo del anfitrión), autorizador_id
///   (correo del jefe directo para filtrado), visit_type y status.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

/// Valores válidos para requests.status.
enum RequestStatus {
  pendiente,
  aprobada,
  rechazada,
  cancelada,
  vencida;

  String get dbValue => name.toUpperCase();

  static RequestStatus fromDbValue(String value) =>
      RequestStatus.values.firstWhere(
        (e) => e.dbValue == value.toUpperCase(),
        orElse: () => RequestStatus.pendiente,
      );
}

/// Valores válidos para requests.visit_type (en minúsculas en la BD).
enum VisitTypeDb {
  /// Visita de un solo visitante a un anfitrión específico.
  individual,

  /// Varios visitantes con una sola solicitud, QR individual por persona.
  grupal,

  /// Evento académico (graduaciones, conferencias).
  evento,

  /// Equipos o grupos externos de actividades extraescolares.
  extraescolares,

  /// Visita de consulta generada en el momento por el Guardia (walk-in).
  espontaneo;

  /// Valor exacto almacenado en la BD (respeta acento en 'espontáneo').
  String get dbValue => switch (this) {
    VisitTypeDb.individual => 'individual',
    VisitTypeDb.grupal => 'grupal',
    VisitTypeDb.evento => 'evento',
    VisitTypeDb.extraescolares => 'extraescolares',
    VisitTypeDb.espontaneo => 'espontáneo',
  };

  static VisitTypeDb fromDbValue(String value) {
    final lower = value.toLowerCase();
    return switch (lower) {
      'individual' => VisitTypeDb.individual,
      'grupal' => VisitTypeDb.grupal,
      'evento' => VisitTypeDb.evento,
      'extraescolares' => VisitTypeDb.extraescolares,
      'espontáneo' || 'espontaneo' => VisitTypeDb.espontaneo,
      _ => VisitTypeDb.individual,
    };
  }
}

/// Modelo de la tabla `requests` — inmutable.
class RequestDbModel {
  const RequestDbModel({
    this.requestId,
    required this.emailHost,
    required this.autorizadorId,
    required this.buildingId,
    required this.visitType,
    this.scheduledDate,
    this.scheduledTime,
    this.toleranceMinutes,
    this.status = RequestStatus.pendiente,
    this.groupName,
    this.extensionPending = false,
  });

  final int? requestId;

  /// Correo del anfitrión que crea la solicitud (columna Email_Host).
  final String emailHost;

  /// Identificador del autorizador — almacena el correo del jefe directo
  /// del anfitrión para filtrar solicitudes en el panel del Autorizador.
  /// (columna autorizador_id, VARCHAR 100).
  final String autorizadorId;

  final int buildingId;
  final VisitTypeDb visitType;

  /// Fecha programada (DATE en BD).
  final DateTime? scheduledDate;

  /// Hora programada como String 'HH:MM:SS' (TIME en BD).
  final String? scheduledTime;

  final int? toleranceMinutes;
  final RequestStatus status;

  /// Nombre del grupo para visitas grupales.
  final String? groupName;

  /// True cuando el guardia solicitó extensión de llegada tardía y el
  /// anfitrión aún no ha respondido. Mapeado desde `extension_pending` (TINYINT).
  final bool extensionPending;

  factory RequestDbModel.fromMap(Map<String, String?> map) {
    return RequestDbModel(
      requestId: int.parse(map['request_id']!),
      emailHost: map['Email_Host']!,
      autorizadorId: map['autorizador_id'] ?? '',
      buildingId: int.parse(map['building_id']!),
      visitType: VisitTypeDb.fromDbValue(map['visit_type']!),
      scheduledDate: map['scheduled_date'] != null
          ? DateTime.parse(map['scheduled_date']!)
          : null,
      scheduledTime: map['scheduled_time'],
      toleranceMinutes: map['tolerance_minutes'] != null
          ? int.tryParse(map['tolerance_minutes']!)
          : null,
      status: RequestStatus.fromDbValue(map['status'] ?? 'PENDIENTE'),
      groupName: map['group_name'],
      extensionPending: (map['extension_pending'] ?? '0') == '1',
    );
  }

  /// Mapa para INSERT (sin request_id — AUTO_INCREMENT).
  Map<String, dynamic> toInsertMap() => {
    'Email_Host': emailHost,
    'autorizador_id': autorizadorId,
    'building_id': buildingId,
    'visit_type': visitType.dbValue,
    if (scheduledDate != null)
      'scheduled_date': scheduledDate!.toIso8601String().substring(0, 10),
    if (scheduledTime != null) 'scheduled_time': scheduledTime,
    if (toleranceMinutes != null) 'tolerance_minutes': toleranceMinutes,
    'status': status.dbValue,
    if (groupName != null) 'group_name': groupName,
  };

  RequestDbModel copyWith({RequestStatus? status, bool? extensionPending}) =>
      RequestDbModel(
        requestId: requestId,
        emailHost: emailHost,
        autorizadorId: autorizadorId,
        buildingId: buildingId,
        visitType: visitType,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        toleranceMinutes: toleranceMinutes,
        status: status ?? this.status,
        groupName: groupName,
        extensionPending: extensionPending ?? this.extensionPending,
      );
}

// ── DTO para extensiones pendientes (vista del Anfitrión) ─────────────────────

/// Datos mínimos de una solicitud de extensión pendiente.
class ExtensionDto {
  const ExtensionDto({
    required this.requestId,
    required this.visitorNames,
    required this.buildingName,
    this.scheduledTime,
  });

  final int requestId;
  final String visitorNames;
  final String buildingName;

  /// Hora original programada — para mostrar cuánto se retrasó el visitante.
  final String? scheduledTime;

  String get formattedTime {
    if (scheduledTime == null) return '—';
    return scheduledTime!.length >= 5
        ? scheduledTime!.substring(0, 5)
        : scheduledTime!;
  }

  factory ExtensionDto.fromMap(Map<String, String?> map) {
    return ExtensionDto(
      requestId: int.parse(map['request_id']!),
      visitorNames: map['visitor_names'] ?? '—',
      buildingName: map['building_name'] ?? '—',
      scheduledTime: map['scheduled_time'],
    );
  }
}
