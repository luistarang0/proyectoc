/// @file: app_text_field.dart
/// @project: ControlAcceso - G.A.M.A.
/// @description: Campo de texto estándar del sistema. Encapsula TextFormField
///   con soporte para prefijo icónico, visibilidad de contraseña, validación,
///   estados habilitado/deshabilitado y sufijo personalizable, conforme a la
///   Sección 5.2.6 / Figura 40 del Manual de Programación Flutter (MPF).
///   IMPORTANTE: Queda PROHIBIDO usar TextField sin validación asociada.
///   Todo campo de texto debe incluir su validador correspondiente.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-07

library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/app_text_styles.dart';

/// Campo de texto institucional con label, validación y estados visuales.
///
/// Soporta campos de contraseña con toggle de visibilidad, prefijos icónicos,
/// sufijos personalizados y los estados enabled, disabled y readOnly.
/// Referencia: Sección 5.2.6 / Figura 40 del Manual de Programación Flutter.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.suffixWidget,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  // ── Contenido ────────────────────────────────────────────────────────────

  /// Etiqueta visible encima del campo.
  final String label;

  /// Texto de sugerencia mostrado cuando el campo está vacío.
  final String? hint;

  // ── Control ──────────────────────────────────────────────────────────────

  /// Controlador externo del campo de texto.
  final TextEditingController? controller;

  /// Función de validación del valor ingresado.
  final String? Function(String?)? validator;

  /// Callback invocado cada vez que el valor del campo cambia.
  final ValueChanged<String>? onChanged;

  /// Callback invocado al enviar el campo (teclado → acción).
  final ValueChanged<String>? onFieldSubmitted;

  /// Callback invocado al tocar el campo en modo [readOnly].
  final VoidCallback? onTap;

  // ── Apariencia ───────────────────────────────────────────────────────────

  /// Ícono prefijo mostrado al inicio del campo.
  final IconData? prefixIcon;

  /// Widget sufijo personalizado (ignorado si [obscureText] es true).
  final Widget? suffixWidget;

  // ── Comportamiento ───────────────────────────────────────────────────────

  /// Cuando es true, oculta el texto e incluye toggle de visibilidad.
  final bool obscureText;

  /// Tipo de teclado presentado al enfocar el campo.
  final TextInputType? keyboardType;

  /// Acción del botón de acción del teclado.
  final TextInputAction? textInputAction;

  /// Capitalización automática del texto ingresado.
  final TextCapitalization textCapitalization;

  /// Número máximo de líneas visibles (ignorado si [obscureText] es true).
  final int maxLines;

  /// Cuando es true, el campo recibe foco automáticamente al montarse.
  final bool autofocus;

  // ── Estado ───────────────────────────────────────────────────────────────

  /// Cuando es false, el campo se muestra deshabilitado.
  final bool enabled;

  /// Cuando es true, el campo es visible pero no editable.
  final bool readOnly;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

/// Estado interno de [AppTextField].
///
/// Gestiona la visibilidad del texto en campos de tipo contraseña.
class _AppTextFieldState extends State<AppTextField> {
  // ── Estado privado ────────────────────────────────────────────────────────

  /// Controla si el texto del campo está oculto o visible.
  late bool _obscure;

  // ── Ciclo de vida ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──────────────────────────────────────────────────────────
        Text(widget.label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: AppSpacing.xs),

        // ── Campo ──────────────────────────────────────────────────────────
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          autofocus: widget.autofocus,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          style: AppTextStyles.body.copyWith(color: AppColors.textContrast),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.fieldHint,
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: FaIcon(
                      widget.prefixIcon,
                      size: 15,
                      color: AppColors.iconGray,
                    ),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: FaIcon(
                      _obscure
                          ? FontAwesomeIcons.eyeSlash
                          : FontAwesomeIcons.eye,
                      size: 15,
                      color: AppColors.iconGray,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : widget.suffixWidget,
            filled: true,
            fillColor: widget.enabled ? AppColors.iceBlue : AppColors.mistBlue,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            errorStyle: AppTextStyles.errorText,
          ),
        ),
      ],
    );
  }
}
