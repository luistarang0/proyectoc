/// @file: home_empleado_view.dart
/// @project: Control de Accesos - GAMA
/// @description: Vista principal del rol Empleado. Gestiona la navegación
///   entre tabs (solicitudes, visitantes, nueva solicitud y perfil) mediante
///   un [IndexedStack] y un [BottomNavigationBar].
///   Referencia: RF-17 / RF-01.
/// @author: Jesús David Johnson Soto
/// @version: 1.0.0
/// @last_update: 2026-05-26

library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_icons.dart';
import '../../../../core/config/app_spacing.dart';
import '../../../../core/config/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../model/solicitud_model.dart';
import '../../model/visitante_model.dart';

// ── Extensión de presentación sobre EstatusVisitante (perspectiva Empleado)

extension _EstatusEmpleadoExt on EstatusVisitante {
  String get label => switch (this) {
    EstatusVisitante.enEspera => 'Esperando llegada',
    EstatusVisitante.enInstituto => 'Llegó al instituto',
    EstatusVisitante.enOficina => 'En tu oficina',
    EstatusVisitante.salidoOficina => 'Salió de tu oficina',
    EstatusVisitante.salidoInstituto => 'Salió del instituto',
  };

  Color get color => switch (this) {
    EstatusVisitante.enEspera => AppColors.iconGray,
    EstatusVisitante.enInstituto => AppColors.warning,
    EstatusVisitante.enOficina => AppColors.success,
    EstatusVisitante.salidoOficina => AppColors.info,
    EstatusVisitante.salidoInstituto => AppColors.borderGray,
  };

  IconData get icon => switch (this) {
    EstatusVisitante.enEspera => AppIcons.clock,
    EstatusVisitante.enInstituto => AppIcons.doorOpen,
    EstatusVisitante.enOficina => AppIcons.building,
    EstatusVisitante.salidoOficina => AppIcons.circleInfo,
    EstatusVisitante.salidoInstituto => AppIcons.circleCheck,
  };
}

// ── Extensión de presentación sobre EstadoSolicitud (perspectiva Empleado)

extension _EstadoEmpleadoExt on EstadoSolicitud {
  Color get color => switch (this) {
    EstadoSolicitud.aprobada => AppColors.success,
    EstadoSolicitud.rechazada => AppColors.error,
    EstadoSolicitud.pendiente => AppColors.warning,
    EstadoSolicitud.cancelada => AppColors.iconGray,
    EstadoSolicitud.vencida => AppColors.iconGray,
  };

  String get label => switch (this) {
    EstadoSolicitud.aprobada => 'Aprobada',
    EstadoSolicitud.rechazada => 'Rechazada',
    EstadoSolicitud.pendiente => 'Pendiente',
    EstadoSolicitud.cancelada => 'Cancelada',
    EstadoSolicitud.vencida => 'Vencida',
  };

  IconData get icon => switch (this) {
    EstadoSolicitud.aprobada => AppIcons.circleCheck,
    EstadoSolicitud.rechazada => AppIcons.circleXmark,
    EstadoSolicitud.pendiente => AppIcons.clock,
    EstadoSolicitud.cancelada => AppIcons.ban,
    EstadoSolicitud.vencida => AppIcons.triangle,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// VISTA PRINCIPAL — HomeEmpleadoView
// ═══════════════════════════════════════════════════════════════════════════

/// Vista raíz del rol Empleado.
///
/// Administra cuatro secciones mediante [IndexedStack]:
///   0 — Mis solicitudes
///   1 — Mis visitantes
///   2 — Nueva solicitud
///   3 — Perfil
class HomeEmpleadoView extends StatefulWidget {
  const HomeEmpleadoView({super.key});

  @override
  State<HomeEmpleadoView> createState() => _HomeEmpleadoViewState();
}

class _HomeEmpleadoViewState extends State<HomeEmpleadoView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        title: const Text('Mi Espacio'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.bell, size: 18),
            onPressed: () {},
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 18),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _TabMisSolicitudes(),
          _TabMisVisitantes(),
          _TabNuevaSolicitud(),
          _TabPerfil(),
        ],
      ),
      floatingActionButton: (_selectedIndex == 0 || _selectedIndex == 1)
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _selectedIndex = 2),
              backgroundColor: AppColors.primary,
              icon: const FaIcon(
                FontAwesomeIcons.plus,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                'Nueva visita',
                style: AppTextStyles.button.copyWith(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.listCheck, size: 17),
            label: 'Solicitudes',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.usersLine, size: 17),
            label: 'Mis visitantes',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.plus, size: 17),
            label: 'Nueva',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.user, size: 17),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 0 — Mis solicitudes de visita
