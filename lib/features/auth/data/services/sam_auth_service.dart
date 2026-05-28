/// @file: sam_auth_service.dart
/// @project: Control de Accesos - GAMA
/// @description: Servicio de comunicación con el web service SAM.
///   Flujo de autenticación:
///     1. GET captcha.png → JSESSIONID
///     2. POST validarCaptcha.do → "si"/"no"
///     3. POST empleado.do?accion=verificar → HTML con título de sesión
///     4. GET empleado.do?accion=perfil → JSON con credenciales/jefe/correo
///   Referencia: Sección 6.2 del Manual de Programación Flutter (MPF).
/// @author: Luis Antonio Tarango Regis
/// @version: 2.0.0
/// @last_update: 2026-05-26

library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/http_service.dart';
import '../models/sam_response_model.dart';

/// Servicio de autenticación SAM — GAMA MPF v1.0.
class SamAuthService {
  SamAuthService(this._httpService);

  final HttpService _httpService;
  Dio get _dio => _httpService.dio;

  // ── Endpoints SAM ─────────────────────────────────────────────────────────

  static const _captchaPath = '/app/login/captcha.png';
  static const _validateCaptchaPath = '/app/login/validarCaptcha.do';
  static const _loginPath = '/app/empleado.do?accion=verificar';
  static const _perfilPath = '/app/empleado.do?accion=perfil';
  static const _logoutPath = '/app/login.do?accion=salir';

  // ── API pública ───────────────────────────────────────────────────────────

  /// Descarga la imagen CAPTCHA e inicializa la cookie JSESSIONID.
  Future<Uint8List> fetchCaptcha() async {
    try {
      debugPrint(
        '[SAM] GET captcha | sesión previa: ${_httpService.hasSession}',
      );
      final response = await _dio.get<List<int>>(
        _captchaPath,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data == null) {
        throw const SamAuthException('No se pudo cargar el CAPTCHA');
      }
      final bytes = Uint8List.fromList(response.data!);
      debugPrint(
        '[SAM] Captcha: ${bytes.length} bytes | sesión: ${_httpService.hasSession}',
      );
      return bytes;
    } on DioException catch (e) {
      debugPrint('[SAM][ERROR] fetchCaptcha: ${e.type} ${e.message}');
      throw SamAuthException('Error de red al obtener CAPTCHA: ${e.message}');
    }
  }

