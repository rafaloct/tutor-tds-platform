import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/data/ead_portal_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cadastro usa WordPress e analytics de campanha sem dados pessoais', () {
    final uri = EadPortalLinks.registration();
    expect(uri.scheme, 'https');
    expect(uri.host, EadCatalogRepository.host);
    expect(uri.path, '/cadastro/');
    expect(uri.queryParameters['tds_curso'], isNull);
    expect(uri.queryParameters['utm_source'], 'tutor_tds_app');
    expect(uri.queryParameters['utm_medium'], 'app');
    expect(uri.queryParameters['utm_campaign'], 'ead_signup');
    expect(uri.queryParameters['utm_content'], 'welcome_signup');
    expect(uri.toString(), isNot(contains('cpf')));
    expect(uri.toString(), isNot(contains('email')));
    expect(uri.toString(), isNot(contains('phone')));
    expect(EadPortalLinks.isTrustedDestination(uri), isTrue);
  });

  test('cadastro mantém o curso para a matrícula manual LearnPress', () {
    final uri = EadPortalLinks.registration(courseId: 1298);
    expect(uri.queryParameters['tds_curso'], '1298');
    expect(uri.queryParameters['utm_content'], 'course_1298');
    expect(uri.queryParameters['utm_campaign'], 'ead_signup');
    expect(EadPortalLinks.isTrustedDestination(uri), isTrue);
    expect(() => EadPortalLinks.registration(courseId: 0), throwsArgumentError);
    expect(
      () => EadPortalLinks.registration(courseId: -4),
      throwsArgumentError,
    );
  });

  test('login usa a mesma conta do site sem URL externa de retorno', () {
    final uri = EadPortalLinks.login();
    expect(uri.host, EadCatalogRepository.host);
    expect(uri.path, '/wp-login.php');
    expect(
      uri.queryParameters['redirect_to'],
      'https://ead.ipexdesenvolvimento.cloud/minha-area/',
    );
    expect(uri.queryParameters['utm_campaign'], 'ead_login');
    expect(EadPortalLinks.isTrustedDestination(uri), isTrue);
  });

  test('curso mantém slug seguro e tag de origem do aplicativo', () {
    const course = EadCourse(
      id: 1298,
      title: 'Agricultura Sustentável',
      slug: 'agricultura-sustentavel',
    );
    final uri = EadPortalLinks.course(course);
    expect(uri.path, '/courses/agricultura-sustentavel/');
    expect(uri.queryParameters['utm_content'], 'course_1298');
    expect(uri.queryParameters['utm_campaign'], 'ead_catalog');
    expect(EadPortalLinks.isTrustedDestination(uri), isTrue);
  });

  test('nunca encaminha outros domínios, credenciais ou HTTP', () {
    for (final uri in [
      Uri.parse('http://ead.ipexdesenvolvimento.cloud/cadastro/'),
      Uri.parse('https://example.net/cadastro/'),
      Uri.parse('https://user:secret@ead.ipexdesenvolvimento.cloud/cadastro/'),
      Uri.parse('https://ead.ipexdesenvolvimento.cloud:8443/cadastro/'),
      Uri.parse('https://ead.ipexdesenvolvimento.cloud/cadastro/#fragment'),
      Uri.parse('https://ead.ipexdesenvolvimento.cloud/wp-admin/'),
      Uri.parse(
        'https://ead.ipexdesenvolvimento.cloud/wp-login.php?redirect_to=https%3A%2F%2Fevil.example',
      ),
      Uri.parse(
        'https://ead.ipexdesenvolvimento.cloud/cadastro/?tds_curso=abc',
      ),
    ]) {
      expect(EadPortalLinks.isTrustedDestination(uri), isFalse);
    }
  });
}