// ═══════════════════════════════════════════════════════════════════════════

/// Tab que lista las solicitudes de visita realizadas por el Empleado.
class _TabMisSolicitudes extends StatelessWidget {
  const _TabMisSolicitudes();

  // TODO: reemplazar con datos del repositorio de solicitudes.
  static const _solicitudes = [
    SolicitudModel(
      visitante: 'Carlos Mejía',
      solicitante: 'SoftTech S.A.',
      area: 'Sala de Juntas A',
      fecha: 'Hoy',
      hora: '10:00',
      motivo: 'Reunión de proyecto',
      estado: EstadoSolicitud.pendiente,
    ),
    SolicitudModel(
      visitante: 'Laura Torres',
      solicitante: 'Auditores MX',
      area: 'Sala de Cómputo B',
      fecha: 'Ayer',
      hora: '14:00',
      motivo: 'Revisión de contratos',
      estado: EstadoSolicitud.aprobada,
    ),
    SolicitudModel(
      visitante: 'Roberto Fuentes',
      solicitante: 'IndTec',
      area: 'Rectoría',
      fecha: '07/04',
      hora: '09:00',
      motivo: 'Capacitación',
      estado: EstadoSolicitud.rechazada,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.screenH,
        AppSpacing.screenH,
        80,
      ),
      itemCount: _solicitudes.length + 1,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppSpacing.listItemGap),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('Mis solicitudes', style: AppTextStyles.subtitle),
          );
        }

        return _SolicitudEmpleadoCard(solicitud: _solicitudes[i - 1]);
      },
    );
  }
}

/// Tarjeta de una solicitud de visita (perspectiva Empleado).
class _SolicitudEmpleadoCard extends StatelessWidget {
  const _SolicitudEmpleadoCard({required this.solicitud});

