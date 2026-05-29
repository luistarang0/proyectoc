/// @file: login_view.dart
/// @project: Control de Accesos - GAMA
/// @description: Pantalla de inicio de sesión del sistema. Presenta el
///   header institucional (TECNM / ITT), el formulario de credenciales
///   con CAPTCHA de SAM y el footer institucional. Delega la lógica
///   de autenticación al LoginViewModel mediante Riverpod.
///   Referencia: RF-15 / Mockup S-01 del Proyecto C — Control de Accesos.
/// @author: Jesús David Johnson Soto
/// @version: 3.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sim_card_info/sim_card_info.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_icons.dart';
import '../../../../core/config/app_spacing.dart';
import '../../../../core/config/app_text_styles.dart';
import '../../../../core/services/session_storage_service.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../model/guardia_session.dart';
import '../viewmodels/login_viewmodel.dart';

/// Vista raíz de la pantalla de login.
///
/// Presenta dos modos: "Empleado / Admin" (SAM) y "Guardia" (teléfono).
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loginViewModelProvider.notifier).fetchCaptcha();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Limpiar el campo de captcha cada vez que se carga una nueva imagen.
    // Esto evita que el controller muestre el captcha anterior mientras
    // state.captchaText ya fue reseteado a ''.
    ref.listen<LoginState>(loginViewModelProvider, (prev, next) {
      if (prev?.captchaImage != next.captchaImage && next.captchaImage != null) {
        _captchaController.clear();
      }
    });

    return _buildScaffold(context);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Widget _buildScaffold(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.iceBlue,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _InstitutionalHeader(),

            // ── Selector de modo ──────────────────────────────
            Container(
              color: AppColors.iceBlue,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.iconGray,
                indicatorColor: AppColors.primary,
                labelStyle: AppTextStyles.captionBold,
                tabs: const [
                  Tab(
                    icon: FaIcon(FontAwesomeIcons.idCard, size: 16),
                    text: 'Empleado / Admin',
                  ),
                  Tab(
                    icon: FaIcon(FontAwesomeIcons.shieldHalved, size: 16),
                    text: 'Guardia',
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Tab 0: SAM ────────────────────────────────
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH,
                        vertical: AppSpacing.blockGap,
                      ),
                      child: Column(
                        children: [
                          _LoginForm(
                            formKey: _formKey,
                            userController: _userController,
                            passwordController: _passwordController,
                            captchaController: _captchaController,
                          ),
                          const _InstitutionalFooter(),
                        ],
                      ),
                    ),
                  ),

                  // ── Tab 1: Guardia ────────────────────────────
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH,
                        vertical: AppSpacing.blockGap,
                      ),
                      child: Column(
                        children: [
                          const _GuardiaLoginForm(),
                          const _InstitutionalFooter(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Header institucional
// ═════════════════════════════════════════════════════════════════════════════

/// Header del login con los logos institucionales reales.
///
/// Layout:
///   ┌───────────────────────────────────────────────────┐
///   │  fondo azul oscuro (AppColors.primary)            │
///   │  [tec.png]   [logo.png — grande, centro]  [ittol] │
///   └───────────────────────────────────────────────────┘
///   ┌───────────────────────────────────────────────────┐
///   │  fondo iceBlue                                     │
///   │  "Control de Accesos"   (título)                  │
///   │  "Instituto Tecnológico de Toluca"  (subtítulo)   │
///   └───────────────────────────────────────────────────┘
class _InstitutionalHeader extends StatelessWidget {
  const _InstitutionalHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Banda de logos ────────────────────────────────
        Container(
          width: double.infinity,
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo TECNM (tec.png — fondo blanco propio)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/tec.png',
                  fit: BoxFit.contain,
                ),
              ),

              // Logo del sistema — centro, más grande
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Logo ITT Toluca (ittol.png — fondo transparente)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/ittol.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),

        // ── Banda de nombre del sistema ───────────────────
        Container(
          width: double.infinity,
          color: AppColors.iceBlue,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.screenH,
          ),
          child: Column(
            children: [
              Text(
                'Control de Accesos',
                style: AppTextStyles.title.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                'Instituto Tecnológico de Toluca',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Formulario de login
// ═════════════════════════════════════════════════════════════════════════════

/// Formulario de credenciales con campo de CAPTCHA.
class _LoginForm extends ConsumerWidget {
  const _LoginForm({
    required this.formKey,
    required this.userController,
    required this.passwordController,
    required this.captchaController,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final TextEditingController captchaController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(loginViewModelProvider);
    final notifier = ref.read(loginViewModelProvider.notifier);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Iniciar sesión', style: AppTextStyles.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ingresa tus credenciales institucionales',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.blockGap),

          // ── Campo: Usuario ────────────────────────────────────────
          AppTextField(
            label: 'Usuario',
            hint: 'Ej. juan.garcia',
            controller: userController,
            prefixIcon: AppIcons.user,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            validator: notifier.validateUsername,
            onChanged: notifier.setUsername,
            enabled: !vm.isLoading,
          ),
          const SizedBox(height: AppSpacing.elementGap),

          // ── Campo: Contraseña ─────────────────────────────────────
          AppTextField(
            label: 'Contraseña',
            hint: '••••••••',
            controller: passwordController,
            prefixIcon: AppIcons.lock,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: notifier.validatePassword,
            onChanged: notifier.setPassword,
            enabled: !vm.isLoading,
          ),
          const SizedBox(height: AppSpacing.blockGap),

          // ── CAPTCHA ───────────────────────────────────────────────
          _CaptchaSection(
            captchaImage: vm.captchaImage,
            isLoading: vm.isLoading,
            onRefresh: notifier.fetchCaptcha,
            captchaController: captchaController,
            validator: notifier.validateCaptcha,
            onChanged: notifier.setCaptchaText,
          ),
          const SizedBox(height: AppSpacing.elementGap),

          // ── Mensaje de error ──────────────────────────────────────
          if (vm.errorMsg.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  FaIcon(
                    AppIcons.circleXmark,
                    size: 14,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(vm.errorMsg, style: AppTextStyles.errorText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.elementGap),
          ],

          // ── Botón principal ───────────────────────────────────────
          PrimaryButton(
            label: 'Ingresar',
            isLoading: vm.isLoading,
            isEnabled: !vm.isLoading && vm.captchaImage != null,
            icon: vm.isLoading
                ? null
                : const FaIcon(
                    FontAwesomeIcons.rightToBracket,
                    size: 14,
                    color: Colors.white,
                  ),
            onPressed: () => _submit(context, notifier),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context, LoginViewModel notifier) {
    FocusScope.of(context).unfocus();
    notifier.login(formKey: formKey, context: context);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sección CAPTCHA
// ═════════════════════════════════════════════════════════════════════════════

/// Widget que muestra la imagen CAPTCHA de SAM y el campo de código.
class _CaptchaSection extends StatelessWidget {
  const _CaptchaSection({
    required this.captchaImage,
    required this.isLoading,
    required this.onRefresh,
    required this.captchaController,
    required this.validator,
    required this.onChanged,
  });

  final Uint8List? captchaImage;
  final bool isLoading;
  final VoidCallback onRefresh;
  final TextEditingController captchaController;
  final String? Function(String?) validator;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Imagen CAPTCHA + botón refrescar ──────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.textContrast,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: _buildCaptchaContent(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Botón refrescar CAPTCHA.
            IconButton(
              onPressed: isLoading ? null : onRefresh,
              icon: const FaIcon(AppIcons.refresh, size: 16),
              color: AppColors.secondary,
              tooltip: 'Refrescar CAPTCHA',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.iceBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  side: const BorderSide(color: AppColors.borderGray),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.elementGap),

        // ── Campo código CAPTCHA ──────────────────────────────────
        AppTextField(
          label: 'Código CAPTCHA',
          hint: 'Ingresa el texto de la imagen',
          controller: captchaController,
          prefixIcon: FontAwesomeIcons.shieldHalved,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          validator: validator,
          onChanged: onChanged,
          enabled: !isLoading && captchaImage != null,
        ),
      ],
    );
  }

  Widget _buildCaptchaContent() {
    if (isLoading && captchaImage == null) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }

    if (captchaImage != null) {
      return Image.memory(
        captchaImage!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    return Center(
      child: Text(
        'Error cargando CAPTCHA',
        style: AppTextStyles.caption.copyWith(color: Colors.white54),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Formulario de login del Guardia (validación por teléfono)
// ═════════════════════════════════════════════════════════════════════════════

/// Formulario de autenticación del Guardia mediante número de teléfono.
///
/// Compara el número ingresado con el número real del dispositivo
/// obtenido vía [SimCardInfo]. Modo dummy: si no se puede leer el
/// número del dispositivo, se concede acceso de todas formas.
class _GuardiaLoginForm extends ConsumerStatefulWidget {
  const _GuardiaLoginForm();

  @override
  ConsumerState<_GuardiaLoginForm> createState() => _GuardiaLoginFormState();
}

class _GuardiaLoginFormState extends ConsumerState<_GuardiaLoginForm> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String _errorMsg = '';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final input = _phoneController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMsg = 'Ingresa tu número de teléfono');
      return;
    }
    // Validación básica: exactamente 10 dígitos.
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      setState(() => _errorMsg = 'El número debe tener exactamente 10 dígitos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      // 1. Solicitar permiso de lectura del SIM.
      final granted = await _requestPhonePermission();
      if (!granted) {
        if (mounted) {
          setState(() =>
              _errorMsg = 'Se requiere permiso de teléfono para verificar el dispositivo.');
        }
        return;
      }

      // 2. Verificar que haya SIM presente (carrier no vacío).
      bool simPresente = false;
      try {
        final cards = await SimCardInfo().getSimInfo();
        debugPrint('[GuardiaLogin] SIM count: ${cards?.length ?? 'null'}');
        if (cards != null && cards.isNotEmpty) {
          simPresente = cards.any((c) => c.carrierName.isNotEmpty);
          debugPrint('[GuardiaLogin] carrier: "${cards.first.carrierName}"');
        }
      } catch (e) {
        debugPrint('[GuardiaLogin] SimCardInfo error: $e');
      }

      if (!mounted) return;

      if (!simPresente) {
        setState(() =>
            _errorMsg = 'No se detectó ninguna SIM en este dispositivo.');
        return;
      }

      // 3. Validar contra la whitelist definida en .env (GUARDIA_PHONES).
      //    Formato: números de 10 dígitos separados por coma.
      final rawList = dotenv.env['GUARDIA_PHONES'] ?? '';
      final whitelist = rawList
          .split(',')
          .map((n) => n.trim().replaceAll(RegExp(r'\D'), ''))
          .where((n) => n.length == 10)
          .toSet();

      debugPrint('[GuardiaLogin] whitelist : $whitelist');
      debugPrint('[GuardiaLogin] input     : "$digits"');
      debugPrint('[GuardiaLogin] autorizado: ${whitelist.contains(digits)}');

      if (whitelist.isEmpty) {
        setState(() =>
            _errorMsg = 'No hay guardias configurados. Contacta al administrador.');
        return;
      }

      if (!whitelist.contains(digits)) {
        setState(() =>
            _errorMsg = 'Este número no está autorizado como guardia.');
        return;
      }

      // 4. Acceso concedido.
      final guardiaSession = GuardiaSession(telefono: digits);
      ref.read(guardiaSessionProvider.notifier).state = guardiaSession;
      SessionStorageService.saveGuardiaSession(guardiaSession).ignore();
      Navigator.pushReplacementNamed(context, '/home/guardia');
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Error al verificar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Solicita permiso READ_PHONE_NUMBERS en runtime.
  Future<bool> _requestPhonePermission() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado
        Text('Acceso de Guardia', style: AppTextStyles.subtitle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Ingresa tu número de teléfono registrado.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.blockGap),

        AppTextField(
          label: 'Número de teléfono',
          hint: '10 dígitos',
          controller: _phoneController,
          prefixIcon: AppIcons.phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          enabled: !_isLoading,
          onFieldSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: AppSpacing.elementGap),

        if (_errorMsg.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const FaIcon(AppIcons.circleXmark, size: 14, color: AppColors.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(_errorMsg, style: AppTextStyles.errorText),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.elementGap),
        ],

        PrimaryButton(
          label: 'Ingresar',
          isLoading: _isLoading,
          isEnabled: !_isLoading,
          icon: _isLoading
              ? null
              : const FaIcon(
                  FontAwesomeIcons.rightToBracket,
                  size: 14,
                  color: Colors.white,
                ),
          onPressed: _verify,
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Footer institucional
// ═════════════════════════════════════════════════════════════════════════════

class _InstitutionalFooter extends StatelessWidget {
  const _InstitutionalFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.blockGap,
      ),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Instituto Tecnológico de Toluca',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          Text(
            'Tecnológico Nacional de México',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'v1.0.0 · GAMA MPF',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.borderGray,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
