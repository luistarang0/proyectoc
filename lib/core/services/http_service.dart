/// @file: http_service.dart
/// @project: Control de Accesos - GAMA
/// @description: Servicio HTTP transversal basado en Dio. Configura el
///   cliente HTTP institucional con timeout estándar e interceptor de
///   sesión para gestionar automáticamente la cookie JSESSIONID del
///   servidor SAM. URL base cargada desde variables de entorno.
///   Referencia: Sección 6.2 del Manual de Programación Flutter (MPF).
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Servicio HTTP institucional — cliente Dio con gestión de sesión SAM.
///
/// Mantiene la cookie JSESSIONID en memoria y la inyecta automáticamente
/// en cada solicitud mediante un interceptor. La URL base se carga desde
/// la variable de entorno [SAM_BASE_URL] definida en el archivo .env.
/// Referencia: Sección 6.2 del Manual de Programación Flutter.
class HttpService {
  HttpService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['SAM_BASE_URL'] ?? '',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': '*/*'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  late final Dio _dio;

  /// Cookie de sesión SAM almacenada en memoria.
  String? _sessionCookie;

  /// Instancia de Dio lista para usar.
  Dio get dio => _dio;

  // ── Interceptores ─────────────────────────────────────────────────────────

  /// Inyecta la cookie de sesión en cada solicitud saliente.
  void _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (_sessionCookie != null) {
      options.headers['Cookie'] = _sessionCookie;
    }
    handler.next(options);
  }

  /// Extrae y almacena la cookie JSESSIONID de cada respuesta entrante.
  ///
  /// Usa `headers['set-cookie']` (lista) para manejar múltiples cabeceras
  /// Set-Cookie correctamente — `headers.value()` las une con coma y puede
  /// romper el regex de extracción.
  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    final setCookies = response.headers['set-cookie'];
    if (setCookies != null) {
      for (final cookie in setCookies) {
        final match = RegExp(r'JSESSIONID=([^;]+)').firstMatch(cookie);
        if (match != null) {
          _sessionCookie = 'JSESSIONID=${match.group(1)}';
          debugPrint(
            '[HttpService] JSESSIONID capturado (${response.requestOptions.path})',
          );
          break;
        }
      }
    }
    handler.next(response);
  }

  /// Propaga errores sin transformación al nivel de repositorio.
  void _onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }

  // ── Métodos públicos ──────────────────────────────────────────────────────

  /// Limpia la cookie de sesión activa.
  ///
  /// Debe llamarse al cerrar sesión para invalidar la sesión SAM local.
  void clearSession() => _sessionCookie = null;

  /// Retorna true si hay una sesión activa en memoria.
  bool get hasSession => _sessionCookie != null;
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Provider del [HttpService] — instancia única compartida en toda la app.
final httpServiceProvider = Provider<HttpService>((ref) => HttpService());