  final SolicitudModel solicitud;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = solicitud.estado.color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.appBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.iceBlue,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Center(
              child: FaIcon(AppIcons.person, size: 20, color: AppColors.tertiary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(solicitud.visitante, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text(solicitud.solicitante, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const FaIcon(
                      AppIcons.clock,
                      size: 10,
                      color: AppColors.iconGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${solicitud.fecha} ${solicitud.hora}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(solicitud.estado.icon, size: 10, color: badgeColor),
                const SizedBox(width: 4),
                Text(
                  solicitud.estado.label,
                  style: AppTextStyles.caption.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
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
// TAB 2 — Nueva solicitud de visita (RF-01)
// ═══════════════════════════════════════════════════════════════════════════

/// Tab con el formulario para registrar una nueva solicitud de visita.
class _TabNuevaSolicitud extends StatefulWidget {
  const _TabNuevaSolicitud();

  @override
  State<_TabNuevaSolicitud> createState() => _TabNuevaSolicitudState();
}

/// Encapsula los controladores de texto de una persona adicional en la visita.
class _PersonaAdicional {
  _PersonaAdicional()
    : nombreCtrl = TextEditingController(),
      correoCtrl = TextEditingController();

  final TextEditingController nombreCtrl;
  final TextEditingController correoCtrl;

  /// Libera los recursos de los controladores.
  void dispose() {
    nombreCtrl.dispose();
    correoCtrl.dispose();
  }
}

class _TabNuevaSolicitudState extends State<_TabNuevaSolicitud> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();

  bool _isLoading = false;
  final List<_PersonaAdicional> _personasAdicionales = [];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _motivoCtrl.dispose();
    _fechaCtrl.dispose();
    _horaCtrl.dispose();
    for (final p in _personasAdicionales) {
      p.dispose();
    }
    super.dispose();
  }

  void _agregarPersona() {
    setState(() => _personasAdicionales.add(_PersonaAdicional()));
  }

  void _eliminarPersona(int index) {
    setState(() {
      _personasAdicionales[index].dispose();
      _personasAdicionales.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nueva solicitud de visita', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Completa los datos del visitante principal.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.blockGap),

            Text('Visitante principal', style: AppTextStyles.fieldLabel),
            const SizedBox(height: AppSpacing.sm),

            AppTextField(
              label: 'Nombre completo',
              hint: 'Nombre del visitante',
              controller: _nombreCtrl,
              prefixIcon: AppIcons.person,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: AppSpacing.elementGap),

            AppTextField(
              label: 'Correo electrónico',
              hint: 'correo@ejemplo.com',
              controller: _correoCtrl,
              prefixIcon: AppIcons.email,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Campo requerido';
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.elementGap),

            AppTextField(
              label: 'Fecha de visita',
              hint: 'DD/MM/AAAA',
              controller: _fechaCtrl,
              prefixIcon: AppIcons.calendar,
              readOnly: true,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Selecciona una fecha'
                  : null,
              onTap: () => _pickDate(context),
            ),
            const SizedBox(height: AppSpacing.elementGap),

            AppTextField(
              label: 'Hora estimada',
              hint: 'HH:MM',
              controller: _horaCtrl,
              prefixIcon: AppIcons.clock,
              readOnly: true,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Selecciona una hora'
                  : null,
              onTap: () => _pickTime(context),
            ),
            const SizedBox(height: AppSpacing.elementGap),

            AppTextField(
              label: 'Motivo de la visita',
              hint: 'Describe brevemente el propósito...',
              controller: _motivoCtrl,
              prefixIcon: AppIcons.circleInfo,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: AppSpacing.blockGap),

            // ── Personas adicionales ─────────────────────────────
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personas adicionales',
                      style: AppTextStyles.fieldLabel,
                    ),
                    Text(
                      '${_personasAdicionales.length} persona(s) añadida(s)',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _agregarPersona,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.plus,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Añadir persona',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_personasAdicionales.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ..._personasAdicionales.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PersonaCard(
                    persona: p,
                    numero: i + 1,
                    onEliminar: () => _eliminarPersona(i),
                  ),
                );
              }),
            ],

            const SizedBox(height: AppSpacing.blockGap),
            PrimaryButton(
              label: 'Enviar solicitud',
              isLoading: _isLoading,
              isEnabled: !_isLoading,
              icon: _isLoading
                  ? null
                  : const FaIcon(
                      FontAwesomeIcons.paperPlane,
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

  /// Muestra el selector de fecha y actualiza [_fechaCtrl].
  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date != null) {
      _fechaCtrl.text =
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }
  }

  /// Muestra el selector de hora y actualiza [_horaCtrl].
  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null && context.mounted) {
      _horaCtrl.text =
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Valida el formulario y envía la solicitud (RF-01).
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // TODO: llamar a repositorio de solicitudes (RF-01).
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isLoading = false);

    final total = 1 + _personasAdicionales.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Solicitud enviada para $total persona(s)'),
        backgroundColor: AppColors.success,
      ),
    );

