<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_editorial_ai\Unit;

use Drupal\Tests\UnitTestCase;
use Drupal\tds_editorial_ai\Client\OpenRouterClient;
use Drupal\tds_editorial_ai\Exception\EditorialAiException;
use GuzzleHttp\Client;
use GuzzleHttp\ClientInterface;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Middleware;
use GuzzleHttp\Psr7\Response;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;

/**
 * Exercises the actual HTTP adapter with an in-memory handler, never network.
 */
#[CoversClass(OpenRouterClient::class)]
#[Group('tds_editorial_ai')]
final class OpenRouterClientTest extends UnitTestCase {

  /**
   * Tests run without access to a real environment credential.
   */
  protected function setUp(): void {
    parent::setUp();
    putenv('TDS_EDITORIAL_OPENROUTER_API_KEY=synthetic-editorial-test-key');
  }

  /**
   * {@inheritdoc}
   */
  protected function tearDown(): void {
    putenv('TDS_EDITORIAL_OPENROUTER_API_KEY');
    parent::tearDown();
  }

  /**
   * Verifies fixed endpoint/model, selected-only payload and bounded options.
   */
  public function testBoundedRequest(): void {
    $history = [];
    $payload = ['choices' => [['message' => ['content' => 'Proposta sintética.']]]];
    $client = $this->client([new Response(200, [], json_encode($payload))], $history);
    self::assertSame('Proposta sintética.', $client->suggest('summarize', 'Texto selecionado.'));
    self::assertCount(1, $history);
    $request = $history[0]['request'];
    $options = $history[0]['options'];
    self::assertSame('https://openrouter.ai/api/v1/chat/completions', (string) $request->getUri());
    self::assertSame('Bearer synthetic-editorial-test-key', $request->getHeaderLine('Authorization'));
    $data = json_decode((string) $request->getBody(), TRUE);
    self::assertSame(['model', 'stream', 'max_tokens', 'messages'], array_keys($data));
    self::assertSame(OpenRouterClient::MODEL, $data['model']);
    self::assertFalse($data['stream']);
    self::assertSame(512, $data['max_tokens']);
    self::assertCount(2, $data['messages']);
    self::assertSame(['role' => 'user', 'content' => 'Texto selecionado.'], $data['messages'][1]);
    self::assertFalse($options['allow_redirects']);
    self::assertSame(15, $options['timeout']);
    self::assertSame(3, $options['connect_timeout']);
    self::assertTrue($options['verify']);
  }

  /**
   * An upstream failure is not retried, chained, logged or exposed.
   */
  public function testExceptionSanitizedWithoutRetry(): void {
    $http = $this->createMock(ClientInterface::class);
    $http->expects(self::once())->method('request')->willThrowException(new \RuntimeException('PRIVATE-PROMPT-KEY'));
    $client = new OpenRouterClient($http);
    try {
      $client->suggest('tone', 'Seleção.');
      self::fail('Expected sanitized failure.');
    }
    catch (EditorialAiException $error) {
      self::assertSame('provider_unavailable', $error->getMessage());
      self::assertNull($error->getPrevious());
    }
  }

  /**
   * Redirect/error/oversized/tool responses are never followed or returned.
   */
  public function testUnsafeResponsesRejected(): void {
    foreach ([
      new Response(302, ['Location' => 'https://example.invalid/leak']),
      new Response(429, [], 'PRIVATE-UPSTREAM-PAYLOAD'),
      new Response(200, [], str_repeat('x', 32769)),
      new Response(200, [], '{"choices":[{"message":{"content":"text","tool_calls":[{}]}}]}'),
      new Response(200, [], '{"choices":[]}'),
    ] as $response) {
      $history = [];
      try {
        $this->client([$response], $history)->suggest('spell_fix', 'Texto.');
        self::fail('Unsafe response accepted.');
      }
      catch (EditorialAiException $error) {
        self::assertContains($error->errorCode, ['invalid_provider_response', 'provider_unavailable']);
        self::assertCount(1, $history);
      }
    }
  }

  /**
   * Missing credential prevents even the mock transport from being invoked.
   */
  public function testMissingCredentialFailsClosed(): void {
    putenv('TDS_EDITORIAL_OPENROUTER_API_KEY');
    $history = [];
    try {
      $this->client([], $history)->suggest('summarize', 'Texto.');
      self::fail('Missing credential accepted.');
    }
    catch (EditorialAiException $error) {
      self::assertSame('provider_not_configured', $error->errorCode);
      self::assertSame([], $history);
    }
  }

  /**
   * Download callbacks abort oversized declared and chunked upstream responses.
   */
  public function testDownloadLimits(): void {
    $http = $this->createMock(ClientInterface::class);
    $http->expects(self::once())->method('request')->willReturnCallback(static function ($method, $uri, $options) {
      foreach ([
        static fn() => $options['on_headers'](new Response(200, ['Content-Length' => '32769'])),
        static fn() => $options['progress'](0, 32769),
      ] as $callback) {
        try {
          $callback();
          self::fail('Oversized download accepted.');
        }
        catch (EditorialAiException $error) {
          self::assertSame('invalid_provider_response', $error->errorCode);
        }
      }
      $options['on_headers'](new Response(200, ['Content-Length' => '100']));
      $options['progress'](100, 100);
      return new Response(200, [], '{"choices":[{"message":{"content":"synthetic"}}]}');
    });
    self::assertSame('synthetic', (new OpenRouterClient($http))->suggest('tone', 'Texto.'));
  }

  /**
   * Builds an injected fake HTTP stack; no fallback network handler exists.
   */
  private function client(array $responses, array &$history): OpenRouterClient {
    $stack = HandlerStack::create(new MockHandler($responses));
    $stack->push(Middleware::history($history));
    return new OpenRouterClient(new Client(['handler' => $stack]));
  }

}
