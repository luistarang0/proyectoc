// @file:        home_guardia_view.dart
// @project:     Control de Accesos - GAMA
// @description: Vista principal del rol Guardia de Seguridad. Gestiona
//               el control de accesos mediante escaneo QR, registro
//               manual de visitas y consulta de visitas activas del día.
//               Referencia: RF-17 / RF-09 / RF-10.
// @author:      Luis Antonio Tarango Regis
// @version:     1.0.0
// @last_update: 2026-05-26

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/utils/logout.dart';
import '../../../../core/config/app_icons.dart';
import '../../../../core/config/app_spacing.dart';
import '../../../../core/config/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/home_shell.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/models/access_log_db_model.dart';
import '../../data/models/building_model.dart';
import '../../data/repositories/access_log_repository.dart';
import '../../data/repositories/building_repository.dart';
import '../viewmodels/escaneo_viewmodel.dart';
import '../viewmodels/espontaneo_viewmodel.dart';
import '../viewmodels/guardia_visitas_viewmodel.dart';

// ═══════════════════════════════════════════════════════════════════════════
// VISTA PRINCIPAL — HomeGuardiaView
// ═══════════════════════════════════════════════════════════════════════════

/// Vista raíz del rol Guardia de Seguridad.
///
/// Administra tres secciones mediante [IndexedStack]:
///   0 — Escaneo QR
///   1 — Registro manual (RF-10)
///   2 — Visitas activas del día (RF-09)
class HomeGuardiaView extends StatefulWidget {
  const HomeGuardiaView({super.key});

  @override
  State<HomeGuardiaView> createState() => _HomeGuardiaViewState();
}

class _HomeGuardiaViewState extends State<HomeGuardiaView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return HomeShell(
      child: Scaffold(
        backgroundColor: AppColors.appBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Control de Accesos'),
          actions: [
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.bell, size: 18),
              onPressed: () {},
              tooltip: 'Notificaciones',
            ),
            const LogoutButton(),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            _TabEscaneoQR(), // 0
            _TabRegistroManual(), // 1
            _TabVisitasActivas(), // 2
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.qrcode, size: 18),
              label: 'Escaneo',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.hashtag, size: 18),
              label: 'Manual',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.listCheck, size: 18),
              label: 'Visitas',
            ),
          ],
        ),
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 0 — Escaneo de QR
// ═══════════════════════════════════════════════════════════════════════════

/// Tab de escaneo QR para registrar entradas y salidas del instituto.
///
/// Usa [MobileScanner] para leer códigos QR en tiempo real.
/// Al detectar un token válido, pausa el scanner, muestra el resultado
/// en un BottomSheet y lo reanuda al cerrar.
class _TabEscaneoQR extends ConsumerStatefulWidget {
  const _TabEscaneoQR();

  @override
  ConsumerState<_TabEscaneoQR> createState() => _TabEscaneoQRState();
}

class _TabEscaneoQRState extends ConsumerState<_TabEscaneoQR> {
  late final MobileScannerController _scannerController;

  // Debounce: evitar procesar el mismo token dos veces rápidamente.
  String? _lastToken;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(autoStart: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  bool _shouldProcess(String token) {
    final now = DateTime.now();
    if (_lastToken == token &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inSeconds < 3) {
      return false;
    }
    _lastToken = token;
    _lastScanTime = now;
    return true;
  }

  void _onQrDetected(String token) {
    if (!_shouldProcess(token)) return;
    if (ref.read(escaneoViewModelProvider).isProcessing) return;
    ref.read(escaneoViewModelProvider.notifier).processScan(token);
  }

  Future<void> _showResultSheet(BuildContext context, ScanResult result) async {
    _scannerController.stop();
    final isExtension = result.action == ScanAction.extensionPendiente;
    final isSalidaSinOficina = result.action == ScanAction.salidaSinOficina;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: !isExtension,
      enableDrag: !isExtension && !isSalidaSinOficina,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScanResultSheet(result: result),
    );
    if (mounted) {
      ref.read(escaneoViewModelProvider.notifier).clearResult();
      _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vmState = ref.watch(escaneoViewModelProvider);

    // Cuando llega un resultado, mostrar el sheet.
    ref.listen<EscaneoState>(escaneoViewModelProvider, (prev, next) {
      if (next.lastScan != null && prev?.lastScan == null) {
        _showResultSheet(context, next.lastScan!);
      }
    });

    return Column(
      children: [
        // ── Tarjeta del guardia ───────────────────────────────
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: _AccessPointCard(),
        ),

        // ── Visor de cámara ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Text('Escanear código QR', style: AppTextStyles.subtitle),
        ),
        const SizedBox(height: AppSpacing.elementGap),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final raw = capture.barcodes.firstOrNull?.rawValue;
                      if (raw != null) _onQrDetected(raw);
                    },
                  ),
                  // Overlay de esquinas del visor.
                  _ScannerOverlay(),
                  // Indicador de procesamiento.
                  if (vmState.isProcessing)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── Último resultado ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: _LastScanSummary(lastScan: vmState.lastScan),
        ),
      ],
    );
  }
}

