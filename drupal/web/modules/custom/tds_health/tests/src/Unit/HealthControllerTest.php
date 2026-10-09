<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_health\Unit;

use Drupal\Core\Database\Connection;
use Drupal\Core\Database\StatementInterface;
use Drupal\Core\Site\Settings;
use Drupal\tds_health\Controller\HealthController;
use Drupal\Tests\UnitTestCase;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;

/**
 * Testa o endpoint de health do portal.
 */
#[CoversClass(HealthController::class)]
#[Group('tds_health')]
final class HealthControllerTest extends UnitTestCase {

  /**
   * {@inheritdoc}
   */
  protected function setUp(): void {
    parent::setUp();
    new Settings(['tds_environment' => 'test']);
  }

  /**
   * Banco respondendo deve devolver status ok/200.
   */
  public function testStatusOk(): void {
    $statement = $this->createMock(StatementInterface::class);
    $statement->method('fetchField')->willReturn('1');

    $connection = $this->createMock(Connection::class);
    $connection->method('query')->willReturn($statement);

    $response = (new HealthController($connection))->status();

    $this->assertSame(200, $response->getStatusCode());
    $payload = json_decode((string) $response->getContent(), TRUE);
    $this->assertSame('ok', $payload['status']);
    $this->assertSame('tutor-tds-drupal', $payload['service']);
    $this->assertSame('test', $payload['environment']);
    $this->assertSame('up', $payload['database']);
    $this->assertTrue($response->headers->hasCacheControlDirective('no-store'));
  }

  /**
   * Falha no banco deve devolver degraded/503, nunca erro fatal.
   */
  public function testStatusDatabaseDown(): void {
    $connection = $this->createMock(Connection::class);
    $connection->method('query')->willThrowException(new \RuntimeException('db gone'));

    $response = (new HealthController($connection))->status();

    $this->assertSame(503, $response->getStatusCode());
    $payload = json_decode((string) $response->getContent(), TRUE);
    $this->assertSame('degraded', $payload['status']);
    $this->assertSame('down', $payload['database']);
  }

}
