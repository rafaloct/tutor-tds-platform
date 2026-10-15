<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_editorial_ai\Unit;

use Drupal\Core\Flood\FloodInterface;
use Drupal\Core\Lock\LockBackendInterface;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_editorial_ai\Exception\EditorialAiException;
use Drupal\tds_editorial_ai\Quota\EditorialAiQuota;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;

/**
 * Tests reservation ordering and contention with fake lock/flood state.
 */
#[CoversClass(EditorialAiQuota::class)]
#[Group('tds_editorial_ai')]
final class EditorialAiQuotaTest extends UnitTestCase {

  /**
   * Check/register cannot race; counted failures are not refunded on release.
   */
  public function testQuotaAndContention(): void {
    $held = FALSE;
    $attempts = [];
    $lock = $this->createMock(LockBackendInterface::class);
    $lock->method('acquire')->with(EditorialAiQuota::LOCK_NAME, 60.0)->willReturnCallback(static function () use (&$held): bool {
      if ($held) {
        return FALSE;
      }
      $held = TRUE;
      return TRUE;
    });
    $lock->method('release')->willReturnCallback(static function () use (&$held): void {
      $held = FALSE;
    });
    $flood = $this->createMock(FloodInterface::class);
    $flood->method('isAllowed')->willReturnCallback(static function ($event, $threshold, $window, $identifier) use (&$held, &$attempts): bool {
      self::assertTrue($held);
      self::assertSame(10, $threshold);
      self::assertSame(3600, $window);
      return ($attempts[$identifier] ?? 0) < $threshold;
    });
    $flood->method('register')->willReturnCallback(static function ($event, $window, $identifier) use (&$held, &$attempts): void {
      self::assertTrue($held);
      $attempts[$identifier] = ($attempts[$identifier] ?? 0) + 1;
    });
    $flood->expects(self::never())->method('clear');
    $first = new EditorialAiQuota($lock, $flood);
    $second = new EditorialAiQuota($lock, $flood);
    $first->reserve('42');
    try {
      $second->reserve('43');
      self::fail('Contending request accepted.');
    }
    catch (EditorialAiException $error) {
      self::assertSame('editorial_busy', $error->errorCode);
    }
    self::assertSame(['42' => 1], $attempts);
    $first->release();
    for ($i = 1; $i < 10; $i++) {
      $first->reserve('42');
      $first->release();
    }
    try {
      $first->reserve('42');
      self::fail('Eleventh attempt accepted.');
    }
    catch (EditorialAiException $error) {
      self::assertSame('editorial_quota_exceeded', $error->errorCode);
    }
    self::assertFalse($held);
    self::assertSame(10, $attempts['42']);
    $second->reserve('43');
    $second->release();
    self::assertSame(1, $attempts['43']);
  }

  /**
   * A storage failure releases the lease and removes private exception details.
   */
  public function testStorageFailureIsSanitizedAndReleased(): void {
    $lock = $this->createMock(LockBackendInterface::class);
    $lock->method('acquire')->willReturn(TRUE);
    $lock->expects(self::once())->method('release');
    $flood = $this->createMock(FloodInterface::class);
    $flood->method('isAllowed')->willThrowException(new \RuntimeException('PRIVATE-DATABASE-DETAILS'));
    try {
      (new EditorialAiQuota($lock, $flood))->reserve('42');
      self::fail('Storage failure accepted.');
    }
    catch (EditorialAiException $error) {
      self::assertSame('editorial_unavailable', $error->getMessage());
      self::assertNull($error->getPrevious());
    }
  }

}