/// Tarjeta de información del punto de acceso activo.
class _AccessPointCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Row(
        children: [
          const FaIcon(AppIcons.guardia, size: 28, color: Colors.white),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guardia de Seguridad',
                  style: AppTextStyles.subtitleWhite,
                ),
                Text(
                  'Puerta Principal · Activo',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay con esquinas decorativas sobre el visor de la cámara.
class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF4FC3F7);
    const s = 28.0;
    const w = 3.5;
    return Stack(
      children: [
        // Fondo semitransparente.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _OverlayPainter()),
          ),
        ),
        Positioned(top: 24, left: 24, child: _Corner(color: c, size: s, strokeWidth: w, topLeft: true)),
        Positioned(top: 24, right: 24, child: _Corner(color: c, size: s, strokeWidth: w, topRight: true)),
        Positioned(bottom: 24, left: 24, child: _Corner(color: c, size: s, strokeWidth: w, bottomLeft: true)),
        Positioned(bottom: 24, right: 24, child: _Corner(color: c, size: s, strokeWidth: w, bottomRight: true)),
      ],
    );
  }
}

/// Dibuja el fondo oscuro semitransparente alrededor de la zona de escaneo.
class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.3);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Widget que dibuja una esquina del visor QR mediante [CustomPaint].
class _Corner extends StatelessWidget {
  const _Corner({
    required this.color,
    required this.size,
    required this.strokeWidth,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  final Color color;
  final double size;
  final double strokeWidth;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          strokeWidth: strokeWidth,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({
    required this.color,
    required this.strokeWidth,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  final Color color;
  final double strokeWidth;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    if (topLeft) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), p);
      canvas.drawLine(Offset.zero, Offset(0, size.height), p);
    }
    if (topRight) {
      canvas.drawLine(Offset(size.width, 0), Offset(0, 0), p);
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), p);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), p);
      canvas.drawLine(Offset(0, size.height), Offset(0, 0), p);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(size.width, size.height), Offset(0, size.height), p);
      canvas.drawLine(Offset(size.width, size.height), Offset(size.width, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Resumen compacto del último escaneo mostrado debajo del visor.
class _LastScanSummary extends StatelessWidget {
  const _LastScanSummary({this.lastScan});

  final ScanResult? lastScan;

  @override
  Widget build(BuildContext context) {
    if (lastScan == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.iceBlue,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: [
            const FaIcon(AppIcons.circleInfo, size: 14, color: AppColors.info),
            const SizedBox(width: AppSpacing.xs),
            Text('Sin escaneos recientes', style: AppTextStyles.caption),
          ],
        ),
      );
    }

    final color = lastScan!.isSuccess ? AppColors.success : AppColors.error;
    final icon = lastScan!.isSuccess ? AppIcons.circleCheck : AppIcons.circleXmark;
    final label = lastScan!.isSuccess
        ? (lastScan!.action == ScanAction.entrada ? 'Entrada registrada' : 'Salida registrada')
        : 'Acceso denegado';
    final detail = lastScan!.isSuccess
        ? lastScan!.visitorName ?? ''
        : lastScan!.errorMessage ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          FaIcon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.captionBold.copyWith(color: color)),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BottomSheet — Resultado del escaneo
// ═══════════════════════════════════════════════════════════════════════════

/// Sheet deslizable que muestra el resultado de un escaneo QR.
/// Se actualiza automáticamente cuando el ViewModel cambia (extensión pendiente).
class _ScanResultSheet extends ConsumerWidget {
  const _ScanResultSheet({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchar cambios del ViewModel para actualizar el sheet en tiempo real.
    final current =
        ref.watch(escaneoViewModelProvider).lastScan ?? result;

    // Si ya se resolvió la extensión (éxito/error final), cerrar el sheet.
    if (result.action == ScanAction.extensionPendiente &&
        current.action != ScanAction.extensionPendiente) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
    }

    // Si la salida sin oficina fue confirmada (→ acción cambió a salida), cerrar.
    if (result.action == ScanAction.salidaSinOficina &&
        current.action == ScanAction.salida) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
    }

    // Mostrar variante de espera de extensión.
    if (current.action == ScanAction.extensionPendiente) {
      return _buildExtensionWaiting(context, ref, current);
    }

    // Mostrar variante de confirmación de salida sin ciclo de oficina.
    if (current.action == ScanAction.salidaSinOficina) {
      return _buildSalidaSinOficina(context, ref, current);
    }

    final bool isEntrada =
        current.isSuccess && current.action == ScanAction.entrada;

    final Color headerColor = result.isSuccess
        ? (isEntrada ? AppColors.success : AppColors.info)
        : AppColors.error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de arrastre.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.blockGap),

            // ── Ícono de resultado ──────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: headerColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FaIcon(
                  result.isSuccess
                      ? (isEntrada ? AppIcons.doorEnter : AppIcons.doorExit)
                      : AppIcons.circleXmark,
                  size: 32,
                  color: headerColor,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Título ──────────────────────────────────────────
            Text(
              result.isSuccess
                  ? (isEntrada ? 'Puede entrar' : 'Salida registrada')
                  : 'Acceso denegado',
              style: AppTextStyles.title.copyWith(color: headerColor),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Detalles ────────────────────────────────────────
            if (result.isSuccess) ...[
              Text(
                result.visitorName ?? '—',
                style: AppTextStyles.subtitle,
                textAlign: TextAlign.center,
              ),
              if (isEntrada) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(AppIcons.building, size: 12, color: AppColors.iconGray),
                    const SizedBox(width: AppSpacing.xs),
                    Text(result.buildingName ?? '—', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(AppIcons.email, size: 12, color: AppColors.iconGray),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Anfitrión: ${result.emailHost ?? '—'}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ] else ...[
              Text(
                result.errorMessage ?? 'Código no válido',
                style: AppTextStyles.body.copyWith(color: AppColors.textContrast),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: AppSpacing.blockGap),

            // ── Botón cerrar ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      result.isSuccess ? headerColor : AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.buttonV,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: Text(
                  current.isSuccess ? 'Continuar escaneando' : 'Entendido',
                  style: AppTextStyles.button,
                ),
              ),
            ),

            // Botón de solicitar extensión (solo cuando es error por horario).
            if (!current.isSuccess &&
                current.canExtend &&
                current.requestId != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // cerrar sheet primero
                    ref
                        .read(escaneoViewModelProvider.notifier)
                        .solicitarExtension(
                          requestId: current.requestId!,
                          itemId: current.itemId!,
                          visitorName: current.visitorName ?? '—',
                          accessToken: current.accessToken ?? '',
                        );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.buttonV,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  icon: const FaIcon(FontAwesomeIcons.bell, size: 14),
                  label: Text(
                    'Notificar al anfitrión',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Variante: Salida sin ciclo de oficina completo ───────────────────────

  Widget _buildSalidaSinOficina(
    BuildContext context,
    WidgetRef ref,
    ScanResult current,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de arrastre.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.blockGap),

            // Ícono de advertencia.
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: FaIcon(
                  AppIcons.circleInfo,
                  size: 32,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Confirmar salida',
              style: AppTextStyles.title.copyWith(color: AppColors.warning),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              current.visitorName ?? '—',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              current.errorMessage ?? '',
              style: AppTextStyles.body.copyWith(color: AppColors.textContrast),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.blockGap),

            // Botón confirmar salida.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: current.itemId == null
                    ? null
                    : () => ref
                          .read(escaneoViewModelProvider.notifier)
                          .confirmarSalidaDirecta(current.itemId!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.buttonV,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                icon: const FaIcon(AppIcons.doorExit, size: 14),
                label: Text(
                  'Sí, registrar salida',
                  style: AppTextStyles.button,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Botón cancelar.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(escaneoViewModelProvider.notifier).clearResult();
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textContrast,
                  side: const BorderSide(color: AppColors.borderGray),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.buttonV,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: Text(
                  'Cancelar',
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.textContrast,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Variante: Esperando respuesta del anfitrión ───────────────────────────

  Widget _buildExtensionWaiting(
    BuildContext context,
    WidgetRef ref,
    ScanResult current,
  ) {
    final seconds = current.secondsRemaining ?? 0;
    final pct = seconds / 60.0;
    final Color color = seconds > 20 ? AppColors.warning : AppColors.error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.blockGap),

            // Ícono de espera.
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        value: pct,
                        color: color,
                        backgroundColor: AppColors.borderGray,
                        strokeWidth: 4,
                      ),
                    ),
                    Text(
                      '$seconds',
                      style: AppTextStyles.subtitle.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Esperando al anfitrión',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              current.visitorName ?? '—',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'El anfitrión debe aprobar o rechazar el acceso',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.blockGap),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(escaneoViewModelProvider.notifier)
                      .cancelarExtension(current.requestId!);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.buttonV,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                icon: const FaIcon(AppIcons.ban, size: 14),
                label: Text(
                  'Cancelar',
                  style: AppTextStyles.button.copyWith(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — Registro Manual / Visita Espontánea
// ═══════════════════════════════════════════════════════════════════════════

/// Tab con dos modos: visita espontánea (walk-in) y registro por código.
class _TabRegistroManual extends ConsumerStatefulWidget {
  const _TabRegistroManual();

  @override
  ConsumerState<_TabRegistroManual> createState() => _TabRegistroManualState();
}

class _TabRegistroManualState extends ConsumerState<_TabRegistroManual>
    with SingleTickerProviderStateMixin {
  late final TabController _modeController;

  @override
  void initState() {
    super.initState();
    _modeController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _modeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Selector de modo ────────────────────────────────────
        Container(
          color: AppColors.iceBlue,
          child: TabBar(
            controller: _modeController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.iconGray,
            indicatorColor: AppColors.primary,
            labelStyle: AppTextStyles.captionBold,
            tabs: const [
              Tab(text: 'Visita espontánea'),
              Tab(text: 'Registro por código'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _modeController,
            children: const [
              _ModoEspontaneo(),
              _ModoCodigo(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Modo A — Visita espontánea ────────────────────────────────────────────────

/// Formulario para crear una visita espontánea (walk-in).
class _ModoEspontaneo extends ConsumerStatefulWidget {
  const _ModoEspontaneo();

  @override
  ConsumerState<_ModoEspontaneo> createState() => _ModoEspontaneoState();
}

class _ModoEspontaneoState extends ConsumerState<_ModoEspontaneo> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  BuildingModel? _selectedBuilding;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(espontaneoViewModelProvider);
    final notifier = ref.read(espontaneoViewModelProvider.notifier);
    final buildingsCatalog = ref.watch(buildingCatalogProvider);

    // Si ya se creó el token, mostrar pantalla de confirmación.
    if (vm.hasToken) {
      return _EspontaneoConfirmacion(
        token: vm.createdToken!,
        visitorName: vm.visitorName ?? '',
        entradaRegistrada: vm.entradaRegistrada,
        isRegistering: vm.isRegistering,
        onRegistrarEntrada: notifier.registrarEntradaInmediata,
        onNuevaVisita: () {
          notifier.reset();
          _correoCtrl.clear();
          _nombreCtrl.clear();
          setState(() => _selectedBuilding = null);
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Visita espontánea', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Captura los datos del visitante y el edificio destino.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.blockGap),

            AppTextField(
              label: 'Correo del visitante',
              hint: 'correo@ejemplo.com',
              controller: _correoCtrl,
              prefixIcon: AppIcons.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !vm.isSubmitting,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido';
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.elementGap),

            AppTextField(
              label: 'Nombre (opcional)',
              hint: 'Nombre del visitante',
              controller: _nombreCtrl,
              prefixIcon: AppIcons.person,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !vm.isSubmitting,
            ),
            const SizedBox(height: AppSpacing.elementGap),

            // Selector de edificio.
            Text('Edificio destino', style: AppTextStyles.fieldLabel),
            const SizedBox(height: AppSpacing.xs),
            buildingsCatalog.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(
                'Error al cargar edificios',
                style: AppTextStyles.errorText,
              ),
              data: (buildings) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: AppColors.iceBlue,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<BuildingModel>(
                    value: _selectedBuilding,
                    isExpanded: true,
                    hint: Text(
                      'Selecciona un edificio',
                      style: AppTextStyles.fieldHint,
                    ),
                    items: buildings
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(
                              b.buildingName,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textContrast,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: vm.isSubmitting
                        ? null
                        : (b) => setState(() => _selectedBuilding = b),
                  ),
                ),
              ),
            ),

            if (vm.hasError) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(vm.errorMsg, style: AppTextStyles.errorText),
            ],

            const SizedBox(height: AppSpacing.blockGap),
            PrimaryButton(
              label: 'Generar código de visita',
              isLoading: vm.isSubmitting,
              isEnabled: !vm.isSubmitting,
              icon: vm.isSubmitting
                  ? null
                  : const FaIcon(
                      FontAwesomeIcons.qrcode,
                      size: 14,
                      color: Colors.white,
                    ),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBuilding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona el edificio destino'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    ref.read(espontaneoViewModelProvider.notifier).submit(
      correoVisitante: _correoCtrl.text.trim(),
      nombreVisitante: _nombreCtrl.text.trim(),
      buildingId: _selectedBuilding!.buildingId,
      edificioCode: _selectedBuilding!.buildingName,
    );
  }
}

/// Pantalla de confirmación tras crear la visita espontánea.
class _EspontaneoConfirmacion extends StatelessWidget {
  const _EspontaneoConfirmacion({
    required this.token,
    required this.visitorName,
    required this.entradaRegistrada,
    required this.isRegistering,
    required this.onRegistrarEntrada,
    required this.onNuevaVisita,
  });

  final String token;
  final String visitorName;
  final bool entradaRegistrada;
  final bool isRegistering;
  final VoidCallback onRegistrarEntrada;
  final VoidCallback onNuevaVisita;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ícono de éxito.
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: FaIcon(
                  AppIcons.circleCheck,
                  size: 36,
                  color: AppColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Visita creada',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          if (visitorName.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              visitorName,
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.blockGap),

          // Token de acceso.
          Text('Código de acceso', style: AppTextStyles.fieldLabel),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.textContrast,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: SelectableText(
              token,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Comunica este código al visitante',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.blockGap),

          // Botón entrada inmediata.
          if (!entradaRegistrada)
            PrimaryButton(
              label: 'Registrar entrada ahora',
              variant: PrimaryButtonVariant.success,
              isLoading: isRegistering,
              isEnabled: !isRegistering,
              icon: isRegistering
                  ? null
                  : const FaIcon(
                      AppIcons.doorEnter,
                      size: 14,
                      color: Colors.white,
                    ),
              onPressed: onRegistrarEntrada,
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(
                    AppIcons.circleCheck,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Entrada registrada',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.elementGap),

          PrimaryButton(
            label: 'Nueva visita',
            variant: PrimaryButtonVariant.outlined,
            icon: const FaIcon(
              AppIcons.add,
              size: 14,
              color: AppColors.primary,
            ),
            onPressed: onNuevaVisita,
          ),
        ],
      ),
    );
  }
}

// ── Modo B — Registro por código ──────────────────────────────────────────────

/// Formulario para registrar manualmente un token existente.
/// Reutiliza la lógica del [EscaneoViewModel].
class _ModoCodigo extends ConsumerStatefulWidget {
  const _ModoCodigo();

  @override
  ConsumerState<_ModoCodigo> createState() => _ModoCodigoState();
}

class _ModoCodigoState extends ConsumerState<_ModoCodigo> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(escaneoViewModelProvider);

    // Mostrar resultado cuando llega.
    ref.listen<EscaneoState>(escaneoViewModelProvider, (prev, next) {
      if (next.lastScan != null && prev?.lastScan == null) {
        final r = next.lastScan!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              r.isSuccess
                  ? (r.action == ScanAction.entrada
                      ? 'Entrada registrada: ${r.visitorName}'
                      : 'Salida registrada: ${r.visitorName}')
                  : r.errorMessage ?? 'Código no válido',
            ),
            backgroundColor: r.isSuccess ? AppColors.success : AppColors.error,
          ),
        );
        ref.read(escaneoViewModelProvider.notifier).clearResult();
        if (r.isSuccess) _tokenCtrl.clear();
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registro por código', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ingresa el UUID del código de acceso manualmente.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.blockGap),
            AppTextField(
              label: 'Código de acceso (UUID)',
              hint: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              controller: _tokenCtrl,
              prefixIcon: AppIcons.hashtag,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              enabled: !vm.isProcessing,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa el código' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.blockGap),
            PrimaryButton(
              label: 'Procesar código',
              isLoading: vm.isProcessing,
              isEnabled: !vm.isProcessing,
              icon: vm.isProcessing
                  ? null
                  : const FaIcon(
                      FontAwesomeIcons.magnifyingGlass,
                      size: 14,
                      color: Colors.white,
                    ),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref
        .read(escaneoViewModelProvider.notifier)
        .processScan(_tokenCtrl.text.trim());
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — Visitas activas del día (conectado a BD)
// ═══════════════════════════════════════════════════════════════════════════

/// Tab que lista todas las visitas activas del día para el Guardia.
/// Permite registrar entrada/salida directamente (útil para espontáneas).
/// Valida la ventana de horario antes de registrar una entrada; si la
/// visita está vencida ofrece el flujo de extensión al anfitrión.
class _TabVisitasActivas extends ConsumerStatefulWidget {
  const _TabVisitasActivas();

  @override
  ConsumerState<_TabVisitasActivas> createState() => _TabVisitasActivasState();
}

class _TabVisitasActivasState extends ConsumerState<_TabVisitasActivas> {
  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(guardiaVisitasViewModelProvider);
    final notifier = ref.read(guardiaVisitasViewModelProvider.notifier);

    // ── Reaccionar a errores de horario ──────────────────────────────────
    ref.listen<GuardiaVisitasState>(guardiaVisitasViewModelProvider,
        (prev, next) {
      if (next.timeError != null && prev?.timeError == null) {
        final err = next.timeError!;
        notifier.clearTimeError();

        if (err.canExtend) {
          _showVencidaDialog(context, err);
        } else {
          // Demasiado temprano — solo informar.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.message),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });

    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(
                AppIcons.circleXmark,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                vm.errorMsg,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.blockGap),
              ElevatedButton.icon(
                onPressed: notifier.refresh,
                icon: const FaIcon(AppIcons.refresh, size: 14),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (vm.visitas.isEmpty) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            EmptyState(
              icon: AppIcons.listVisitas,
              label: 'Sin visitas registradas hoy',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: vm.visitas.length + 1,
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppSpacing.listItemGap),
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Visitas del día',
                      style: AppTextStyles.subtitle,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${vm.visitas.length}',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final dto = vm.visitas[i - 1];
          final itemId = dto.item.itemId!;
          final isProcessing = vm.isProcessing(itemId);
          final event = dto.currentEvent;

          return _VisitaGuardiaCard(
            dto: dto,
            isProcessing: isProcessing,
            // Entrada: solo si el visitante aún no ha registrado ningún evento.
            onEntrada: event == null
                ? () => notifier.registrarEntrada(itemId)
                : null,
            // Salida del instituto: solo cuando el anfitrión confirmó que el
            // visitante ya salió de su oficina (salidaOficina).
            // Si el visitante está en entradaInstitucion, llegadaOficina o
            // aún en enEspera, el guardia no puede registrar la salida aún.
            onSalida: event == AccessEventType.salidaOficina
                ? () => notifier.registrarSalida(itemId)
                : null,
          );
        },
      ),
    );
  }

  // ── Diálogo: visita vencida ─────────────────────────────────────────────

  void _showVencidaDialog(BuildContext ctx, TimeError err) {
    final dto = err.dto;
    showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        title: Row(
          children: [
            const FaIcon(
              FontAwesomeIcons.clockRotateLeft,
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Visita vencida'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dto.visitor.fullName, style: AppTextStyles.bodyBold),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const FaIcon(
                  AppIcons.clock,
                  size: 12,
                  color: AppColors.iconGray,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Programada: ${dto.formattedTime}'
                  '${dto.toleranceMinutes != null ? ' ±${dto.toleranceMinutes}min' : ''}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'El tiempo de tolerancia ha expirado. '
              'Puedes notificar al anfitrión para que autorice la entrada.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            icon: const FaIcon(FontAwesomeIcons.bell, size: 13),
            label: const Text('Notificar al anfitrión'),
            onPressed: () {
              Navigator.pop(dCtx);
              _solicitarExtension(ctx, dto);
            },
          ),
        ],
      ),
    );
  }

  /// Inicia el flujo de extensión y muestra el sheet de espera.
  void _solicitarExtension(BuildContext ctx, ActiveVisitDto dto) {
    // Disparar el flujo en el escaneo ViewModel (reutiliza countdown + polling).
    ref.read(escaneoViewModelProvider.notifier).solicitarExtension(
          requestId: dto.item.requestId,
          itemId: dto.item.itemId!,
          visitorName: dto.visitor.fullName,
          accessToken: dto.item.accessToken,
        );

    // Mostrar el mismo BottomSheet de extensión que usa el tab QR.
    showModalBottomSheet<void>(
      context: ctx,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScanResultSheet(
        result: ScanResult.extensionPendiente(
          visitorName: dto.visitor.fullName,
          requestId: dto.item.requestId,
          itemId: dto.item.itemId!,
          secondsRemaining: 60,
        ),
      ),
    ).then((_) {
      // Cuando el sheet se cierra, refrescar la lista de visitas.
      ref.read(escaneoViewModelProvider.notifier).clearResult();
      ref.read(guardiaVisitasViewModelProvider.notifier).refresh();
    });
  }
}

/// Tarjeta de visita del día para el Guardia con acciones de entrada/salida.
class _VisitaGuardiaCard extends StatelessWidget {
  const _VisitaGuardiaCard({
    required this.dto,
    this.isProcessing = false,
    this.onEntrada,
    this.onSalida,
  });

  final ActiveVisitDto dto;
  final bool isProcessing;
  final VoidCallback? onEntrada;
  final VoidCallback? onSalida;

  @override
  Widget build(BuildContext context) {
    final event = dto.currentEvent;
    final Color stateColor = _eventColor(event);
    final String stateLabel = _eventLabel(event);
    final bool showActions = onEntrada != null || onSalida != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.appBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: stateColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: FaIcon(AppIcons.person, size: 20, color: stateColor),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dto.visitor.fullName, style: AppTextStyles.bodyBold),
                    if (dto.visitor.email != null)
                      Text(dto.visitor.email!, style: AppTextStyles.caption),
                    Row(
                      children: [
                        const FaIcon(
                          AppIcons.building,
                          size: 10,
                          color: AppColors.iconGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dto.buildingName ?? '—',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      stateLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: stateColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (dto.isEspontanea) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'ESPONTÁNEA',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.info,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          if (showActions) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (onEntrada != null)
                  Expanded(
                    child: _BtnVisita(
                      label: 'Entrada',
                      icon: AppIcons.doorEnter,
                      color: AppColors.success,
                      isLoading: isProcessing,
                      onTap: isProcessing ? null : onEntrada,
                    ),
                  ),
                if (onEntrada != null && onSalida != null)
                  const SizedBox(width: AppSpacing.sm),
                if (onSalida != null)
                  Expanded(
                    child: _BtnVisita(
                      label: 'Salida',
                      icon: AppIcons.doorExit,
                      color: AppColors.error,
                      isLoading: isProcessing,
                      onTap: isProcessing ? null : onSalida,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _eventColor(AccessEventType? event) => switch (event) {
    null => AppColors.iconGray,
    AccessEventType.entradaInstitucion => AppColors.warning,
    AccessEventType.llegadaOficina => AppColors.success,
    AccessEventType.salidaOficina => AppColors.info,
    AccessEventType.salidaInstitucion => AppColors.borderGray,
  };

  String _eventLabel(AccessEventType? event) => switch (event) {
    null => 'Esperando',
    AccessEventType.entradaInstitucion => 'En instituto',
    AccessEventType.llegadaOficina => 'En oficina',
    AccessEventType.salidaOficina => 'Salió oficina',
    AccessEventType.salidaInstitucion => 'Salió ITT',
  };
}

/// Botón de acción compacto para la tarjeta de visita del guardia.
class _BtnVisita extends StatelessWidget {
  const _BtnVisita({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(icon, size: 12, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: AppTextStyles.captionBold.copyWith(color: color),
                  ),
                ],
              ),
      ),
    );
  }
}
