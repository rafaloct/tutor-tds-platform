<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_support_certificates\Unit;

use Drupal\Core\Site\Settings;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_support_certificates\Client\SupportCertificatesClientInterface;
use Drupal\tds_support_certificates\Controller\SupportCertificatesController;
use Drupal\tds_support_certificates\Security\ExternalUrlPolicy;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Group;

/**
 * Browser responses never cache signed identities or expose bearer tokens.
 */
#[CoversClass(SupportCertificatesController::class)]
#[Group('tds_support_certificates')]
final class SupportCertificatesControllerTest extends UnitTestCase {

  /**
   * Disabled widget causes no upstream identity fetch.
   */
  public function testDisabledByDefault(): void {
    $client = $this->createMock(SupportCertificatesClientInterface::class);
    $client->expects(self::never())->method('identity');
    $response = $this->controller($client, FALSE)->identity();
    self::assertSame(503, $response->getStatusCode());
    self::assertTrue($response->headers->hasCacheControlDirective('no-store'));
  }

  /**
   * Signed identity is delivered only by the no-store runtime endpoint.
   */
  public function testIdentityResponse(): void {
    $client = $this->createMock(SupportCertificatesClientInterface::class);
    $identity = ['identifier' => 'staging:user-1', 'identifier_hash' => str_repeat('a', 64)];
    $client->method('identity')->willReturn($identity);
    $response = $this->controller($client)->identity();
    self::assertSame(200, $response->getStatusCode());
    self::assertTrue($response->headers->hasCacheControlDirective('no-store'));
    self::assertSame('no-referrer', $response->headers->get('Referrer-Policy'));
    self::assertSame($identity + ['base_url' => 'https://chat.example.test', 'website_token' => 'public-inbox'], json_decode($response->getContent(), TRUE));
  }

  /**
   * Failures retain no-store and never return exception details.
   */
  public function testExpiredIdentity(): void {
    $client = $this->createMock(SupportCertificatesClientInterface::class);
    $client->method('identity')->willThrowException(new GatewayException('session_required', 401));
    $response = $this->controller($client)->identity();
    self::assertSame(401, $response->getStatusCode());
    self::assertTrue($response->headers->hasCacheControlDirective('no-store'));
    self::assertSame(['error' => 'session_required'], json_decode($response->getContent(), TRUE));
  }

  /**
   * Private page failure states are explicit and have no stale certificates.
   */
  #[DataProvider('pageErrors')]
  public function testPrivatePageErrors(int $status, string $state): void {
    $client = $this->createMock(SupportCertificatesClientInterface::class);
    $client->method('certificates')->willThrowException(new GatewayException('failure', $status));
    $page = $this->controller($client)->certificates();
    self::assertSame($state, $page['#state']);
    self::assertSame([], $page['#certificates']);
    self::assertSame(0, $page['#cache']['max-age']);
    self::assertContains(['Cache-Control', 'no-store, private', TRUE], $page['#attached']['http_header']);
  }

  /**
   * Authentication, authorization, upstream and divergent-reference failures.
   */
  public static function pageErrors(): array {
    return [[401, 'session_required'], [403, 'access_denied'], [503, 'unavailable'], [502, 'unavailable']];
  }

  /**
   * Public handoff does not call the private API or synthesize a verifier.
   */
  public function testPublicVerifierUnavailable(): void {
    $client = $this->createMock(SupportCertificatesClientInterface::class);
    $client->expects(self::never())->method('certificates');
    self::assertNull($this->controller($client)->verification()['#verifier']);
  }

  /**
   * Controller with synthetic, operator-owned configuration only.
   */
  private function controller(SupportCertificatesClientInterface $client, bool $enabled = TRUE): SupportCertificatesController {
    $settings = new Settings([
      'tds_chatwoot_enabled' => $enabled,
      'tds_chatwoot_origin' => 'https://chat.example.test',
      'tds_chatwoot_allowed_origins' => ['https://chat.example.test'],
      'tds_chatwoot_website_token' => 'public-inbox',
    ]);
    return new SupportCertificatesController($client, new ExternalUrlPolicy($settings), $settings, 'modules/custom/tds_support_certificates');
  }

}
