import 'dart:async';
import 'dart:convert';

import 'package:cartilhas_app/features/media/data/media_repository.dart';
import 'package:cartilhas_app/features/media/presentation/media_catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('loading informa atualização sem bloquear cartilhas', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final repository = MediaRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) => response.future),
    );

    await tester.pumpWidget(
      MaterialApp(home: MediaCatalogScreen(repository: repository)),
    );
    await tester.pump();

    expect(find.text('Organizando os vídeos do seu curso...'), findsOneWidget);
    expect(
      find.textContaining('Suas cartilhas continuam disponíveis'),
      findsOneWidget,
    );

    response.complete(http.Response(jsonEncode({'media': <Object>[]}), 200));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum vídeo publicado ainda'), findsOneWidget);
  });

  testWidgets('falha sem cache exibe erro acessível e retry', (tester) async {
    final repository = MediaRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('offline', 503)),
    );

    await tester.pumpWidget(
      MaterialApp(home: MediaCatalogScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vídeos indisponíveis agora'), findsOneWidget);
    expect(find.text('Nenhum vídeo publicado ainda'), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('offline com cache identifica metadados salvos', (tester) async {
    SharedPreferences.setMockInitialValues({
      'media:catalog_cache:v1': jsonEncode([_mediaJson()]),
    });
    final repository = MediaRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('offline', 503)),
    );

    await tester.pumpWidget(
      MaterialApp(home: MediaCatalogScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo salvo no aparelho'), findsOneWidget);
    expect(
      find.textContaining('A reprodução protegida precisa de conexão'),
      findsOneWidget,
    );
    expect(find.text('Vídeo de cooperativismo'), findsOneWidget);
    expect(find.text('Acesso protegido • conexão necessária'), findsOneWidget);
  });
}

Map<String, dynamic> _mediaJson() => {
  'id': 'media-1',
  'institution_id': 'inst-1',
  'program_id': 'program-1',
  'course_id': 'course-1',
  'module_id': 'module-1',
  'creator_user_id': 'creator-1',
  'title': 'Vídeo de cooperativismo',
  'description': 'Introdução',
  'competency_id': 'competency-1',
  'provider': 'cloudflare_stream',
  'provider_asset_id': '',
  'duration_seconds': 120,
  'captions': const [],
  'visibility': 'enrolled',
  'offline_policy': 'forbidden',
  'status': 'published',
  'followup_activity_id': 'quiz-1',
  'published_at': '2026-09-20T12:00:00Z',
};
