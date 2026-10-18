<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_support_certificates\Unit;

use Drupal\Core\Site\Settings;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_support_certificates\Security\ExternalUrlPolicy;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Group;

/**
 * Verifier links cannot become arbitrary destinations or script URLs.
 */
#[CoversClass(ExternalUrlPolicy::class)]
#[Group('tds_support_certificates')]
final class ExternalUrlPolicyTest extends UnitTestCase {

  /**
   * Rejects unsafe URL classes, including exact-origin lookalikes.
   */
  #[DataProvider('unsafeUrls')]
  public function testUnsafeUrl(mixed $url): void {
    $policy = new ExternalUrlPolicy(new Settings(['allowed' => ['https://verify.example.test']]));
    self::assertNull($policy->approved($url, 'allowed'));
  }

  /**
   * Invalid examples must never reach rendered href/src attributes.
   */
  public static function unsafeUrls(): array {
    return [
      [NULL], ['javascript:alert(1)'], ['//verify.example.test/code'],
      ['http://verify.example.test/code'], ['https://verify.example.test.evil.test/code'],
      ['https://user:pass@verify.example.test/code'], ['https://verify.example.test:8443/code'],
      ['https://verify.example.test/code#secret'], ["https://verify.example.test/\ncode"],
      ['https://verify.example.test\\@evil.example.test/code'],
    ];
  }

  /**
   * Official opaque verification paths pass through without interpretation.
   */
  public function testApproved(): void {
    $url = 'https://verify.example.test/check/opaque?code=opaque';
    $policy = new ExternalUrlPolicy(new Settings(['allowed' => ['https://verify.example.test']]));
    self::assertSame($url, $policy->approved($url, 'allowed'));
    self::assertNull($policy->approved($url, 'missing'));
  }

  /**
   * SDK configuration must be an origin, not a path/query-controlled loader.
   */
  public function testWidgetRejectsPath(): void {
    $policy = new ExternalUrlPolicy(new Settings([
      'tds_chatwoot_origin' => 'https://chat.example.test/path',
      'tds_chatwoot_allowed_origins' => ['https://chat.example.test'],
    ]));
    self::assertNull($policy->widgetOrigin());
  }

}
