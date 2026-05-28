/// @file: request_repository.dart
/// @project: Control de Accesos - GAMA
/// @description: Repositorio de solicitudes de visita. Gestiona creación,
///   consulta por anfitrión/autorizador y actualización de estado.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/foundation.dart';
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

  /// SQL base para consultas con JOIN.
  /// Usa LEFT JOIN en items/visitors para incluir solicitudes sin ítems aún.
  static const _joinSelect = '''
    SELECT
      r.request_id, r.Email_Host, r.status, r.visit_type,
      r.scheduled_date, r.scheduled_time, r.tolerance_minutes, r.group_name,
      b.building_name,
      GROUP_CONCAT(v.full_name ORDER BY v.visitor_id SEPARATOR ', ') AS visitor_names,
      COALESCE(COUNT(ri.item_id), 0) AS visitor_count
    FROM requests r
    JOIN buildings b ON b.building_id = r.building_id
    LEFT JOIN requests_items ri ON ri.request_id = r.request_id
    LEFT JOIN visitors v ON v.visitor_id = ri.visitor_id
  ''';

  /// Solicitudes pendientes del autorizador con datos de edificio y visitantes.
  Future<List<RequestSummaryDto>> findPendingWithDetails(
    String autorizadorId,
  ) async {
    debugPrint('[RequestRepo] findPendingWithDetails | autorizador_id="$autorizadorId"');
    return _db.execute((conn) async {
      final result = await conn.execute(
        '$_joinSelect'
        'WHERE r.autorizador_id = :id '
        '  AND r.status = \'PENDIENTE\' '
        '  AND r.scheduled_date >= CURDATE() '
        'GROUP BY r.request_id, r.Email_Host, r.status, r.visit_type, '
        '  r.scheduled_date, r.scheduled_time, r.tolerance_minutes, '
        '  r.group_name, b.building_name '
        'ORDER BY r.scheduled_date ASC, r.scheduled_time ASC',
        {'id': autorizadorId},
      );
      debugPrint('[RequestRepo] findPendingWithDetails → ${result.rows.length} filas');
      return result.rows
          .map((r) => RequestSummaryDto.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Historial de solicitudes procesadas del autorizador (aprobadas+rechazadas).
  Future<List<RequestSummaryDto>> findHistoryWithDetails(
    String autorizadorId,
  ) async {
    debugPrint('[RequestRepo] findHistoryWithDetails | autorizador_id="$autorizadorId"');
    return _db.execute((conn) async {
      final result = await conn.execute(
        '$_joinSelect'
        'WHERE r.autorizador_id = :id '
        '  AND r.status IN (\'APROBADA\',\'RECHAZADA\') '
        '  AND r.scheduled_date >= CURDATE() '
        'GROUP BY r.request_id, r.Email_Host, r.status, r.visit_type, '
        '  r.scheduled_date, r.scheduled_time, r.tolerance_minutes, '
        '  r.group_name, b.building_name '
        'ORDER BY r.scheduled_date DESC, r.scheduled_time DESC',
        {'id': autorizadorId},
      );
      debugPrint('[RequestRepo] findHistoryWithDetails → ${result.rows.length} filas');
      return result.rows
          .map((r) => RequestSummaryDto.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Solicitudes del anfitrión con datos de edificio y visitantes.
  Future<List<RequestSummaryDto>> findByHostWithDetails(
    String emailHost,
  ) async {
    debugPrint('[RequestRepo] findByHostWithDetails | Email_Host="$emailHost"');
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
      debugPrint('[RequestRepo] findByHostWithDetails → ${result.rows.length} filas');
      return result.rows
          .map((r) => RequestSummaryDto.fromMap(r.assoc()))
          .toList();
    });
  }

  /// Solicitudes visibles en la tab "Mis Solicitudes" del Anfitrión.
  ///
  /// Reglas de visibilidad:
  ///   • PENDIENTE  → siempre visible (esperando decisión del autorizador).
  ///   • APROBADA   → visible solo si ningún visitante ha ingresado aún al
  ///                  instituto (ENTRADA_INSTITUCION no existe en access_logs).
  ///   • CANCELADA / RECHAZADA / VENCIDA → excluidas (aparecerían eliminadas).
  ///
  /// Una vez que el visitante escanea el QR y entra (entradaInstitucion), la
  /// solicitud desaparece de aquí y pasa a "Mis Visitantes".
  Future<List<RequestSummaryDto>> findSolicitudesAnfitrion(
    String emailHost,
  ) async {
    debugPrint('[RequestRepo] findSolicitudesAnfitrion | Email_Host="$emailHost"');
    return _db.execute((conn) async {
      final result = await conn.execute(
        '$_joinSelect'
        "WHERE r.Email_Host = :email "
        "  AND r.status IN ('PENDIENTE', 'APROBADA') "
        '  AND r.scheduled_date >= CURDATE() '
        '  AND NOT EXISTS ( '
        '    SELECT 1 FROM requests_items ri2 '
        '    JOIN access_logs al ON al.item_id = ri2.item_id '
        '    WHERE ri2.request_id = r.request_id '
        "      AND al.event_type = 'ENTRADA_INSTITUCION' "
        '  ) '
        'GROUP BY r.request_id, r.Email_Host, r.status, r.visit_type, '
        '  r.scheduled_date, r.scheduled_time, r.tolerance_minutes, '
        '  r.group_name, b.building_name '
        'ORDER BY r.scheduled_date DESC, r.scheduled_time DESC',
        {'email': emailHost},
      );
      debugPrint('[RequestRepo] findSolicitudesAnfitrion → ${result.rows.length} filas');
      return result.rows
          .map((r) => RequestSummaryDto.fromMap(r.assoc()))
          .toList();
    });
  }

  // ── Cierre automático de solicitudes ─────────────────────────────────────

  /// Rechaza automáticamente solicitudes PENDIENTES que ya vencieron:
  ///   • Fechas anteriores a hoy.
  ///   • Hoy, si `scheduled_time + tolerance_minutes` ya pasó.
  ///
  /// Retorna el número de filas afectadas.
  /// Idempotente: se puede llamar en cada ciclo de poll sin efectos secundarios.
  Future<int> autoRejectExpired() async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''UPDATE requests
           SET status = 'RECHAZADA'
           WHERE status = 'PENDIENTE'
             AND (
               scheduled_date < CURDATE()
               OR (
                 scheduled_date = CURDATE()
                 AND ADDTIME(scheduled_time,
                       SEC_TO_TIME(IFNULL(tolerance_minutes, 0) * 60)
                     ) < CURTIME()
               )
             )''',
      );
      final affected = result.affectedRows.toInt();
      if (affected > 0) {
        debugPrint('[RequestRepo] autoRejectExpired: $affected solicitud(es) rechazada(s)');
      }
      return affected;
    });
  }

  /// Cierre de 9 PM: rechaza TODAS las solicitudes PENDIENTES del día actual.
  ///
  /// Solo debe llamarse cuando `DateTime.now().hour >= 21`.
  /// Idempotente.
  Future<int> autoRejectAllPending() async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''UPDATE requests
           SET status = 'RECHAZADA'
           WHERE status = 'PENDIENTE'
             AND scheduled_date = CURDATE()''',
      );
      final affected = result.affectedRows.toInt();
      if (affected > 0) {
        debugPrint('[RequestRepo] autoRejectAllPending (21:00): $affected rechazada(s)');
      }
      return affected;
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
