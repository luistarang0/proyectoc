/// @file: guardia_visitas_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del tab "Visitas del día" del Guardia.
///   Carga todas las visitas activas del día y permite al guardia
///   registrar entradas y salidas directamente desde la lista,
///   especialmente útil para visitas espontáneas.
///   Incluye validación de horario: bloquea entradas fuera del rango
///   scheduled_time ± tolerance_minutes y expone el estado para que
///   la vista muestre el mensaje adecuado o inicie el flujo de extensión.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.1.0
/// @last_update: 2026-05-28

library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/access_log_db_model.dart';
import '../../data/repositories/access_log_repository.dart';

// ── Resultado de la validación de horario ─────────────────────────────────────

enum TimeCheckResult { ok, tooEarly, expired }

// ── Estado ────────────────────────────────────────────────────────────────────

class GuardiaVisitasState {
  const GuardiaVisitasState({
    this.visitas = const [],
    this.isLoading = false,
    this.errorMsg = '',
    this.processingItemId,
    this.timeError,
  });

  final List<ActiveVisitDto> visitas;
  final bool isLoading;
  final String errorMsg;
  final int? processingItemId;

  /// Error de validación de horario. Non-null cuando la entrada fue bloqueada.
  final TimeError? timeError;

  bool get hasError => errorMsg.isNotEmpty;
  bool get hasTimeError => timeError != null;
  bool isProcessing(int itemId) => processingItemId == itemId;

  GuardiaVisitasState copyWith({
    List<ActiveVisitDto>? visitas,
    bool? isLoading,
    String? errorMsg,
    int? processingItemId,
    bool clearProcessing = false,
    TimeError? timeError,
    bool clearTimeError = false,
  }) {
    return GuardiaVisitasState(
      visitas: visitas ?? this.visitas,
      isLoading: isLoading ?? this.isLoading,
      errorMsg: errorMsg ?? this.errorMsg,
      processingItemId:
          clearProcessing ? null : (processingItemId ?? this.processingItemId),
      timeError: clearTimeError ? null : (timeError ?? this.timeError),
    );
  }
}

/// Datos del error de horario para mostrar en la UI.
class TimeError {
  const TimeError({
    required this.result,
    required this.dto,
    required this.message,
  });

  /// Si es [TimeCheckResult.expired], la vista puede ofrecer extensión.
  final TimeCheckResult result;

  /// El DTO de la visita que generó el error (para el flujo de extensión).
  final ActiveVisitDto dto;

  /// Mensaje amigable para mostrar al guardia.
  final String message;

  bool get canExtend => result == TimeCheckResult.expired;
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

class GuardiaVisitasViewModel extends Notifier<GuardiaVisitasState> {
  late final AccessLogRepository _logRepo;
  Timer? _pollTimer;

  @override
  GuardiaVisitasState build() {
    _logRepo = ref.read(accessLogRepositoryProvider);
    Future.microtask(_load);

    // Polling cada 10 s: detecta nuevos visitantes y cambios de estado
    // (entradas/salidas registradas por el guardia en QR o por el anfitrión).
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    ref.onDispose(() => _pollTimer?.cancel());

    return const GuardiaVisitasState(isLoading: true);
  }

  Future<void> _load() async {
    final isFirstLoad = state.visitas.isEmpty && !state.hasError;
    if (isFirstLoad) {
      state = state.copyWith(
        isLoading: true,
        errorMsg: '',
        clearProcessing: true,
      );
    }
    try {
      final data = await _logRepo.getActiveVisitsForDate(DateTime.now());
      state = state.copyWith(
        isLoading: false,
        errorMsg: '',
        visitas: data,
        clearProcessing: true,
      );
    } catch (e) {
      debugPrint('[GuardiaVisitasVM] Error: $e');
      if (isFirstLoad) {
        state = state.copyWith(
          isLoading: false,
          errorMsg: 'Error al cargar las visitas del día.',
        );
      }
    }
  }

  /// Registra la entrada del visitante al instituto, validando primero
  /// que la hora actual esté dentro del rango permitido.
  ///
  /// Para visitas espontáneas (sin horario programado) no se aplica
  /// restricción de tiempo.
  Future<void> registrarEntrada(int itemId) async {
    final dto = state.visitas.firstWhere((d) => d.item.itemId == itemId);

    // Las espontáneas no tienen restricción de horario.
    if (!dto.isEspontanea &&
        dto.scheduledTime != null &&
        dto.toleranceMinutes != null) {
      final check = _checkTime(dto);

      if (check != TimeCheckResult.ok) {
        final tol = dto.toleranceMinutes!;
        final message = check == TimeCheckResult.tooEarly
            ? 'Aún no es hora\nProgramada: ${dto.formattedTime} ±${tol}min'
            : 'Visita vencida\nProgramada: ${dto.formattedTime} ±${tol}min\n'
                'Puedes notificar al anfitrión para solicitar extensión.';

        state = state.copyWith(
          timeError: TimeError(result: check, dto: dto, message: message),
        );
        return;
      }
    }

    await _registrar(itemId, AccessEventType.entradaInstitucion);
  }

  /// Registra la salida del visitante del instituto.
  Future<void> registrarSalida(int itemId) async {
    await _registrar(itemId, AccessEventType.salidaInstitucion);
  }

  Future<void> refresh() => _load();

  /// Limpia el error de tiempo (llamar después de que la vista lo procesó).
  void clearTimeError() {
    state = state.copyWith(clearTimeError: true);
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

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

  /// Compara la hora actual contra scheduled_time ± tolerance_minutes.
  TimeCheckResult _checkTime(ActiveVisitDto dto) {
    final parts = dto.scheduledTime!.split(':');
    if (parts.length < 2) return TimeCheckResult.ok;

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final schedMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final diff = nowMin - schedMin; // positivo = llegó tarde
    final tol = dto.toleranceMinutes!;

    if (diff < -tol) return TimeCheckResult.tooEarly;
    if (diff > tol) return TimeCheckResult.expired;
    return TimeCheckResult.ok;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final guardiaVisitasViewModelProvider =
    NotifierProvider<GuardiaVisitasViewModel, GuardiaVisitasState>(
  GuardiaVisitasViewModel.new,
);
