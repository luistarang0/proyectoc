/// @file: home_autorizador_view.dart
/// @project: Control de Accesos - GAMA
/// @description: Pantalla principal del rol Autorizador. Presenta tres
///   pestañas: solicitudes pendientes de autorización, aprobadas y
///   rechazadas. Conectada al AutorizadorViewModel para datos reales de BD.
///   Referencia: RF-17 del Proyecto C — Control de Accesos.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/utils/logout.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_icons.dart';
import '../../../../core/config/app_spacing.dart';
import '../../../../core/config/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/models/request_db_model.dart';
import '../../data/models/request_summary_dto.dart';
import '../viewmodels/autorizador_viewmodel.dart';

// ── Extensión de presentación ──────────────────────────────────────────────

extension _RequestStatusExt on RequestStatus {
  String get label => switch (this) {
    RequestStatus.pendiente => 'Pendiente',
    RequestStatus.aprobada => 'Aprobada',
    RequestStatus.rechazada => 'Rechazada',
    RequestStatus.cancelada => 'Cancelada',
    RequestStatus.vencida => 'Vencida',
  };

  Color get color => switch (this) {
    RequestStatus.pendiente => AppColors.warning,
    RequestStatus.aprobada => AppColors.success,
    RequestStatus.rechazada => AppColors.error,
    RequestStatus.cancelada => AppColors.iconGray,
    RequestStatus.vencida => AppColors.iconGray,
  };

  Color get borderColor => switch (this) {
    RequestStatus.pendiente => AppColors.warning,
    RequestStatus.aprobada => AppColors.borderGray,
    RequestStatus.rechazada => AppColors.borderGray,
    RequestStatus.cancelada => AppColors.borderGray,
    RequestStatus.vencida => AppColors.borderGray,
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// VISTA PRINCIPAL
// ═════════════════════════════════════════════════════════════════════════════

/// Vista raíz del Home para el rol Autorizador.
class HomeAutorizadorView extends ConsumerStatefulWidget {
  const HomeAutorizadorView({super.key});

  @override
  ConsumerState<HomeAutorizadorView> createState() =>
      _HomeAutorizadorViewState();
}

class _HomeAutorizadorViewState extends ConsumerState<HomeAutorizadorView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(autorizadorViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: const Text('Panel Autorizador'),
        actions: [
          // Badge de pendientes.
          if (vm.pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${vm.pending.length}',
                    style: AppTextStyles.captionBold.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
            onPressed: vm.isLoading
                ? null
                : () => ref
                    .read(autorizadorViewModelProvider.notifier)
                    .refresh(),
            tooltip: 'Actualizar',
          ),
          const LogoutButton(),
        ],
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.hasError
          ? _ErrorPanel(
              message: vm.errorMsg,
              onRetry: () => ref
                  .read(autorizadorViewModelProvider.notifier)
                  .refresh(),
            )
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _TabPendientes(
                  items: vm.pending,
                  isProcessing: vm.isProcessing,
                ),
                _TabHistorial(
                  items: vm.approved,
                  titulo: 'Solicitudes aprobadas',
                  badgeColor: AppColors.success,
                  emptyLabel: 'Sin solicitudes aprobadas',
                ),
                _TabHistorial(
                  items: vm.rejected,
                  titulo: 'Solicitudes rechazadas',
                  badgeColor: AppColors.error,
                  emptyLabel: 'Sin solicitudes rechazadas',
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: [
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: vm.pending.isNotEmpty,
              label: Text('${vm.pending.length}'),
              child: const FaIcon(FontAwesomeIcons.inbox, size: 17),
            ),
            label: 'Pendientes',
          ),
          const BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.circleCheck, size: 17),
            label: 'Aprobadas',
          ),
          const BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.circleXmark, size: 17),
            label: 'Rechazadas',
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 0 — Solicitudes pendientes
// ═════════════════════════════════════════════════════════════════════════════

/// Tab que lista solicitudes pendientes con acciones de aprobar/rechazar.
class _TabPendientes extends ConsumerWidget {
  const _TabPendientes({required this.items, required this.isProcessing});

