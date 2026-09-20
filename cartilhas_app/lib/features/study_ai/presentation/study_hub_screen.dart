import 'package:flutter/material.dart';

import '../../../models/cartilha.dart';
import '../../../screens/genui_assistant_screen.dart';
import 'assessment_screen.dart';
import 'flashcards_screen.dart';
import 'summary_screen.dart';
import '../../analytics/telemetry_route.dart';

class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({super.key, required this.cartilhas});

  final List<Cartilha> cartilhas;

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  late Cartilha _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.cartilhas.first;
  }

  void _open({
    required Widget screen,
    required String pageId,
    required String resourceId,
    required String featureId,
  }) {
    Navigator.push(
      context,
      trackedRoute(
        pageId: pageId,
        courseId: _selected.id,
        resourceId: resourceId,
        featureId: featureId,
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resources = <_StudyResource>[
      _StudyResource(
        title: 'Chat com IA',
        description: 'Tire dúvidas e peça explicações passo a passo.',
        icon: Icons.forum_outlined,
        color: colors.primary,
        onTap: () => _open(
          pageId: 'ai_assistant',
          resourceId: 'ai_chat',
          featureId: 'ai_tutor',
          screen: GenUIAssistantScreen(
            initialContext: 'Quero estudar a cartilha: ${_selected.title}.',
            contextLabel: _selected.title,
          ),
        ),
      ),
      _StudyResource(
        title: 'Cartões de estudo',
        description: 'Revise conceitos e repita os cartões mais difíceis.',
        icon: Icons.style_outlined,
        color: colors.tertiary,
        onTap: () => _open(
          pageId: 'flashcards',
          resourceId: 'ai_flashcards',
          featureId: 'flashcards',
          screen: FlashcardsScreen(topic: _selected.title),
        ),
      ),
      _StudyResource(
        title: 'Quiz com IA',
        description: 'Pratique com correção e explicação imediatas.',
        icon: Icons.quiz_outlined,
        color: colors.secondary,
        onTap: () => _open(
          pageId: 'assessment',
          resourceId: 'ai_quiz',
          featureId: 'assessment',
          screen: AssessmentScreen(
            courseId: _selected.id,
            topic: _selected.title,
            mode: AssessmentMode.quiz,
          ),
        ),
      ),
      _StudyResource(
        title: 'Resumo com IA',
        description: 'Gere pontos-chave, exemplos e perguntas de revisão.',
        icon: Icons.summarize_outlined,
        color: colors.primary,
        onTap: () => _open(
          pageId: 'summary',
          resourceId: 'ai_summary',
          featureId: 'summary',
          screen: SummaryScreen(courseId: _selected.id, topic: _selected.title),
        ),
      ),
      _StudyResource(
        title: 'Simulado com IA',
        description: 'Teste seus conhecimentos com tempo e resultado final.',
        icon: Icons.assignment_outlined,
        color: colors.error,
        onTap: () => _open(
          pageId: 'assessment',
          resourceId: 'ai_exam',
          featureId: 'assessment',
          screen: AssessmentScreen(
            courseId: _selected.id,
            topic: _selected.title,
            mode: AssessmentMode.exam,
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Estudar com IA')),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 600
                ? 2
                : 1;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sua central de estudos',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Escolha uma cartilha. O Tutor TDS cria atividades usando o conteúdo educacional do projeto.',
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<Cartilha>(
                              initialValue: _selected,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Cartilha para estudar',
                                prefixIcon: Icon(Icons.menu_book_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: widget.cartilhas
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item.title,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selected = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Card.filled(
                              color: colors.primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_outlined,
                                      color: colors.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Visão geral da IA',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      colors.onPrimaryContainer,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'A IA pode cometer erros. Confira informações importantes na cartilha e não informe dados pessoais no chat.',
                                            style: TextStyle(
                                              color: colors.onPrimaryContainer,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 174,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _ResourceCard(resource: resources[index]),
                      childCount: resources.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudyResource {
  const _StudyResource({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});

  final _StudyResource resource;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: resource.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(resource.icon, size: 30, color: resource.color),
              const Spacer(),
              Text(
                resource.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                resource.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
