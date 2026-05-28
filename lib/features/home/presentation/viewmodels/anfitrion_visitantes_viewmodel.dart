/// @file: anfitrion_visitantes_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del tab "Mis Visitantes" del Anfitrión.
///   Carga los visitantes activos del día para el anfitrión autenticado
///   y registra los eventos de llegada/salida de su oficina en access_logs.
///   Referencia: RF-13 del Proyecto C — Control de Accesos.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/session_provider.dart';
import '../../data/models/access_log_db_model.dart';
import '../../data/repositories/access_log_repository.dart';
import '../../data/repositories/request_repository.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

@immutable
class AnfitrionVisitantesState {
  const AnfitrionVisitantesState({
    this.visitantes = const [],
    this.pendingExtensions = const [],
    this.isLoading = false,
    this.errorMsg = '',
    this.processingItemId,
    this.processingExtensionId,
  });

  final List<ActiveVisitDto> visitantes;

  /// Solicitudes de extensión pendientes para este anfitrión.
  final List<ExtensionDto> pendingExtensions;

  final bool isLoading;
  final String errorMsg;
  final int? processingItemId;

  /// requestId de la extensión que se está procesando.
  final int? processingExtensionId;

  bool get hasError => errorMsg.isNotEmpty;
  bool get hasPendingExtensions => pendingExtensions.isNotEmpty;

  bool isProcessing(int itemId) => processingItemId == itemId;
  bool isProcessingExtension(int requestId) =>
      processingExtensionId == requestId;

  AnfitrionVisitantesState copyWith({
    List<ActiveVisitDto>? visitantes,
    List<ExtensionDto>? pendingExtensions,
    bool? isLoading,
    String? errorMsg,
    int? processingItemId,
    int? processingExtensionId,
    bool clearProcessing = false,
    bool clearExtProcessing = false,
  }) {
    return AnfitrionVisitantesState(
      visitantes: visitantes ?? this.visitantes,
      pendingExtensions: pendingExtensions ?? this.pendingExtensions,
      isLoading: isLoading ?? this.isLoading,
      errorMsg: errorMsg ?? this.errorMsg,
      processingItemId:
          clearProcessing ? null : (processingItemId ?? this.processingItemId),
      processingExtensionId: clearExtProcessing
          ? null
          : (processingExtensionId ?? this.processingExtensionId),
    );
  }
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

/// ViewModel del tab "Mis Visitantes" del Anfitrión — GAMA MPF v1.0.
class AnfitrionVisitantesViewModel
    extends Notifier<AnfitrionVisitantesState> {
  late final AccessLogRepository _logRepo;
  late final RequestRepository _requestRepo;
  Timer? _extensionPollTimer;

  @override
  AnfitrionVisitantesState build() {
    _logRepo = ref.read(accessLogRepositoryProvider);
    _requestRepo = ref.read(requestRepositoryProvider);
    Future.microtask(_load);
    // Polling cada 10 s: actualiza visitantes Y extensiones pendientes.
    _extensionPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        await _pollExtensions();
        await _loadSilent();
      },
    );
    ref.onDispose(() => _extensionPollTimer?.cancel());
    return const AnfitrionVisitantesState(isLoading: true);
  }

  // ── Carga de datos ────────────────────────────────────────────────────────

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (session == null) {
      state = state.copyWith(
        isLoading: false,
        errorMsg: 'Sesión no disponible.',
        clearProcessing: true,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMsg: '', clearProcessing: true);
    try {
      final data = await _logRepo.getActiveVisitsForHost(
        session.correo,
        DateTime.now(),
      );
      state = state.copyWith(isLoading: false, visitantes: data);
    } catch (e) {
      debugPrint('[AnfitrionVisitantesVM] Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMsg: 'Error al cargar visitantes. Intenta de nuevo.',
      );
    }
  }

  /// Recarga silenciosa (sin spinner) usada por el timer de polling.
  Future<void> _loadSilent() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    try {
      final data = await _logRepo.getActiveVisitsForHost(
        session.correo,
        DateTime.now(),
      );
      state = state.copyWith(visitantes: data);
    } catch (_) {}
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  /// Registra que el visitante llegó a la oficina del Anfitrión.
  Future<void> confirmarLlegadaOficina(int itemId) async {
    await _registerEvent(itemId, AccessEventType.llegadaOficina);
  }

  /// Registra que el visitante salió de la oficina del Anfitrión.
  Future<void> confirmarSalidaOficina(int itemId) async {
    await _registerEvent(itemId, AccessEventType.salidaOficina);
  }

  /// Recarga la lista manualmente (pull-to-refresh).
  Future<void> refresh() => _load();

  // ── Extensiones de llegada tardía ─────────────────────────────────────────

  Future<void> _pollExtensions() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    try {
      final extensions = await _requestRepo.findPendingExtensions(
        session.correo,
      );
      state = state.copyWith(pendingExtensions: extensions);
    } catch (_) {}
  }

  /// Aprueba la extensión — actualiza tiempos en la solicitud.
  Future<void> aprobarExtension(int requestId) async {
    state = state.copyWith(processingExtensionId: requestId);
    try {
      await _requestRepo.resolveExtension(
        requestId: requestId,
        approved: true,
      );
      await _pollExtensions();
    } catch (e) {
      debugPrint('[AnfitrionVisitantesVM] Error aprobando extensión: $e');
    } finally {
      state = state.copyWith(clearExtProcessing: true);
    }
  }

  /// Rechaza la extensión — el QR sigue vencido para el guardia.
  Future<void> rechazarExtension(int requestId) async {
    state = state.copyWith(processingExtensionId: requestId);
    try {
      await _requestRepo.resolveExtension(
        requestId: requestId,
        approved: false,
      );
      await _pollExtensions();
    } catch (e) {
      debugPrint('[AnfitrionVisitantesVM] Error rechazando extensión: $e');
    } finally {
      state = state.copyWith(clearExtProcessing: true);
    }
  }

  // ── Helper privado ────────────────────────────────────────────────────────

  Future<void> _registerEvent(int itemId, AccessEventType event) async {
    state = state.copyWith(processingItemId: itemId, errorMsg: '');
    try {
      await _logRepo.create(
        AccessLogDbModel(itemId: itemId, eventType: event),
      );
      await _load();
    } catch (e) {
      debugPrint('[AnfitrionVisitantesVM] Error registrando evento: $e');
      state = state.copyWith(
        clearProcessing: true,
        errorMsg: 'Error al registrar. Intenta de nuevo.',
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final anfitrionVisitantesViewModelProvider = NotifierProvider<
    AnfitrionVisitantesViewModel, AnfitrionVisitantesState>(
  AnfitrionVisitantesViewModel.new,
);
