// @file: main.dart
// @project: Control de Accesos - GAMA
// @description: Punto de entrada de la aplicación. Carga las variables de
//   entorno desde .env, restaura la sesión persistida (si existe) para que
//   el usuario no tenga que volver a autenticarse, e inicializa el
//   ProviderScope de Riverpod con los overrides de sesión.
//   La ruta inicial se determina en función de la sesión restaurada.
// @author: Luis Antonio Tarango Regis
// @version: 2.0.0
// @last_update: 2026-05-28

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_router.dart';
import 'core/services/session_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/models/sam_response_model.dart';
import 'features/auth/model/guardia_session.dart';
import 'features/auth/presentation/providers/session_provider.dart';
import 'features/auth/presentation/views/login_view.dart';
import 'features/home/presentation/views/home_anfitrion_view.dart';
import 'features/home/presentation/views/home_autorizador_view.dart';
import 'features/home/presentation/views/home_guardia_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno desde .env (MPF §8.1).
  await dotenv.load(fileName: '.env');

  // Restaurar sesiones persistidas.
  final samSession = await SessionStorageService.loadSamSession();
  final guardiaSession = await SessionStorageService.loadGuardiaSession();

  // Construir overrides de Riverpod con las sesiones restauradas.
  final overrides = <Override>[
    if (samSession != null)
      sessionProvider.overrideWith((ref) => samSession),
    if (guardiaSession != null)
      guardiaSessionProvider.overrideWith((ref) => guardiaSession),
  ];

  // Determinar la widget de inicio según la sesión disponible.
  final Widget homeWidget = _resolveHome(samSession, guardiaSession);

  runApp(
    ProviderScope(
      overrides: overrides,
      child: ControlAccesosApp(homeWidget: homeWidget),
    ),
  );
}

/// Resuelve la vista inicial según la sesión guardada.
///
/// - GuardiaSession presente  → [HomeGuardiaView]
/// - SamUserModel 'administrativo' → [HomeAutorizadorView]
/// - SamUserModel 'docente' o 'empleado' → [HomeAnfitrionView]
/// - Sin sesión → [LoginView]
Widget _resolveHome(SamUserModel? sam, GuardiaSession? guardia) {
  if (guardia != null) return const HomeGuardiaView();

  if (sam != null) {
    final creds = sam.credenciales.trim().toLowerCase();
    if (creds.contains('administrativo') || sam.samRole == 'master') {
      return const HomeAutorizadorView();
    }
    return const HomeAnfitrionView();
  }

  return const LoginView();
}

/// Widget raíz de la aplicación Control de Accesos.
///
/// [homeWidget] es la primera pantalla que verá el usuario.
/// Si hay sesión persistida será el Home correspondiente; si no, el Login.
class ControlAccesosApp extends StatelessWidget {
  const ControlAccesosApp({super.key, required this.homeWidget});

  final Widget homeWidget;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Accesos · ITT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // `home` define la raíz del stack. No tiene back button.
      // El login/home tras logout/login se gestiona con pushReplacementNamed.
      home: homeWidget,
      onGenerateRoute: onGenerateRoute,
    );
  }
}
