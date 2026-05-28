/// @file: autorizador_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del panel de autorización. Carga solicitudes
///   pendientes e historial filtradas por el empleadoSamId del autorizador
///   autenticado y gestiona las acciones de aprobar y rechazar.
///   Referencia: RF-17 del Proyecto C — Control de Accesos.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.1.0
/// @last_update: 2026-05-28

library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/session_provider.dart';
import '../../data/models/request_db_model.dart';
import '../../data/models/request_summary_dto.dart';
import '../../data/repositories/request_repository.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

/// Estado inmutable del panel del Autorizador.
@immutable
class AutorizadorState {
  const AutorizadorState({
    this.pending = const [],
    this.approved = const [],
    this.rejected = const [],
    this.isLoading = false,
    this.processingRequestId,
    this.errorMsg = '',
  });

  /// Solicitudes en espera de resolución.
  final List<RequestSummaryDto> pending;

  /// Solicitudes ya aprobadas.
  final List<RequestSummaryDto> approved;

  /// Solicitudes rechazadas.
  final List<RequestSummaryDto> rejected;

  /// True mientras se cargan los datos del servidor.
  final bool isLoading;

  /// ID de la solicitud que se está procesando actualmente (aprobar/rechazar).
  /// Null cuando no hay ninguna en proceso. Permite deshabilitar SOLO la
  /// tarjeta en proceso y no toda la lista.
  final int? processingRequestId;

  final String errorMsg;

  bool get hasError => errorMsg.isNotEmpty;

  /// True si la solicitud [requestId] está siendo procesada en este momento.
  bool isProcessingFor(int requestId) => processingRequestId == requestId;

  AutorizadorState copyWith({
    List<RequestSummaryDto>? pending,
    List<RequestSummaryDto>? approved,
    List<RequestSummaryDto>? rejected,
    bool? isLoading,
    int? processingRequestId,
    bool clearProcessing = false,
    String? errorMsg,
  }) {
    return AutorizadorState(
      pending: pending ?? this.pending,
      approved: approved ?? this.approved,
      rejected: rejected ?? this.rejected,
      isLoading: isLoading ?? this.isLoading,
      processingRequestId: clearProcessing
          ? null
          : (processingRequestId ?? this.processingRequestId),
      errorMsg: errorMsg ?? this.errorMsg,
    );
  }
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

/// ViewModel del panel de autorización — GAMA MPF v1.0.
///
/// Filtra por `autorizador_id = session.empleadoSamId`. Si el empleadoSamId
/// no está disponible en sesión (usuario master que no llamó a
/// obtenerDatosMaster), se muestra un error descriptivo.
class AutorizadorViewModel extends Notifier<AutorizadorState> {
  late final RequestRepository _requestRepo;
  Timer? _pollTimer;

  @override
  AutorizadorState build() {
    _requestRepo = ref.read(requestRepositoryProvider);
    Future.microtask(_loadAll);

    // Polling cada 10 s para detectar nuevas solicitudes en tiempo real.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadAll());
    ref.onDispose(() => _pollTimer?.cancel());

    return const AutorizadorState(isLoading: true);
  }

  // ── Carga de datos ────────────────────────────────────────────────────────

  /// Carga pendientes e historial en paralelo.
  Future<void> _loadAll() async {
    final session = ref.read(sessionProvider);

    if (session == null) {
      state = state.copyWith(
        isLoading: false,
        errorMsg: 'Sesión no disponible. Cierra sesión e inicia de nuevo.',
      );
      return;
    }

    if (session.empleadoSamId == null) {
      debugPrint(
        '[AutorizadorVM] empleadoSamId es null | correo: ${session.correo} | '
        'credenciales: ${session.credenciales}',
      );
      state = state.copyWith(
        isLoading: false,
        errorMsg:
            'No se pudo identificar tu ID en SAM.\n'
            'Cierra sesión e inicia de nuevo para actualizar la sesión.',
      );
      return;
    }

    // Primera carga: mostrar spinner. Polls silenciosos: no interrumpir la UI.
    final isFirstLoad = state.pending.isEmpty &&
        state.approved.isEmpty &&
        state.rejected.isEmpty &&
        !state.hasError;
    if (isFirstLoad) state = state.copyWith(isLoading: true, errorMsg: '');

    try {
      // Rechazar solicitudes vencidas antes de cargar el panel.
      await _autoRejectIfNeeded();

      final autorizadorId = session.empleadoSamId.toString();
      debugPrint(
        '[AutorizadorVM] cargando con autorizador_id="$autorizadorId"',
      );

      final results = await Future.wait([
        _requestRepo.findPendingWithDetails(autorizadorId),
        _requestRepo.findHistoryWithDetails(autorizadorId),
      ]);

      final history = results[1];
      state = state.copyWith(
        isLoading: false,
        clearProcessing: true, // libera bloqueo tras recarga
        pending: results[0],
        approved: history
            .where((r) => r.status == RequestStatus.aprobada)
            .toList(),
        rejected: history
            .where((r) => r.status == RequestStatus.rechazada)
            .toList(),
      );
    } catch (e) {
      debugPrint('[AutorizadorVM] Error cargando solicitudes: $e');
      if (isFirstLoad) {
        state = state.copyWith(
          isLoading: false,
          errorMsg: 'Error al cargar solicitudes. Intenta de nuevo.',
        );
      }
    }
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  /// Aprueba la solicitud [requestId] y recarga el panel.
  Future<void> approve(int requestId) async {
    await _updateStatus(requestId, RequestStatus.aprobada);
  }

  /// Rechaza la solicitud [requestId] y recarga el panel.
  Future<void> reject(int requestId) async {
    await _updateStatus(requestId, RequestStatus.rechazada);
  }

  /// Recarga manualmente el panel.
  Future<void> refresh() async => _loadAll();

  // ── Cierre automático ─────────────────────────────────────────────────────

  Future<void> _autoRejectIfNeeded() async {
    try {
      await _requestRepo.autoRejectExpired();
      if (DateTime.now().hour >= 21) {
        await _requestRepo.autoRejectAllPending();
      }
    } catch (e) {
      debugPrint('[AutorizadorVM] autoReject error: $e');
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<void> _updateStatus(int requestId, RequestStatus status) async {
    // Solo bloquea la tarjeta de ESTA solicitud, no las demás.
    state = state.copyWith(processingRequestId: requestId, errorMsg: '');
    try {
      await _requestRepo.updateStatus(requestId, status);
      await _loadAll(); // clearProcessing: true dentro de _loadAll
    } catch (e) {
      debugPrint('[AutorizadorVM] Error actualizando solicitud $requestId: $e');
      state = state.copyWith(
        clearProcessing: true,
        errorMsg: 'Error al procesar la solicitud. Intenta de nuevo.',
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Provider del [AutorizadorViewModel].
final autorizadorViewModelProvider =
    NotifierProvider<AutorizadorViewModel, AutorizadorState>(
  AutorizadorViewModel.new,
);
