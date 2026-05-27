/// @file: request_item_db_model.dart
/// @project: Control de Accesos - GAMA
/// @description: Modelo de serialización para la tabla requests_items.
///   Cada item representa a un visitante dentro de una solicitud y
///   contiene el access_token (UUID) que se convierte en código QR.
///   El estado actual del item se deriva del último registro en access_logs.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

/// Modelo de la tabla `requests_items` — inmutable.
class RequestItemDbModel {
  const RequestItemDbModel({
    this.itemId,
    required this.requestId,
    required this.visitorId,
    required this.accessToken,
    this.createdAt,
  });

  final int? itemId;
  final int requestId;
  final int visitorId;

  /// UUID que se codifica en el QR y se usa para validar acceso.
  final String accessToken;

  final DateTime? createdAt;

  factory RequestItemDbModel.fromMap(Map<String, String?> map) {
    return RequestItemDbModel(
      itemId: int.parse(map['item_id']!),
      requestId: int.parse(map['request_id']!),
      visitorId: int.parse(map['visitor_id']!),
      accessToken: map['access_token']!,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at']!.replaceFirst(' ', 'T'))
          : null,
    );
  }

  /// Mapa para INSERT (sin item_id y created_at — auto en BD).
  Map<String, dynamic> toInsertMap() => {
    'request_id': requestId,
    'visitor_id': visitorId,
    'access_token': accessToken,
  };
}
