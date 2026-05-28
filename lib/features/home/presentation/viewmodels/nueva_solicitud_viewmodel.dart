/// @file: nueva_solicitud_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del formulario de nueva solicitud de visita.
///   Orquesta la creación de visitantes y solicitud en la BD y genera
///   los access_token UUID de cada ítem. El edificio de destino se
///   resuelve automáticamente desde el perfil SAM del anfitrión
///   (edificio_empleado → building_id en el catálogo).
///   Referencia: RF-01 del Proyecto C — Control de Accesos.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/data/models/sam_response_model.dart';
import '../../../auth/presentation/providers/session_provider.dart';
import '../../data/models/request_db_model.dart';
import '../../data/models/request_item_db_model.dart';
import '../../data/repositories/building_repository.dart';
import '../../data/repositories/request_item_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/visitor_repository.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

/// Datos de un visitante adicional en el formulario.
@immutable
class VisitanteFormData {
  const VisitanteFormData({required this.nombre, required this.correo});
  final String nombre;
  final String correo;
}

/// Estado inmutable del formulario de nueva solicitud.
@immutable
class NuevaSolicitudState {
  const NuevaSolicitudState({
    this.isSubmitting = false,
    this.errorMsg = '',
    this.submitSuccess = false,
  });

  final bool isSubmitting;
  final String errorMsg;

  /// True tras envío exitoso; la vista lo usa para limpiar el form.
  final bool submitSuccess;

  bool get hasError => errorMsg.isNotEmpty;

  NuevaSolicitudState copyWith({
    bool? isSubmitting,
    String? errorMsg,
    bool? submitSuccess,
  }) {
    return NuevaSolicitudState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMsg: errorMsg ?? this.errorMsg,
      submitSuccess: submitSuccess ?? this.submitSuccess,
    );
  }
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

/// ViewModel del formulario de nueva solicitud — GAMA MPF v1.0.
///
/// El anfitrión NO selecciona edificio: el building_id se resuelve
/// automáticamente buscando `session.edificio` en el catálogo de edificios.
class NuevaSolicitudViewModel extends Notifier<NuevaSolicitudState> {
  static const _uuid = Uuid();

  late final BuildingRepository _buildingRepo;
  late final VisitorRepository _visitorRepo;
  late final RequestRepository _requestRepo;
  late final RequestItemRepository _itemRepo;

  @override
  NuevaSolicitudState build() {
    _buildingRepo = ref.read(buildingRepositoryProvider);
    _visitorRepo = ref.read(visitorRepositoryProvider);
    _requestRepo = ref.read(requestRepositoryProvider);
    _itemRepo = ref.read(requestItemRepositoryProvider);
    return const NuevaSolicitudState();
  }

  // ── Envío del formulario ──────────────────────────────────────────────────

