import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../analytics/app_telemetry_service.dart';
import '../models/classroom_models.dart';

class MonitorExceptionsView extends StatelessWidget {
  const MonitorExceptionsView({super.key, required this.dashboard});

  static const actionableCodes = {
    'inactive_7_days',
    'required_activity_pending',
    'below_expected_hours',
  };

  final ClassroomDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final students = dashboard.students;
    final attention = students
        .where(
          (student) => student.alerts.any(
            (alert) => actionableCodes.contains(alert.code),
          ),
        )
        .toList(growable: false);
    final normal = students.length - attention.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Monitor por exceção',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Veja somente sinais que precisam de acompanhamento. Eles não são veredictos sobre o participante.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatusMetric(
              label: 'Percurso normal',
              value: normal,
              icon: Icons.check_circle_outline,
              attention: false,
            ),
            _StatusMetric(
              label: 'Precisam de atenção',
              value: attention.length,
              icon: Icons.warning_amber_rounded,
              attention: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card.filled(
          child: const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Acompanhamento sem ações simuladas'),
            subtitle: Text(
              'Mensagem e marcar como resolvido dependem de contratos de comunicação e resolução ainda não disponíveis. Use os detalhes autorizados para orientar o acompanhamento.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Exceções acionáveis',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (attention.isEmpty)
          const Card.outlined(
            child: ListTile(
              leading: Icon(Icons.task_alt),
              title: Text('Nenhum alerta acionável agora'),
              subtitle: Text(
                'Todos os participantes seguem sem sinais de inatividade, pendência obrigatória ou carga abaixo do esperado.',
              ),
            ),
          )
        else
          for (final student in attention)
            _MonitorStudentCard(student: student),
        const SizedBox(height: 12),
        Text(
          'Atualizado em ${_dateTime(dashboard.generatedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.attention,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = attention ? colors.error : colors.primary;
    return SizedBox(
      width: 190,
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonitorStudentCard extends StatelessWidget {
  const _MonitorStudentCard({required this.student});

  final ClassroomStudent student;

  void _trackDetails(BuildContext context, bool expanded) {
    if (!expanded) return;
    Provider.of<AppTelemetryService?>(
      context,
      listen: false,
    )?.trackFeature(featureId: 'monitor_student_details');
  }

  @override
  Widget build(BuildContext context) {
    final alerts = student.alerts
        .where(
          (alert) => MonitorExceptionsView.actionableCodes.contains(alert.code),
        )
        .toList(growable: false);
    return Card(
      child: ExpansionTile(
        onExpansionChanged: (expanded) => _trackDetails(context, expanded),
        leading: CircleAvatar(child: Text(_initials(student.name))),
        title: Text(student.name),
        subtitle: Text(
          '${alerts.length} sinal(is) acionável(is) • ${student.progressPercent.toStringAsFixed(0)}% do percurso',
        ),
        trailing: Badge(
          label: Text('${alerts.length}'),
          child: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Detalhes autorizados',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
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
                Text('Matrícula interna: ${student.enrollmentId}'),
                const SizedBox(height: 10),
                for (final alert in alerts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _alertIcon(alert.code),
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_alertLabel(alert.code))),
                      ],
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

IconData _alertIcon(String code) => switch (code) {
  'inactive_7_days' => Icons.snooze_outlined,
  'required_activity_pending' => Icons.pending_actions_outlined,
  'below_expected_hours' => Icons.trending_down,
  _ => Icons.info_outline,
};

String _alertLabel(String code) => switch (code) {
  'inactive_7_days' => 'Sem atividade há 7 dias ou mais',
  'required_activity_pending' => 'Atividade obrigatória pendente',
  'below_expected_hours' => 'Carga horária abaixo do esperado',
  _ => 'Sinal pedagógico',
};

String _hours(double value) =>
    '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} h';

String _dateTime(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
      'às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'
      .toUpperCase();
}
