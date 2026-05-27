/// @file: database_service.dart
/// @project: Control de Accesos - GAMA
/// @description: Servicio de conexión directa a la base de datos MySQL
///   hosteada en Railway. Gestiona el ciclo de vida de la conexión y
///   expone un método genérico para ejecutar cualquier consulta.
///   Las credenciales se cargan desde variables de entorno.
///   Referencia: Sección 6 del Manual de Programación Flutter (MPF).
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysql_client/mysql_client.dart';

/// Servicio de acceso directo a la base de datos MySQL en Railway.
///
/// Abre una nueva conexión por operación y la cierra en el bloque
/// `finally` para garantizar la liberación de recursos. Las credenciales
/// se obtienen del archivo .env mediante flutter_dotenv.
///
/// Uso recomendado: llamar únicamente desde los repositorios de cada
/// feature, nunca directamente desde ViewModels o vistas.
class DatabaseService {
  // ── Conexión ──────────────────────────────────────────────────────────────

  /// Crea y abre una nueva conexión MySQL con las credenciales del .env.
  Future<MySQLConnection> _getConnection() async {
    final conn = await MySQLConnection.createConnection(
      host: dotenv.env['DB_HOST']!,
      port: int.parse(dotenv.env['DB_PORT']!),
      userName: dotenv.env['DB_USER']!,
      password: dotenv.env['DB_PASSWORD']!,
      databaseName: dotenv.env['DB_NAME']!,
      secure: true,
    );
    await conn.connect();
    return conn;
  }

  // ── API pública ───────────────────────────────────────────────────────────

  /// Ejecuta [query] dentro de una conexión administrada.
  ///
  /// Garantiza que la conexión se cierre siempre en el bloque `finally`,
  /// incluso si ocurre una excepción. El repositorio que llama a este
  /// método es responsable de transformar los errores en excepciones
  /// del dominio antes de propagarlos al ViewModel.
  Future<T> execute<T>(
    Future<T> Function(MySQLConnection conn) query,
  ) async {
    MySQLConnection? conn;
    try {
      conn = await _getConnection();
      return await query(conn);
    } finally {
      await conn?.close();
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Provider del [DatabaseService] — instancia única compartida en toda la app.
final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);
