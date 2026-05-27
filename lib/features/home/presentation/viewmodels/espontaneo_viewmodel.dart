/// @file: espontaneo_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel para la creación de visitas espontáneas (walk-in).
///   El guardia captura el correo del visitante y el edificio destino.
///   El correo del área (Email_Host) se resuelve desde el caché del mapa
///   edificio→correoPuesto obtenido de SAM.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/sam_departamento_service.dart';
import '../../data/models/access_log_db_model.dart';
import '../../data/models/request_db_model.dart';
import '../../data/models/request_item_db_model.dart';
import '../../data/repositories/access_log_repository.dart';
import '../../data/repositories/request_item_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/visitor_repository.dart';

// ── Estado ────────────────────────────────────────────────────────────────────

@immutable
class EspontaneoState {
  const EspontaneoState({
    this.isSubmitting = false,
    this.isRegistering = false,
    this.createdToken,
    this.visitorName,
    this.entradaRegistrada = false,
    this.errorMsg = '',
  });

  final bool isSubmitting;
  final bool isRegistering;

  /// UUID generado tras crear la visita — null hasta que se crea.
  final String? createdToken;

  /// Nombre del visitante — para mostrar confirmación.
  final String? visitorName;

  /// True si ya se registró la entrada de forma inmediata.
  final bool entradaRegistrada;

  final String errorMsg;

  bool get hasError => errorMsg.isNotEmpty;
  bool get hasToken => createdToken != null;

  EspontaneoState copyWith({
    bool? isSubmitting,
    bool? isRegistering,
    String? createdToken,
    String? visitorName,
    bool? entradaRegistrada,
    String? errorMsg,
  }) {
    return EspontaneoState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isRegistering: isRegistering ?? this.isRegistering,
      createdToken: createdToken ?? this.createdToken,
      visitorName: visitorName ?? this.visitorName,
      entradaRegistrada: entradaRegistrada ?? this.entradaRegistrada,
      errorMsg: errorMsg ?? this.errorMsg,
    );
  }

  EspontaneoState reset() => const EspontaneoState();
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

class EspontaneoViewModel extends Notifier<EspontaneoState> {
  static const _uuid = Uuid();

  late final VisitorRepository _visitorRepo;
  late final RequestRepository _requestRepo;
  late final RequestItemRepository _itemRepo;
  late final AccessLogRepository _logRepo;

  @override
  EspontaneoState build() {
    _visitorRepo = ref.read(visitorRepositoryProvider);
    _requestRepo = ref.read(requestRepositoryProvider);
    _itemRepo = ref.read(requestItemRepositoryProvider);
    _logRepo = ref.read(accessLogRepositoryProvider);
    return const EspontaneoState();
  }

  // ── API pública ───────────────────────────────────────────────────────────

  /// Crea la visita espontánea en BD y genera el access_token.
  ///
  /// El [edificioCode] es el nombre del edificio (A, B, C...) de nuestro
  /// catálogo. El correo del área se resuelve desde el caché SAM.
  Future<void> submit({
    required String correoVisitante,
    required String nombreVisitante,
    required int buildingId,
    required String edificioCode,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMsg: '');

    try {
      // Resolver Email_Host desde el caché edificio→correoPuesto.
      final emailMap = ref.read(edificioEmailCacheProvider);
      final areaEmail = emailMap[edificioCode] ?? '';

      if (areaEmail.isEmpty) {
        debugPrint(
          '[EspontaneoVM] Sin correo para edificio "$edificioCode". '
          'Caché: $emailMap',
        );
      }

      // Buscar o crear visitante.
      final visitor = await _visitorRepo.findOrCreate(
        fullName: nombreVisitante.isEmpty ? correoVisitante : nombreVisitante,
        email: correoVisitante,
      );

      // Crear solicitud espontánea (pre-aprobada, sin autorizador).
      final requestId = await _requestRepo.create(
        RequestDbModel(
          emailHost: areaEmail,
          autorizadorId: '',
          buildingId: buildingId,
          visitType: VisitTypeDb.espontaneo,
          scheduledDate: DateTime.now(),
          status: RequestStatus.aprobada,
        ),
      );

      // Generar UUID y crear ítem.
      final token = _uuid.v4();
      await _itemRepo.create(
        RequestItemDbModel(
          requestId: requestId,
          visitorId: visitor.visitorId!,
          accessToken: token,
        ),
      );

      state = state.copyWith(
        isSubmitting: false,
        createdToken: token,
        visitorName: visitor.fullName,
      );
    } catch (e) {
      debugPrint('[EspontaneoVM] Error: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMsg: 'Error al crear la visita. Intenta de nuevo.',
      );
    }
  }

  /// Registra la entrada inmediata del visitante espontáneo.
  Future<void> registrarEntradaInmediata() async {
    final token = state.createdToken;
    if (token == null) return;

    state = state.copyWith(isRegistering: true, errorMsg: '');
    try {
      final item = await _itemRepo.findByToken(token);
      if (item == null) {
        state = state.copyWith(
          isRegistering: false,
          errorMsg: 'Token no encontrado en BD.',
        );
        return;
      }
      await _logRepo.create(
        AccessLogDbModel(
          itemId: item.itemId!,
          eventType: AccessEventType.entradaInstitucion,
        ),
      );
      state = state.copyWith(
        isRegistering: false,
        entradaRegistrada: true,
      );
    } catch (e) {
      state = state.copyWith(
        isRegistering: false,
        errorMsg: 'Error al registrar entrada.',
      );
    }
  }

  /// Resetea el ViewModel para crear otra visita.
  void reset() {
    state = state.reset();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final espontaneoViewModelProvider =
    NotifierProvider<EspontaneoViewModel, EspontaneoState>(
  EspontaneoViewModel.new,
);
