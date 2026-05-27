/// @file: solicitud_model.dart
/// @project: Control de Accesos - GAMA
/// @description: Modelos de dominio para la entidad Solicitud de Acceso.
///   Define los estados posibles, los tipos de visita y la estructura
///   de datos compartida entre los roles Autorizador y Anfitrión.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

/// Estados posibles de una solicitud de acceso.
enum EstadoSolicitud { pendiente, aprobada, rechazada, cancelada, vencida }

/// Tipos de visita soportados por el sistema.
///
/// - [individual]: un único visitante visita a un anfitrión específico.
/// - [grupal]: múltiples visitantes, un solo anfitrión, un QR por persona.
/// - [evento]: actos académicos gestionados por servicios escolares.
/// - [extraescolares]: equipos deportivos u grupos externos.
/// - [espontaneo]: visita de consulta generada en el momento por el Guardia.
enum VisitType { individual, grupal, evento, extraescolares, espontaneo }

/// Modelo de datos de una solicitud de acceso — inmutable.
///
/// Implementa serialización JSON para la comunicación con la API REST.
/// Referencia: Sección 5.1 del Manual de Programación Flutter.
class SolicitudModel {
  const SolicitudModel({
    required this.visitante,
    required this.solicitante,
    required this.area,
    required this.fecha,
    required this.hora,
    required this.motivo,
    this.estado = EstadoSolicitud.pendiente,
    this.visitType = VisitType.individual,
  });

  // ── Atributos ─────────────────────────────────────────────────────────────

  /// Nombre completo del visitante.
  final String visitante;

  /// Departamento o persona que genera la solicitud.
  final String solicitante;

  /// Área o sala a la que se solicita acceso.
  final String area;

  /// Fecha programada de la visita.
  final String fecha;

  /// Hora programada de la visita.
  final String hora;

  /// Motivo declarado de la solicitud.
  final String motivo;

  /// Estado actual de la solicitud.
  final EstadoSolicitud estado;

  /// Tipo de visita.
  final VisitType visitType;

  // ── Copias inmutables ─────────────────────────────────────────────────────

  SolicitudModel copyWith({
    String? visitante,
    String? solicitante,
    String? area,
    String? fecha,
    String? hora,
    String? motivo,
    EstadoSolicitud? estado,
    VisitType? visitType,
  }) {
    return SolicitudModel(
      visitante: visitante ?? this.visitante,
      solicitante: solicitante ?? this.solicitante,
      area: area ?? this.area,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      motivo: motivo ?? this.motivo,
      estado: estado ?? this.estado,
      visitType: visitType ?? this.visitType,
    );
  }

  // ── Serialización ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'visitante': visitante,
      'solicitante': solicitante,
      'area': area,
      'fecha': fecha,
      'hora': hora,
      'motivo': motivo,
      'estado': estado.name,
      'visit_type': visitType.name,
    };
  }

  factory SolicitudModel.fromJson(Map<String, dynamic> json) {
    return SolicitudModel(
      visitante: json['visitante'] as String,
      solicitante: json['solicitante'] as String,
      area: json['area'] as String,
      fecha: json['fecha'] as String,
      hora: json['hora'] as String,
      motivo: json['motivo'] as String,
      estado: EstadoSolicitud.values.firstWhere(
        (e) => e.name == json['estado'],
        orElse: () => EstadoSolicitud.pendiente,
      ),
      visitType: VisitType.values.firstWhere(
        (e) => e.name == json['visit_type'],
        orElse: () => VisitType.individual,
      ),
    );
  }
}
