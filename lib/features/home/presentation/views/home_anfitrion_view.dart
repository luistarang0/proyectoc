/// @file: home_anfitrion_view.dart
/// @project: Control de Accesos - GAMA
/// @description: Vista principal del rol Anfitrión. Gestiona la navegación
///   entre tabs (solicitudes, visitantes, nueva solicitud y perfil) mediante
///   un [IndexedStack] y un [BottomNavigationBar].
///   El Anfitrión es el empleado que recibe visitantes en sus instalaciones.
///   Referencia: RF-17 / RF-01.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_icons.dart';
import '../../../../core/config/app_spacing.dart';
import '../../../../core/config/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/home_shell.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/utils/logout.dart';
import '../../data/models/request_db_model.dart';
import '../../data/models/request_summary_dto.dart';
import '../../data/repositories/request_item_repository.dart';
import '../../model/visitante_model.dart';
import '../../../auth/data/models/sam_response_model.dart';
import '../../../auth/presentation/providers/session_provider.dart';
import '../viewmodels/anfitrion_solicitudes_viewmodel.dart';
import '../viewmodels/anfitrion_visitantes_viewmodel.dart';
import '../viewmodels/nueva_solicitud_viewmodel.dart';
import 'qr_viewer_view.dart';

// ── Extensión de presentación sobre EstatusVisitante (perspectiva Anfitrión)

extension _EstatusAnfitrionExt on EstatusVisitante {
  String get label => switch (this) {
    EstatusVisitante.enEspera => 'Esperando llegada',
    EstatusVisitante.enInstituto => 'Llegó al instituto',
    EstatusVisitante.enOficina => 'En tu oficina',
    EstatusVisitante.salidoOficina => 'Salió de tu oficina',
    EstatusVisitante.salidoInstituto => 'Salió del instituto',
  };

  Color get color => switch (this) {
    EstatusVisitante.enEspera => AppColors.iconGray,
    EstatusVisitante.enInstituto => AppColors.warning,
    EstatusVisitante.enOficina => AppColors.success,
    EstatusVisitante.salidoOficina => AppColors.info,
    EstatusVisitante.salidoInstituto => AppColors.borderGray,
  };

  IconData get icon => switch (this) {
    EstatusVisitante.enEspera => AppIcons.clock,
    EstatusVisitante.enInstituto => AppIcons.doorOpen,
    EstatusVisitante.enOficina => AppIcons.building,
    EstatusVisitante.salidoOficina => AppIcons.circleInfo,
    EstatusVisitante.salidoInstituto => AppIcons.circleCheck,
  };
}

// ── Extensión de presentación sobre EstadoSolicitud (perspectiva Anfitrión)

/// Extensión de presentación sobre [RequestStatus] para las cards
/// de "Mis Solicitudes" del Anfitrión.
extension _RequestStatusAnfitrionExt on RequestStatus {
  Color get color => switch (this) {
    RequestStatus.aprobada => AppColors.success,
    RequestStatus.rechazada => AppColors.error,
    RequestStatus.pendiente => AppColors.warning,
    RequestStatus.cancelada => AppColors.iconGray,
    RequestStatus.vencida => AppColors.iconGray,
  };

