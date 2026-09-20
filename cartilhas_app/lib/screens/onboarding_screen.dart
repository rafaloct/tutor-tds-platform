import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/responsive_body.dart';
import 'home_screen.dart';
import '../features/analytics/telemetry_route.dart';

class OnboardingScreen extends StatefulWidget {
  final bool openedFromSettings;

  const OnboardingScreen({super.key, this.openedFromSettings = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _seenKey = 'onboarding_seen_v1';
  final _controller = PageController();
  int _page = 0;

  static const _items = [
    (
      Icons.auto_stories_outlined,
      'Aprenda no seu ritmo',
      'Escolha uma cartilha e avance por explicações curtas, perguntas e exemplos ligados à realidade do Tocantins.',
    ),
    (
      Icons.psychology_outlined,
      'Converse com o Tutor de IA',
      'Digite ou fale sua dúvida. O Tutor ajuda a entender o conteúdo com linguagem simples e aplicação prática.',
    ),
    (
      Icons.workspace_premium_outlined,
      'Acompanhe sua formação',
      'Conclua as atividades, emita certificados com QR Code e guarde todos na sua carteira para imprimir ou compartilhar.',
    ),
  ];

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    if (!mounted) return;
    if (widget.openedFromSettings) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        trackedRoute(pageId: 'home', builder: (_) => const HomeScreen()),
      );
    }
  }

  void _next() {
    if (_page == _items.length - 1) {
      _complete();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 600,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _complete,
                  child: const Text('Pular'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) {
                    final (icon, title, description) = _items[index];
                    return Semantics(
                      label: 'Passo ${index + 1} de ${_items.length}: $title',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                size: 68,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              description,
                              textAlign: TextAlign.center,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _items.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: index == _page ? 26 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index == _page
                                ? colors.primary
                                : colors.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _next,
                      icon: Icon(
                        _page == _items.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        _page == _items.length - 1 ? 'Começar' : 'Continuar',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
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
