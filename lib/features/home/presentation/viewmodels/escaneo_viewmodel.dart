/// @file: escaneo_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del escáner QR del Guardia. Valida el token,
///   determina entrada/salida, registra el evento y gestiona el flujo
///   de extensión de llegada tardía con polling de 60 segundos.
///   Referencia: RF-09 / RF-10 del Proyecto C — Control de Accesos.
/// @author: Luis Antonio Tarango Regis
/// @version: 2.0.0
/// @last_update: 2026-05-26

library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/access_log_db_model.dart';
import '../../data/models/request_db_model.dart';
import '../../data/repositories/access_log_repository.dart';
import '../../data/repositories/request_item_repository.dart';
import '../../data/repositories/request_repository.dart';

// ── Resultado del escaneo ─────────────────────────────────────────────────────

enum ScanAction {
  entrada,
  salida,

  /// El visitante está en el instituto pero no pasó por la oficina (o aún está
  /// en ella). Se pide confirmación antes de registrar la salida.
  salidaSinOficina,

  extensionPendiente,
}

/// Resultado completo de procesar un token QR.
class ScanResult {
  const ScanResult({
    required this.isSuccess,
    required this.action,
    this.visitorName,
    this.buildingName,
    this.emailHost,
    this.errorMessage,
    this.canExtend = false,
    this.requestId,
    this.itemId,
    this.accessToken,
    this.secondsRemaining,
  });

  final bool isSuccess;
  final ScanAction action;
  final String? visitorName;
  final String? buildingName;
  final String? emailHost;
  final String? errorMessage;

  /// True cuando el error es por tolerancia y el guardia puede solicitar
  /// extensión al anfitrión.
  final bool canExtend;

  /// ID de la solicitud — necesario para el flujo de extensión.
  final int? requestId;

  /// ID del ítem QR — para registrar ENTRADA tras aprobación.
  final int? itemId;

  /// UUID del access_token — necesario para re-validar tras aprobación.
  final String? accessToken;

  /// Segundos restantes del countdown (solo en [extensionPendiente]).
  final int? secondsRemaining;

  factory ScanResult.entrada({
    required String visitorName,
    required String buildingName,
    required String emailHost,
  }) =>
      ScanResult(
        isSuccess: true,
        action: ScanAction.entrada,
        visitorName: visitorName,
        buildingName: buildingName,
        emailHost: emailHost,
      );

  factory ScanResult.salida({required String visitorName}) => ScanResult(
    isSuccess: true,
    action: ScanAction.salida,
    visitorName: visitorName,
  );

  factory ScanResult.error(String message) => ScanResult(
    isSuccess: false,
    action: ScanAction.entrada,
    errorMessage: message,
  );

  /// El visitante entró al instituto pero nunca llegó a la oficina del anfitrión
  /// (o aún está en ella). El guardia debe confirmar que desea registrar la
  /// salida sin el ciclo oficina completo.
  factory ScanResult.salidaSinOficina({
    required String visitorName,
    required int itemId,
    required String message,
  }) =>
      ScanResult(
        isSuccess: false,
        action: ScanAction.salidaSinOficina,
        visitorName: visitorName,
        itemId: itemId,
        errorMessage: message,
      );

  factory ScanResult.fueraDeHorario({
    required String visitorName,
    required int requestId,
    required int itemId,
    required String accessToken,
    required String message,
  }) =>
      ScanResult(
        isSuccess: false,
        action: ScanAction.entrada,
        visitorName: visitorName,
        requestId: requestId,
        itemId: itemId,
        accessToken: accessToken,
        errorMessage: message,
        canExtend: true,
      );

  factory ScanResult.extensionPendiente({
    required String visitorName,
    required int requestId,
    required int itemId,
    required int secondsRemaining,
  }) =>
      ScanResult(
        isSuccess: false,
        action: ScanAction.extensionPendiente,
        visitorName: visitorName,
        requestId: requestId,
        itemId: itemId,
        secondsRemaining: secondsRemaining,
      );
}

// ── Estado ────────────────────────────────────────────────────────────────────

class EscaneoState {
  const EscaneoState({this.isProcessing = false, this.lastScan});
  final bool isProcessing;
  final ScanResult? lastScan;

  EscaneoState copyWith({bool? isProcessing, ScanResult? lastScan}) =>
      EscaneoState(
        isProcessing: isProcessing ?? this.isProcessing,
        lastScan: lastScan ?? this.lastScan,
      );

  EscaneoState cleared() => const EscaneoState();
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

class EscaneoViewModel extends Notifier<EscaneoState> {
  late final RequestItemRepository _itemRepo;
  late final AccessLogRepository _logRepo;
  late final RequestRepository _requestRepo;

