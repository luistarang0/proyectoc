/// @file: request_item_repository.dart
/// @project: Control de Accesos - GAMA
/// @description: Repositorio de ítems de solicitud. Cada ítem representa
///   un visitante dentro de una solicitud y contiene su access_token (QR).
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/database_service.dart';
import '../models/request_item_db_model.dart';
import '../models/scan_details_dto.dart';
import '../models/visitor_qr_dto.dart';

/// Repositorio de la tabla `requests_items`.
class RequestItemRepository {
  const RequestItemRepository(this._db);

  final DatabaseService _db;

  // ── Escritura ──────────────────────────────────────────────────────────────

  /// Inserta un ítem y retorna el model con su item_id asignado.
  Future<RequestItemDbModel> create(RequestItemDbModel item) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''INSERT INTO requests_items (request_id, visitor_id, access_token)
           VALUES (:request_id, :visitor_id, :access_token)''',
        item.toInsertMap(),
      );
      return RequestItemDbModel(
        itemId: result.lastInsertID.toInt(),
        requestId: item.requestId,
        visitorId: item.visitorId,
        accessToken: item.accessToken,
      );
    });
  }

  /// Inserta múltiples ítems en una sola conexión (visitas grupales).
  Future<List<RequestItemDbModel>> createAll(
    List<RequestItemDbModel> items,
  ) async {
    return _db.execute((conn) async {
      final created = <RequestItemDbModel>[];
      for (final item in items) {
        final result = await conn.execute(
          '''INSERT INTO requests_items (request_id, visitor_id, access_token)
             VALUES (:request_id, :visitor_id, :access_token)''',
          item.toInsertMap(),
        );
        created.add(
          RequestItemDbModel(
            itemId: result.lastInsertID.toInt(),
            requestId: item.requestId,
            visitorId: item.visitorId,
            accessToken: item.accessToken,
          ),
        );
      }
      return created;
    });
  }

  // ── Consulta ───────────────────────────────────────────────────────────────

  /// Retorna todos los ítems de una solicitud.
  Future<List<RequestItemDbModel>> findByRequestId(int requestId) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        'SELECT * FROM requests_items WHERE request_id = :id',
        {'id': requestId},
      );
      return result.rows
          .map((r) => RequestItemDbModel.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Obtiene todos los datos necesarios para procesar un escaneo de QR.
  ///
  /// JOIN entre requests_items, requests, visitors y buildings.
  /// Retorna null si el token no existe.
  Future<ScanDetailsDto?> findScanDetails(String token) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT
             ri.item_id, ri.request_id, ri.access_token,
             r.Email_Host, r.status, r.scheduled_date,
             r.scheduled_time, r.tolerance_minutes,
             v.full_name, v.email,
             b.building_name
           FROM requests_items ri
           JOIN requests r ON r.request_id = ri.request_id
           JOIN visitors v ON v.visitor_id = ri.visitor_id
           JOIN buildings b ON b.building_id = r.building_id
           WHERE ri.access_token = :token
           LIMIT 1''',
        {'token': token},
      );
      if (result.rows.isEmpty) return null;
      return ScanDetailsDto.fromMap(result.rows.first.assoc());
    });
  }

  /// Retorna los datos de QR (nombre + correo + token) para todos los
  /// visitantes de una solicitud. Usado en el visor QR del Anfitrión.
  Future<List<VisitorQrDto>> findItemsWithVisitorNames(int requestId) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT ri.access_token, v.full_name, v.email
           FROM requests_items ri
           JOIN visitors v ON v.visitor_id = ri.visitor_id
           WHERE ri.request_id = :id
           ORDER BY ri.item_id ASC''',
        {'id': requestId},
      );
      return result.rows
          .map((r) => VisitorQrDto.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Retorna true si algún ítem de [requestId] tiene ya una ENTRADA registrada.
  ///
  /// Usado para impedir la cancelación de solicitudes cuando el visitante
  /// ya se encuentra dentro del instituto.
  Future<bool> hasAnyEntrada(int requestId) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT COUNT(*) AS cnt
           FROM requests_items ri
           JOIN access_logs al ON al.item_id = ri.item_id
           WHERE ri.request_id = :id
             AND al.event_type = 'ENTRADA_INSTITUCION'
           LIMIT 1''',
        {'id': requestId},
      );
      if (result.rows.isEmpty) return false;
      return (int.tryParse(result.rows.first.assoc()['cnt'] ?? '0') ?? 0) > 0;
    });
  }

  /// Busca un ítem por su access_token (usado al escanear el QR).
  Future<RequestItemDbModel?> findByToken(String token) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        'SELECT * FROM requests_items WHERE access_token = :token LIMIT 1',
        {'token': token},
      );
      if (result.rows.isEmpty) return null;
      return RequestItemDbModel.fromMap(result.rows.first.assoc());
    });
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final requestItemRepositoryProvider = Provider<RequestItemRepository>(
  (ref) => RequestItemRepository(ref.watch(databaseServiceProvider)),
);
