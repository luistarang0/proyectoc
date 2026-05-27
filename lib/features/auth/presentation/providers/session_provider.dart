/// @file: session_provider.dart
/// @project: Control de Accesos - GAMA
/// @description: Provider de sesión activa. Almacena el perfil SAM del
///   usuario autenticado para que cualquier widget o ViewModel de la app
///   pueda leerlo sin pasar datos entre pantallas.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/sam_response_model.dart';

/// Perfil SAM del usuario actualmente autenticado.
///
/// Se establece en [LoginViewModel] tras autenticación exitosa y se
/// limpia al cerrar sesión. Cualquier ViewModel o widget puede leerlo
/// con `ref.watch(sessionProvider)`.
final sessionProvider = StateProvider<SamUserModel?>((ref) => null);