  /// Valida el código CAPTCHA ingresado por el usuario.
  Future<bool> validateCaptcha(String captchaCode) async {
    try {
      debugPrint(
        '[SAM] POST validarCaptcha | cookie=${_httpService.hasSession} | captcha="$captchaCode"',
      );
      final response = await _dio.post<String>(
        _validateCaptchaPath,
        data: 'inpCaptcha=${Uri.encodeComponent(captchaCode)}',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          responseType: ResponseType.plain,
        ),
      );
      final raw = (response.data ?? '').trim();
      final clean = raw.replaceAll('"', '').toLowerCase();
      debugPrint('[SAM] validarCaptcha raw: "$raw" → clean: "$clean"');
      return clean == 'si';
    } on DioException catch (e) {
      debugPrint('[SAM][ERROR] validarCaptcha: ${e.message}');
      throw SamAuthException('Error validando CAPTCHA: ${e.message}');
    }
  }

  /// Ejecuta el login y determina si es sesión master o empleado.
  ///
  /// Solo detecta éxito/fallo del login en el HTML. El perfil completo
  /// se obtiene por separado con [fetchPerfil].
  Future<SamLoginResult> login(
    String username,
    String password,
    String captchaCode,
  ) async {
    try {
      debugPrint(
        '[SAM] POST login | user="$username" | cookie=${_httpService.hasSession}',
      );
      final response = await _dio.post<String>(
        _loginPath,
        data:
            'itt_username=${Uri.encodeComponent(username)}'
            '&itt_password=${Uri.encodeComponent(password)}'
            '&inpCaptcha=${Uri.encodeComponent(captchaCode)}',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final html = response.data ?? '';
      _logHtml(html, response.statusCode ?? 0);
      return _parseLoginHtml(html);
    } on DioException catch (e) {
      debugPrint('[SAM][ERROR] login: ${e.type} ${e.message}');
      throw SamAuthException('Error de red en login: ${e.message}');
    }
  }

  /// Obtiene el perfil completo del usuario autenticado usando la
  /// sesión JSESSIONID activa.
  ///
  /// Nuevo endpoint SAM del ITT. Responde con:
  /// { "status": "0", "usuario": "...", "correo": "...",
  ///   "credenciales": "Administrativo"/"Docente", "jefe": "5", ... }
  Future<SamUserModel> fetchPerfil(String username, String samRole) async {
    try {
      debugPrint('[SAM] GET $_perfilPath | cookie=${_httpService.hasSession}');
      final response = await _dio.get<dynamic>(
        _perfilPath,
        options: Options(responseType: ResponseType.plain),
      );

      debugPrint('[SAM] Perfil raw: ${response.data}');

      final raw = response.data;
      Map<String, dynamic> data;
      if (raw is Map<String, dynamic>) {
        data = raw;
      } else if (raw is String) {
        data = _parseJson(raw);
      } else {
        throw const SamAuthException(
          'Formato inesperado en respuesta de perfil',
        );
      }

      final status = data['status'];
      final isOk = status == 0 || status == '0' || status?.toString() == '0';
      if (!isOk) {
        throw SamAuthException('SAM reportó error en perfil: $status');
      }

      final model = SamUserModel.fromPerfilResponse(data, samRole);
      debugPrint(
        '[SAM] Perfil → usuario: "${model.username}" | '
        'nombre: "${model.nombre}" | '
        'credenciales: "${model.credenciales}" | '
        'correo: "${model.correo}" | '
        'departamento: "${model.departamento}" | '
        'edificio: "${model.edificio}" | '
        'jefe: ${model.jefeSamId} | '
        'id_empleado: ${model.empleadoSamId}',
      );
      return model;
    } on DioException catch (e) {
      debugPrint('[SAM][ERROR] fetchPerfil: ${e.message}');
      throw SamAuthException('Error obteniendo perfil SAM: ${e.message}');
    } on FormatException catch (e) {
      debugPrint('[SAM][ERROR] fetchPerfil JSON: $e');
      throw const SamAuthException('JSON inválido en respuesta de perfil SAM');
    }
  }

  /// Cierra la sesión en el servidor SAM y limpia la cookie local.
  Future<void> logout() async {
    try {
      await _dio.get(
        _logoutPath,
        options: Options(validateStatus: (_) => true),
      );
    } finally {
      _httpService.clearSession();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _logHtml(String html, int statusCode) {
    debugPrint('[SAM] login HTTP $statusCode | longitud HTML: ${html.length}');
    const chunkSize = 200;
    for (var i = 0; i < html.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, html.length);
      debugPrint('[SAM HTML #${i ~/ chunkSize}] ${html.substring(i, end)}');
    }
    debugPrint('[SAM] --- FIN HTML ---');
  }

  Map<String, dynamic> _parseJson(String raw) {
    try {
      return jsonDecode(raw.trimLeft()) as Map<String, dynamic>;
    } catch (_) {
      throw SamAuthException('JSON inválido: $raw');
    }
  }

  // ── Parsing HTML ──────────────────────────────────────────────────────────

  /// Analiza el HTML de login para detectar éxito/fallo y el tipo de sesión.
  ///
  /// Solo determina si el login fue exitoso y si es sesión master o empleado.
  /// El perfil completo se obtiene por separado con [fetchPerfil].
  SamLoginResult _parseLoginHtml(String html) {
    // Login fallido.
    if (html.contains('login.css')) {
      throw const SamAuthException('Usuario o contraseña incorrectos');
    }

    // Sesión administrador de SAM.
    if (html.contains('<title>MASTER</title>') ||
        html.contains('inicioMaster')) {
      debugPrint('[SAM] Login: sesión master');
      return const SamLoginResult(samRole: 'master');
    }

    // Sesión empleado (vistaLinks.jsp).
    if (html.contains('<title>Enlaces</title>') ||
        html.contains('recuadros.css') ||
        html.contains('vistaLinks') ||
        html.contains('vistalinks')) {
      debugPrint('[SAM] Login: sesión empleado');
      return const SamLoginResult(samRole: 'empleado');
    }

    debugPrint('[SAM][WARN] HTML no reconocido — ver logs [SAM HTML #N]');
    throw const SamAuthException(
      'Respuesta no reconocida del servidor SAM.\n'
      'Revisa los logs [SAM HTML #N] para diagnóstico.',
    );
  }
}

// ── Excepción de dominio ──────────────────────────────────────────────────────

/// Excepción del dominio de autenticación SAM.
class SamAuthException implements Exception {
  const SamAuthException(this.message);
  final String message;

  @override
  String toString() => 'SamAuthException: $message';
}

// ── Provider ──────────────────────────────────────────────────────────────────

final samAuthServiceProvider = Provider<SamAuthService>((ref) {
  return SamAuthService(ref.watch(httpServiceProvider));
});
