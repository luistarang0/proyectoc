/// @file: anfitrion_solicitudes_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del tab "Mis Solicitudes" del Anfitrión.
///   Solo muestra solicitudes PENDIENTES o APROBADAS donde ningún visitante
///   ha ingresado aún (antes de entradaInstitucion). Las canceladas/rechazadas
///   se excluyen. Usa polling cada 10 s para reflejar cambios en tiempo real.
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
  Timer? _pollTimer;

  @override
  AnfitrionSolicitudesState build() {
    _repo = ref.read(requestRepositoryProvider);
    _itemRepo = ref.read(requestItemRepositoryProvider);
    Future.microtask(_load);

    // Polling cada 10 s para reflejar cambios en tiempo real:
    // aprobación por el autorizador, entrada del visitante, etc.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    ref.onDispose(() => _pollTimer?.cancel());

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

    // Primera carga: isLoading = true. Polls silenciosos: no cambiar isLoading
    // para no mostrar el spinner en cada tick.
    final isFirstLoad = state.solicitudes.isEmpty && !state.hasError;
    if (isFirstLoad) state = state.copyWith(isLoading: true, errorMsg: '');

    try {
      // Rechazar solicitudes vencidas antes de cargar la lista.
      await _autoRejectIfNeeded();

      // Solo PENDIENTE y APROBADA sin entrada registrada.
      final data = await _repo.findSolicitudesAnfitrion(session.correo);
      state = state.copyWith(isLoading: false, errorMsg: '', solicitudes: data);
    } catch (e) {
      debugPrint('[AnfitrionSolicitudesVM] Error: $e');
      // Solo mostrar error en primera carga; silenciar fallos de poll.
      if (isFirstLoad) {
        state = state.copyWith(
          isLoading: false,
          errorMsg: 'Error al cargar solicitudes. Intenta de nuevo.',
        );
      }
    }
  }

  Future<void> refresh() => _load();

  // ── Cierre automático ─────────────────────────────────────────────────────

  /// Ejecuta las reglas de cierre antes de cada carga:
  ///   1. Rechaza solicitudes cuyo scheduled_time + tolerance ya pasó.
  ///   2. Si son las 21:00 o más, rechaza todo lo que quede pendiente del día.
  Future<void> _autoRejectIfNeeded() async {
    try {
      await _repo.autoRejectExpired();
      if (DateTime.now().hour >= 21) {
        await _repo.autoRejectAllPending();
      }
    } catch (e) {
      debugPrint('[AnfitrionSolicitudesVM] autoReject error: $e');
    }
  }

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
          errorMsg:
              'No se puede cancelar: el visitante ya ingresó al instituto.',
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