  final List<RequestSummaryDto> items;
  final bool isProcessing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: AppIcons.circleCheck,
        label: 'Sin solicitudes pendientes',
        color: AppColors.success,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppSpacing.listItemGap),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return _SectionHeader(
            title: 'Solicitudes pendientes',
            count: items.length,
            badgeColor: AppColors.warning,
          );
        }
        return _SolicitudCard(
          data: items[i - 1],
          isProcessing: isProcessing,
          onAprobar: () => ref
              .read(autorizadorViewModelProvider.notifier)
              .approve(items[i - 1].requestId),
          onRechazar: () => ref
              .read(autorizadorViewModelProvider.notifier)
              .reject(items[i - 1].requestId),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 1/2 — Historial (aprobadas / rechazadas)
// ═════════════════════════════════════════════════════════════════════════════

/// Tab genérico para mostrar el historial de solicitudes procesadas.
class _TabHistorial extends StatelessWidget {
  const _TabHistorial({
    required this.items,
    required this.titulo,
    required this.badgeColor,
    required this.emptyLabel,
  });

  final List<RequestSummaryDto> items;
  final String titulo;
  final Color badgeColor;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: AppIcons.listVisitas,
        label: emptyLabel,
        color: AppColors.iconGray,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppSpacing.listItemGap),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return _SectionHeader(
            title: titulo,
            count: items.length,
            badgeColor: badgeColor,
          );
        }
        return _SolicitudCard(data: items[i - 1]);
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tarjeta de solicitud
// ═════════════════════════════════════════════════════════════════════════════

/// Tarjeta de solicitud. Muestra acciones Aprobar/Rechazar solo si está
/// en estado pendiente y se proporcionan los callbacks correspondientes.
class _SolicitudCard extends StatelessWidget {
  const _SolicitudCard({
    required this.data,
    this.isProcessing = false,
    this.onAprobar,
    this.onRechazar,
  });

  final RequestSummaryDto data;
  final bool isProcessing;
  final VoidCallback? onAprobar;
  final VoidCallback? onRechazar;

  bool get _showActions =>
      data.status == RequestStatus.pendiente &&
      onAprobar != null &&
      onRechazar != null;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = data.status.color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.appBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: data.status.borderColor,
          width: data.status == RequestStatus.pendiente ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado: visitantes + estado ──────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: FaIcon(
                    data.visitorCount > 1
                        ? AppIcons.users
                        : AppIcons.person,
                    size: 17,
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
                      data.visitorNames,
                      style: AppTextStyles.bodyBold,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'Solicitado por ${data.emailHost}',
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    data.formattedTime,
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.textContrast,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _StatusBadge(status: data.status),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          // ── Detalles ──────────────────────────────────────────
          _DetailRow(icon: AppIcons.building, text: data.buildingName),
          const SizedBox(height: 4),
          _DetailRow(
            icon: AppIcons.calendar,
            text: '${data.formattedDate} · ${data.formattedTime}'
                '${data.toleranceMinutes != null ? '  ±${data.toleranceMinutes}′' : ''}',
          ),
          if (data.visitorCount > 1) ...[
            const SizedBox(height: 4),
            _DetailRow(
              icon: AppIcons.usersLine,
              text: '${data.visitorCount} visitantes',
            ),
          ],

          // ── Acciones (solo pendientes) ────────────────────────
          if (_showActions) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Aprobar',
                    variant: PrimaryButtonVariant.success,
                    isLoading: isProcessing,
                    isEnabled: !isProcessing,
                    icon: isProcessing
                        ? null
                        : const FaIcon(
                            FontAwesomeIcons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                    onPressed: onAprobar,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    label: 'Rechazar',
                    variant: PrimaryButtonVariant.danger,
                    isEnabled: !isProcessing,
                    icon: const FaIcon(
                      FontAwesomeIcons.xmark,
                      size: 12,
                      color: Colors.white,
                    ),
                    onPressed: onRechazar,
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

// ═════════════════════════════════════════════════════════════════════════════
// Widgets auxiliares
// ═════════════════════════════════════════════════════════════════════════════

/// Fila de detalle con ícono y texto.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FaIcon(icon, size: 11, color: AppColors.iconGray),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Badge de estado de la solicitud.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Header de sección con título y badge de conteo.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.badgeColor,
  });

  final String title;
  final int count;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.subtitle)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.captionBold.copyWith(color: badgeColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel de error con botón de reintento.
class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              AppIcons.circleXmark,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.textContrast),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.blockGap),
            PrimaryButton(
              label: 'Reintentar',
              icon: const FaIcon(
                AppIcons.refresh,
                size: 14,
                color: Colors.white,
              ),
              onPressed: onRetry,
              width: 160,
            ),
          ],
        ),
      ),
    );
  }
}
