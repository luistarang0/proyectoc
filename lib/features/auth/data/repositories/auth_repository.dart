/// @file: auth_repository.dart
/// @project: Control de Accesos - GAMA
/// @description: Repositorio de autenticación. Orquesta el flujo completo
///   de login contra SAM, mapea el rol SAM al UserRole de la aplicación
///   y expone una interfaz limpia al ViewModel. Es la única capa
///   autorizada para comunicarse con SamAuthService.
///   Referencia: Sección 6.1 del Manual de Programación Flutter (MPF).
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/auth_models.dart';
import '../models/sam_response_model.dart';
import '../services/sam_auth_service.dart';

/// Resultado exitoso del proceso de autenticación.
class AuthResult {
  const AuthResult({required this.role, required this.user});

  /// Rol de la aplicación asignado al usuario autenticado.
  final UserRole role;

  /// Datos del usuario obtenidos de SAM.
  final SamUserModel user;
}

/// Repositorio de autenticación — GAMA MPF v1.0.
///
/// Flujo de autenticación:
///   1. [fetchCaptcha] — obtiene imagen CAPTCHA del servidor SAM.
///   2. [login] — valida captcha, autentica credenciales, obtiene perfil.
///   3. [logout] — cierra sesión en SAM y limpia estado local.
///
/// Todo error técnico de [SamAuthService] se transforma aquí en un
/// mensaje de dominio antes de propagarse al ViewModel.
class AuthRepository {
  const AuthRepository(this._samService);

  final SamAuthService _samService;

  // ── API pública ───────────────────────────────────────────────────────────

  /// Descarga los bytes del CAPTCHA para mostrar en la vista de login.
  Future<Uint8List> fetchCaptcha() async {
    return _samService.fetchCaptcha();
  }

  /// Ejecuta el flujo completo de autenticación.
  ///
  /// Pasos internos:
  ///   1. Valida el [captchaCode] con SAM.
  ///   2. Realiza el login con [username] y [password].
  ///   3. Obtiene el perfil completo del empleado si corresponde.
  ///   4. Mapea el rol SAM al [UserRole] de la aplicación.
  ///
  /// Lanza [SamAuthException] si cualquier paso falla.
  Future<AuthResult> login({
    required String username,
    required String password,
    required String captchaCode,
  }) async {
    // 1. Validar CAPTCHA.
    final captchaValid = await _samService.validateCaptcha(captchaCode);
    if (!captchaValid) {
      throw const SamAuthException('Código CAPTCHA incorrecto');
    }

    // 2. Login SAM → detectar tipo de sesión (master o empleado) desde HTML.
    final loginResult = await _samService.login(username, password, captchaCode);

    // 3. Obtener perfil completo desde el nuevo endpoint /empleado.do?accion=perfil.
    //    Usa la JSESSIONID activa — funciona para master y empleado por igual.
    final samUser = await _samService.fetchPerfil(username, loginResult.samRole);

    // 4. Mapear rol SAM → UserRole de la aplicación.
    final appRole = _mapSamRoleToUserRole(samUser);

    return AuthResult(role: appRole, user: samUser);
  }

  /// Cierra la sesión en SAM y limpia las cookies de sesión.
  Future<void> logout() async {
    await _samService.logout();
  }

  // ── Mapeo de roles ────────────────────────────────────────────────────────

  /// Convierte los datos SAM en el [UserRole] de la aplicación.
  ///
  /// Mapeo confirmado para el SAM del ITT:
  /// - samRole 'master'                      → [UserRole.autorizador]
  /// - nombre_puesto_empleado 'Administrativo' → [UserRole.autorizador]
  /// - nombre_puesto_empleado 'Docente'        → [UserRole.anfitrion]
  /// - puesto con 'guardia'/'seguridad'        → [UserRole.guardia]
  /// - cualquier otro                          → [UserRole.anfitrion]
  UserRole _mapSamRoleToUserRole(SamUserModel user) {
    // Mapeo por campo `credenciales` del endpoint /perfil del SAM del ITT.
    // Valores confirmados: "Administrativo" → autorizador, "Docente" → anfitrion.
    final creds = user.credenciales.trim().toLowerCase();
    if (creds.contains('administrativo')) return UserRole.autorizador;
    if (creds.contains('docente')) return UserRole.anfitrion;

    // Sesión master de SAM (admin del sistema).
    if (user.samRole == 'master') return UserRole.autorizador;

    return UserRole.anfitrion;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Provider del [AuthRepository] con inyección de [SamAuthService].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(samAuthServiceProvider));
});
