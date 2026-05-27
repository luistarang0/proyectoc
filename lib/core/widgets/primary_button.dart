/// @file: primary_button.dart
/// @project: ControlAcceso - G.A.M.A.
/// @description: Botón primario estándar del sistema. Soporta cuatro
///   variantes visuales (filled, outlined, danger, success), estado de
///   carga con indicador circular, estado deshabilitado e ícono opcional.
///   Referencia: Sección 5.2.6 / Figura 39 del Manual de Programación
///   Flutter (MPF).
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-07

library;

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/app_text_styles.dart';

/// Variantes visuales disponibles para [PrimaryButton].
///
/// - [filled]: fondo sólido primario (acción principal).
/// - [outlined]: borde primario sin relleno (acción secundaria).
/// - [danger]: fondo rojo para acciones destructivas.
/// - [success]: fondo verde para confirmaciones positivas.
enum PrimaryButtonVariant { filled, outlined, danger, success }

/// Botón de acción primario institucional — GAMA MPF v1.0.
///
/// Adapta su apariencia según la [variant] seleccionada y gestiona
/// los estados de carga y deshabilitado de forma visual y funcional.
/// Referencia: Sección 5.2.6 / Figura 39 del Manual de Programación Flutter.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PrimaryButtonVariant.filled,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.width,
  });

  // ── Contenido ────────────────────────────────────────────────────────────

  /// Texto del botón (se transforma a mayúsculas automáticamente).
  final String label;

  /// Ícono opcional mostrado a la izquierda del texto.
  final Widget? icon;

  // ── Control ──────────────────────────────────────────────────────────────

  /// Callback ejecutado al presionar el botón.
  ///
  /// Si es null, el botón se comporta como deshabilitado.
  final VoidCallback? onPressed;

  // ── Apariencia ───────────────────────────────────────────────────────────

  /// Variante visual del botón. Por defecto [PrimaryButtonVariant.filled].
  final PrimaryButtonVariant variant;

  /// Ancho del botón. Si es null, ocupa el ancho disponible completo.
  final double? width;

  // ── Estado ───────────────────────────────────────────────────────────────

  /// Cuando es true, muestra un indicador de carga y bloquea la interacción.
  final bool isLoading;

  /// Cuando es false, el botón se muestra deshabilitado visualmente.
  final bool isEnabled;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool canPress = isEnabled && !isLoading && onPressed != null;

    return SizedBox(
      width: width ?? double.infinity,
      child: switch (variant) {
        PrimaryButtonVariant.filled => _buildFilled(canPress),
        PrimaryButtonVariant.outlined => _buildOutlined(canPress),
        PrimaryButtonVariant.danger => _buildColored(AppColors.error, canPress),
        PrimaryButtonVariant.success => _buildColored(
          AppColors.success,
          canPress,
        ),
      },
    );
  }

  // ── Constructores de variante ─────────────────────────────────────────────

  /// Construye la variante [PrimaryButtonVariant.filled].
  Widget _buildFilled(bool canPress) => ElevatedButton(
    onPressed: canPress ? onPressed : null,
    style: ElevatedButton.styleFrom(
      backgroundColor: canPress ? AppColors.primary : AppColors.disabled,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.buttonV,
        horizontal: AppSpacing.buttonH,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    ),
    child: _buildChild(),
  );

  /// Construye la variante [PrimaryButtonVariant.outlined].
  Widget _buildOutlined(bool canPress) => OutlinedButton(
    onPressed: canPress ? onPressed : null,
    style: OutlinedButton.styleFrom(
      foregroundColor: canPress ? AppColors.primary : AppColors.disabled,
      side: BorderSide(
        color: canPress ? AppColors.primary : AppColors.disabled,
        width: 1.5,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.buttonV,
        horizontal: AppSpacing.buttonH,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    ),
    child: _buildChild(isOutlined: true),
  );

  /// Construye las variantes [PrimaryButtonVariant.danger] y
  /// [PrimaryButtonVariant.success] con el [color] institucional
  /// correspondiente.
  Widget _buildColored(Color color, bool canPress) => ElevatedButton(
    onPressed: canPress ? onPressed : null,
    style: ElevatedButton.styleFrom(
      backgroundColor: canPress ? color : AppColors.disabled,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.buttonV,
        horizontal: AppSpacing.buttonH,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    ),
    child: _buildChild(),
  );

  // ── Contenido interno ─────────────────────────────────────────────────────

  /// Construye el contenido interno del botón.
  ///
  /// Muestra un [CircularProgressIndicator] cuando [isLoading] es true.
  /// Si [icon] está presente, lo antepone al texto con separación estándar.
  Widget _buildChild({bool isOutlined = false}) {
    if (isLoading) {
      return SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: isOutlined ? AppColors.primary : Colors.white,
        ),
      );
    }

    final TextStyle style = AppTextStyles.button.copyWith(
      color: isOutlined ? AppColors.primary : Colors.white,
    );

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: AppSpacing.sm),
          Text(label.toUpperCase(), style: style),
        ],
      );
    }

    return Text(label.toUpperCase(), style: style);
  }
}
