/// @file: visitante_model.dart
/// @project: Control de Accesos - GAMA
/// @description: Modelo de dominio para la entidad Visitante. Define el
///   ciclo de vida del visitante dentro del instituto y la estructura
///   de datos compartida entre los roles Guardia y Empleado.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

/// Estados posibles de un visitante dentro del sistema de control de accesos.
///
/// El ciclo de vida es:
/// enEspera → enInstituto (Guardia) → enOficina (Empleado)
///          → salidoOficina (Empleado) → salidoInstituto (Guardia)
enum EstatusVisitante {
  /// Solicitud aprobada; el visitante aún no ha llegado al instituto.
  enEspera,

  /// El Guardia confirmó la entrada al instituto.
  enInstituto,

  /// El Empleado confirmó la llegada a su oficina.
  enOficina,

  /// El Empleado confirmó que el visitante salió de su oficina.
  salidoOficina,

  /// El Guardia confirmó la salida definitiva del instituto.
  salidoInstituto,
}

/// Modelo de datos de un visitante — inmutable.
///
/// Implementa serialización JSON para la comunicación con la API REST.
/// Referencia: Sección 5.1 del Manual de Programación Flutter.
class VisitanteModel {
  const VisitanteModel({
    required this.id,
    required this.nombre,
    required this.destino,
    required this.horaEstimada,
    this.correo,
    this.entradaAt,
    this.estatus = EstatusVisitante.enEspera,
  });

  // ── Atributos ─────────────────────────────────────────────────────────────

  /// Identificador único de la visita.
  final String id;

  /// Nombre completo del visitante.
  final String nombre;

  /// Área o departamento de destino dentro del instituto.
  final String destino;

  /// Hora estimada de llegada.
  final String horaEstimada;

  /// Correo electrónico del visitante (opcional según el rol que consulta).
  final String? correo;

  /// Timestamp real registrado cuando el Guardia confirma la entrada.
  final DateTime? entradaAt;

  /// Estado actual del visitante en el ciclo de vida del acceso.
  final EstatusVisitante estatus;

  // ── Copias inmutables ─────────────────────────────────────────────────────

  /// Retorna una copia del modelo con los campos especificados modificados.
  VisitanteModel copyWith({
    String? id,
    String? nombre,
    String? destino,
    String? horaEstimada,
    String? correo,
    DateTime? entradaAt,
    EstatusVisitante? estatus,
  }) {
    return VisitanteModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      destino: destino ?? this.destino,
      horaEstimada: horaEstimada ?? this.horaEstimada,
      correo: correo ?? this.correo,
      entradaAt: entradaAt ?? this.entradaAt,
      estatus: estatus ?? this.estatus,
    );
  }

  // ── Serialización ─────────────────────────────────────────────────────────

  /// Serializa el modelo a un mapa JSON para enviar a la API.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'destino': destino,
      'hora_estimada': horaEstimada,
      if (correo != null) 'correo': correo,
      if (entradaAt != null) 'entrada_at': entradaAt!.toIso8601String(),
      'estatus': estatus.name,
    };
  }

  /// Construye un [VisitanteModel] a partir de un mapa JSON de la API.
  factory VisitanteModel.fromJson(Map<String, dynamic> json) {
    return VisitanteModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      destino: json['destino'] as String,
      horaEstimada: json['hora_estimada'] as String,
      correo: json['correo'] as String?,
      entradaAt: json['entrada_at'] != null
          ? DateTime.parse(json['entrada_at'] as String)
          : null,
      estatus: EstatusVisitante.values.firstWhere(
        (e) => e.name == json['estatus'],
        orElse: () => EstatusVisitante.enEspera,
      ),
    );
  }
}
