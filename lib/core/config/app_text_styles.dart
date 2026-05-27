/// @file: app_text_styles.dart
/// @project: ControlAcceso - G.A.M.A.
/// @description: Sistema de tipografía institucional basado en Open Sans.
///   Define los estilos de texto estándar organizados por jerarquía y uso,
///   conforme a la Sección 5.2.2 / Tabla 8 del Manual de Programación
///   Flutter (MPF). Toda vista debe consumir estilos exclusivamente desde
///   esta clase.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-07

library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Sistema de tipografía institucional — Open Sans — GAMA MPF v1.0.
///
/// Clase de solo getters estáticos. No debe instanciarse.
/// Referencia: Sección 5.2.2 / Tabla 8 del Manual de Programación Flutter.
class AppTextStyles {
  AppTextStyles._();

  // ── Estilos base ─────────────────────────────────────────────────────────

  /// SemiBold 600 · 22 px · h1.3 — Encabezados principales de pantalla.
  static TextStyle get title => GoogleFonts.openSans(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textContrast,
  );

  /// Medium 500 · 17 px · h1.4 — Secciones y encabezados secundarios.
  static TextStyle get subtitle => GoogleFonts.openSans(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textContrast,
  );

  /// Regular 400 · 15 px · h1.5 — Párrafos y texto general.
  static TextStyle get body => GoogleFonts.openSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textMain,
  );

  /// Bold 700 · 14 px · h1.2 — Botones (siempre en mayúsculas).
  static TextStyle get button => GoogleFonts.openSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.5,
    color: Colors.white,
  );

  /// Regular 400 · 12 px · h1.4 — Textos de apoyo, hints, notas secundarias.
  static TextStyle get caption => GoogleFonts.openSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.iconGray,
  );

  /// Regular 400 · 12 px · h1.4 · color error — Validaciones fallidas.
  static TextStyle get errorText => GoogleFonts.openSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.error,
  );

  // ── Variantes de estilos base ────────────────────────────────────────────

  /// Variante semibold de [body] para énfasis en texto corrido.
  static TextStyle get bodyBold => body.copyWith(fontWeight: FontWeight.w600);

  /// Variante semibold de [caption] para etiquetas destacadas.
  static TextStyle get captionBold =>
      caption.copyWith(fontWeight: FontWeight.w600);

  /// Variante blanca de [subtitle] para uso sobre fondos oscuros.
  static TextStyle get subtitleWhite => subtitle.copyWith(color: Colors.white);

  /// Variante blanca de [body] para uso sobre fondos oscuros.
  static TextStyle get bodyWhite => body.copyWith(color: Colors.white);

  /// Variante blanca de [title] para uso sobre fondos oscuros.
  static TextStyle get titleWhite => title.copyWith(color: Colors.white);

  // ── Estilos de componentes específicos ───────────────────────────────────

  /// Texto del título en AppBar.
  static TextStyle get appBarTitle => GoogleFonts.openSans(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// Etiqueta (label) de campos de formulario.
  static TextStyle get fieldLabel => GoogleFonts.openSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textContrast,
  );

  /// Texto de sugerencia (hint) de campos de formulario.
  static TextStyle get fieldHint => GoogleFonts.openSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.iconGray,
  );
}
