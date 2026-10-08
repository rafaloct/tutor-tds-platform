<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_tutor_gateway\Unit;

use Drupal\Tests\UnitTestCase;
use Drupal\tds_tutor_gateway\Controller\TutorSessionController;
use Drupal\tds_tutor_gateway\Session\TutorSessionManagerInterface;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;

/**
 * Testa a superficie web sanitizada do gateway.
 */
#[CoversClass(TutorSessionController::class)]
#[Group('tds_tutor_gateway')]
final class TutorSessionControllerTest extends UnitTestCase {

  /**
   * A resposta de login nunca contem bearer, refresh ou senha.
   */
  public function testLoginResponseContainsOnlyPublicUser(): void {
    $manager = $this->createMock(TutorSessionManagerInterface::class);
    $manager->expects(self::once())->method('login')->willReturn([
      'id' => 'user-1',
      'name' => 'Pessoa QA',
      'role' => 'student',
    ]);
    $controller = new TutorSessionController($manager);
    $request = Request::create(
      '/tds/session/login',
      'POST',
      server: ['CONTENT_TYPE' => 'application/json'],
      content: json_encode([
        'cpf' => '00000000000',
        'password' => 'synthetic-password',
      ], JSON_THROW_ON_ERROR),
    );

    $response = $controller->login($request);
    $body = (string) $response->getContent();
    self::assertSame(200, $response->getStatusCode());
    self::assertStringContainsString('user-1', $body);
    self::assertStringNotContainsString('access_token', $body);
    self::assertStringNotContainsString('refresh_token', $body);
    self::assertStringNotContainsString('synthetic-password', $body);
    self::assertStringContainsString('no-store', $response->headers->get('Cache-Control', ''));
  }

}