    _formKey.currentState!.reset();
    _nombreCtrl.clear();
    _correoCtrl.clear();
    _motivoCtrl.clear();
    _fechaCtrl.clear();
    _horaCtrl.clear();
    for (final p in _personasAdicionales) {
      p.dispose();
    }
    setState(() => _personasAdicionales.clear());
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENTE — Tarjeta de persona adicional
// ═══════════════════════════════════════════════════════════════════════════

/// Tarjeta de captura de datos para un acompañante dentro de una solicitud.
class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.persona,
    required this.numero,
    required this.onEliminar,
  });

  final _PersonaAdicional persona;
  final int numero;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.iceBlue,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$numero',
                        style: AppTextStyles.captionBold.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Persona adicional',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onEliminar,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const FaIcon(
                    AppIcons.trash,
                    size: 13,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Nombre completo',
            hint: 'Nombre del acompañante',
            controller: persona.nombreCtrl,
            prefixIcon: AppIcons.person,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
          ),
          const SizedBox(height: AppSpacing.elementGap),
          AppTextField(
            label: 'Correo electrónico',
            hint: 'correo@ejemplo.com',
            controller: persona.correoCtrl,
            prefixIcon: AppIcons.email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              if (!v.contains('@')) return 'Correo inválido';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — Mis visitantes (perspectiva del Empleado)
// ═══════════════════════════════════════════════════════════════════════════

/// Tab que muestra los visitantes asignados al Empleado en el día actual
/// y permite confirmar su llegada o salida de la oficina.
class _TabMisVisitantes extends StatefulWidget {
  const _TabMisVisitantes();

  @override
  State<_TabMisVisitantes> createState() => _TabMisVisitantesState();
}

class _TabMisVisitantesState extends State<_TabMisVisitantes> {
  // TODO: reemplazar con datos del repositorio filtrado por empleado actual.
  final List<VisitanteModel> _visitantes = [
    const VisitanteModel(
      id: 'VIS-001',
      nombre: 'Carlos Mejía Hernández',
      destino: 'Mi oficina',
      horaEstimada: '08:30',
      correo: 'carlos.mejia@softtech.com',
      estatus: EstatusVisitante.enInstituto,
    ),
    const VisitanteModel(
      id: 'VIS-002',
      nombre: 'Andrea Ríos Castillo',
      destino: 'Mi oficina',
      horaEstimada: '10:00',
      correo: 'andrea.rios@indtech.mx',
      estatus: EstatusVisitante.enEspera,
    ),
    const VisitanteModel(
      id: 'VIS-003',
      nombre: 'Pedro Sánchez Vargas',
      destino: 'Mi oficina',
      horaEstimada: '09:15',
      correo: 'pedro.sv@outlook.com',
      estatus: EstatusVisitante.salidoInstituto,
    ),
  ];

  void _confirmarLlegadaOficina(VisitanteModel v) {
    setState(() {
      final index = _visitantes.indexOf(v);
      _visitantes[index] = v.copyWith(
        estatus: EstatusVisitante.enOficina,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${v.nombre} llegó a tu oficina'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _confirmarSalidaOficina(VisitanteModel v) {
    setState(() {
      final index = _visitantes.indexOf(v);
      _visitantes[index] = v.copyWith(
        estatus: EstatusVisitante.salidoOficina,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${v.nombre} salió de tu oficina — sigue en el instituto',
        ),
        backgroundColor: AppColors.info,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_visitantes.isEmpty) {
      return const EmptyState(
        icon: AppIcons.users,
        label: 'No tienes visitantes hoy',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      itemCount: _visitantes.length + 1,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppSpacing.listItemGap),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mis visitantes de hoy', style: AppTextStyles.subtitle),
                const SizedBox(height: 2),
                Text(
                  'Confirma la llegada a tu oficina y su salida.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          );
        }

        final v = _visitantes[i - 1];
        return _VisitanteEmpCard(
          visitante: v,
          onLlegadaOficina: v.estatus == EstatusVisitante.enInstituto
              ? () => _confirmarLlegadaOficina(v)
              : null,
          onSalidaOficina: v.estatus == EstatusVisitante.enOficina
              ? () => _confirmarSalidaOficina(v)
              : null,
        );
      },
    );
  }
}

/// Tarjeta que presenta el estado de un visitante y las acciones disponibles.
class _VisitanteEmpCard extends StatelessWidget {
  const _VisitanteEmpCard({
    required this.visitante,
    this.onLlegadaOficina,
    this.onSalidaOficina,
  });

  final VisitanteModel visitante;
  final VoidCallback? onLlegadaOficina;
  final VoidCallback? onSalidaOficina;

  @override
  Widget build(BuildContext context) {
    final est = visitante.estatus;
    final color = est.color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.appBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: FaIcon(AppIcons.person, size: 22, color: color),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visitante.nombre, style: AppTextStyles.bodyBold),
                    const SizedBox(height: 2),
                    if (visitante.correo != null)
                      Row(
                        children: [
                          FaIcon(
                            AppIcons.email,
                            size: 10,
                            color: AppColors.iconGray,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              visitante.correo!,
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        FaIcon(
                          AppIcons.clock,
                          size: 10,
                          color: AppColors.iconGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Estimada: ${visitante.horaEstimada}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(est.icon, size: 10, color: color),
                    const SizedBox(width: 3),
                    Text(
                      est.label,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (onLlegadaOficina != null || onSalidaOficina != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
          ],

          if (onLlegadaOficina != null)
            _BtnEmp(
              label: 'Llegó a mi oficina',
              icon: AppIcons.building,
              color: AppColors.success,
              onTap: onLlegadaOficina!,
            ),

          if (onSalidaOficina != null)
            _BtnEmp(
              label: 'Salió de mi oficina',
              icon: AppIcons.personWalking,
              color: AppColors.info,
              onTap: onSalidaOficina!,
            ),

          if (est == EstatusVisitante.salidoOficina) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  FaIcon(AppIcons.circleInfo, size: 11, color: AppColors.info),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Salió de tu oficina — sigue en el instituto',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (est == EstatusVisitante.salidoInstituto) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                FaIcon(
                  AppIcons.circleCheck,
                  size: 12,
                  color: AppColors.iconGray,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Salió del instituto',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.iconGray,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón de acción estilizado para las interacciones del Empleado.
class _BtnEmp extends StatelessWidget {
  const _BtnEmp({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.sm),
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

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — Perfil del empleado
// ═══════════════════════════════════════════════════════════════════════════

/// Tab que presenta la información de perfil y el resumen de solicitudes
/// del Empleado autenticado.
class _TabPerfil extends StatelessWidget {
  const _TabPerfil();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.mistBlue,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: const Center(
                child: FaIcon(AppIcons.user, size: 40, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Juan García Hernández',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Empleado · Depto. Sistemas',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.blockGap),
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.iceBlue,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: Column(
              children: [
                _ProfileRow(
                  icon: AppIcons.email,
                  label: 'juan.garcia@itt.edu.mx',
                ),
                const Divider(height: AppSpacing.blockGap),
                _ProfileRow(
                  icon: AppIcons.building,
                  label: 'Instituto Tecnológico de Toluca',
                ),
                const Divider(height: AppSpacing.blockGap),
                _ProfileRow(
                  icon: AppIcons.phone,
                  label: '+52 722 000 0000',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.blockGap),
          Text('Resumen de solicitudes', style: AppTextStyles.fieldLabel),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: const [
              Expanded(
                child: _StatCard(
                  label: 'Total',
                  value: '3',
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: 'Aprobadas',
                  value: '1',
                  color: AppColors.success,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: 'Pendientes',
                  value: '1',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila de dato de perfil con icono y etiqueta de texto.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FaIcon(icon, size: 15, color: AppColors.secondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de estadística con valor numérico destacado y etiqueta.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.title.copyWith(color: color, fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