  String get label => switch (this) {
    RequestStatus.aprobada => 'Aprobada',
    RequestStatus.rechazada => 'Rechazada',
    RequestStatus.pendiente => 'Pendiente',
    RequestStatus.cancelada => 'Cancelada',
    RequestStatus.vencida => 'Vencida',
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// VISTA PRINCIPAL — HomeAnfitrionView
// ═══════════════════════════════════════════════════════════════════════════

/// Vista raíz del rol Anfitrión.
///
/// Administra cuatro secciones mediante [IndexedStack]:
///   0 — Mis solicitudes
///   1 — Mis visitantes
///   2 — Nueva solicitud
///   3 — Perfil
class HomeAnfitrionView extends ConsumerStatefulWidget {
  const HomeAnfitrionView({super.key});

  @override
  ConsumerState<HomeAnfitrionView> createState() => _HomeAnfitrionViewState();
}

class _HomeAnfitrionViewState extends ConsumerState<HomeAnfitrionView> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Recargar siempre al montar: garantiza datos frescos tras login/logout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(anfitrionSolicitudesViewModelProvider.notifier).refresh();
        ref.read(anfitrionVisitantesViewModelProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return HomeShell(
      child: Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false, // sin flecha de retroceso
        title: const Text('Panel de Anfitrión'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.bell, size: 18),
            onPressed: () {},
          ),
          const LogoutButton(),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _TabMisSolicitudes(),
          _TabMisVisitantes(),
          _TabNuevaSolicitud(),
          _TabPerfil(),
        ],
      ),
      floatingActionButton: (_selectedIndex == 0 || _selectedIndex == 1)
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _selectedIndex = 2),
              backgroundColor: AppColors.primary,
              icon: const FaIcon(
                FontAwesomeIcons.plus,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                'Nueva visita',
                style: AppTextStyles.button.copyWith(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.listCheck, size: 17),
            label: 'Solicitudes',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.usersLine, size: 17),
            label: 'Mis visitantes',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.plus, size: 17),
            label: 'Nueva',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.user, size: 17),
            label: 'Perfil',
          ),
        ],
      ),
    ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 0 — Mis solicitudes de visita
// ═══════════════════════════════════════════════════════════════════════════

/// Tab que lista las solicitudes de visita realizadas por el Anfitrión.
/// Conectado al [AnfitrionSolicitudesViewModel] para datos reales de BD.
class _TabMisSolicitudes extends ConsumerStatefulWidget {
  const _TabMisSolicitudes();

  @override
  ConsumerState<_TabMisSolicitudes> createState() =>
      _TabMisSolicitudesState();
}

class _TabMisSolicitudesState extends ConsumerState<_TabMisSolicitudes> {
  /// requestId que está cargando su QR en este momento (null = ninguno).
  int? _loadingQrFor;

  Future<void> _confirmarCancelacion(
    BuildContext context,
    RequestSummaryDto solicitud,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancelar solicitud', style: AppTextStyles.subtitle),
        content: Text(
          '¿Cancelar la visita de ${solicitud.visitorNames}?\n'
          'Esta acción no se puede deshacer.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sí, cancelar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final success = await ref
        .read(anfitrionSolicitudesViewModelProvider.notifier)
        .cancelarSolicitud(solicitud.requestId);

    if (!success && context.mounted) {
      final vm = ref.read(anfitrionSolicitudesViewModelProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMsg),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openQrViewer(
    BuildContext context,
    int requestId,
  ) async {
    setState(() => _loadingQrFor = requestId);
    try {
      final items = await ref
          .read(requestItemRepositoryProvider)
          .findItemsWithVisitorNames(requestId);

      if (!context.mounted) return;

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron visitantes para esta solicitud.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => QrViewerView(items: items),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cargar el QR. Intenta de nuevo.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingQrFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(anfitrionSolicitudesViewModelProvider);

    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(
                AppIcons.circleXmark,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                vm.errorMsg,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.blockGap),
              ElevatedButton.icon(
                onPressed: () => ref
                    .read(anfitrionSolicitudesViewModelProvider.notifier)
                    .refresh(),
                icon: const FaIcon(AppIcons.refresh, size: 14),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (vm.solicitudes.isEmpty) {
      return const EmptyState(
        icon: AppIcons.listVisitas,
        label: 'No has creado ninguna solicitud',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(anfitrionSolicitudesViewModelProvider.notifier)
          .refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.screenH,
          AppSpacing.screenH,
          80,
        ),
        itemCount: vm.solicitudes.length + 1,
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppSpacing.listItemGap),
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('Mis solicitudes', style: AppTextStyles.subtitle),
            );
          }
          final solicitud = vm.solicitudes[i - 1];
          return _SolicitudAnfitrionCard(
            solicitud: solicitud,
            isLoadingQr: _loadingQrFor == solicitud.requestId,
            onVerQr: solicitud.status == RequestStatus.aprobada
                ? () => _openQrViewer(ctx, solicitud.requestId)
                : null,
            onCancelar: (solicitud.status == RequestStatus.pendiente ||
                    solicitud.status == RequestStatus.aprobada)
                ? () => _confirmarCancelacion(ctx, solicitud)
                : null,
          );
        },
      ),
    );
  }
}

