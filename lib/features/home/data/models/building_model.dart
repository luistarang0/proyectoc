/// @file: building_model.dart
/// @project: Control de Accesos - GAMA
/// @description: Modelo de serialización para la tabla buildings.
///   Los edificios funcionan como catálogo fijo (enum de BD); no hay
///   CRUD desde la app, solo se consultan para poblar selectores.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

/// Modelo inmutable que representa un edificio del catálogo institucional.
class BuildingModel {
  const BuildingModel({
    required this.buildingId,
    required this.buildingName,
  });

  final int buildingId;
  final String buildingName;

  /// Construye desde una fila de mysql_client (row.assoc() devuelve String?).
  factory BuildingModel.fromMap(Map<String, String?> map) {
    return BuildingModel(
      buildingId: int.parse(map['building_id']!),
      buildingName: map['building_name']!,
    );
  }

  @override
  String toString() => buildingName;
}