  Timer? _countdownTimer;

  @override
  EscaneoState build() {
    _itemRepo = ref.read(requestItemRepositoryProvider);
    _logRepo = ref.read(accessLogRepositoryProvider);
    _requestRepo = ref.read(requestRepositoryProvider);
    ref.onDispose(() => _countdownTimer?.cancel());
    return const EscaneoState();
  }

  // ── Procesamiento principal ───────────────────────────────────────────────

  Future<void> processScan(String token) async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true);

    try {
      final details = await _itemRepo.findScanDetails(token);
      if (details == null) { _setError('Código no reconocido'); return; }

      if (details.status != RequestStatus.aprobada) {
        _setError('Solicitud no autorizada'); return;
      }

      if (details.scheduledDate != null) {
        final today = DateTime.now();
        final d = details.scheduledDate!;
        if (d.year != today.year ||
            d.month != today.month ||
            d.day != today.day) {
          final f =
              '${d.day.toString().padLeft(2, '0')}/'
              '${d.month.toString().padLeft(2, '0')}/'
              '${d.year}';
          _setError('Fecha incorrecta\nVisita programada el $f');
          return;
        }
      }

      final lastLog = await _logRepo.getLatest(details.itemId);
      final isFirstEntry = lastLog == null;

      // Verificar tolerancia (solo para primera entrada).
      if (isFirstEntry &&
          details.scheduledTime != null &&
          details.toleranceMinutes != null) {
        final now = DateTime.now();
        final nowMin = now.hour * 60 + now.minute;
        final parts = details.scheduledTime!.split(':');
        final schedMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        final diff = nowMin - schedMin;
        final tol = details.toleranceMinutes!;

        if (diff < -tol || diff > tol) {
          final hh = (schedMin ~/ 60).toString().padLeft(2, '0');
          final mm = (schedMin % 60).toString().padLeft(2, '0');
          state = EscaneoState(
            lastScan: ScanResult.fueraDeHorario(
              visitorName: details.visitorName,
              requestId: details.requestId,
              itemId: details.itemId,
              accessToken: details.accessToken,
              message: 'Fuera del horario permitido\n$hh:$mm ±${tol}min',
            ),
          );
          return;
        }
      }

      final lastEvent = lastLog?.eventType;

      // ── Caso 1: visita ya cerrada ─────────────────────────────────────────
      if (lastEvent == AccessEventType.salidaInstitucion) {
        _setError('Visita ya finalizada');
        return;
      }

      // ── Caso 2: primera entrada ───────────────────────────────────────────
      if (isFirstEntry) {
        await _logRepo.create(AccessLogDbModel(
          itemId: details.itemId,
          eventType: AccessEventType.entradaInstitucion,
        ));
        state = EscaneoState(
          lastScan: ScanResult.entrada(
            visitorName: details.visitorName,
            buildingName: details.buildingName,
            emailHost: details.emailHost,
          ),
        );
        return;
      }

      // ── Caso 3: salida normal (el anfitrión ya confirmó salidaOficina) ────
      if (lastEvent == AccessEventType.salidaOficina) {
        await _logRepo.create(AccessLogDbModel(
          itemId: details.itemId,
          eventType: AccessEventType.salidaInstitucion,
        ));
        state = EscaneoState(
          lastScan: ScanResult.salida(visitorName: details.visitorName),
        );
        return;
      }

      // ── Caso 4: el visitante está en el instituto pero sin ciclo de oficina
      //   completo (entradaInstitucion o llegadaOficina sin salidaOficina).
      //   Pedir confirmación al guardia antes de registrar la salida.
      final message = lastEvent == AccessEventType.llegadaOficina
          ? 'El visitante aún está registrado en la oficina del anfitrión.\n'
              '¿Registrar salida del instituto de todos modos?'
          : 'El visitante nunca llegó a la oficina del anfitrión.\n'
              '¿Registrar salida del instituto de todos modos?';

      state = EscaneoState(
        lastScan: ScanResult.salidaSinOficina(
          visitorName: details.visitorName,
          itemId: details.itemId,
          message: message,
        ),
      );
    } catch (e) {
      debugPrint('[EscaneoVM] Error: $e');
      _setError('Error de conexión. Intenta de nuevo.');
    }
  }

  // ── Salida directa sin ciclo de oficina ──────────────────────────────────

  /// Registra [salidaInstitucion] después de que el guardia confirmó que el
  /// visitante sale sin haber completado el ciclo de oficina.
  Future<void> confirmarSalidaDirecta(int itemId) async {
    state = const EscaneoState(isProcessing: true);
    try {
      await _logRepo.create(
        AccessLogDbModel(
          itemId: itemId,
          eventType: AccessEventType.salidaInstitucion,
        ),
      );
      // Obtener el nombre del visitante desde el último resultado para mostrarlo.
      final visitorName = state.lastScan?.visitorName ?? '—';
      state = EscaneoState(
        lastScan: ScanResult.salida(visitorName: visitorName),
      );
    } catch (e) {
      debugPrint('[EscaneoVM] Error confirmando salida directa: $e');
      _setError('Error al registrar la salida. Intenta de nuevo.');
    }
  }

  // ── Extensión de llegada tardía ───────────────────────────────────────────

  /// Inicia el flujo de extensión: marca la solicitud en BD y arranca
  /// el countdown de 60 segundos con polling cada 5s.
  Future<void> solicitarExtension({
    required int requestId,
    required int itemId,
    required String visitorName,
    required String accessToken,
  }) async {
    _countdownTimer?.cancel();
    try {
      await _requestRepo.requestExtension(requestId);
    } catch (e) {
      _setError('Error al solicitar extensión. Intenta de nuevo.');
      return;
    }

    int seconds = 60;
    state = EscaneoState(
      lastScan: ScanResult.extensionPendiente(
        visitorName: visitorName,
        requestId: requestId,
        itemId: itemId,
        secondsRemaining: seconds,
      ),
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      seconds--;

      // Actualizar countdown cada segundo.
      state = EscaneoState(
        lastScan: ScanResult.extensionPendiente(
          visitorName: visitorName,
          requestId: requestId,
          itemId: itemId,
          secondsRemaining: seconds,
        ),
      );

      if (seconds <= 0) {
        timer.cancel();
        try {
          await _requestRepo.resolveExtension(
            requestId: requestId,
            approved: false,
          );
        } catch (_) {}
        state = EscaneoState(
          lastScan: ScanResult.error('Tiempo de espera agotado'),
        );
        return;
      }

      // Consultar BD cada 5 segundos.
      if (seconds % 5 != 0) return;

      try {
        final request = await _requestRepo.findById(requestId);
        if (request == null || request.extensionPending) return;

        timer.cancel();
        // Anfitrión respondió — re-validar QR con tiempos actualizados.
        await _revalidarTrasExtension(accessToken, itemId);
      } catch (e) {
        debugPrint('[EscaneoVM] Error polling extensión: $e');
      }
    });
  }

  /// Cancela la solicitud de extensión activa (guardia decide no esperar).
  Future<void> cancelarExtension(int requestId) async {
    _countdownTimer?.cancel();
    try {
      await _requestRepo.resolveExtension(
        requestId: requestId,
        approved: false,
      );
    } catch (_) {}
    state = EscaneoState(
      lastScan: ScanResult.error('Extensión cancelada'),
    );
  }

  /// Limpia el resultado y permite escanear de nuevo.
  void clearResult() {
    _countdownTimer?.cancel();
    state = state.cleared();
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  void _setError(String message) {
    state = EscaneoState(lastScan: ScanResult.error(message));
  }

  /// Re-valida el QR con los tiempos actualizados por el anfitrión.
  /// Si ahora es válido → registra ENTRADA. Si no → acceso denegado.
  Future<void> _revalidarTrasExtension(String token, int itemId) async {
    try {
      final fresh = await _itemRepo.findScanDetails(token);
      if (fresh == null) {
        state = EscaneoState(
          lastScan: ScanResult.error('Error al verificar el código'),
        );
        return;
      }

      // Verificar nueva tolerancia.
      if (fresh.scheduledTime != null && fresh.toleranceMinutes != null) {
        final now = DateTime.now();
        final nowMin = now.hour * 60 + now.minute;
        final parts = fresh.scheduledTime!.split(':');
        final schedMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        final diff = nowMin - schedMin;
        final tol = fresh.toleranceMinutes!;

        if (diff < -tol || diff > tol) {
          state = EscaneoState(
            lastScan: ScanResult.error('Acceso denegado por el anfitrión'),
          );
          return;
        }
      }

      // Tiempo válido → registrar entrada.
      await _logRepo.create(
        AccessLogDbModel(
          itemId: itemId,
          eventType: AccessEventType.entradaInstitucion,
        ),
      );
      state = EscaneoState(
        lastScan: ScanResult.entrada(
          visitorName: fresh.visitorName,
          buildingName: fresh.buildingName,
          emailHost: fresh.emailHost,
        ),
      );
    } catch (e) {
      state = EscaneoState(
        lastScan: ScanResult.error('Error al procesar la extensión'),
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final escaneoViewModelProvider =
    NotifierProvider<EscaneoViewModel, EscaneoState>(EscaneoViewModel.new);
