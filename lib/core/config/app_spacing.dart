/// @file: app_spacing.dart
/// @project: ControlAcceso - G.A.M.A.
/// @description: Sistema de espaciado estándar del sistema. Define todas las
///   constantes de dimensión organizadas por categoría semántica conforme
///   a la Sección 5.2.3 del Manual de Programación Flutter (MPF).
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-07

library;

/// Sistema de espaciado institucional — GAMA MPF v1.0.
///
/// Clase de solo constantes. No debe instanciarse.
/// Referencia: Sección 5.2.3 del Manual de Programación Flutter.
class AppSpacing {
  AppSpacing._();

  // ── Escala base ──────────────────────────────────────────────────────────

  /// Espaciado extra pequeño.
  static const double xs = 4.0;

  /// Separación entre ítems de lista.
  static const double sm = 8.0;

  /// Separación entre elementos (SizedBox).
  static const double md = 12.0;

  /// Padding horizontal de pantalla / entre bloques.
  static const double lg = 16.0;

  /// Padding interno de diálogos / padding horizontal de botones.
  static const double xl = 24.0;

  /// Espaciado extra grande.
  static const double xxl = 32.0;

  // ── Pantalla ─────────────────────────────────────────────────────────────

  /// Padding horizontal estándar de pantalla (Scaffold / SafeArea).
  static const double screenH = 16.0;

  /// Padding vertical estándar de pantalla.
  static const double screenV = 12.0;

  // ── Bloques y elementos ──────────────────────────────────────────────────

  /// Separación entre bloques de contenido independientes.
  static const double blockGap = 16.0;

  /// Separación entre elementos dentro de un mismo bloque.
  static const double elementGap = 12.0;

  /// Separación entre ítems de lista (ListView.separated).
  static const double listItemGap = 8.0;

  // ── Tarjetas ─────────────────────────────────────────────────────────────

  /// Padding interno de tarjetas.
  static const double cardPadding = 16.0;

  // ── Botones ──────────────────────────────────────────────────────────────

  /// Padding vertical de botón.
  static const double buttonV = 12.0;

  /// Padding horizontal de botón.
  static const double buttonH = 24.0;

  // ── Radios de borde ──────────────────────────────────────────────────────

  /// Radio de borde pequeño.
  static const double radiusSm = 6.0;

  /// Radio de borde estándar.
  static const double radiusMd = 8.0;

  /// Radio de borde grande.
  static const double radiusLg = 12.0;

  /// Radio de borde para tarjetas.
  static const double radiusCard = 10.0;

  /// Radio de borde extra grande.
  static const double radiusXl = 20.0;
}
