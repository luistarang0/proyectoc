/// @file: guardia_session.dart
/// @project: Control de Accesos - GAMA
/// @description: Modelo de sesión del Guardia de seguridad. Los guardias
///   no están en SAM; se autentican mediante validación del número de
///   teléfono del dispositivo. Este modelo mínimo identifica al guardia
///   activo en la aplicación.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sesión mínima del Guardia de seguridad.
///
/// El número de teléfono es el único identificador disponible, ya que
/// los guardias no tienen perfil en SAM.
@immutable
class GuardiaSession {
  const GuardiaSession({required this.telefono});

  /// Número de teléfono del dispositivo del guardia.
  final String telefono;
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Sesión activa del Guardia. Se establece tras autenticación exitosa
/// por número de teléfono y se limpia al cerrar sesión.
final guardiaSessionProvider = StateProvider<GuardiaSession?>((ref) => null);
