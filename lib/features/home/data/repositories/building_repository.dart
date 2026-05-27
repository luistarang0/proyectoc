/// @file: building_repository.dart
/// @project: Control de Accesos - GAMA
/// @description: Repositorio del catálogo de edificios. Solo lectura.
///   Los edificios son un catálogo fijo gestionado por el administrador
///   de BD; la app únicamente los consulta para poblar selectores.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/database_service.dart';
import '../models/building_model.dart';

/// Repositorio de edificios — solo lectura.
class BuildingRepository {
  const BuildingRepository(this._db);

  final DatabaseService _db;

  /// Retorna todos los edificios del catálogo ordenados por nombre.
  Future<List<BuildingModel>> getAll() async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        'SELECT building_id, building_name FROM buildings ORDER BY building_name',
      );
      return result.rows
          .map((r) => BuildingModel.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Busca un edificio por nombre exacto.
  ///
  /// Usado para resolver el edificio del anfitrión a partir del campo
  /// `edificio_empleado` devuelto por SAM. Retorna null si no se encuentra.
  Future<BuildingModel?> findByName(String name) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        'SELECT building_id, building_name FROM buildings WHERE building_name = :name LIMIT 1',
        {'name': name},
      );
      if (result.rows.isEmpty) return null;
      return BuildingModel.fromMap(result.rows.first.assoc());
    });
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final buildingRepositoryProvider = Provider<BuildingRepository>(
  (ref) => BuildingRepository(ref.watch(databaseServiceProvider)),
);

/// Cache del catálogo de edificios. Se carga una vez por sesión.
final buildingCatalogProvider = FutureProvider<List<BuildingModel>>((ref) {
  return ref.read(buildingRepositoryProvider).getAll();
});
