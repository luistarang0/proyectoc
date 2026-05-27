/// @file: guardia_visitas_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del tab "Visitas del día" del Guardia.
///   Carga todas las visitas activas del día y permite al guardia
///   registrar entradas y salidas directamente desde la lista,
///   especialmente útil para visitas espontáneas.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/access_log_db_model.dart';
import '../../data/repositories/access_log_repository.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

class GuardiaVisitasState {
  const GuardiaVisitasState({
    this.visitas = const [],
    this.isLoading = false,
    this.errorMsg = '',
    this.processingItemId,
  });

  final List<ActiveVisitDto> visitas;
  final bool isLoading;
  final String errorMsg;
  final int? processingItemId;

  bool get hasError => errorMsg.isNotEmpty;
  bool isProcessing(int itemId) => processingItemId == itemId;

  GuardiaVisitasState copyWith({
    List<ActiveVisitDto>? visitas,
    bool? isLoading,
    String? errorMsg,
    int? processingItemId,
    bool clearProcessing = false,
  }) {
    return GuardiaVisitasState(
      visitas: visitas ?? this.visitas,
      isLoading: isLoading ?? this.isLoading,
      errorMsg: errorMsg ?? this.errorMsg,
      processingItemId:
          clearProcessing ? null : (processingItemId ?? this.processingItemId),
    );
  }
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

class GuardiaVisitasViewModel extends Notifier<GuardiaVisitasState> {
  late final AccessLogRepository _logRepo;

  @override
  GuardiaVisitasState build() {
    _logRepo = ref.read(accessLogRepositoryProvider);
    Future.microtask(_load);
    return const GuardiaVisitasState(isLoading: true);
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, errorMsg: '', clearProcessing: true);
    try {
      final data = await _logRepo.getActiveVisitsForDate(DateTime.now());
      state = state.copyWith(isLoading: false, visitas: data);
    } catch (e) {
      debugPrint('[GuardiaVisitasVM] Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMsg: 'Error al cargar las visitas del día.',
      );
    }
  }

  /// Registra la entrada del visitante al instituto.
  Future<void> registrarEntrada(int itemId) async {
    await _registrar(itemId, AccessEventType.entradaInstitucion);
  }

  /// Registra la salida del visitante del instituto.
  Future<void> registrarSalida(int itemId) async {
    await _registrar(itemId, AccessEventType.salidaInstitucion);
  }

  Future<void> refresh() => _load();

  Future<void> _registrar(int itemId, AccessEventType event) async {
    state = state.copyWith(processingItemId: itemId, errorMsg: '');
    try {
      await _logRepo.create(
        AccessLogDbModel(itemId: itemId, eventType: event),
      );
      await _load();
    } catch (e) {
      state = state.copyWith(
        clearProcessing: true,
        errorMsg: 'Error al registrar. Intenta de nuevo.',
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final guardiaVisitasViewModelProvider =
    NotifierProvider<GuardiaVisitasViewModel, GuardiaVisitasState>(
  GuardiaVisitasViewModel.new,
);
