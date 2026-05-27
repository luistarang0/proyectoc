/// @file: visitor_qr_dto.dart
/// @project: Control de Accesos - GAMA
/// @description: DTO que agrupa el nombre, correo y access_token de un
///   visitante para renderizar su código QR en el visor del Anfitrión.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

/// Datos necesarios para mostrar y compartir el QR de un visitante.
class VisitorQrDto {
  const VisitorQrDto({
    required this.visitorName,
    this.email,
    required this.accessToken,
  });

  /// Nombre completo del visitante.
  final String visitorName;

  /// Correo del visitante (mostrado en el visor para facilitar el envío).
  final String? email;

  /// UUID que se codifica en el QR y que el Guardia escaneará.
  final String accessToken;

  factory VisitorQrDto.fromMap(Map<String, String?> map) {
    return VisitorQrDto(
      visitorName: map['full_name'] ?? '—',
      email: map['email'],
      accessToken: map['access_token']!,
    );
  }
}
