<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_public_portal\Unit;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Component\Uuid\Php;
use Drupal\Core\Cache\CacheBackendInterface;
use Drupal\Core\Site\Settings;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_public_portal\Client\PublicCatalogClient;
use Drupal\tds_public_portal\ValueObject\CatalogResult;
use GuzzleHttp\Client;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Middleware;
use GuzzleHttp\Psr7\Response;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;

/**
 * Cobre allowlist, isolamento de cache e degradacao do catalogo.
 */
#[CoversClass(PublicCatalogClient::class)]
#[Group('tds_public_portal')]
final class PublicCatalogClientTest extends UnitTestCase {

  /**
   * Draft/private e campos fora do contrato nunca chegam ao render.
   */
  public function testListKeepsOnlyPublishedAllowlistedFields(): void {
    $history = [];
    $cache = $this->createMock(CacheBackendInterface::class);
    $cache->method('get')->willReturn(FALSE);
    $cache->expects(self::once())
      ->method('set')
      ->with(
        self::isType('string'),
        self::callback(static fn (array $value): bool => $value['fetched_at'] === 1000),
        1360,
        ['tds_public_catalog'],
      );
    $client = $this->client([
      new Response(200, [], json_encode([
        'courses' => [
          $this->course(['private_token' => 'must-not-escape']),
          $this->course(['slug' => 'draft-course', 'status' => 'draft']),
        ],
        'offset' => 0,
        'limit' => 50,
        'total' => 2,
      ], JSON_THROW_ON_ERROR)),
    ], $history, $cache);

    $result = $client->list();

    self::assertSame(CatalogResult::FRESH, $result->state);
    self::assertCount(1, $result->payload['courses']);
    self::assertSame('curso-publico', $result->payload['courses'][0]['slug']);
    self::assertArrayNotHasKey('private_token', $result->payload['courses'][0]);
    self::assertCount(1, $history);
    self::assertSame('/tutor-api/public/courses', $history[0]['request']->getUri()->getPath());
    self::assertSame('offset=0&limit=50', $history[0]['request']->getUri()->getQuery());
    self::assertSame('', $history[0]['request']->getHeaderLine('Authorization'));
  }

  /**
   * Falha de rede pode servir somente stale ainda dentro da janela explicita.
   */
  public function testApiOfflineReturnsValidStaleWithoutRetryLeak(): void {
    $history = [];
    $cache = $this->createMock(CacheBackendInterface::class);
    $cache->method('get')->willReturn((object) [
      'data' => [
        'payload' => [
          'courses' => [$this->course()],
          'offset' => 0,
          'limit' => 50,
          'total' => 1,
        ],
        'fetched_at' => 900,
      ],
    ]);
    $cache->expects(self::never())->method('set');
    $client = $this->client([
      new Response(503, [], '{"detail":"sensitive upstream"}'),
      new Response(503, [], '{"detail":"sensitive upstream"}'),
    ], $history, $cache);

    $result = $client->list();

    self::assertSame(CatalogResult::STALE, $result->state);
    self::assertSame('Curso publico', $result->payload['courses'][0]['title']);
    self::assertCount(2, $history);
  }

  /**
   * Cache vencido nunca e apresentado como atual.
   */
  public function testExpiredStaleBecomesUnavailable(): void {
    $history = [];
    $cache = $this->createMock(CacheBackendInterface::class);
    $cache->method('get')->willReturn((object) [
      'data' => [
        'payload' => ['courses' => [$this->course()]],
        'fetched_at' => 639,
      ],
    ]);
    $client = $this->client([
      new Response(503, [], '{}'),
      new Response(503, [], '{}'),
    ], $history, $cache);

    self::assertSame(CatalogResult::UNAVAILABLE, $client->list()->state);
  }

  /**
   * Detalhe 404 nao recebe fallback de outro curso.
   */
  public function testUnknownCourseIsNotFound(): void {
    $history = [];
    $cache = $this->createMock(CacheBackendInterface::class);
    $cache->method('get')->willReturn(FALSE);
    $client = $this->client([
      new Response(404, [], '{"detail":"not found"}'),
    ], $history, $cache);

    self::assertSame(CatalogResult::NOT_FOUND, $client->detail('nao-existe')->state);
    self::assertCount(1, $history);
  }

