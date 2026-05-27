/// @file: empty_state.dart
/// @project: Control de Accesos - GAMA
/// @description: Widget de estado vacío estándar del sistema. Se presenta
///   cuando la aplicación funciona correctamente pero no existe información
///   para mostrar (lista vacía, búsqueda sin resultados).
///   Referencia: Sección 5.2.7.4 / Figura 44 del Manual de Programación
///   Flutter (MPF).
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/app_text_styles.dart';

/// Widget de estado vacío institucional — GAMA MPF v1.0.
///
/// Muestra un ícono semántico con opacidad reducida y una etiqueta
/// descriptiva cuando no hay contenido para presentar al usuario.
/// Referencia: Sección 5.2.7.4 / Figura 44 del Manual de Programación
/// Flutter.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.iconGray,
  });

  // ── Propiedades ───────────────────────────────────────────────────────────

  /// Ícono representativo del estado vacío.
  final IconData icon;

  /// Mensaje descriptivo mostrado bajo el ícono.
  final String label;

  /// Color semántico del ícono. Por defecto [AppColors.iconGray].
  final Color color;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 48, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.iconGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
