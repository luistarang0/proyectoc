/// @file: home_shell.dart
/// @project: Control de Accesos - GAMA
/// @description: Wrapper de las vistas Home que intercepta el botón de
///   retroceso del sistema para implementar el comportamiento
///   "presiona atrás dos veces para salir":
///     · Primera pulsación → SnackBar de aviso (2 s de ventana).
///     · Segunda pulsación dentro de 2 s → cierra la aplicación.
///   Evita que el usuario regrese accidentalmente a la pantalla de login.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-28

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Envuelve cualquier vista Home para manejar el botón de retroceso.
///
/// Uso:
/// ```dart
/// return HomeShell(child: Scaffold(...));
/// ```
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  DateTime? _lastBackPressed;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Deshabilita la navegación hacia atrás del sistema.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final now = DateTime.now();
        final hasRecentPress = _lastBackPressed != null &&
            now.difference(_lastBackPressed!) <= const Duration(seconds: 2);

        if (hasRecentPress) {
          // Segunda pulsación dentro de 2 s → salir.
          SystemNavigator.pop();
        } else {
          // Primera pulsación → avisar al usuario.
          _lastBackPressed = now;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('Presiona atrás de nuevo para salir'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      },
      child: widget.child,
    );
  }
}
