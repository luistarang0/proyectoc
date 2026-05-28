/// @file: access_log_repository.dart
/// @project: Control de Accesos - GAMA
/// @description: Repositorio del registro de accesos. Registra cada evento
///   del ciclo de vida de un visitante y provee el estado actual derivado
///   del último evento. También carga las visitas activas del día para
///   el panel del Guardia.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/database_service.dart';
import '../models/access_log_db_model.dart';
import '../models/request_db_model.dart';
import '../models/request_item_db_model.dart';
import '../models/visitor_db_model.dart';

/// Repositorio de la tabla `access_logs`.
class AccessLogRepository {
  const AccessLogRepository(this._db);

  final DatabaseService _db;

  // ── Escritura ──────────────────────────────────────────────────────────────

  /// Registra un nuevo evento para un ítem.
  Future<void> create(AccessLogDbModel log) async {
    await _db.execute((conn) async {
      await conn.execute(
        'INSERT INTO access_logs (item_id, event_type) VALUES (:item_id, :event_type)',
        log.toInsertMap(),
      );
    });
  }

  // ── Consulta de estado ─────────────────────────────────────────────────────

  /// Retorna el último evento registrado para un ítem.
  ///
  /// Si no hay registros, el ítem está en estado PENDIENTE (sin acceso aún).
  Future<AccessLogDbModel?> getLatest(int itemId) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT * FROM access_logs
           WHERE item_id = :id
           ORDER BY registered_at DESC
           LIMIT 1''',
        {'id': itemId},
      );
      if (result.rows.isEmpty) return null;
      return AccessLogDbModel.fromMap(result.rows.first.assoc());
    });
  }

  /// Retorna el historial completo de eventos de un ítem.
  Future<List<AccessLogDbModel>> getHistory(int itemId) async {
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT * FROM access_logs
           WHERE item_id = :id
           ORDER BY registered_at ASC''',
        {'id': itemId},
      );
      return result.rows
          .map((r) => AccessLogDbModel.fromMap(r.assoc()))
          .toList();
    });
  }

  // ── Consulta de visitas activas del día ───────────────────────────────────

  /// Retorna ítems con visitante y estado actual para [date].
  ///
  /// Incluye ítems de solicitudes aprobadas cuyo último evento
  /// NO sea SALIDA_INSTITUCION.
  Future<List<ActiveVisitDto>> getActiveVisitsForDate(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT
             ri.item_id, ri.request_id, ri.visitor_id,
             ri.access_token, ri.created_at,
             v.full_name, v.email,
             r.building_id, r.scheduled_time, r.tolerance_minutes,
             r.Email_Host, r.visit_type,
             b.building_name
           FROM requests_items ri
           JOIN requests r ON r.request_id = ri.request_id
           JOIN visitors v ON v.visitor_id = ri.visitor_id
           JOIN buildings b ON b.building_id = r.building_id
           WHERE r.scheduled_date = :date
             AND r.status = 'APROBADA'
           ORDER BY r.scheduled_time ASC''',
        {'date': dateStr},
      );

      final dtos = <ActiveVisitDto>[];
      for (final row in result.rows) {
        final map = row.assoc();
        final item = RequestItemDbModel.fromMap({
          'item_id': map['item_id'],
          'request_id': map['request_id'],
          'visitor_id': map['visitor_id'],
          'access_token': map['access_token'],
          'created_at': map['created_at'],
        });
        final visitor = VisitorDbModel(
          visitorId: int.parse(map['visitor_id']!),
          fullName: map['full_name']!,
          email: map['email'],
        );

        final lastLog = await getLatest(item.itemId!);
        if (lastLog?.eventType == AccessEventType.salidaInstitucion) continue;

        dtos.add(ActiveVisitDto(
          item: item,
          visitor: visitor,
          lastLog: lastLog,
          scheduledTime: map['scheduled_time'],
          toleranceMinutes: map['tolerance_minutes'] != null
              ? int.tryParse(map['tolerance_minutes']!)
              : null,
          visitType: map['visit_type'] != null
              ? VisitTypeDb.fromDbValue(map['visit_type']!)
              : null,
          buildingName: map['building_name'],
        ));
      }
      return dtos;
    });
  }

  /// Ítems del día asociados a un anfitrión específico.
  Future<List<ActiveVisitDto>> getActiveVisitsForHost(
    String emailHost,
    DateTime date,
  ) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    return _db.execute((conn) async {
      final result = await conn.execute(
        '''SELECT
             ri.item_id, ri.request_id, ri.visitor_id,
             ri.access_token, ri.created_at,
             v.full_name, v.email,
             r.building_id, r.scheduled_time, r.Email_Host, r.visit_type,
             b.building_name
           FROM requests_items ri
           JOIN requests r ON r.request_id = ri.request_id
           JOIN visitors v ON v.visitor_id = ri.visitor_id
           JOIN buildings b ON b.building_id = r.building_id
           WHERE r.scheduled_date = :date
             AND r.status = 'APROBADA'
             AND r.Email_Host = :email
           ORDER BY r.scheduled_time ASC''',
        {'date': dateStr, 'email': emailHost},
      );

      final dtos = <ActiveVisitDto>[];
      for (final row in result.rows) {
        final map = row.assoc();
        final item = RequestItemDbModel.fromMap({
          'item_id': map['item_id'],
          'request_id': map['request_id'],
          'visitor_id': map['visitor_id'],
          'access_token': map['access_token'],
          'created_at': map['created_at'],
        });
        final visitor = VisitorDbModel(
          visitorId: int.parse(map['visitor_id']!),
          fullName: map['full_name']!,
          email: map['email'],
        );
        final lastLog = await getLatest(item.itemId!);
        dtos.add(ActiveVisitDto(
          item: item,
          visitor: visitor,
          lastLog: lastLog,
          scheduledTime: map['scheduled_time'],
          toleranceMinutes: map['tolerance_minutes'] != null
              ? int.tryParse(map['tolerance_minutes']!)
              : null,
          visitType: map['visit_type'] != null
              ? VisitTypeDb.fromDbValue(map['visit_type']!)
              : null,
          buildingName: map['building_name'],
        ));
      }
      return dtos;
    });
  }
}

/// DTO que agrupa un ítem con su visitante, su último estado y la hora
/// programada de la visita para mostrar en los cards del Anfitrión.
class ActiveVisitDto {
  const ActiveVisitDto({
    required this.item,
    required this.visitor,
    this.lastLog,
    this.scheduledTime,
    this.toleranceMinutes,
    this.visitType,
    this.buildingName,
  });

  final RequestItemDbModel item;
  final VisitorDbModel visitor;

  /// Último evento registrado — null si el visitante aún no ha llegado.
  final AccessLogDbModel? lastLog;

  /// Hora programada de la visita en formato 'HH:MM:SS' (de requests).
  final String? scheduledTime;

  /// Minutos de tolerancia configurados en la solicitud.
  final int? toleranceMinutes;

  /// Tipo de visita — permite identificar espontáneas en el panel del guardia.
  final VisitTypeDb? visitType;

  /// Nombre del edificio destino (para mostrar en el panel del guardia).
  final String? buildingName;

  /// Evento actual derivado del último log (null = PENDIENTE).
  AccessEventType? get currentEvent => lastLog?.eventType;

  /// True si la visita fue creada en el momento por el guardia.
  bool get isEspontanea => visitType == VisitTypeDb.espontaneo;

  /// Hora formateada 'HH:MM' para mostrar en UI.
  String get formattedTime {
    if (scheduledTime == null) return '—';
    return scheduledTime!.length >= 5
        ? scheduledTime!.substring(0, 5)
        : scheduledTime!;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final accessLogRepositoryProvider = Provider<AccessLogRepository>(
  (ref) => AccessLogRepository(ref.watch(databaseServiceProvider)),
);
