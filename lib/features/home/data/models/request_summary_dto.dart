/// @file: request_summary_dto.dart
/// @project: Control de Accesos - GAMA
/// @description: DTO que combina datos de requests, buildings y visitors
///   en una sola consulta JOIN para el panel del Autorizador y la lista
///   de solicitudes del Anfitrión. Evita consultas N+1.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'request_db_model.dart';

/// DTO de resumen de solicitud con datos de edificio y visitantes.
class RequestSummaryDto {
  const RequestSummaryDto({
    required this.requestId,
    required this.emailHost,
    required this.buildingName,
    required this.visitorNames,
    required this.visitorCount,
    this.scheduledDate,
    this.scheduledTime,
    this.toleranceMinutes,
    required this.status,
    required this.visitType,
    this.groupName,
  });

  final int requestId;

  /// Correo del anfitrión que creó la solicitud.
  final String emailHost;

  /// Nombre del edificio destino.
  final String buildingName;

  /// Nombres de visitantes concatenados (ej. "Juan García, María López").
  final String visitorNames;

  /// Número total de visitantes en la solicitud.
  final int visitorCount;

  final DateTime? scheduledDate;

  /// Hora como 'HH:MM:SS' — usar [formattedTime] para mostrar en UI.
  final String? scheduledTime;

  final int? toleranceMinutes;
  final RequestStatus status;
  final VisitTypeDb visitType;

  /// Nombre del grupo para visitas grupales.
  final String? groupName;

  // ── Helpers de presentación ───────────────────────────────────────────────

  /// Hora formateada 'HH:MM' para mostrar en UI.
  String get formattedTime {
    if (scheduledTime == null) return '—';
    return scheduledTime!.length >= 5
        ? scheduledTime!.substring(0, 5)
        : scheduledTime!;
  }

  /// Fecha formateada 'DD/MM/YYYY' para mostrar en UI.
  String get formattedDate {
    if (scheduledDate == null) return '—';
    return '${scheduledDate!.day.toString().padLeft(2, '0')}/'
        '${scheduledDate!.month.toString().padLeft(2, '0')}/'
        '${scheduledDate!.year}';
  }

  // ── Serialización ─────────────────────────────────────────────────────────

  factory RequestSummaryDto.fromMap(Map<String, String?> map) {
    return RequestSummaryDto(
      requestId: int.parse(map['request_id']!),
      emailHost: map['Email_Host']!,
      buildingName: map['building_name'] ?? '—',
      visitorNames: map['visitor_names'] ?? '—',
      visitorCount: int.tryParse(map['visitor_count'] ?? '0') ?? 0,
      scheduledDate: map['scheduled_date'] != null
          ? DateTime.tryParse(map['scheduled_date']!)
          : null,
      scheduledTime: map['scheduled_time'],
      toleranceMinutes: map['tolerance_minutes'] != null
          ? int.tryParse(map['tolerance_minutes']!)
          : null,
      status: RequestStatus.fromDbValue(map['status'] ?? 'PENDIENTE'),
      visitType: VisitTypeDb.fromDbValue(map['visit_type'] ?? 'individual'),
      groupName: map['group_name'],
    );
  }
}
