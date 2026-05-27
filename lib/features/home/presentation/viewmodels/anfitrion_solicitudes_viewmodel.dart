/// @file: anfitrion_solicitudes_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del tab "Mis Solicitudes" del Anfitrión.
///   Carga el historial de solicitudes del anfitrión autenticado desde
///   la BD usando findByHostWithDetails.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/session_provider.dart';
import '../../data/models/request_db_model.dart';
import '../../data/models/request_summary_dto.dart';
import '../../data/repositories/request_item_repository.dart';
import '../../data/repositories/request_repository.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

@immutable
class AnfitrionSolicitudesState {
  const AnfitrionSolicitudesState({
    this.solicitudes = const [],
    this.isLoading = false,
    this.errorMsg = '',
  });

  final List<RequestSummaryDto> solicitudes;
  final bool isLoading;
  final String errorMsg;

  bool get hasError => errorMsg.isNotEmpty;

  AnfitrionSolicitudesState copyWith({
    List<RequestSummaryDto>? solicitudes,
    bool? isLoading,
    String? errorMsg,
  }) {
    return AnfitrionSolicitudesState(
      solicitudes: solicitudes ?? this.solicitudes,
      isLoading: isLoading ?? this.isLoading,
      errorMsg: errorMsg ?? this.errorMsg,
    );
  }
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

/// ViewModel del historial de solicitudes del Anfitrión.
class AnfitrionSolicitudesViewModel
    extends Notifier<AnfitrionSolicitudesState> {
  late final RequestRepository _repo;
  late final RequestItemRepository _itemRepo;

  @override
  AnfitrionSolicitudesState build() {
    _repo = ref.read(requestRepositoryProvider);
    _itemRepo = ref.read(requestItemRepositoryProvider);
    Future.microtask(_load);
    return const AnfitrionSolicitudesState(isLoading: true);
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    if (session == null) {
      state = state.copyWith(
        isLoading: false,
        errorMsg: 'Sesión no disponible.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMsg: '');
    try {
      final data = await _repo.findByHostWithDetails(session.correo);
      state = state.copyWith(isLoading: false, solicitudes: data);
    } catch (e) {
      debugPrint('[AnfitrionSolicitudesVM] Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMsg: 'Error al cargar solicitudes. Intenta de nuevo.',
      );
    }
  }

  Future<void> refresh() => _load();

  // ── Cancelar solicitud ────────────────────────────────────────────────────

  /// Cancela la solicitud [requestId] si ningún visitante ha entrado aún.
  ///
  /// Retorna `true` si la cancelación fue exitosa, `false` si no se puede
  /// cancelar porque algún visitante ya ingresó al instituto.
  Future<bool> cancelarSolicitud(int requestId) async {
    state = state.copyWith(isLoading: true, errorMsg: '');
    try {
      final tieneEntrada = await _itemRepo.hasAnyEntrada(requestId);
      if (tieneEntrada) {
        state = state.copyWith(
          isLoading: false,
          errorMsg: 'No se puede cancelar: el visitante ya ingresó al instituto.',
        );
        return false;
      }
      await _repo.updateStatus(requestId, RequestStatus.cancelada);
      await _load();
      return true;
    } catch (e) {
      debugPrint('[AnfitrionSolicitudesVM] Error cancelando: $e');
      state = state.copyWith(
        isLoading: false,
        errorMsg: 'Error al cancelar. Intenta de nuevo.',
      );
      return false;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final anfitrionSolicitudesViewModelProvider = NotifierProvider<
    AnfitrionSolicitudesViewModel, AnfitrionSolicitudesState>(
  AnfitrionSolicitudesViewModel.new,
);
