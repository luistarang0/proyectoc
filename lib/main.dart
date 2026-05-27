// @file: main.dart
// @project: Control de Accesos - GAMA
// @description: Punto de entrada de la aplicación. Carga las variables de
//   entorno desde .env, inicializa el ProviderScope de Riverpod y monta
//   la raíz [ControlAccesosApp] con el tema global y el enrutador central.
//   TODO: inicializar Hive y registrar adaptadores conforme MPF §4.1.4.
//   TODO: configurar l10n (AppLocalizations) conforme MPF §4.1.3.
// @author: Jesús David Johnson Soto
// @version: 1.0.0
// @last_update: 2026-05-26

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno desde .env (MPF §8.1).
  await dotenv.load(fileName: '.env');

  runApp(
    const ProviderScope(child: ControlAccesosApp()),
  );
}

/// Widget raíz de la aplicación Control de Accesos.
///
/// Configura el [MaterialApp] con el tema global [AppTheme.theme]
/// y delega la navegación a [AppRouter] mediante [onGenerateRoute].
class ControlAccesosApp extends StatelessWidget {
  const ControlAccesosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Accesos · ITT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: initialRoute,
      onGenerateRoute: onGenerateRoute,
    );
  }
}
