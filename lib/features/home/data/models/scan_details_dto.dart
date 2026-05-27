/// @file: scan_details_dto.dart
/// @project: Control de Accesos - GAMA
/// @description: DTO con todos los datos necesarios para procesar un
///   escaneo de QR: información del ítem, solicitud, visitante y
///   edificio obtenidos en una sola consulta JOIN.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'request_db_model.dart';

/// Datos completos de un token QR para validación y registro de acceso.
class ScanDetailsDto {
  const ScanDetailsDto({
    required this.itemId,
    required this.requestId,
    required this.accessToken,
    required this.emailHost,
    required this.status,
    this.scheduledDate,
    this.scheduledTime,
    this.toleranceMinutes,
    required this.visitorName,
    this.visitorEmail,
    required this.buildingName,
  });

  final int itemId;
  final int requestId;
  final String accessToken;

  /// Correo del anfitrión que creó la solicitud.
  final String emailHost;

  final RequestStatus status;
  final DateTime? scheduledDate;

  /// Hora programada en formato 'HH:MM:SS'.
  final String? scheduledTime;

  final int? toleranceMinutes;
  final String visitorName;
  final String? visitorEmail;
  final String buildingName;

  factory ScanDetailsDto.fromMap(Map<String, String?> map) {
    return ScanDetailsDto(
      itemId: int.parse(map['item_id']!),
      requestId: int.parse(map['request_id']!),
      accessToken: map['access_token']!,
      emailHost: map['Email_Host']!,
      status: RequestStatus.fromDbValue(map['status'] ?? 'PENDIENTE'),
      scheduledDate: map['scheduled_date'] != null
          ? DateTime.tryParse(map['scheduled_date']!)
          : null,
      scheduledTime: map['scheduled_time'],
      toleranceMinutes: map['tolerance_minutes'] != null
          ? int.tryParse(map['tolerance_minutes']!)
          : null,
      visitorName: map['full_name'] ?? '—',
      visitorEmail: map['email'],
      buildingName: map['building_name'] ?? '—',
    );
  }
}
