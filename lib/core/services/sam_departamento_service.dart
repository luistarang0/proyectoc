/// @file: sam_departamento_service.dart
/// @project: Control de Accesos - GAMA
/// @description: Servicio que consulta los endpoints de departamentos y
///   puestos de SAM para construir el mapa edificio → correoPuesto.
///   Se ejecuta tras login SAM exitoso y el resultado se cachea en
///   [edificioEmailCacheProvider] para que el guardia lo use sin sesión SAM.
///
///   NOTA: El parsing de HTML de SAM depende de la estructura real de las
///   páginas JSP. Ajustar las expresiones regulares según la respuesta
///   del servidor del ITT.
/// @author: Luis Antonio Tarango Regis
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'http_service.dart';

/// Mapa en memoria de código de edificio → correo del área (correoPuesto).
///
/// Se popula cuando cualquier usuario SAM inicia sesión.
/// El guardia lo consume al crear visitas espontáneas.
final edificioEmailCacheProvider =
    StateProvider<Map<String, String>>((ref) => {});

/// Servicio que resuelve el correo de área de un edificio vía SAM.
class SamDepartamentoService {
  SamDepartamentoService(this._httpService);

  final HttpService _httpService;
  Dio get _dio => _httpService.dio;

  // ── Endpoints SAM ─────────────────────────────────────────────────────────

  static const _deptoPath = '/app/departamento.do';
  static const _puestoPath = '/app/puesto.do';

  // ── API pública ───────────────────────────────────────────────────────────

  /// Construye y retorna el mapa [edificio → correoPuesto] consultando SAM.
  ///
  /// Llama a [_deptoPath] para listar departamentos con su código de edificio
  /// y a [_puestoPath] para obtener el [correoPuesto] de cada departamento.
  ///
  /// Retorna mapa vacío si ocurre algún error (degradación grácil).
  Future<Map<String, String>> fetchEdificioEmailMap() async {
    try {
      // 1. Obtener departamentos (edificio → id_departamento).
      final deptMap = await _fetchDepartamentos();
      if (deptMap.isEmpty) return {};

      // 2. Obtener correos por departamento (id_departamento → correoPuesto).
      final emailMap = await _fetchCorreosPorDepartamento();
      if (emailMap.isEmpty) return {};

      // 3. Cruzar: edificio → correoPuesto.
      final result = <String, String>{};
      deptMap.forEach((edificio, idDepto) {
        final correo = emailMap[idDepto];
        if (correo != null && correo.isNotEmpty) {
          result[edificio] = correo;
        }
      });

      debugPrint('[SAM Depto] Mapa edificio→email: $result');
      return result;
    } catch (e) {
      debugPrint('[SAM Depto] Error obteniendo mapa: $e');
      return {};
    }
  }

  // ── Parsing ───────────────────────────────────────────────────────────────

  /// Obtiene el mapa [edificio → id_departamento] desde SAM.
  ///
  /// TODO: Ajustar el regex/parsing a la estructura HTML real del SAM del ITT.
  /// Patrón esperado en la tabla HTML de departamentos:
  /// columnas: id | nombre | nombreCorto | edificio
  Future<Map<String, int>> _fetchDepartamentos() async {
    final response = await _dio.get<String>(
      _deptoPath,
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data ?? '';
    return _parseDepartamentosHtml(html);
  }

  /// Obtiene el mapa [id_departamento → correoPuesto] desde SAM.
  ///
  /// TODO: Ajustar el regex/parsing a la estructura HTML real del SAM del ITT.
  Future<Map<int, String>> _fetchCorreosPorDepartamento() async {
    final response = await _dio.get<String>(
      '$_puestoPath?accion=listar',
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data ?? '';
    return _parsePuestosHtml(html);
  }

  /// Parsea la tabla HTML de departamentos para extraer [edificio → id_depto].
  ///
  /// Patrón asumido: celdas <td> en orden id | nombre | nombreCorto | edificio.
  /// AJUSTAR según la respuesta real del SAM del ITT.
  Map<String, int> _parseDepartamentosHtml(String html) {
    final result = <String, int>{};
    // Busca filas de tabla con cuatro celdas <td>
    final rowPattern = RegExp(
      r'<tr[^>]*>(?:\s*<td[^>]*>([^<]*)</td>\s*){4}',
      caseSensitive: false,
      dotAll: true,
    );
    final cellPattern = RegExp(
      r'<td[^>]*>\s*([^<]*)\s*</td>',
      caseSensitive: false,
    );

    for (final rowMatch in rowPattern.allMatches(html)) {
      final cells = cellPattern
          .allMatches(rowMatch.group(0) ?? '')
          .map((m) => m.group(1)?.trim() ?? '')
          .toList();

      if (cells.length >= 4) {
        final idDepto = int.tryParse(cells[0]);
        final edificio = cells[3]; // columna 4 = edificio
        if (idDepto != null && edificio.isNotEmpty) {
          result[edificio] = idDepto;
        }
      }
    }
    return result;
  }

  /// Parsea la lista HTML de puestos para extraer [id_departamento → correoPuesto].
  ///
  /// Busca el patrón de email en las celdas de la tabla de puestos.
  /// AJUSTAR según la respuesta real del SAM del ITT.
  Map<int, String> _parsePuestosHtml(String html) {
    final result = <int, String>{};

    // Patrón para buscar correos en celdas de tabla de puestos.
    // Asume que el correo tiene formato email estándar en una celda td.
    final emailInCellPattern = RegExp(
      r'<td[^>]*>\s*([a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})\s*</td>',
      caseSensitive: false,
    );
    // Patrón para id_departamento en la fila (asume columna 4).
    final rowWithEmailPattern = RegExp(
      r'<tr[^>]*>(.*?)</tr>',
      caseSensitive: false,
      dotAll: true,
    );
    final cellPattern = RegExp(
      r'<td[^>]*>\s*([^<]*)\s*</td>',
      caseSensitive: false,
    );

    for (final rowMatch in rowWithEmailPattern.allMatches(html)) {
      final rowHtml = rowMatch.group(1) ?? '';
      if (!emailInCellPattern.hasMatch(rowHtml)) continue;

      final cells = cellPattern
          .allMatches(rowHtml)
          .map((m) => m.group(1)?.trim() ?? '')
          .toList();

      // Estructura asumida: id_puesto | nombre | dependecia | id_departamento | correoPuesto
      if (cells.length >= 5) {
        final idDepto = int.tryParse(cells[3]);
        final correo = cells[4];
        if (idDepto != null &&
            correo.contains('@') &&
            !result.containsKey(idDepto)) {
          result[idDepto] = correo;
        }
      }
    }
    return result;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final samDepartamentoServiceProvider = Provider<SamDepartamentoService>((ref) {
  return SamDepartamentoService(ref.watch(httpServiceProvider));
});
