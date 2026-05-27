/// @file: visitor_repository.dart
/// @project: Control de Accesos - GAMA
/// @description: Repositorio de visitantes. Busca por correo para evitar
///   duplicados o crea uno nuevo si no existe en la BD.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/database_service.dart';
import '../models/visitor_db_model.dart';

/// Repositorio de la tabla `visitors`.
class VisitorRepository {
  const VisitorRepository(this._db);

  final DatabaseService _db;

  /// Busca un visitante por correo electrónico.
  Future<VisitorDbModel?> findByEmail(String email) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        'SELECT visitor_id, full_name, email FROM visitors WHERE email = :email LIMIT 1',
        {'email': email},
      );
      if (result.rows.isEmpty) return null;
      return VisitorDbModel.fromMap(result.rows.first.assoc());
    });
  }

  /// Busca un visitante por correo o lo crea si no existe.
  ///
  /// Retorna el [VisitorDbModel] con su `visitor_id` asignado.
  Future<VisitorDbModel> findOrCreate({
    required String fullName,
    required String email,
  }) async {
    final existing = await findByEmail(email);
    if (existing != null) return existing;
    return create(VisitorDbModel(fullName: fullName, email: email));
  }

  /// Inserta un nuevo visitante y retorna el modelo con su ID asignado.
  Future<VisitorDbModel> create(VisitorDbModel visitor) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        'INSERT INTO visitors (full_name, email) VALUES (:full_name, :email)',
        visitor.toInsertMap(),
      );
      return VisitorDbModel(
        visitorId: result.lastInsertID.toInt(),
        fullName: visitor.fullName,
        email: visitor.email,
      );
    });
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final visitorRepositoryProvider = Provider<VisitorRepository>(
  (ref) => VisitorRepository(ref.watch(databaseServiceProvider)),
);
