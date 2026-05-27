/// @file: autorizador_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del panel de autorización. Carga solicitudes
///   pendientes e historial filtradas por el empleadoSamId del autorizador
///   autenticado y gestiona las acciones de aprobar y rechazar.
///   Referencia: RF-17 del Proyecto C — Control de Accesos.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

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
    this.isProcessing = false,
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

  /// True mientras se procesa un aprobar/rechazar.
  final bool isProcessing;

  final String errorMsg;

  bool get hasError => errorMsg.isNotEmpty;

  AutorizadorState copyWith({
    List<RequestSummaryDto>? pending,
    List<RequestSummaryDto>? approved,
    List<RequestSummaryDto>? rejected,
    bool? isLoading,
    bool? isProcessing,
    String? errorMsg,
  }) {
    return AutorizadorState(
      pending: pending ?? this.pending,
      approved: approved ?? this.approved,
      rejected: rejected ?? this.rejected,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
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

  @override
  AutorizadorState build() {
    _requestRepo = ref.read(requestRepositoryProvider);
    Future.microtask(_loadAll);
    return const AutorizadorState(isLoading: true);
  }

  // ── Carga de datos ────────────────────────────────────────────────────────

  /// Carga pendientes e historial en paralelo.
  Future<void> _loadAll() async {
    final session = ref.read(sessionProvider);

    if (session == null) {
      state = state.copyWith(
        isLoading: false,
        errorMsg: 'Sesión no disponible.',
      );
      return;
    }

    if (session.empleadoSamId == null) {
      state = state.copyWith(
        isLoading: false,
        errorMsg:
            'No se pudo identificar tu ID de empleado en SAM. '
            'Cierra sesión e intenta de nuevo.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMsg: '');

    try {
      final autorizadorId = session.empleadoSamId.toString();

      final results = await Future.wait([
        _requestRepo.findPendingWithDetails(autorizadorId),
        _requestRepo.findHistoryWithDetails(autorizadorId),
      ]);

      final history = results[1];
      state = state.copyWith(
        isLoading: false,
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
      state = state.copyWith(
        isLoading: false,
        errorMsg: 'Error al cargar solicitudes. Intenta de nuevo.',
      );
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

  /// Recarga manualmente el panel (pull-to-refresh).
  Future<void> refresh() async => _loadAll();

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<void> _updateStatus(int requestId, RequestStatus status) async {
    state = state.copyWith(isProcessing: true, errorMsg: '');
    try {
      await _requestRepo.updateStatus(requestId, status);
      await _loadAll();
    } catch (e) {
      debugPrint('[AutorizadorVM] Error actualizando solicitud $requestId: $e');
      state = state.copyWith(
        isProcessing: false,
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