  /// Crea la solicitud completa en la BD.
  ///
  /// Flujo:
  ///   1. Validar sesión y jefeSamId.
  ///   2. Resolver building_id desde session.edificio (SAM).
  ///   3. findOrCreate de cada visitante en `visitors`.
  ///   4. INSERT en `requests`.
  ///   5. INSERT en `requests_items` (UUID por visitante).
  Future<void> submit({
    required String nombrePrincipal,
    required String correoPrincipal,
    required String scheduledTime, // 'HH:MM:SS'
    required DateTime scheduledDate,
    required int toleranceMinutes,
    required String motivo,
    required List<VisitanteFormData> adicionales,
  }) async {
    final SamUserModel? session = ref.read(sessionProvider);

    if (session == null) {
      state = state.copyWith(
        errorMsg: 'Sesión no disponible. Inicia sesión nuevamente.',
      );
      return;
    }
    if (session.jefeSamId == null) {
      state = state.copyWith(
        errorMsg: 'No se pudo identificar al autorizador. Contacta a soporte.',
      );
      return;
    }

    // ── Validación de ventana horaria institucional (07:00–19:00) ────────────
    final timeError = _validateTimeWindow(scheduledTime, toleranceMinutes);
    if (timeError != null) {
      state = state.copyWith(errorMsg: timeError);
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      errorMsg: '',
      submitSuccess: false,
    );

    try {
      // Resolver building_id desde el nombre de edificio en SAM.
      final building = await _buildingRepo.findByName(session.edificio);
      if (building == null) {
        state = state.copyWith(
          isSubmitting: false,
          errorMsg:
              'El edificio "${session.edificio}" no está registrado en el catálogo. '
              'Contacta al administrador del sistema.',
        );
        return;
      }

      // Compilar lista de visitantes.
      final allVisitors = [
        VisitanteFormData(nombre: nombrePrincipal, correo: correoPrincipal),
        ...adicionales,
      ];

      final visitType = allVisitors.length == 1
          ? VisitTypeDb.individual
          : VisitTypeDb.grupal;

      // Crear solicitud.
      final requestId = await _requestRepo.create(
        RequestDbModel(
          emailHost: session.correo,
          autorizadorId: session.jefeSamId.toString(),
          buildingId: building.buildingId,
          visitType: visitType,
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          toleranceMinutes: toleranceMinutes,
          status: RequestStatus.pendiente,
          groupName: visitType == VisitTypeDb.grupal ? motivo : null,
        ),
      );

      // Crear visitantes e ítems con token UUID.
      final items = <RequestItemDbModel>[];
      for (final v in allVisitors) {
        final visitor = await _visitorRepo.findOrCreate(
          fullName: v.nombre,
          email: v.correo,
        );
        items.add(
          RequestItemDbModel(
            requestId: requestId,
            visitorId: visitor.visitorId!,
            accessToken: _uuid.v4(),
          ),
        );
      }

      await _itemRepo.createAll(items);

      state = state.copyWith(isSubmitting: false, submitSuccess: true);
    } catch (e) {
      debugPrint('[NuevaSolicitud] Error: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMsg: 'Error al enviar la solicitud. Intenta de nuevo.',
      );
    }
  }

  /// Resetea el flag de éxito para reutilizar el formulario.
  void resetSuccess() {
    state = state.copyWith(submitSuccess: false);
  }

  // ── Validación de ventana horaria ─────────────────────────────────────────

  /// Verifica que la visita quepa dentro del horario institucional 07:00–19:00,
  /// considerando la tolerancia (± [toleranceMinutes]).
  ///
  /// Retorna un mensaje de error si la validación falla, o `null` si es válido.
  String? _validateTimeWindow(String scheduledTime, int toleranceMinutes) {
    // Parsear 'HH:MM:SS' o 'HH:MM'.
    final parts = scheduledTime.split(':');
    if (parts.length < 2) return 'Formato de hora inválido.';

    final h = int.tryParse(parts[0]) ?? -1;
    final m = int.tryParse(parts[1]) ?? -1;
    if (h < 0 || m < 0) return 'Formato de hora inválido.';

    // Convertir todo a minutos desde medianoche.
    final scheduledMin = h * 60 + m;
    const openMin = 7 * 60;   // 07:00
    const closeMin = 19 * 60; // 19:00

    final earliestMin = scheduledMin - toleranceMinutes;
    final latestMin   = scheduledMin + toleranceMinutes;

    if (earliestMin < openMin) {
      final earliest = _fmtMin(earliestMin);
      return 'Con tolerancia de ${toleranceMinutes}min, la ventana de llegada '
          'empieza a las $earliest, antes de la apertura institucional (07:00).\n'
          'Elige una hora igual o posterior a las 07:${toleranceMinutes.toString().padLeft(2, '0')}.';
    }

    if (latestMin > closeMin) {
      final latest = _fmtMin(latestMin);
      return 'Con tolerancia de ${toleranceMinutes}min, la ventana de llegada '
          'termina a las $latest, después del cierre institucional (19:00).\n'
          'Elige una hora igual o anterior a las ${_fmtMin(closeMin - toleranceMinutes)}.';
    }

    return null; // válido
  }

  /// Formatea minutos desde medianoche como 'HH:MM'.
  String _fmtMin(int totalMinutes) {
    final h = (totalMinutes ~/ 60).clamp(0, 23).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).clamp(0, 59).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final nuevaSolicitudViewModelProvider =
    NotifierProvider<NuevaSolicitudViewModel, NuevaSolicitudState>(
  NuevaSolicitudViewModel.new,
);
