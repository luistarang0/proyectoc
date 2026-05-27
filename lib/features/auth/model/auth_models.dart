/// @file: auth_models.dart
/// @project: Control de Accesos - GAMA
/// @description: Enumeraciones de dominio del módulo de autenticación.
///   Define los roles disponibles en el sistema y los estados del
///   flujo de autenticación.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

/// Roles disponibles en el sistema de Control de Accesos.
///
/// Determina la vista Home a la que se redirige tras autenticación exitosa.
enum UserRole { guardia, anfitrion, autorizador }

/// Estado del flujo de autenticación.
///
/// - [idle]: estado inicial, sin acción en curso.
/// - [loading]: autenticación en progreso.
/// - [success]: credenciales válidas, navegación ejecutada.
/// - [error]: credenciales inválidas o fallo de conexión.
enum AuthStatus { idle, loading, success, error }