  /**
   * Origem HTTP nao local falha antes de qualquer request.
   */
  public function testUnsafeOriginFailsClosed(): void {
    $history = [];
    $cache = $this->createMock(CacheBackendInterface::class);
    $client = $this->client([], $history, $cache, [
      'tutor_api_base_url' => 'http://api.example.test/tutor-api',
      'tds_environment' => 'staging',
    ]);

    self::assertSame(CatalogResult::UNAVAILABLE, $client->list()->state);
    self::assertSame([], $history);
  }

  /**
   * Ambiente e base URL participam da chave e impedem cache cruzado.
   */
  public function testCacheIsIsolatedByEnvironment(): void {
    $cacheIds = [];
    $cache = $this->createMock(CacheBackendInterface::class);
    $cache->method('get')->willReturnCallback(
      static function (string $cacheId) use (&$cacheIds): bool {
        $cacheIds[] = $cacheId;
        return FALSE;
      },
    );
    $historyA = [];
    $clientA = $this->client([
      new Response(200, [], $this->collectionJson()),
    ], $historyA, $cache, [
      'tutor_api_base_url' => 'https://api.example.test/tutor-api',
      'tds_environment' => 'qa-a',
    ]);
    $clientA->list();

    $historyB = [];
    $clientB = $this->client([
      new Response(200, [], $this->collectionJson()),
    ], $historyB, $cache, [
      'tutor_api_base_url' => 'https://api.example.test/tutor-api',
      'tds_environment' => 'qa-b',
    ]);
    $clientB->list();

    self::assertCount(2, $cacheIds);
    self::assertNotSame($cacheIds[0], $cacheIds[1]);
  }

  /**
   * Cria cliente com transporte e tempo deterministicos.
   *
   * @param array<\Psr\Http\Message\ResponseInterface> $responses
   *   Respostas HTTP.
   * @param array<int, array<string, mixed>> $history
   *   Historico por referencia.
   * @param \Drupal\Core\Cache\CacheBackendInterface $cache
   *   Backend de cache mockado.
   * @param array<string, mixed>|null $settings
   *   Settings opcionais.
   */
  private function client(
    array $responses,
    array &$history,
    CacheBackendInterface $cache,
    ?array $settings = NULL,
  ): PublicCatalogClient {
    $handler = new MockHandler($responses);
    $stack = HandlerStack::create($handler);
    $stack->push(Middleware::history($history));
    $time = $this->createMock(TimeInterface::class);
    $time->method('getCurrentTime')->willReturn(1000);
    return new PublicCatalogClient(
      new Client(['handler' => $stack]),
      new Settings($settings ?? [
        'tutor_api_base_url' => 'https://api.example.test/tutor-api',
        'tds_environment' => 'qa',
      ]),
      new Php(),
      $time,
      $cache,
    );
  }

  /**
   * Retorna um curso sintetico publicado.
   *
   * @param array<string, mixed> $overrides
   *   Sobrescritas sinteticas.
   *
   * @return array<string, mixed>
   *   Curso sintetico.
   */
  private function course(array $overrides = []): array {
    return array_replace([
      'slug' => 'curso-publico',
      'title' => 'Curso publico',
      'status' => 'published',
      'published_version_label' => 'v1',
      'updated_at' => '2026-10-08T12:00:00Z',
      'summary' => 'Resumo aprovado.',
      'cover_public_url' => 'https://cdn.example.test/course.jpg',
      'public_workload_text' => '40 horas',
      'public_audience_text' => 'Publico aprovado',
    ], $overrides);
  }

  /**
   * Colecao JSON sintetica.
   */
  private function collectionJson(): string {
    return json_encode([
      'courses' => [$this->course()],
      'offset' => 0,
      'limit' => 50,
      'total' => 1,
    ], JSON_THROW_ON_ERROR);
  }

}
