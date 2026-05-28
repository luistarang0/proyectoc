/// @file: session_storage_service.dart
/// @project: Control de Accesos - GAMA
/// @description: Servicio de persistencia de sesión usando SharedPreferences.
///   Guarda el perfil SAM y la sesión del Guardia entre reinicios de la app,
///   de modo que el usuario no necesite volver a autenticarse cada vez.
///   La sesión se borra únicamente al hacer logout explícito.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-28

library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/models/sam_response_model.dart';
import '../../features/auth/model/guardia_session.dart';

/// Claves de SharedPreferences usadas por este servicio.
abstract class _Keys {
  static const samSession = 'gama_sam_session';
  static const guardiaSession = 'gama_guardia_session';
}

/// Servicio estático para guardar y restaurar sesiones entre reinicios.
abstract class SessionStorageService {
  // ── SAM (Anfitrión / Autorizador) ─────────────────────────────────────────

  /// Persiste el perfil SAM del usuario autenticado.
  static Future<void> saveSamSession(SamUserModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.samSession, jsonEncode(model.toJson()));
  }

  /// Restaura el perfil SAM guardado. Retorna `null` si no hay sesión.
  static Future<SamUserModel?> loadSamSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_Keys.samSession);
    if (raw == null) return null;
    try {
      return SamUserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Elimina la sesión SAM persistida.
  static Future<void> clearSamSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_Keys.samSession);
  }

  // ── Guardia ───────────────────────────────────────────────────────────────

  /// Persiste la sesión del Guardia (número de teléfono).
  static Future<void> saveGuardiaSession(GuardiaSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.guardiaSession, session.telefono);
  }

  /// Restaura la sesión del Guardia. Retorna `null` si no hay sesión.
  static Future<GuardiaSession?> loadGuardiaSession() async {
    final prefs = await SharedPreferences.getInstance();
    final telefono = prefs.getString(_Keys.guardiaSession);
    if (telefono == null || telefono.isEmpty) return null;
    return GuardiaSession(telefono: telefono);
  }

  /// Elimina la sesión del Guardia persistida.
  static Future<void> clearGuardiaSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_Keys.guardiaSession);
  }

  // ── Limpieza total ────────────────────────────────────────────────────────

  /// Elimina TODAS las sesiones persistidas (llamar en logout).
  static Future<void> clearAll() async {
    await Future.wait([
      clearSamSession(),
      clearGuardiaSession(),
    ]);
  }
}