/// Tarjeta de una solicitud de visita (perspectiva Anfitrión).
class _SolicitudAnfitrionCard extends StatelessWidget {
  const _SolicitudAnfitrionCard({
    required this.solicitud,
    this.onVerQr,
    this.isLoadingQr = false,
    this.onCancelar,
  });

  final RequestSummaryDto solicitud;
  final VoidCallback? onVerQr;
  final VoidCallback? onCancelar;
  final bool isLoadingQr;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = solicitud.status.color;
    final bool isAprobada = solicitud.status == RequestStatus.aprobada;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.appBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: isAprobada ? AppColors.success.withValues(alpha: 0.4) : AppColors.borderGray,
          width: isAprobada ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: FaIcon(
                    solicitud.visitorCount > 1
                        ? AppIcons.users
                        : AppIcons.person,
                    size: 20,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitud.visitorNames,
                      style: AppTextStyles.bodyBold,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const FaIcon(
                          AppIcons.building,
                          size: 10,
                          color: AppColors.iconGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          solicitud.buildingName,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const FaIcon(
                          AppIcons.clock,
                          size: 10,
                          color: AppColors.iconGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${solicitud.formattedDate} · ${solicitud.formattedTime}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Badge de estado.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  solicitud.status.label,
                  style: AppTextStyles.caption.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // ── Acciones: Ver QR y Cancelar ────────────────────────
          if (isAprobada || solicitud.status == RequestStatus.pendiente) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                // Ver QR — solo si está aprobada.
                if (isAprobada)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoadingQr ? null : onVerQr,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      icon: isLoadingQr
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const FaIcon(FontAwesomeIcons.qrcode, size: 14),
                      label: Text(
                        isLoadingQr ? 'Cargando...' : 'Ver QR',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),

                if (isAprobada && onCancelar != null)
                  const SizedBox(width: AppSpacing.sm),

                // Cancelar — pendiente o aprobada (sin entrada).
                if (onCancelar != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancelar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      icon: const FaIcon(AppIcons.ban, size: 13),
                      label: Text('Cancelar', style: AppTextStyles.button.copyWith(color: AppColors.error)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — Nueva solicitud de visita (RF-01)
// ═══════════════════════════════════════════════════════════════════════════

/// Tab con el formulario para registrar una nueva solicitud de visita.
/// Conectado al [NuevaSolicitudViewModel] para crear visitantes y solicitud en BD.
class _TabNuevaSolicitud extends ConsumerStatefulWidget {
  const _TabNuevaSolicitud();

  @override
  ConsumerState<_TabNuevaSolicitud> createState() => _TabNuevaSolicitudState();
}

/// Encapsula los controladores de texto de una persona adicional en la visita.
class _PersonaAdicional {
  _PersonaAdicional()
    : nombreCtrl = TextEditingController(),
      correoCtrl = TextEditingController();

  final TextEditingController nombreCtrl;
  final TextEditingController correoCtrl;

  void dispose() {
    nombreCtrl.dispose();
    correoCtrl.dispose();
  }
}

class _TabNuevaSolicitudState extends ConsumerState<_TabNuevaSolicitud> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();

  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  int _toleranceMinutes = 15;

  final List<_PersonaAdicional> _personasAdicionales = [];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _motivoCtrl.dispose();
    _fechaCtrl.dispose();
    _horaCtrl.dispose();
    for (final p in _personasAdicionales) {
      p.dispose();
    }
    super.dispose();
  }

  void _agregarPersona() {
    setState(() => _personasAdicionales.add(_PersonaAdicional()));
  }

  void _eliminarPersona(int index) {
    setState(() {
      _personasAdicionales[index].dispose();
      _personasAdicionales.removeAt(index);
    });
  }

  void _limpiarFormulario() {
    _formKey.currentState!.reset();
    _nombreCtrl.clear();
    _correoCtrl.clear();
    _motivoCtrl.clear();
    _fechaCtrl.clear();
    _horaCtrl.clear();
    for (final p in _personasAdicionales) {
      p.dispose();
    }
    setState(() {
      _personasAdicionales.clear();
      _scheduledDate = null;
      _scheduledTime = null;
      _toleranceMinutes = 15;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(nuevaSolicitudViewModelProvider);
    final notifier = ref.read(nuevaSolicitudViewModelProvider.notifier);

    // Escuchar éxito para limpiar el formulario y notificar.
    ref.listen<NuevaSolicitudState>(nuevaSolicitudViewModelProvider, (prev, next) {
      if (!next.submitSuccess || (prev?.submitSuccess ?? false)) return;
      _limpiarFormulario();
      notifier.resetSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada — pendiente de autorización'),
          backgroundColor: AppColors.success,
        ),
      );
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nueva solicitud de visita', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Completa los datos del visitante principal.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.blockGap),

            // ── Visitante principal ─────────────────────────────
            Text('Visitante principal', style: AppTextStyles.fieldLabel),
            const SizedBox(height: AppSpacing.sm),

            AppTextField(
              label: 'Nombre completo',
              hint: 'Nombre del visitante',
              controller: _nombreCtrl,
              prefixIcon: AppIcons.person,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !vm.isSubmitting,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: AppSpacing.elementGap),

            AppTextField(
              label: 'Correo electrónico',
              hint: 'correo@ejemplo.com',
              controller: _correoCtrl,
              prefixIcon: AppIcons.email,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              enabled: !vm.isSubmitting,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido';
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.blockGap),

            // ── Detalles de la visita ───────────────────────────
            Text('Detalles de la visita', style: AppTextStyles.fieldLabel),
            const SizedBox(height: AppSpacing.sm),

            AppTextField(
              label: 'Fecha de visita',
              hint: 'Selecciona la fecha',
              controller: _fechaCtrl,
              prefixIcon: AppIcons.calendar,
              readOnly: true,
              textInputAction: TextInputAction.next,
              enabled: !vm.isSubmitting,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Selecciona una fecha'
                  : null,
              onTap: () => _pickDate(context),
            ),
            const SizedBox(height: AppSpacing.elementGap),

            AppTextField(
              label: 'Hora estimada de llegada',
              hint: 'Selecciona la hora',
              controller: _horaCtrl,
              prefixIcon: AppIcons.clock,
              readOnly: true,
              enabled: !vm.isSubmitting,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Selecciona una hora'
                  : null,
              onTap: () => _pickTime(context),
            ),
            const SizedBox(height: AppSpacing.elementGap),

            // Selector de tolerancia.
            _ToleranceSelector(
              value: _toleranceMinutes,
              onChanged: (v) => setState(() => _toleranceMinutes = v),
              enabled: !vm.isSubmitting,
            ),
            const SizedBox(height: AppSpacing.elementGap),

            AppTextField(
              label: 'Motivo de la visita',
              hint: 'Describe brevemente el propósito...',
              controller: _motivoCtrl,
              prefixIcon: AppIcons.circleInfo,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              enabled: !vm.isSubmitting,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: AppSpacing.blockGap),

            // ── Personas adicionales ────────────────────────────
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personas adicionales',
                      style: AppTextStyles.fieldLabel,
                    ),
                    Text(
                      '${_personasAdicionales.length} persona(s) añadida(s)',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: vm.isSubmitting ? null : _agregarPersona,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.plus,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Añadir persona',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_personasAdicionales.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ..._personasAdicionales.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PersonaCard(
                    persona: p,
                    numero: i + 1,
                    onEliminar: () => _eliminarPersona(i),
                  ),
                );
              }),
            ],

            // ── Error ───────────────────────────────────────────
            if (vm.hasError) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const FaIcon(
                      AppIcons.circleXmark,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        vm.errorMsg,
                        style: AppTextStyles.errorText,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.blockGap),
            PrimaryButton(
              label: 'Enviar solicitud',
              isLoading: vm.isSubmitting,
              isEnabled: !vm.isSubmitting,
              icon: vm.isSubmitting
                  ? null
                  : const FaIcon(
                      FontAwesomeIcons.paperPlane,
                      size: 14,
                      color: Colors.white,
                    ),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date != null) {
      _scheduledDate = date;
      _fechaCtrl.text =
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null && context.mounted) {
      _scheduledTime = time;
      _horaCtrl.text =
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_scheduledDate == null || _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona fecha y hora de la visita'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final scheduledTimeStr =
        '${_scheduledTime!.hour.toString().padLeft(2, '0')}:'
        '${_scheduledTime!.minute.toString().padLeft(2, '0')}:00';

    final adicionales = _personasAdicionales
        .map(
          (p) => VisitanteFormData(
            nombre: p.nombreCtrl.text.trim(),
            correo: p.correoCtrl.text.trim(),
          ),
        )
        .toList();

    ref.read(nuevaSolicitudViewModelProvider.notifier).submit(
      nombrePrincipal: _nombreCtrl.text.trim(),
      correoPrincipal: _correoCtrl.text.trim(),
      scheduledDate: _scheduledDate!,
      scheduledTime: scheduledTimeStr,
      toleranceMinutes: _toleranceMinutes,
      motivo: _motivoCtrl.text.trim(),
      adicionales: adicionales,
    );
  }
}

// ── Widgets auxiliares del formulario ─────────────────────────────────────────

/// Selector visual de tolerancia en minutos.
class _ToleranceSelector extends StatelessWidget {
  const _ToleranceSelector({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  static const _options = [5, 10, 15, 20, 30];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tolerancia de llegada', style: AppTextStyles.fieldLabel),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Minutos antes/después de la hora programada',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: _options.map((minutes) {
            final selected = value == minutes;
            return Expanded(
              child: GestureDetector(
                onTap: enabled ? () => onChanged(minutes) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : AppColors.iceBlue,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.borderGray,
                    ),
                  ),
                  child: Text(
                    '$minutes′',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.captionBold.copyWith(
                      color: selected ? Colors.white : AppColors.textContrast,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENTE — Tarjeta de persona adicional
// ═══════════════════════════════════════════════════════════════════════════

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.persona,
    required this.numero,
    required this.onEliminar,
  });

  final _PersonaAdicional persona;
  final int numero;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.iceBlue,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$numero',
                        style: AppTextStyles.captionBold.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Persona adicional',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onEliminar,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const FaIcon(
                    AppIcons.trash,
                    size: 13,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Nombre completo',
            hint: 'Nombre del acompañante',
            controller: persona.nombreCtrl,
            prefixIcon: AppIcons.person,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
          ),
          const SizedBox(height: AppSpacing.elementGap),
          AppTextField(
            label: 'Correo electrónico',
            hint: 'correo@ejemplo.com',
            controller: persona.correoCtrl,
            prefixIcon: AppIcons.email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              if (!v.contains('@')) return 'Correo inválido';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — Mis visitantes (perspectiva del Anfitrión)
// ═══════════════════════════════════════════════════════════════════════════

/// Tab que muestra los visitantes activos del día para el Anfitrión
/// y permite confirmar su llegada o salida de la oficina.
/// Conectado al [AnfitrionVisitantesViewModel] para datos reales de BD.
class _TabMisVisitantes extends ConsumerWidget {
  const _TabMisVisitantes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(anfitrionVisitantesViewModelProvider);
    final notifier = ref.read(anfitrionVisitantesViewModelProvider.notifier);

    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(AppIcons.circleXmark, size: 40, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(vm.errorMsg, style: AppTextStyles.body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.blockGap),
              ElevatedButton.icon(
                onPressed: notifier.refresh,
                icon: const FaIcon(AppIcons.refresh, size: 14),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (vm.visitantes.isEmpty) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            EmptyState(
              icon: AppIcons.users,
              label: 'No tienes visitantes hoy',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: vm.visitantes.length + 1 +
            (vm.hasPendingExtensions ? 1 : 0),
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppSpacing.listItemGap),
        itemBuilder: (ctx, i) {
          // Índice 0: encabezado + banner de extensiones (si hay).
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner de extensiones pendientes.
                if (vm.hasPendingExtensions)
                  _ExtensionBanner(
                    extensions: vm.pendingExtensions,
                    notifier: notifier,
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  ),
                Text('Mis visitantes de hoy', style: AppTextStyles.subtitle),
                const SizedBox(height: 2),
                Text(
                  'Confirma la llegada a tu oficina y su salida.',
                  style: AppTextStyles.caption,
                ),
              ],
            );
          }

          final dto = vm.visitantes[i - 1];
          final itemId = dto.item.itemId!;
          final estatus = dto.currentEvent?.toEstatusVisitante()
              ?? EstatusVisitante.enEspera;
          final isProcessing = vm.isProcessing(itemId);

          // Convertir DTO al modelo de presentación para el card existente.
          final visitante = VisitanteModel(
            id: itemId.toString(),
            nombre: dto.visitor.fullName,
            destino: 'Tu oficina',
            horaEstimada: dto.formattedTime,
            correo: dto.visitor.email,
            estatus: estatus,
          );

          return _VisitanteAnfitrionCard(
            visitante: visitante,
            isProcessing: isProcessing,
            onLlegadaOficina: estatus == EstatusVisitante.enInstituto
                ? () => notifier.confirmarLlegadaOficina(itemId)
                : null,
            onSalidaOficina: estatus == EstatusVisitante.enOficina
                ? () => notifier.confirmarSalidaOficina(itemId)
                : null,
          );
        },
      ),
    );
  }
}

/// Tarjeta que presenta el estado de un visitante y las acciones disponibles
/// para el Anfitrión.
class _VisitanteAnfitrionCard extends StatelessWidget {
  const _VisitanteAnfitrionCard({
    required this.visitante,
    this.onLlegadaOficina,
    this.onSalidaOficina,
    this.isProcessing = false,
  });

  final VisitanteModel visitante;
  final VoidCallback? onLlegadaOficina;
  final VoidCallback? onSalidaOficina;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final est = visitante.estatus;
    final color = est.color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.appBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: FaIcon(AppIcons.person, size: 22, color: color),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visitante.nombre, style: AppTextStyles.bodyBold),
                    const SizedBox(height: 2),
                    if (visitante.correo != null)
                      Row(
                        children: [
                          FaIcon(
                            AppIcons.email,
                            size: 10,
                            color: AppColors.iconGray,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              visitante.correo!,
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        FaIcon(
                          AppIcons.clock,
                          size: 10,
                          color: AppColors.iconGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Estimada: ${visitante.horaEstimada}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(est.icon, size: 10, color: color),
                    const SizedBox(width: 3),
                    Text(
                      est.label,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (onLlegadaOficina != null || onSalidaOficina != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
          ],

          if (onLlegadaOficina != null)
            _BtnAccion(
              label: 'Llegó a mi oficina',
              icon: AppIcons.building,
              color: AppColors.success,
              onTap: isProcessing ? null : onLlegadaOficina,
              isLoading: isProcessing,
            ),

          if (onSalidaOficina != null)
            _BtnAccion(
              label: 'Salió de mi oficina',
              icon: AppIcons.personWalking,
              color: AppColors.info,
              onTap: isProcessing ? null : onSalidaOficina,
              isLoading: isProcessing,
            ),

          if (est == EstatusVisitante.salidoOficina) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  FaIcon(AppIcons.circleInfo, size: 11, color: AppColors.info),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Salió de tu oficina — sigue en el instituto',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (est == EstatusVisitante.salidoInstituto) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                FaIcon(
                  AppIcons.circleCheck,
                  size: 12,
                  color: AppColors.iconGray,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Salió del instituto',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.iconGray,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón de acción estilizado para las interacciones del Anfitrión.
class _BtnAccion extends StatelessWidget {
  const _BtnAccion({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(icon, size: 14, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: AppTextStyles.captionBold.copyWith(color: color),
                  ),
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Banner de extensiones pendientes
// ═══════════════════════════════════════════════════════════════════════════

/// Banner naranja que aparece cuando hay visitantes tardíos esperando respuesta.
/// Cada solicitud tiene botones Aprobar / Rechazar.
class _ExtensionBanner extends StatelessWidget {
  const _ExtensionBanner({
    required this.extensions,
    required this.notifier,
    this.padding,
  });

  final List<ExtensionDto> extensions;
  final AnfitrionVisitantesViewModel notifier;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        children: extensions.map((ext) {
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.warning, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(AppIcons.bell, size: 14, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '${ext.visitorNames} llegó tarde',
                        style: AppTextStyles.bodyBold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Programada: ${ext.formattedTime}  ·  ${ext.buildingName}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => notifier.aprobarExtension(ext.requestId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                        ),
                        child: Text('Aprobar', style: AppTextStyles.button),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => notifier.rechazarExtension(ext.requestId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                        ),
                        child: Text(
                          'Rechazar',
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — Perfil del Anfitrión
// ═══════════════════════════════════════════════════════════════════════════

/// Tab que presenta la información de perfil real del Anfitrión autenticado
/// y un resumen de sus solicitudes del día.
class _TabPerfil extends ConsumerWidget {
  const _TabPerfil();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SamUserModel? session = ref.watch(sessionProvider);
    final solicitudesState = ref.watch(anfitrionSolicitudesViewModelProvider);

    // Estadísticas derivadas de la lista ya cargada.
    final solicitudes = solicitudesState.solicitudes;
    final total = solicitudes.length;
    final aprobadas = solicitudes
        .where((s) => s.status == RequestStatus.aprobada)
        .length;
    final pendientes = solicitudes
        .where((s) => s.status == RequestStatus.pendiente)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Avatar ───────────────────────────────────────────
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.mistBlue,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: const Center(
                child: FaIcon(AppIcons.user, size: 40, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            session?.nombre.isNotEmpty == true
                ? session!.nombre
                : session?.username ?? '—',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (session?.puesto.isNotEmpty == true) session!.puesto,
              if (session?.departamento.isNotEmpty == true) session!.departamento,
            ].join(' · '),
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.blockGap),

          // ── Datos de contacto ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.iceBlue,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: Column(
              children: [
                if (session?.correo.isNotEmpty == true) ...[
                  _ProfileRow(icon: AppIcons.email, label: session!.correo),
                  const Divider(height: AppSpacing.blockGap),
                ],
                if (session?.departamento.isNotEmpty == true)
                  _ProfileRow(
                    icon: AppIcons.building,
                    label: session!.departamento,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.blockGap),

          // ── Estadísticas de solicitudes ───────────────────────
          Text('Resumen de solicitudes', style: AppTextStyles.fieldLabel),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total',
                  value: '$total',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: 'Aprobadas',
                  value: '$aprobadas',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: 'Pendientes',
                  value: '$pendientes',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FaIcon(icon, size: 15, color: AppColors.secondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.title.copyWith(color: color, fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
