import 'package:flutter/material.dart';

import '../../auth/models/auth_session.dart';
import '../application/team_capability.dart';
import '../data/classroom_repository.dart';
import '../models/classroom_models.dart';
import '../../evidence/data/evidence_repository.dart';
import '../../evidence/presentation/evidence_staff_screen.dart';
import '../../analytics/telemetry_route.dart';
import 'monitor_exceptions_view.dart';

class ClassroomDashboardScreen extends StatefulWidget {
  const ClassroomDashboardScreen({
    super.key,
    required this.gateway,
    this.evidenceGateway,
  });

  final ClassroomGateway gateway;
  final EvidenceGateway? evidenceGateway;

  @override
  State<ClassroomDashboardScreen> createState() =>
      _ClassroomDashboardScreenState();
}

class _ClassroomDashboardScreenState extends State<ClassroomDashboardScreen> {
  AuthUser? _user;
  List<ClassroomDetails> _classes = const [];
  Map<String, ClassroomStaffCapability> _capabilities = const {};
  ClassroomDashboard? _dashboard;
  UsageSummary? _usage;
  String? _selectedClassId;
  String? _error;
  String? _usageWarning;
  bool _loading = true;
  int _days = 30;

  // O papel global não é autoridade: vínculos por programa/turma podem
  // conceder capacidade de professor ou monitor a uma conta `student`.
  bool get _hasOnlineAccount => _user != null;
  ClassroomStaffCapability? get _selectedCapability =>
      _capabilities[_selectedClassId];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    final gateway = widget.gateway;
    if (gateway is ClassroomRepository) gateway.dispose();
    final evidenceGateway = widget.evidenceGateway;
    if (evidenceGateway is EvidenceRepository) evidenceGateway.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final snapshot = await TeamCapabilityResolver(widget.gateway).resolve();
      if (!mounted) return;
      _user = snapshot.user;
      _classes = snapshot.classrooms;
      _capabilities = snapshot.capabilities;
      if (_classes.isNotEmpty) {
        _selectedClassId = _classes.first.id;
        await _loadDashboard(showProgress: false);
      }
    } on Object catch (error) {
      if (mounted) _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDashboard({bool showProgress = true}) async {
    final classId = _selectedClassId;
    if (classId == null) return;
    if (showProgress) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final dashboard = await widget.gateway.dashboard(classId);
      UsageSummary usage;
      String? usageWarning;
      if (_capabilities[classId] == ClassroomStaffCapability.monitor) {
        final now = DateTime.now();
        usage = UsageSummary(
          periodStart: now.subtract(Duration(days: _days)),
          periodEnd: now,
          items: const [],
        );
      } else {
        try {
          usage = await widget.gateway.usage(classId, days: _days);
        } on Object {
          final now = DateTime.now();
          usage = UsageSummary(
            periodStart: now.subtract(Duration(days: _days)),
            periodEnd: now,
            items: const [],
          );
          usageWarning =
              'Analytics de recursos temporariamente indisponível. O progresso pedagógico continua atualizado.';
        }
      }
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _usage = usage;
        _usageWarning = usageWarning;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _dashboard = null;
        _usage = null;
        _usageWarning = null;
        _error = error.toString();
      });
    } finally {
      if (showProgress && mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedCapability == ClassroomStaffCapability.monitor
              ? 'Monitor por exceção'
              : 'Área da equipe',
        ),
      ),
      body: _loading && _user == null
          ? const Center(child: CircularProgressIndicator())
          : !_hasOnlineAccount
          ? _AccessMessage(error: _error, user: _user)
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    _selectedCapability == ClassroomStaffCapability.monitor
                        ? 'Acompanhamento acionável'
                        : 'Acompanhamento de turma',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedCapability == ClassroomStaffCapability.monitor
                        ? 'Priorize participantes com sinais reais de atenção, sem expor dados além do seu vínculo.'
                        : 'Progresso, alertas pedagógicos, carga horária e uso dos recursos em um só lugar.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_classes.isEmpty && _error == null)
                    const _EmptyCard(
                      message: 'Nenhuma turma está vinculada à sua conta.',
                    )
                  else if (_classes.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Turma',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      items: _classes
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() => _selectedClassId = value);
                              _loadDashboard();
                            },
                    ),
                    const SizedBox(height: 12),
                    if (_selectedCapability == ClassroomStaffCapability.teacher)
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _days,
                        decoration: const InputDecoration(
                          labelText: 'Período de uso dos recursos',
                        ),
                        items: const [
                          DropdownMenuItem(value: 7, child: Text('7 dias')),
                          DropdownMenuItem(value: 30, child: Text('30 dias')),
                          DropdownMenuItem(value: 90, child: Text('90 dias')),
                        ],
                        onChanged: _loading
                            ? null
                            : (value) {
                                setState(() => _days = value ?? 30);
                                _loadDashboard();
                              },
                      ),
                    if (widget.evidenceGateway != null &&
                        _selectedCapability ==
                            ClassroomStaffCapability.teacher &&
                        _dashboard != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _loading
                              ? null
                              : () => Navigator.push(
                                  context,
                                  trackedRoute(
                                    pageId: 'evidence_cockpit',
                                    courseId: _dashboard!.classroom.courseId,
                                    resourceId: 'class_session',
                                    featureId: 'evidence_engine',
                                    builder: (_) => EvidenceStaffScreen(
                                      classroom: _dashboard!.classroom,
                                      gateway: widget.evidenceGateway!,
                                    ),
                                  ),
                                ),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Presença, QR e evidências'),
                        ),
                      ),
                    ],
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorCard(message: _error!),
                  ],
                  if (_dashboard != null && _usage != null) ...[
                    const SizedBox(height: 20),
                    if (_selectedCapability == ClassroomStaffCapability.monitor)
                      MonitorExceptionsView(dashboard: _dashboard!)
                    else
                      _Dashboard(
                        dashboard: _dashboard!,
                        usage: _usage!,
                        usageWarning: _usageWarning,
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _AccessMessage extends StatelessWidget {
  const _AccessMessage({required this.error, required this.user});
  final String? error;
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final restricted = user != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              restricted ? Icons.lock_outline : Icons.cloud_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              restricted ? 'Área restrita à equipe' : 'Conta online necessária',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error ??
                  'O painel está disponível para professores, monitores e administradores vinculados.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.dashboard,
    required this.usage,
    required this.usageWarning,
  });
  final ClassroomDashboard dashboard;
  final UsageSummary usage;
  final String? usageWarning;

  @override
  Widget build(BuildContext context) {
    final classroom = dashboard.classroom;
    final topItems = [...usage.items]
      ..sort((a, b) => b.count.compareTo(a.count));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classroom.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Curso ${classroom.courseId} • ${_status(classroom.status)}',
                ),
                Text(
                  '${_date(classroom.startDate)} a ${_date(classroom.endDate)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric(
              label: 'Participantes',
              value: '${dashboard.summary.totalStudents}',
              icon: Icons.people_outline,
            ),
            _Metric(
              label: 'Inativos',
              value: '${dashboard.summary.inactiveStudents}',
              icon: Icons.snooze_outlined,
              alert: dashboard.summary.inactiveStudents > 0,
            ),
            _Metric(
              label: 'Com pendências',
              value: '${dashboard.summary.pendingStudents}',
              icon: Icons.pending_actions_outlined,
              alert: dashboard.summary.pendingStudents > 0,
            ),
            _Metric(
              label: 'Abaixo do esperado',
              value: '${dashboard.summary.belowExpectedStudents}',
              icon: Icons.trending_down,
              alert: dashboard.summary.belowExpectedStudents > 0,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Progresso esperado hoje: ${dashboard.expectedProgressPercent.toStringAsFixed(0)}%',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Text('Participantes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (dashboard.students.isEmpty)
          const _EmptyCard(message: 'Nenhum participante ativo nesta turma.')
        else
          ...dashboard.students.map(
            (student) => _StudentTile(student: student),
          ),
        const SizedBox(height: 24),
        Text(
          'Recursos mais usados',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (usageWarning != null) ...[
          _EmptyCard(message: usageWarning!),
          const SizedBox(height: 8),
        ],
        if (topItems.isEmpty)
          const _EmptyCard(
            message: 'Ainda não há uso registrado neste período.',
          )
        else
          ...topItems
              .take(8)
              .map(
                (item) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${item.count}')),
                    title: Text(_targetLabel(item.targetId)),
                    subtitle: Text(
                      '${_eventLabel(item.eventType)} • ${item.uniqueUsers} participante(s)',
                    ),
                    trailing: Text(_date(item.lastOccurredAt)),
                  ),
                ),
              ),
        const SizedBox(height: 12),
        Text(
          'Atualizado em ${_dateTime(dashboard.generatedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});
  final ClassroomStudent student;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(_initials(student.name))),
        title: Text(student.name),
        subtitle: Text(
          '${student.progressPercent.toStringAsFixed(0)}% • ${_hours(student.validatedHours)} validadas',
        ),
        trailing: student.alerts.isEmpty
            ? const Icon(Icons.check_circle_outline, color: Colors.green)
            : Badge(
                label: Text('${student.alerts.length}'),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label:
                      'Progresso de ${student.progressPercent.toStringAsFixed(0)} por cento',
                  child: LinearProgressIndicator(value: student.completion),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_hours(student.validatedHours)} validadas de ${_hours(student.plannedHours)} planejadas',
                ),
                Text(
                  student.lastActivityAt == null
                      ? 'Sem atividade registrada'
                      : 'Última atividade: ${_dateTime(student.lastActivityAt!)}',
                ),
                if (student.alerts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: student.alerts
                        .map(
                          (alert) => Chip(
                            avatar: const Icon(Icons.info_outline, size: 18),
                            label: Text(_alertLabel(alert.code)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.alert = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 154,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _dateTime(DateTime date) =>
    '${_date(date.toLocal())} às ${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}';
String _hours(double value) =>
    '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} h';
String _status(String status) => switch (status) {
  'active' => 'Ativa',
  'closed' => 'Encerrada',
  _ => 'Planejada',
};
String _eventLabel(String type) => switch (type) {
  'page_viewed' => 'Página visualizada',
  'resource_opened' => 'Recurso aberto',
  'feature_used' => 'Funcionalidade usada',
  _ => type,
};
String _alertLabel(String code) => switch (code) {
  'inactive_7_days' => 'Sem atividade há 7 dias',
  'required_activity_pending' => 'Atividade obrigatória pendente',
  'below_expected_hours' => 'Carga horária abaixo do esperado',
  _ => 'Atenção pedagógica',
};
String _targetLabel(String target) => target
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return '$first$last'.toUpperCase();
}
