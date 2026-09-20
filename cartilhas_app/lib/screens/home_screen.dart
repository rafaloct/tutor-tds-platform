import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../features/courses/data/course_repository.dart';
import '../models/cartilha.dart';
import 'chat_experience_screen.dart';
import 'cadunico_screen.dart';
import 'glossary_screen.dart';
import 'about_screen.dart';
import 'guide_screen.dart';
import 'chatwoot_screen.dart';
import 'genui_assistant_screen.dart';
import 'settings_screen.dart';
import '../features/study_ai/presentation/study_hub_screen.dart';
import '../features/study_ai/data/assessment_attempt_repository.dart';
import '../features/study_ai/models/study_models.dart';
import '../features/study_ai/presentation/assessment_screen.dart';
import '../features/certificates/presentation/certificate_wallet_screen.dart';
import '../features/study_progress/study_progress_repository.dart';
import '../widgets/study_resume_card.dart';
import '../widgets/tds_wait_experience.dart';
import '../widgets/tds_brand_stripe.dart';
import '../features/analytics/telemetry_route.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.courseLoader});

  final Future<List<Cartilha>> Function()? courseLoader;

  Future<List<Cartilha>> _loadCartilhas() =>
      courseLoader?.call() ??
      CourseRepository(apiUrl: AppConfig.tutorApiUrl).fetchAll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                'assets/branding/marca_isolada_tds.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Tutor TDS'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Glossário',
            onPressed: () => Navigator.push(
              context,
              trackedRoute(
                pageId: 'glossary',
                resourceId: 'knowledge_glossary',
                featureId: 'glossary',
                builder: (_) => const GlossaryScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Meu Cadastro',
            onPressed: () => Navigator.push(
              context,
              trackedRoute(
                pageId: 'profile',
                featureId: 'profile_management',
                builder: (_) => const CadUnicoScreen(),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (value) {
              final screen = switch (value) {
                'guide' => const GuideScreen(),
                'support' => const ChatwootScreen(),
                'settings' => const SettingsScreen(),
                _ => const AboutScreen(),
              };
              final pageId = switch (value) {
                'guide' => 'user_guide',
                'support' => 'support',
                'settings' => 'settings',
                _ => 'about',
              };
              Navigator.push(
                context,
                trackedRoute(
                  pageId: pageId,
                  resourceId: value == 'guide' ? 'usage_guide' : null,
                  featureId: value == 'support' ? 'support' : null,
                  builder: (_) => screen,
                ),
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'guide',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Como usar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'support',
                child: ListTile(
                  leading: Icon(Icons.support_agent_outlined),
                  title: Text('Suporte TDS'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Configurações'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Sobre o Programa'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Cartilha>>(
        future: _loadCartilhas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TdsWaitExperience(
              title: 'Organizando seus cursos',
              status: 'Carregando a biblioteca disponível neste aparelho...',
              localTip:
                  'As cartilhas instaladas continuam disponíveis mesmo com conexão instável.',
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar cartilhas: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma cartilha encontrada.'));
          }

          final cartilhas = snapshot.data!;
          return Column(
            children: [
              _LearningHeader(
                cartilhas: cartilhas,
                onResumeTap: (cartilha) async {
                  await Navigator.push(
                    context,
                    trackedRoute(
                      pageId: 'guided_lesson',
                      courseId: cartilha.id,
                      resourceId: 'course_content',
                      featureId: 'guided_learning',
                      builder: (_) => ChatExperienceScreen(cartilha: cartilha),
                    ),
                  );
                },
                onStudyTap: () => Navigator.push(
                  context,
                  trackedRoute(
                    pageId: 'study_hub',
                    resourceId: 'study_tools',
                    featureId: 'study_hub',
                    builder: (_) => StudyHubScreen(cartilhas: cartilhas),
                  ),
                ),
                onTutorTap: () => Navigator.push(
                  context,
                  trackedRoute(
                    pageId: 'ai_assistant',
                    resourceId: 'ai_chat',
                    featureId: 'ai_tutor',
                    builder: (_) => const GenUIAssistantScreen(),
                  ),
                ),
                onGuideTap: () => Navigator.push(
                  context,
                  trackedRoute(
                    pageId: 'user_guide',
                    resourceId: 'usage_guide',
                    builder: (_) => const GuideScreen(),
                  ),
                ),
                onCertificatesTap: () => Navigator.push(
                  context,
                  trackedRoute(
                    pageId: 'certificate_wallet',
                    featureId: 'certificates',
                    builder: (_) => const CertificateWalletScreen(),
                  ),
                ),
              ),
              Expanded(child: _CartilhaList(cartilhas: cartilhas)),
              const _SupportersBanner(),
            ],
          );
        },
      ),
    );
  }
}

class _LearningHeader extends StatefulWidget {
  final List<Cartilha> cartilhas;
  final Future<void> Function(Cartilha cartilha) onResumeTap;
  final VoidCallback onStudyTap;
  final VoidCallback onTutorTap;
  final VoidCallback onGuideTap;
  final VoidCallback onCertificatesTap;

  const _LearningHeader({
    required this.cartilhas,
    required this.onResumeTap,
    required this.onStudyTap,
    required this.onTutorTap,
    required this.onGuideTap,
    required this.onCertificatesTap,
  });

  @override
  State<_LearningHeader> createState() => _LearningHeaderState();
}

class _LearningHeaderState extends State<_LearningHeader> {
  String _firstName = '';
  StudyProgress? _lastProgress;
  AssessmentAttempt? _lastAttempt;

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  Future<void> _loadLocalState() async {
    final results = await Future.wait<Object?>([
      SharedPreferences.getInstance(),
      const StudyProgressRepository().loadLast(),
      const AssessmentAttemptRepository().loadLast(),
    ]);
    if (!mounted) return;
    final prefs = results[0]! as SharedPreferences;
    final name = (prefs.getString('user_name') ?? '').trim();
    setState(() {
      _firstName = name.isEmpty ? '' : name.split(' ').first;
      _lastProgress = results[1] as StudyProgress?;
      _lastAttempt = results[2] as AssessmentAttempt?;
    });
  }

  bool get _shouldShowAttempt {
    final attempt = _lastAttempt;
    if (attempt == null) return false;
    final progress = _lastProgress;
    if (progress == null) return true;
    if (!attempt.isCompleted && progress.isCompleted) return true;
    if (attempt.isCompleted && !progress.isCompleted) return false;
    return attempt.updatedAt.isAfter(progress.updatedAt);
  }

  Cartilha? get _lastCartilha {
    final progress = _lastProgress;
    if (progress == null) return null;
    for (final cartilha in widget.cartilhas) {
      if (cartilha.id == progress.courseId) return cartilha;
    }
    return null;
  }

  double _progressFor(Cartilha cartilha, StudyProgress progress) {
    if (progress.isCompleted) return 1;
    final total = cartilha.sections.fold<int>(
      0,
      (sum, section) => sum + section.messages.length,
    );
    if (total == 0) return 0;
    var visited = 0;
    for (
      var index = 0;
      index < progress.sectionIndex && index < cartilha.sections.length;
      index++
    ) {
      visited += cartilha.sections[index].messages.length;
    }
    visited += progress.messageIndex + 1;
    return (visited / total).clamp(0, 1);
  }

  Future<void> _resume(Cartilha cartilha) async {
    await widget.onResumeTap(cartilha);
    await _loadLocalState();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final greeting = _firstName.isEmpty ? 'Olá!' : 'Olá, $_firstName!';
    final lastCartilha = _lastCartilha;
    final attempt = _lastAttempt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TdsBrandStripe(),
            const SizedBox(height: 18),
            Text(
              greeting,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'O que você quer aprender hoje?',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (_shouldShowAttempt && attempt != null)
              StudyResumeCard(
                courseTitle: attempt.topic,
                progress: attempt.totalQuestions > 0
                    ? (attempt.answers.length / attempt.totalQuestions).clamp(
                        0,
                        1,
                      )
                    : 0,
                isCompleted: attempt.isCompleted,
                actionLabel: attempt.isCompleted
                    ? 'Rever resultado (${attempt.mode.label})'
                    : 'Continuar ${attempt.mode.label.toLowerCase()}',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    trackedRoute(
                      pageId: 'assessment',
                      courseId: attempt.courseId,
                      resourceId: attempt.mode == AssessmentMode.exam
                          ? 'ai_exam'
                          : 'ai_quiz',
                      featureId: 'assessment',
                      builder: (_) => AssessmentScreen(
                        courseId: attempt.courseId,
                        topic: attempt.topic,
                        mode: attempt.mode,
                        initialAttempt: attempt,
                      ),
                    ),
                  );
                  await _loadLocalState();
                },
              )
            else if (lastCartilha != null && _lastProgress != null)
              StudyResumeCard(
                courseTitle: lastCartilha.title,
                progress: _progressFor(lastCartilha, _lastProgress!),
                isCompleted: _lastProgress!.isCompleted,
                onPressed: () => _resume(lastCartilha),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: widget.onStudyTap,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Estudar com IA'),
                ),
                FilledButton.tonalIcon(
                  onPressed: widget.onTutorTap,
                  icon: const Icon(Icons.psychology_outlined),
                  label: const Text('Perguntar ao Tutor'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onGuideTap,
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Como usar'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onCertificatesTap,
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('Meus certificados'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartilhaList extends StatelessWidget {
  final List<Cartilha> cartilhas;
  const _CartilhaList({required this.cartilhas});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 720;

    if (isWide) {
      // Grid 2 colunas em telas largas (Chromebook/tablet)
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 3.2,
            ),
            itemCount: cartilhas.length,
            itemBuilder: (context, index) =>
                _CartilhaCard(cartilha: cartilhas[index]),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      itemCount: cartilhas.length,
      itemBuilder: (context, index) =>
          _CartilhaCard(cartilha: cartilhas[index]),
    );
  }
}

class _CartilhaCard extends StatelessWidget {
  final Cartilha cartilha;
  const _CartilhaCard({required this.cartilha});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          trackedRoute(
            pageId: 'guided_lesson',
            courseId: cartilha.id,
            resourceId: 'course_content',
            featureId: 'guided_learning',
            builder: (_) => ChatExperienceScreen(cartilha: cartilha),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cartilha.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Por: ${cartilha.author}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (cartilha.downloadUrl != null &&
                      cartilha.downloadUrl!.isNotEmpty)
                    FilledButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text('PDF', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF093AF4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => launchUrl(
                        Uri.parse(cartilha.downloadUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportersBanner extends StatelessWidget {
  const _SupportersBanner();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          children: [
            const Text(
              'Realização e Apoio',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BannerLogo('assets/logos/logo_ipex.png'),
                _BannerLogo('assets/logos/logo_uft.png'),
                _BannerLogo('assets/logos/logo_fapto.png'),
                _BannerLogo('assets/logos/logo_cdr.png'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerLogo extends StatelessWidget {
  final String asset;
  const _BannerLogo(this.asset);

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, height: 32, fit: BoxFit.contain);
  }
}
