/// @file: request_repository.dart
/// @project: Control de Accesos - GAMA
/// @description: Repositorio de solicitudes de visita. Gestiona creación,
///   consulta por anfitrión/autorizador y actualización de estado.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/database_service.dart';
import '../models/request_db_model.dart';
import '../models/request_summary_dto.dart';

// re-export para que otros archivos importen desde aquí
export '../models/request_db_model.dart' show ExtensionDto;

/// Repositorio de la tabla `requests`.
class RequestRepository {
  const RequestRepository(this._db);

  final DatabaseService _db;

  // ── Escritura ──────────────────────────────────────────────────────────────

  /// Inserta una nueva solicitud y retorna su request_id.
  Future<int> create(RequestDbModel request) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''INSERT INTO requests
           (Email_Host, autorizador_id, building_id, visit_type,
            scheduled_date, scheduled_time, tolerance_minutes,
            status, group_name)
           VALUES
           (:Email_Host, :autorizador_id, :building_id, :visit_type,
            :scheduled_date, :scheduled_time, :tolerance_minutes,
            :status, :group_name)''',
        request.toInsertMap(),
      );
      return result.lastInsertID.toInt();
    });
  }

  /// Actualiza el estado de una solicitud.
  Future<void> updateStatus(int requestId, RequestStatus status) async {
    await _db.execute((conn) async {
      await conn.execute(
        'UPDATE requests SET status = :status WHERE request_id = :id',
        {'status': status.dbValue, 'id': requestId},
      );
    });
  }

  // ── Consulta ───────────────────────────────────────────────────────────────

  /// Solicitudes creadas por [emailHost] (perspectiva Anfitrión).
  Future<List<RequestDbModel>> findByHost(String emailHost) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT * FROM requests
           WHERE Email_Host = :email
           ORDER BY scheduled_date DESC, scheduled_time DESC''',
        {'email': emailHost},
      );
      return result.rows
          .map((r) => RequestDbModel.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Solicitudes pendientes asignadas a [autorizadorId].
  Future<List<RequestDbModel>> findPendingByAutorizador(
    String autorizadorId,
  ) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT * FROM requests
           WHERE autorizador_id = :id AND status = 'PENDIENTE'
           ORDER BY scheduled_date ASC, scheduled_time ASC''',
        {'id': autorizadorId},
      );
      return result.rows
          .map((r) => RequestDbModel.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Historial de solicitudes procesadas por [autorizadorId].
  Future<List<RequestDbModel>> findHistoryByAutorizador(
    String autorizadorId,
  ) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT * FROM requests
           WHERE autorizador_id = :id AND status <> 'PENDIENTE'
           ORDER BY scheduled_date DESC, scheduled_time DESC''',
        {'id': autorizadorId},
      );
      return result.rows
          .map((r) => RequestDbModel.fromMap(r.assoc()))
          .toList();
    });
  }

  // ── Consultas con JOIN (para cards del panel) ─────────────────────────────

  /// SQL base para consultas con JOIN — evita duplicar la query.
  static const _joinSelect = '''
    SELECT
      r.request_id, r.Email_Host, r.status, r.visit_type,
      r.scheduled_date, r.scheduled_time, r.tolerance_minutes, r.group_name,
      b.building_name,
      GROUP_CONCAT(v.full_name ORDER BY v.visitor_id SEPARATOR ', ') AS visitor_names,
      COUNT(ri.item_id) AS visitor_count
    FROM requests r
    JOIN buildings b ON b.building_id = r.building_id
    JOIN requests_items ri ON ri.request_id = r.request_id
    JOIN visitors v ON v.visitor_id = ri.visitor_id
  ''';

  /// Solicitudes pendientes del autorizador con datos de edificio y visitantes.
  Future<List<RequestSummaryDto>> findPendingWithDetails(
    String autorizadorId,
  ) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '$_joinSelect'
        'WHERE r.autorizador_id = :id AND r.status = \'PENDIENTE\' '
        'GROUP BY r.request_id, r.Email_Host, r.status, r.visit_type, '
        '  r.scheduled_date, r.scheduled_time, r.tolerance_minutes, '
        '  r.group_name, b.building_name '
        'ORDER BY r.scheduled_date ASC, r.scheduled_time ASC',
        {'id': autorizadorId},
      );
      return result.rows
          .map((r) => RequestSummaryDto.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Historial de solicitudes procesadas del autorizador (aprobadas+rechazadas).
  Future<List<RequestSummaryDto>> findHistoryWithDetails(
    String autorizadorId,
  ) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '$_joinSelect'
        'WHERE r.autorizador_id = :id AND r.status IN (\'APROBADA\',\'RECHAZADA\') '
        'GROUP BY r.request_id, r.Email_Host, r.status, r.visit_type, '
        '  r.scheduled_date, r.scheduled_time, r.tolerance_minutes, '
        '  r.group_name, b.building_name '
        'ORDER BY r.scheduled_date DESC, r.scheduled_time DESC',
        {'id': autorizadorId},
      );
      return result.rows
          .map((r) => RequestSummaryDto.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Solicitudes del anfitrión con datos de edificio y visitantes.
  Future<List<RequestSummaryDto>> findByHostWithDetails(
    String emailHost,
  ) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '$_joinSelect'
        'WHERE r.Email_Host = :email '
        'GROUP BY r.request_id, r.Email_Host, r.status, r.visit_type, '
        '  r.scheduled_date, r.scheduled_time, r.tolerance_minutes, '
        '  r.group_name, b.building_name '
        'ORDER BY r.scheduled_date DESC, r.scheduled_time DESC',
        {'email': emailHost},
      );
      return result.rows
          .map((r) => RequestSummaryDto.fromMap(r.assoc()))
          .toList();
    });
  }

  // ── Extensión de llegada tardía ───────────────────────────────────────────

  /// Marca la solicitud como pendiente de extensión por parte del anfitrión.
  Future<void> requestExtension(int requestId) async {
    await _db.execute((conn) async {
      await conn.execute(
        'UPDATE requests SET extension_pending = 1 WHERE request_id = :id',
        {'id': requestId},
      );
    });
  }

  /// Resuelve una solicitud de extensión.
  ///
  /// Si [approved] es true, actualiza `scheduled_time`, `scheduled_date`
  /// y `tolerance_minutes = 10` para que el QR pase la validación.
  /// En ambos casos, limpia `extension_pending`.
  Future<void> resolveExtension({
    required int requestId,
    required bool approved,
  }) async {
    await _db.execute((conn) async {
      if (approved) {
        final now = DateTime.now();
        final timeStr =
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}:00';
        final dateStr = now.toIso8601String().substring(0, 10);
        await conn.execute(
          '''UPDATE requests
             SET extension_pending = 0,
                 scheduled_date    = :date,
                 scheduled_time    = :time,
                 tolerance_minutes = 10
             WHERE request_id = :id''',
          {'date': dateStr, 'time': timeStr, 'id': requestId},
        );
      } else {
        await conn.execute(
          'UPDATE requests SET extension_pending = 0 WHERE request_id = :id',
          {'id': requestId},
        );
      }
    });
  }

  /// Retorna las extensiones pendientes para el anfitrión [emailHost].
  Future<List<ExtensionDto>> findPendingExtensions(String emailHost) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT
             r.request_id, r.scheduled_time,
             b.building_name,
             GROUP_CONCAT(v.full_name ORDER BY v.visitor_id SEPARATOR ', ')
               AS visitor_names
           FROM requests r
           JOIN buildings b ON b.building_id = r.building_id
           JOIN requests_items ri ON ri.request_id = r.request_id
           JOIN visitors v ON v.visitor_id = ri.visitor_id
           WHERE r.Email_Host = :email AND r.extension_pending = 1
           GROUP BY r.request_id, r.scheduled_time, b.building_name''',
        {'email': emailHost},
      );
      return result.rows
          .map((r) => ExtensionDto.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Busca una solicitud por su ID.
  Future<RequestDbModel?> findById(int requestId) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        'SELECT * FROM requests WHERE request_id = :id LIMIT 1',
        {'id': requestId},
      );
      if (result.rows.isEmpty) return null;
      return RequestDbModel.fromMap(result.rows.first.assoc());
    });
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final requestRepositoryProvider = Provider<RequestRepository>(
  (ref) => RequestRepository(ref.watch(databaseServiceProvider)),
);
