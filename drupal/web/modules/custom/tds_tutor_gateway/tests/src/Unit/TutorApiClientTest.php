<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_tutor_gateway\Unit;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Component\Uuid\Php;
use Drupal\Core\Site\Settings;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_tutor_gateway\Client\TutorApiClient;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use GuzzleHttp\Client;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Middleware;
use GuzzleHttp\Psr7\Response;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Group;

/**
 * Testa o cliente HTTP tipado da FastAPI.
 */
#[CoversClass(TutorApiClient::class)]
#[Group('tds_tutor_gateway')]
final class TutorApiClientTest extends UnitTestCase {

  /**
   * Login envia credenciais somente upstream e valida TokenResponse.
   */
  public function testLoginContract(): void {
    $history = [];
    $client = $this->client([
      new Response(200, [], json_encode($this->tokenPayload(), JSON_THROW_ON_ERROR)),
    ], $history);

    $result = $client->login('00000000000', 'synthetic-password');

    self::assertSame('access-value', $result['tokens']->accessToken);
    self::assertSame('refresh-value', $result['tokens']->refreshToken);
    self::assertSame(1300, $result['tokens']->expiresAt);
    self::assertSame('student', $result['user']['role']);
    self::assertCount(1, $history);
    self::assertSame('POST', $history[0]['request']->getMethod());
    self::assertSame('/tutor-api/auth/login', $history[0]['request']->getUri()->getPath());
    self::assertNotSame('', $history[0]['request']->getHeaderLine('X-Request-ID'));
    self::assertSame('', $history[0]['request']->getHeaderLine('Authorization'));
  }

  /**
   * Login invalido e sanitizado e POST nao tem retry automatico.
   */
  public function testInvalidLoginIsSanitizedWithoutRetry(): void {
    $history = [];
    $client = $this->client([
      new Response(401, [], '{"detail":"credential database detail"}'),
      new Response(200, [], '{}'),
    ], $history);

    try {
      $client->login('00000000000', 'invalid-password');
      self::fail('Era esperado login invalido.');
    }
    catch (GatewayException $error) {
      self::assertSame('invalid_credentials', $error->publicCode());
      self::assertSame(401, $error->httpStatus());
      self::assertStringNotContainsString('database', $error->getMessage());
      self::assertCount(1, $history);
    }
  }

  /**
   * GET seguro repete uma vez; POST de login nunca e repetido.
   */
  public function testSafeRetryOnlyForGet(): void {
    $history = [];
    $client = $this->client([
      new Response(503, [], '{}'),
      new Response(200, [], json_encode([
        'id' => 'user-1',
        'name' => 'Pessoa QA',
        'role' => 'student',
      ], JSON_THROW_ON_ERROR)),
    ], $history);

    self::assertSame('user-1', $client->me('access-value')['id']);
    self::assertCount(2, $history);
    self::assertSame('Bearer access-value', $history[1]['request']->getHeaderLine('Authorization'));
  }

  /**
   * HTTP fora de loopback local e recusado antes da rede.
   */
  public function testNonLocalRequiresHttps(): void {
    $history = [];
    $client = $this->client([], $history, [
      'tutor_api_base_url' => 'http://api.example.test/tutor-api',
      'tds_environment' => 'staging',
    ]);

    try {
      $client->me('access-value');
      self::fail('Era esperado fail-closed de URL.');
    }
    catch (GatewayException $error) {
      self::assertSame('gateway_not_configured', $error->publicCode());
      self::assertSame(503, $error->httpStatus());
      self::assertSame([], $history);
    }
  }

  /**
   * Userinfo, query e fragment sao recusados individualmente.
   *
   */
  #[DataProvider('unsafeBaseUrlProvider')]
  public function testUnsafeBaseUrlPartsAreRejected(string $baseUrl): void {
    $history = [];
    $client = $this->client([], $history, [
      'tutor_api_base_url' => $baseUrl,
      'tds_environment' => 'staging',
    ]);

    try {
      $client->me('access-value');
      self::fail('Era esperado fail-closed de URL.');
    }
    catch (GatewayException $error) {
      self::assertSame('gateway_not_configured', $error->publicCode());
      self::assertSame([], $history);
    }
  }

  /**
   * URLs inseguras sinteticas.
   *
   * @return array<string, array{string}>
   *   Casos.
   */
  public static function unsafeBaseUrlProvider(): array {
    return [
      'userinfo' => ['https://user@api.example.test/tutor-api'],
      'query' => ['https://api.example.test/tutor-api?target=other'],
      'fragment' => ['https://api.example.test/tutor-api#fragment'],
    ];
  }

  /**
   * Resposta invalida nao vaza corpo upstream.
   */
  public function testInvalidResponseIsSanitized(): void {
    $history = [];
    $client = $this->client([new Response(200, [], '{invalid')], $history);

    $this->expectException(GatewayException::class);
    $this->expectExceptionMessage('invalid_api_response');
    $client->me('access-value');
  }

  /**
   * Status upstream e convertido em codigo estavel.
   */
  public function testUnauthorizedIsSanitized(): void {
    $history = [];
    $client = $this->client([
      new Response(401, [], '{"detail":"upstream detail must not escape"}'),
    ], $history);

    try {
      $client->me('expired');
      self::fail('Era esperado 401.');
    }
    catch (GatewayException $error) {
      self::assertSame('invalid_or_expired_session', $error->publicCode());
      self::assertStringNotContainsString('upstream', $error->getMessage());
    }
  }

  /**
   * Cria cliente com fila HTTP deterministica.
   *
   * @param array<\Psr\Http\Message\ResponseInterface> $responses
   *   Respostas simuladas.
   * @param array<int, array<string, mixed>> $history
   *   Historico por referencia.
   * @param array<string, mixed>|null $settings
   *   Settings opcionais.
   */
  private function client(array $responses, array &$history, ?array $settings = NULL): TutorApiClient {
    $mock = new MockHandler($responses);
    $stack = HandlerStack::create($mock);
    $stack->push(Middleware::history($history));
    $time = $this->createMock(TimeInterface::class);
    $time->method('getCurrentTime')->willReturn(1000);
    return new TutorApiClient(
      new Client(['handler' => $stack]),
      new Settings($settings ?? [
        'tutor_api_base_url' => 'https://api.example.test/tutor-api',
        'tds_environment' => 'qa',
      ]),
      new Php(),
      $time,
    );
  }

  /**
   * TokenResponse sintetico.
   *
   * @return array<string, mixed>
   *   Payload.
   */
  private function tokenPayload(): array {
    return [
      'access_token' => 'access-value',
      'refresh_token' => 'refresh-value',
      'token_type' => 'bearer',
      'expires_in' => 300,
      'user' => [
        'id' => 'user-1',
        'name' => 'Pessoa QA',
        'role' => 'student',
      ],
    ];
  }

}
