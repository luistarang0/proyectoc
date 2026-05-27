/// @file: access_log_db_model.dart
/// @project: Control de Accesos - GAMA
/// @description: Modelo de serialización para la tabla access_logs.
///   Registra cada evento del ciclo de vida de un visitante. El estado
///   actual de un QR se determina por el último evento registrado.
///   Tipos de evento: ENTRADA_INSTITUCION | LLEGADA_OFICINA |
///   SALIDA_OFICINA | SALIDA_INSTITUCION.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import '../../model/visitante_model.dart';

/// Tipos de evento válidos en access_logs.
///
/// La secuencia natural del ciclo de vida es:
/// (sin log → PENDIENTE) →
/// ENTRADA_INSTITUCION → LLEGADA_OFICINA →
/// SALIDA_OFICINA → SALIDA_INSTITUCION
enum AccessEventType {
  entradaInstitucion,
  llegadaOficina,
  salidaOficina,
  salidaInstitucion;

  String get dbValue => switch (this) {
    AccessEventType.entradaInstitucion => 'ENTRADA_INSTITUCION',
    AccessEventType.llegadaOficina => 'LLEGADA_OFICINA',
    AccessEventType.salidaOficina => 'SALIDA_OFICINA',
    AccessEventType.salidaInstitucion => 'SALIDA_INSTITUCION',
  };

  static AccessEventType fromDbValue(String value) => switch (value) {
    'ENTRADA_INSTITUCION' => AccessEventType.entradaInstitucion,
    'LLEGADA_OFICINA' => AccessEventType.llegadaOficina,
    'SALIDA_OFICINA' => AccessEventType.salidaOficina,
    'SALIDA_INSTITUCION' => AccessEventType.salidaInstitucion,
    _ => throw ArgumentError('AccessEventType desconocido: $value'),
  };

  /// Convierte el evento al [EstatusVisitante] equivalente para la UI.
  EstatusVisitante toEstatusVisitante() => switch (this) {
    AccessEventType.entradaInstitucion => EstatusVisitante.enInstituto,
    AccessEventType.llegadaOficina => EstatusVisitante.enOficina,
    AccessEventType.salidaOficina => EstatusVisitante.salidoOficina,
    AccessEventType.salidaInstitucion => EstatusVisitante.salidoInstituto,
  };
}

/// Modelo de la tabla `access_logs` — inmutable.
class AccessLogDbModel {
  const AccessLogDbModel({
    this.logId,
    required this.itemId,
    required this.eventType,
    this.registeredAt,
  });

  final int? logId;
  final int itemId;
  final AccessEventType eventType;
  final DateTime? registeredAt;

  factory AccessLogDbModel.fromMap(Map<String, String?> map) {
    return AccessLogDbModel(
      logId: int.parse(map['log_id']!),
      itemId: int.parse(map['item_id']!),
      eventType: AccessEventType.fromDbValue(map['event_type']!),
      registeredAt: map['registered_at'] != null
          ? DateTime.parse(map['registered_at']!.replaceFirst(' ', 'T'))
          : null,
    );
  }

  /// Mapa para INSERT (sin log_id y registered_at — auto en BD).
  Map<String, dynamic> toInsertMap() => {
    'item_id': itemId,
    'event_type': eventType.dbValue,
  };
}
