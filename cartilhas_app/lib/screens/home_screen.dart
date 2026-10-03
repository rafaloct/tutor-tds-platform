import 'package:flutter/material.dart';
import '../features/operations/operations_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../features/learning_context/learning_home_card.dart';
import '../features/courses/presentation/course_pdf_button.dart';
import '../features/learning_context/learning_home_controller.dart';
import '../features/courses/data/course_repository.dart';
import '../features/course_editor/data/course_editor_repository.dart';
import '../features/course_editor/presentation/course_editor_screen.dart';
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
import '../features/auth/data/auth_repository.dart';
import '../features/classrooms/data/classroom_repository.dart';
import '../features/classrooms/application/team_capability.dart';
import '../features/classrooms/presentation/classroom_dashboard_screen.dart';
import '../features/classrooms/presentation/learner_classrooms_screen.dart';
import '../features/evidence/data/evidence_repository.dart';
import '../features/evidence/presentation/evidence_checkin_screen.dart';
import '../features/media/data/media_repository.dart';
import '../features/media/presentation/media_catalog_screen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.courseLoader,
    this.learningHomeController,
    this.editorGatewayFactory,
  });

  final LearningHomeController? learningHomeController;

  final Future<List<Cartilha>> Function()? courseLoader;
  final CourseEditorGateway Function()? editorGatewayFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasEditorAccess = false;
  bool _hasSession = false;
  int _navigationIndex = 0;
  Future<TeamCapabilitySnapshot?>? _teamCapability;
  late Future<List<Cartilha>> _cartilhas;
  bool _catalogLoading = false;
  bool _catalogReloadQueued = false;

  @override
  void initState() {
    super.initState();
    _cartilhas = _startCatalogLoad();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseLoader != widget.courseLoader) {
      _refreshCatalog(afterCurrent: true);
    }
  }

  Future<List<Cartilha>> _startCatalogLoad() {
    _catalogLoading = true;
    return Future<List<Cartilha>>.sync(_loadCartilhas).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _catalogLoading = false;
        if (_catalogReloadQueued) {
          _catalogReloadQueued = false;
          _cartilhas = _startCatalogLoad();
        }
      });
    });
  }

  void _refreshCatalog({bool afterCurrent = false}) {
    if (_catalogLoading) {
      // A publication can finish while the previous catalog request is pending.
      // Coalesce that return into one reload after the current request finishes.
      _catalogReloadQueued = _catalogReloadQueued || afterCurrent;
      return;
    }
    setState(() {
      _cartilhas = _startCatalogLoad();
    });
  }

  Future<List<Cartilha>> _currentCatalog() async {
    var requested = _cartilhas;
    var courses = await requested;
    while (mounted && !identical(requested, _cartilhas)) {
      requested = _cartilhas;
      courses = await requested;
    }
    return courses;
  }

  CourseEditorGateway _newEditorGateway() =>
      widget.editorGatewayFactory?.call() ??
      CourseEditorRepository(
        apiUrl: AppConfig.tutorApiUrl,
        authRepository: context.read<AuthRepository>(),
      );

  void _refreshTeamCapability() {
    _refreshSessionState();
    _refreshEditorCapability();
    final auth = Provider.of<AuthRepository?>(context, listen: false);
    final Future<TeamCapabilitySnapshot?> next;
    if (auth == null || AppConfig.tutorApiUrl.trim().isEmpty) {
      next = Future.value(null);
    } else {
      final repository = ClassroomRepository(
        apiUrl: AppConfig.tutorApiUrl,
        authRepository: auth,
      );
      next = _resolveTeamCapability(repository);
    }
    if (mounted) {
      setState(() {
        _teamCapability = next;
      });
    }
  }

  Future<List<Cartilha>> _loadCartilhas() =>
      widget.courseLoader?.call() ??
      CourseRepository.forCatalog(
        // Pass an empty URL when the remote catalog flag is off so that
        // CourseRepository skips the network entirely and loads only the
        // 9 bundled local courses. When enabled the existing fallback chain
        // applies: remote -> local cache (SharedPreferences) -> bundled assets.
        apiUrl: AppConfig.tutorApiUrl,
      ).fetchAll();

  Future<void> _openBottomDestination(int index) async {
    if (index == 0 || _navigationIndex != 0) return;
    setState(() => _navigationIndex = index);
    try {
      switch (index) {
        case 1:
          final cartilhas = await _currentCatalog();
          if (!mounted) return;
          if (cartilhas.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Nenhum curso disponível para estudar. Atualize o catálogo.',
                ),
              ),
            );
            return;
          }
          await Navigator.push(
            context,
            trackedRoute(
              pageId: 'study_hub',
              resourceId: 'study_tools',
              featureId: 'study_hub_navigation',
              builder: (_) => StudyHubScreen(cartilhas: cartilhas),
            ),
          );
        case 2:
          if (!mounted) return;
          await Navigator.push(
            context,
            trackedRoute(
              pageId: 'content_catalog',
              resourceId: 'content_catalog',
              featureId: 'content_navigation',
              builder: (_) => MediaCatalogScreen(
                repository: MediaRepository(
                  apiUrl: AppConfig.tutorApiUrl,
                  authRepository: context.read<AuthRepository>(),
                ),
              ),
            ),
          );
        case 3:
          if (!mounted) return;
          await Navigator.push(
            context,
            trackedRoute(
              pageId: 'profile',
              featureId: 'profile_navigation',
              builder: (_) => const CadUnicoScreen(),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _navigationIndex = 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_teamCapability != null) return;
    _refreshSessionState();
    _refreshEditorCapability();
    final auth = Provider.of<AuthRepository?>(context, listen: false);
    if (auth == null || AppConfig.tutorApiUrl.trim().isEmpty) {
      _teamCapability = Future.value(null);
      return;
    }
    final repository = ClassroomRepository(
      apiUrl: AppConfig.tutorApiUrl,
      authRepository: auth,
    );
    _teamCapability = _resolveTeamCapability(repository);
  }

  Future<TeamCapabilitySnapshot?> _resolveTeamCapability(
    ClassroomRepository repository,
  ) async {
    try {
      return await TeamCapabilityResolver(repository).resolve();
    } on Object {
      return null;
    } finally {
      repository.dispose();
    }
  }

  Future<void> _refreshEditorCapability() async {
    final auth = Provider.of<AuthRepository?>(context, listen: false);
    if (widget.editorGatewayFactory == null &&
        (auth == null || AppConfig.tutorApiUrl.trim().isEmpty)) {
      return;
    }
    final repository = _newEditorGateway();
    var hasAccess = false;
    try {
      hasAccess = (await repository.programs()).isNotEmpty;
    } catch (_) {
      // Access is granted only by a successful scoped capability response.
    } finally {
      if (repository is CourseEditorRepository) repository.dispose();
    }
    if (mounted) {
      setState(() => _hasEditorAccess = hasAccess);
    }
  }

  Future<void> _refreshSessionState() async {
    final auth = Provider.of<AuthRepository?>(context, listen: false);
    if (auth == null || AppConfig.tutorApiUrl.trim().isEmpty) {
      if (mounted) setState(() => _hasSession = false);
      return;
    }
    var hasSession = false;
    try {
      hasSession = await auth.hasSession();
    } catch (_) {
      hasSession = false;
    }
    if (mounted) setState(() => _hasSession = hasSession);
  }

  bool get _useLearningHome =>
      widget.learningHomeController != null ||
      (AppConfig.learningContextEnabled && _hasSession);

  Widget _catalogBody({bool embedded = false}) => FutureBuilder<List<Cartilha>>(
    future: _cartilhas,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return TdsWaitExperience(
          compact: embedded,
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
      return ListView(
        shrinkWrap: embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        children: [
          _LearningHeader(
            showLocalResume: !_useLearningHome,
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
            onVideosTap: () => Navigator.push(
              context,
              trackedRoute(
                pageId: 'videos',
                resourceId: 'video_catalog',
                featureId: 'video_learning',
                builder: (_) => MediaCatalogScreen(
                  repository: MediaRepository(
                    apiUrl: AppConfig.tutorApiUrl,
                    authRepository: context.read<AuthRepository>(),
                  ),
                ),
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
          if (_useLearningHome)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'Explorar conteúdos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          _CartilhaList(cartilhas: cartilhas),
          const _SupportersBanner(),
        ],
      );
    },
  );

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
            const Flexible(
              child: Text(
                'Tutor TDS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
          FutureBuilder<TeamCapabilitySnapshot?>(
            future: _teamCapability,
            builder: (context, capability) => PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (value) async {
                if (value == 'refresh_catalog') {
                  _refreshCatalog();
                  return;
                }
                final screen = switch (value) {
                  'operations' => OperationsEntry(
                    auth: context.read<AuthRepository>(),
                    apiUrl: AppConfig.tutorApiUrl,
                  ),
                  'learner_classes' => const LearnerClassroomsScreen(),
                  'editor' => CourseEditorCatalogScreen(
                    gateway: _newEditorGateway(),
                  ),
                  'guide' => const GuideScreen(),
                  'support' => const ChatwootScreen(),
                  'settings' => const SettingsScreen(),
                  'team' || 'monitor' => ClassroomDashboardScreen(
                    gateway: ClassroomRepository(
                      apiUrl: AppConfig.tutorApiUrl,
                      authRepository: context.read<AuthRepository>(),
                    ),
                    evidenceGateway: EvidenceRepository(
                      apiUrl: AppConfig.tutorApiUrl,
                      authRepository: context.read<AuthRepository>(),
                    ),
                  ),
                  'checkin' => EvidenceCheckinScreen(
                    gateway: EvidenceRepository(
                      apiUrl: AppConfig.tutorApiUrl,
                      authRepository: context.read<AuthRepository>(),
                    ),
                  ),
                  _ => const AboutScreen(),
                };
                final pageId = switch (value) {
                  'operations' => 'operator_operations',
                  'learner_classes' => 'learner_classrooms',
                  'editor' => 'course_editor_catalog',
                  'guide' => 'user_guide',
                  'support' => 'support',
                  'settings' => 'settings',
                  'team' => 'team_dashboard',
                  'monitor' => 'monitor_exceptions',
                  'checkin' => 'evidence_checkin',
                  _ => 'about',
                };
                await Navigator.push(
                  context,
                  trackedRoute(
                    pageId: pageId,
                    resourceId: value == 'guide' ? 'usage_guide' : null,
                    featureId: switch (value) {
                      'learner_classes' => 'classroom_learning',
                      'editor' => 'course_editor',
                      'support' => 'support',
                      'team' => 'classroom_dashboard',
                      'monitor' => 'monitor_exceptions',
                      'checkin' => 'evidence_checkin',
                      _ => null,
                    },
                    builder: (_) => screen,
                  ),
                );
                if (mounted) {
                  if (value == 'editor') _refreshCatalog(afterCurrent: true);
                  _refreshTeamCapability();
                }
              },
              itemBuilder: (_) => [
                if (_hasSession && operatorOperationsEnabled)
                  const PopupMenuItem(
                    value: 'operations',
                    child: ListTile(
                      leading: Icon(Icons.manage_accounts_outlined),
                      title: Text('Operação de participantes'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem(
                  value: 'refresh_catalog',
                  enabled: !_catalogLoading,
                  child: const ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Atualizar catálogo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_hasSession)
                  const PopupMenuItem(
                    value: 'learner_classes',
                    child: ListTile(
                      leading: Icon(Icons.school_outlined),
                      title: Text('Minhas turmas'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (_hasEditorAccess)
                  const PopupMenuItem(
                    value: 'editor',
                    child: ListTile(
                      leading: Icon(Icons.edit_note),
                      title: Text('Meus conteúdos'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'guide',
                  child: ListTile(
                    leading: Icon(Icons.help_outline),
                    title: Text('Como usar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'support',
                  child: ListTile(
                    leading: Icon(Icons.support_agent_outlined),
                    title: Text('Suporte TDS'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Configurações'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (capability.data?.hasAccess ?? false)
                  PopupMenuItem(
                    value: capability.data!.hasTeacherCockpit
                        ? 'team'
                        : 'monitor',
                    child: ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(
                        capability.data!.hasTeacherCockpit
                            ? 'Área da equipe'
                            : 'Monitor por exceção',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (_hasSession)
                  const PopupMenuItem(
                    value: 'checkin',
                    child: ListTile(
                      leading: Icon(Icons.qr_code_scanner_outlined),
                      title: Text('Registrar presença'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'about',
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Sobre o Programa'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _useLearningHome
          ? ListView(
              children: [
                LearningHomeCard(controller: widget.learningHomeController),
                _catalogBody(embedded: true),
              ],
            )
          : _catalogBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navigationIndex,
        onDestinationSelected: _openBottomDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Aprender',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Conteúdos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _LearningHeader extends StatefulWidget {
  final bool showLocalResume;
  final List<Cartilha> cartilhas;
  final Future<void> Function(Cartilha cartilha) onResumeTap;
  final VoidCallback onStudyTap;
  final VoidCallback onTutorTap;
  final VoidCallback onVideosTap;
  final VoidCallback onGuideTap;
  final VoidCallback onCertificatesTap;

  const _LearningHeader({
    this.showLocalResume = true,
    required this.cartilhas,
    required this.onResumeTap,
    required this.onStudyTap,
    required this.onTutorTap,
    required this.onVideosTap,
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
      if (cartilha.id == progress.courseId &&
          (progress.courseVersionId == cartilha.courseVersionId ||
              (progress.courseVersionId == null &&
                  cartilha.legacyProgressCompatible))) {
        return cartilha;
      }
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
            if (widget.showLocalResume && _shouldShowAttempt && attempt != null)
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
            else if (widget.showLocalResume &&
                lastCartilha != null &&
                _lastProgress != null)
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
                FilledButton.tonalIcon(
                  onPressed: widget.onVideosTap,
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Vídeos'),
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
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
                    CoursePdfButton(
                      key: ValueKey('course-pdf-${cartilha.id}'),
                      course: cartilha,
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

  String get _partnerName => switch (asset) {
    'assets/logos/logo_ipex.png' => 'IPEX',
    'assets/logos/logo_uft.png' => 'UFT',
    'assets/logos/logo_fapto.png' => 'FAPTO',
    'assets/logos/logo_cdr.png' => 'CDR',
    _ => 'Instituição parceira',
  };

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: 'Logotipo $_partnerName',
        image: true,
        child: Container(
          key: ValueKey('supporter_logo_${_partnerName.toLowerCase()}'),
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ExcludeSemantics(
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
