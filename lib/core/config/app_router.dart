/// @file: app_router.dart
/// @project: Control de Accesos - GAMA
/// @description: Enrutador central del sistema. Define las rutas nombradas
///   disponibles y el generador de rutas compatible con
///   MaterialApp.onGenerateRoute, conforme a la Sección 5.2.8 del Manual
///   de Programación Flutter (MPF).
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/material.dart';

import '../../features/auth/presentation/views/login_view.dart';
import '../../features/home/presentation/views/home_anfitrion_view.dart';
import '../../features/home/presentation/views/home_autorizador_view.dart';
import '../../features/home/presentation/views/home_guardia_view.dart';

/// Catálogo de rutas nombradas del sistema Control de Accesos.
///
/// Clase abstracta de solo constantes. No debe instanciarse.
/// Referencia: Sección 5.2.8 del Manual de Programación Flutter.
abstract class AppRoutes {
  // ── Autenticación ────────────────────────────────────────────────────────

  /// Ruta de la pantalla de inicio de sesión.
  static const String login = '/login';

  // ── Vistas por rol ───────────────────────────────────────────────────────

  /// Ruta del home para el rol Guardia.
  static const String homeGuardia = '/home/guardia';

  /// Ruta del home para el rol Anfitrión.
  static const String homeAnfitrion = '/home/anfitrion';

  /// Ruta del home para el rol Autorizador.
  static const String homeAutorizador = '/home/autorizador';

}

/// Ruta inicial de la aplicación.
const String initialRoute = AppRoutes.login;

/// Generador de rutas compatible con [MaterialApp.onGenerateRoute].
///
/// Recibe el [RouteSettings] de navegación y retorna la [MaterialPageRoute]
/// correspondiente. Rutas no reconocidas muestran una pantalla 404.
Route<dynamic> onGenerateRoute(RouteSettings settings) {
  Widget page;

  switch (settings.name) {
    case '/':
    case AppRoutes.login:
      page = const LoginView();

    case AppRoutes.homeGuardia:
      page = const HomeGuardiaView();

    case AppRoutes.homeAnfitrion:
      page = const HomeAnfitrionView();

    case AppRoutes.homeAutorizador:
      page = const HomeAutorizadorView();

    default:
      page = Scaffold(
        body: Center(child: Text('Ruta no encontrada: ${settings.name}')),
      );
  }

  return MaterialPageRoute(builder: (_) => page, settings: settings);
}
