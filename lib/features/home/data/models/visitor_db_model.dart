/// @file: visitor_db_model.dart
/// @project: Control de Accesos - GAMA
/// @description: Modelo de serialización para la tabla visitors.
///   Representa al visitante externo registrado en la BD.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

/// Modelo de la tabla `visitors` — inmutable.
class VisitorDbModel {
  const VisitorDbModel({
    this.visitorId,
    required this.fullName,
    this.email,
  });

  final int? visitorId;
  final String fullName;
  final String? email;

  factory VisitorDbModel.fromMap(Map<String, String?> map) {
    return VisitorDbModel(
      visitorId: int.parse(map['visitor_id']!),
      fullName: map['full_name']!,
      email: map['email'],
    );
  }

  /// Mapa para INSERT (sin visitor_id — AUTO_INCREMENT).
  Map<String, dynamic> toInsertMap() => {
    'full_name': fullName,
    'email': email,
  };
}
