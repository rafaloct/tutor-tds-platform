import 'package:flutter/material.dart';

import '../data/ead_catalog_repository.dart';
import '../data/ead_portal_links.dart';
import '../learning_path/ead_learning_path_screen.dart';
import '../qa/private_editorial_qa_bridge.dart';

typedef EadCourseLoader = Future<List<EadCourse>> Function();
typedef EadCourseOpener = Future<bool> Function(Uri uri);

/// Public LearnPress discovery, separated from bundled Tutor TDS cartilhas.
class EadCatalogScreen extends StatefulWidget {
  const EadCatalogScreen({
    super.key,
    this.courseLoader,
    this.openCourse,
    this.openRegistration,
  });

  final EadCourseLoader? courseLoader;
  final EadCourseOpener? openCourse;
  final EadCourseOpener? openRegistration;

  @override
  State<EadCatalogScreen> createState() => _EadCatalogScreenState();
}

class _EadCatalogScreenState extends State<EadCatalogScreen> {
  late Future<List<EadCourse>> _courses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _courses = (widget.courseLoader ?? EadCatalogRepository().fetchPublished)();
  }

  void _retry() {
    setState(_load);
  }

  Future<void> _open(EadCourse course) async {
    final success = await (() async {
      try {
        final destination = EadPortalLinks.course(course);
        return await (widget.openCourse?.call(destination) ??
            EadPortalLinks.open(destination));
      } on Object {
        return false;
      }
    })();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir o curso. Acesse ead.ipexdesenvolvimento.cloud.',
          ),
        ),
      );
    }
  }

  Future<void> _register(EadCourse course) async {
    final destination = EadPortalLinks.registration(courseId: course.id);
    bool opened;
    try {
      opened =
          await (widget.openRegistration?.call(destination) ??
              EadPortalLinks.open(destination));
    } on Object {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o cadastro do EAD.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cursos do EAD'),
        actions: [
          IconButton(
            tooltip: 'Atualizar cursos do EAD',
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: FutureBuilder<List<EadCourse>>(
            future: _courses,
            builder: (context, snapshot) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                children: [
                  Text(
                    'Aprenda também pelo portal EAD',
                    style: typography.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Veja as ofertas atualizadas do site. A inscrição e as aulas '
                    'acontecem no EAD; as cartilhas e o Tutor TDS continuam '
                    'disponíveis neste aplicativo.',
                  ),
                  const SizedBox(height: 20),
                  if (PrivateEditorialQaBridge.enabled)
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: ListTile(
                        key: const ValueKey('qa-synthetic-learnpress'),
                        leading: const Icon(Icons.science_outlined),
                        title: const Text(PrivateEditorialQaBridge.marker),
                        subtitle: const Text(
                          'Curso SAF sintético, sem conta, matrícula ou dados reais.',
                        ),
                        trailing: const Icon(Icons.route),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const EadLearningPathScreen(
                              course: EadCourse(
                                id: PrivateEditorialQaBridge.syntheticCourseId,
                                slug: 'saf-qa-sintetico',
                                title:
                                    'SAF QA · teste de publicação do LearnPress',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError)
                    _Message(
                      icon: Icons.wifi_off_outlined,
                      message:
                          'Não foi possível carregar os cursos do EAD. '
                          'Suas cartilhas do aplicativo continuam disponíveis.',
                      onRetry: _retry,
                    )
                  else if (!snapshot.hasData || snapshot.data!.isEmpty)
                    _Message(
                      icon: Icons.school_outlined,
                      message: 'Nenhuma oferta publicada no EAD neste momento.',
                      onRetry: _retry,
                    )
                  else ...[
                    Text(
                      'Ofertas publicadas: ${snapshot.data!.length}',
                      style: typography.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    for (final course in snapshot.data!)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          children: [
                            ListTile(
                              key: ValueKey('ead-course-${course.id}'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 9,
                              ),
                              leading: const Icon(Icons.menu_book_outlined),
                              title: Text(course.title),
                              subtitle: const Text(
                                'Ver aulas e inscrição no EAD',
                              ),
                              trailing: const Icon(Icons.open_in_new),
                              onTap: () => _open(course),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                key: ValueKey('ead-register-${course.id}'),
                                onPressed: () => _register(course),
                                icon: const Icon(Icons.person_add_outlined),
                                label: const Text(
                                  'Criar conta para este curso',
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                key: ValueKey('ead-path-${course.id}'),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        EadLearningPathScreen(course: course),
                                  ),
                                ),
                                icon: const Icon(Icons.route_outlined),
                                label: const Text(
                                  'Ver percurso e prática no app',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Este catálogo mostra ofertas do portal. A visualização '
                    'não cria matrícula, presença nem certificado.',
                    style: typography.bodySmall,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        Icon(icon, size: 36),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}
