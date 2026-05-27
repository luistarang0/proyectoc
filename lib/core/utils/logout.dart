/// @file: logout.dart
/// @project: Control de Accesos - GAMA
/// @description: Utilidad centralizada para cerrar sesión. Limpia todos
///   los providers de sesión activa, llama al logout SAM si aplica,
///   invalida el ViewModel de login para que cargue CAPTCHA fresco,
///   y navega al login.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/services/sam_auth_service.dart';
import '../../features/auth/model/guardia_session.dart';
import '../../features/auth/presentation/providers/session_provider.dart';

/// Cierra la sesión activa y navega al login.
///
/// 1. Llama `SamAuthService.logout()` si hay sesión SAM activa.
/// 2. Limpia [sessionProvider] y [guardiaSessionProvider].
/// 3. Invalida [loginViewModelProvider] para cargar CAPTCHA fresco.
/// 4. Navega a `/login` con `pushReplacementNamed`.
Future<void> logoutUser(WidgetRef ref, BuildContext context) async {
  // 1. Logout SAM si hay sesión activa.
  if (ref.read(sessionProvider) != null) {
    try {
      await ref.read(samAuthServiceProvider).logout();
    } catch (_) {
      // Si falla el logout remoto, continuamos limpiando local.
    }
  }

  // 2. Limpiar sesiones.
  ref.read(sessionProvider.notifier).state = null;
  ref.read(guardiaSessionProvider.notifier).state = null;

  // 3. No invalidamos loginViewModelProvider aquí para evitar
  //    LateInitializationError al reinicializar dentro de un ciclo activo.
  //    LoginView.initState() llama fetchCaptcha() automáticamente al montarse.

  // 4. Navegar al login.
  if (context.mounted) {
    Navigator.pushReplacementNamed(context, '/login');
  }
}

/// Widget de botón de cierre de sesión listo para usar en cualquier AppBar.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout, size: 20),
      onPressed: () => logoutUser(ref, context),
      tooltip: 'Cerrar sesión',
    );
  }
}
