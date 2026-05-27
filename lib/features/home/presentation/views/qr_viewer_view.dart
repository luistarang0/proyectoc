/// @file: qr_viewer_view.dart
/// @project: Control de Accesos - GAMA
/// @description: Pantalla de visualización de códigos QR generados tras
///   la aprobación de una solicitud. Visita individual: un QR en pantalla
///   completa. Visita grupal: PageView con un QR por visitante.
///   Permite compartir el QR como imagen PNG vía share_plus.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_icons.dart';
import '../../../../core/config/app_spacing.dart';
import '../../../../core/config/app_text_styles.dart';
import '../../data/models/visitor_qr_dto.dart';

/// Pantalla de visualización de QR post-aprobación.
///
/// Recibe la lista de [VisitorQrDto] de la solicitud aprobada.
/// Navega hacia esta pantalla con `Navigator.push`.
class QrViewerView extends StatefulWidget {
  const QrViewerView({super.key, required this.items});

  final List<VisitorQrDto> items;

  @override
  State<QrViewerView> createState() => _QrViewerViewState();
}

class _QrViewerViewState extends State<QrViewerView> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Generación y compartir ────────────────────────────────────────────────

  Future<Uint8List> _generateQrBytes(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF134474),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF134474),
      ),
    );
    final byteData = await painter.toImageData(
      512,
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  /// Genera el PNG del QR y abre el share sheet del sistema.
  Future<void> _shareQr(VisitorQrDto item) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _generateQrBytes(item.accessToken);
      final dir = await getTemporaryDirectory();
      final fileName = 'qr_${item.accessToken.substring(0, 8)}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      final shareText =
          'Código de acceso al ITT para ${item.visitorName}'
          '${item.email != null ? ' — ${item.email}' : ''}.\n'
          'Presenta este QR al Guardia al llegar al instituto.';

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'qr_acceso.png')],
        subject: 'Tu código QR de acceso — ITT',
        text: shareText,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo compartir el QR. Intenta de nuevo.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isSingle = widget.items.length == 1;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: Text(isSingle ? 'Código QR' : 'Códigos QR'),
        actions: [
          if (!isSingle)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / ${widget.items.length}',
                  style: AppTextStyles.captionBold.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: isSingle
          ? _buildSingleQr(widget.items.first)
          : _buildPagedQr(),
    );
  }

  /// Vista para solicitud individual — QR centrado en pantalla completa.
  Widget _buildSingleQr(VisitorQrDto item) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: _QrCard(
            item: item,
            isSharing: _isSharing,
            onShare: () => _shareQr(item),
          ),
        ),
      ),
    );
  }

  /// Vista para solicitud grupal — un QR por página con indicador de paginación.
  Widget _buildPagedQr() {
    return Column(
      children: [
        // Indicador de páginas.
        Container(
          color: AppColors.iceBlue,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.borderGray,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
        // PageView de QRs.
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (ctx, i) {
              final item = widget.items[i];
              return SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.screenH),
                    child: _QrCard(
                      item: item,
                      isSharing: _isSharing,
                      onShare: () => _shareQr(item),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Tarjeta de QR ─────────────────────────────────────────────────────────────

/// Tarjeta que muestra el QR de un visitante con su nombre, correo
/// y el botón de compartir.
class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.item,
    required this.isSharing,
    required this.onShare,
  });

  final VisitorQrDto item;
  final bool isSharing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.appBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: [
          BoxShadow(
            color: AppColors.mistBlue.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Nombre del visitante ──────────────────────────────
          Text(
            item.visitorName,
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          if (item.email != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(
                  AppIcons.email,
                  size: 11,
                  color: AppColors.iconGray,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    item.email!,
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.blockGap),

          // ── Código QR ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: QrImageView(
              data: item.accessToken,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF134474), // primary
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF134474), // primary
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Muestra este código al llegar al instituto',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.blockGap),

          // ── Botón compartir ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSharing ? null : onShare,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.buttonV,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              icon: isSharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const FaIcon(FontAwesomeIcons.shareNodes, size: 15),
              label: Text(
                isSharing ? 'Preparando...' : 'Compartir QR',
                style: AppTextStyles.button,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
