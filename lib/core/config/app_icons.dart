/// @file: app_icons.dart
/// @project: ControlAcceso - G.A.M.A.
/// @description: Catálogo centralizado de íconos institucionales basado en
///   Font Awesome Flutter. Toda vista del sistema debe consumir íconos
///   exclusivamente a través de esta clase. Queda prohibido referenciar
///   FontAwesomeIcons directamente en las vistas.
///   Referencia: Sección 5.2.4 / Tabla 10 del Manual de Programación Flutter.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-07

library;

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Catálogo de íconos estándar del sistema — GAMA MPF v1.0.
///
/// Clase de solo constantes. No debe instanciarse.
/// Referencia: Sección 5.2.4 / Tabla 10 del Manual de Programación Flutter.
class AppIcons {
  AppIcons._();

  // ── Navegación ───────────────────────────────────────────────────────────

  static const home = FontAwesomeIcons.house;
  static const back = FontAwesomeIcons.arrowLeft;
  static const close = FontAwesomeIcons.xmark;
  static const menu = FontAwesomeIcons.bars;
  static const chevronRight = FontAwesomeIcons.chevronRight;
  static const moreVert = FontAwesomeIcons.ellipsisVertical;

  // ── Autenticación ────────────────────────────────────────────────────────

  static const user = FontAwesomeIcons.user;
  static const lock = FontAwesomeIcons.lock;
  static const eye = FontAwesomeIcons.eye;
  static const eyeSlash = FontAwesomeIcons.eyeSlash;
  static const gear = FontAwesomeIcons.gear;
  static const phone = FontAwesomeIcons.mobileScreenButton;

  // ── Acciones generales ───────────────────────────────────────────────────

  static const add = FontAwesomeIcons.plus;
  static const edit = FontAwesomeIcons.pen;
  static const trash = FontAwesomeIcons.trash;
  static const send = FontAwesomeIcons.paperPlane;
  static const refresh = FontAwesomeIcons.rotateRight;
  static const search = FontAwesomeIcons.magnifyingGlass;
  static const filter = FontAwesomeIcons.filter;

  // ── Estados / Validación ─────────────────────────────────────────────────

  static const circleCheck = FontAwesomeIcons.circleCheck;
  static const circleXmark = FontAwesomeIcons.circleXmark;
  static const circleInfo = FontAwesomeIcons.circleInfo;
  static const triangle = FontAwesomeIcons.triangleExclamation;
  static const ban = FontAwesomeIcons.ban;

  // ── Datos / Formularios ──────────────────────────────────────────────────

  static const calendar = FontAwesomeIcons.calendar;
  static const clock = FontAwesomeIcons.clock;
  static const building = FontAwesomeIcons.building;
  static const email = FontAwesomeIcons.envelope;
  static const hashtag = FontAwesomeIcons.hashtag;
  static const users = FontAwesomeIcons.users;
  static const usersLine = FontAwesomeIcons.usersLine;
  static const person = FontAwesomeIcons.person;
  static const doorOpen = FontAwesomeIcons.doorOpen;

  // ── Notificaciones ───────────────────────────────────────────────────────

  static const bell = FontAwesomeIcons.bell;

  // ── QR / Escaneo ─────────────────────────────────────────────────────────

  static const qrcode = FontAwesomeIcons.qrcode;
  static const barcode = FontAwesomeIcons.barcode;

  // ── Acceso / Puertas ─────────────────────────────────────────────────────

  static const doorEnter = FontAwesomeIcons.rightToBracket;
  static const doorExit = FontAwesomeIcons.rightFromBracket;
  static const personWalking = FontAwesomeIcons.personWalking;
  static const clockRotateLeft = FontAwesomeIcons.clockRotateLeft;
  static const hourglassHalf = FontAwesomeIcons.hourglassHalf;

  // ── Roles específicos de Control de Accesos ──────────────────────────────

  static const guardia = FontAwesomeIcons.shieldHalved;
  static const anfitrion = FontAwesomeIcons.userCheck;
  static const autorizador = FontAwesomeIcons.inbox;
  static const empleado = FontAwesomeIcons.user;
  static const listVisitas = FontAwesomeIcons.listCheck;
}
