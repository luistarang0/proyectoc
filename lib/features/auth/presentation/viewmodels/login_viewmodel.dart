/// @file: login_viewmodel.dart
/// @project: Control de Accesos - GAMA
/// @description: ViewModel del módulo de autenticación. Gestiona el estado
///   del formulario de login (incluyendo CAPTCHA), delega la autenticación
///   al AuthRepository y enruta al Home según el UserRole obtenido.
///   Referencia: RF-15 / RF-16 del Manual de Proyecto C — GAMA MPF v1.0.
/// @author: Jesús David Johnson Soto
/// @version: 2.0.0
/// @last_update: 2026-05-26

library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sam_departamento_service.dart';
import '../../data/data.dart';
import '../../model/auth_models.dart';
import '../providers/session_provider.dart';

// ── Estado del ViewModel ──────────────────────────────────────────────────────

/// Estado inmutable del formulario de login con soporte para CAPTCHA.
@immutable
class LoginState {
  const LoginState({
    this.username = '',
    this.password = '',
    this.captchaText = '',
    this.captchaImage,
    this.status = AuthStatus.idle,
    this.errorMsg = '',
  });

  final String username;
  final String password;

  /// Código CAPTCHA ingresado por el usuario.
  final String captchaText;

  /// Bytes de la imagen CAPTCHA descargada de SAM.
  final Uint8List? captchaImage;

  /// Estado actual del flujo de autenticación.
  final AuthStatus status;

  /// Mensaje de error actual. Vacío si no hay error.
  final String errorMsg;

  bool get isLoading => status == AuthStatus.loading;
  bool get isCaptchaLoading => status == AuthStatus.loading && captchaImage == null;

  LoginState copyWith({
    String? username,
    String? password,
    String? captchaText,
    Uint8List? captchaImage,
    AuthStatus? status,
    String? errorMsg,
  }) {
    return LoginState(
      username: username ?? this.username,
      password: password ?? this.password,
      captchaText: captchaText ?? this.captchaText,
      captchaImage: captchaImage ?? this.captchaImage,
      status: status ?? this.status,
      errorMsg: errorMsg ?? this.errorMsg,
    );
  }
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

/// ViewModel de la pantalla de login — MVVM + Riverpod.
///
/// Gestiona el estado del formulario, el CAPTCHA y la autenticación
/// contra el web service SAM a través del [AuthRepository].
/// Referencia: RF-15 / RF-16 del Manual de Proyecto C.
class LoginViewModel extends Notifier<LoginState> {
  late final AuthRepository _repository;

  @override
  LoginState build() {
    _repository = ref.read(authRepositoryProvider);
    return const LoginState();
  }

  // ── Setters ───────────────────────────────────────────────────────────────

  void setUsername(String v) {
    state = state.copyWith(username: v.trim(), errorMsg: '');
  }

  void setPassword(String v) {
    state = state.copyWith(password: v, errorMsg: '');
  }

  void setCaptchaText(String v) {
    state = state.copyWith(captchaText: v, errorMsg: '');
  }

  // ── Validadores locales ───────────────────────────────────────────────────

  String? validateUsername(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu usuario';
    return null;
  }

  String? validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
    if (v.length < 4) return 'Mínimo 4 caracteres';
    return null;
  }

  String? validateCaptcha(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa el código CAPTCHA';
    return null;
  }

  // ── CAPTCHA ───────────────────────────────────────────────────────────────

  /// Descarga la imagen CAPTCHA desde SAM y actualiza el estado.
  ///
  /// Se llama automáticamente al montar la vista de login y
  /// manualmente al refrescar el CAPTCHA.
  Future<void> fetchCaptcha() async {
    state = state.copyWith(
      status: AuthStatus.loading,
      captchaImage: null,
      errorMsg: '',
    );
    try {
      final imageBytes = await _repository.fetchCaptcha();
      state = state.copyWith(
        captchaImage: imageBytes,
        captchaText: '',
        status: AuthStatus.idle,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: 'No se pudo cargar el CAPTCHA. Verifica la conexión.',
      );
    }
  }

  // ── Lógica de login ───────────────────────────────────────────────────────

  /// Valida el formulario, autentica contra SAM y navega según el rol.
  ///
  /// [formKey] — GlobalKey del Form para ejecutar validación.
  /// [context] — BuildContext para navegación.
  Future<void> login({
    required GlobalKey<FormState> formKey,
    required BuildContext context,
  }) async {
    if (!formKey.currentState!.validate()) return;

    state = state.copyWith(status: AuthStatus.loading, errorMsg: '');

    try {
      final result = await _repository.login(
        username: state.username,
        password: state.password,
        captchaCode: state.captchaText,
      );

      if (!context.mounted) return;
      // Persistir perfil SAM en sesión para toda la app.
      ref.read(sessionProvider.notifier).state = result.user;

      // Cargar en caché el mapa edificio→correoPuesto desde SAM.
      // No bloqueamos la navegación si falla.
      ref
          .read(samDepartamentoServiceProvider)
          .fetchEdificioEmailMap()
          .then(
            (map) => ref.read(edificioEmailCacheProvider.notifier).state = map,
          )
          .ignore();

      state = state.copyWith(status: AuthStatus.success);
      _navigateByRole(result.role, context);
    } on SamAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: e.message,
      );
      // Refrescar CAPTCHA automáticamente tras error de login.
      await fetchCaptcha();
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMsg: 'Error de conexión. Verifica tu red e intenta de nuevo.',
      );
      await fetchCaptcha();
    }
  }

  // ── Métodos públicos ──────────────────────────────────────────────────────

  /// Limpia todos los campos y restaura el estado inicial.
  Future<void> reset() async {
    state = const LoginState();
    await fetchCaptcha();
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  void _navigateByRole(UserRole role, BuildContext context) {
    const routes = {
      UserRole.guardia: '/home/guardia',
      UserRole.anfitrion: '/home/anfitrion',
      UserRole.autorizador: '/home/autorizador',
    };
    Navigator.pushReplacementNamed(context, routes[role]!);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Provider del [LoginViewModel] para inyección de dependencias con Riverpod.
final loginViewModelProvider =
    NotifierProvider<LoginViewModel, LoginState>(LoginViewModel.new);
