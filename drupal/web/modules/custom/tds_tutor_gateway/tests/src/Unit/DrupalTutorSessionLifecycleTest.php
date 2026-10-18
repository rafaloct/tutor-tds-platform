<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_tutor_gateway\Unit;

use Drupal\Tests\UnitTestCase;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\DrupalTutorSessionLifecycle;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpFoundation\Session\SessionInterface;

/**
 * Fixation protection must destroy the old ID without clearing CMS attributes.
 */
#[CoversClass(DrupalTutorSessionLifecycle::class)]
#[Group('tds_tutor_gateway')]
final class DrupalTutorSessionLifecycleTest extends UnitTestCase {

  /**
   * Successful migration destroys the old record and preserves editorial state.
   */
  public function testDestroyOldIdWithoutInvalidatingEditorialSession(): void {
    $session = $this->createMock(SessionInterface::class);
    $session->method('getId')->willReturnOnConsecutiveCalls('old-id', 'new-id', 'new-id');
    $session->expects(self::once())->method('migrate')->with(TRUE)->willReturn(TRUE);
    $session->expects(self::never())->method('invalidate');
    $session->expects(self::never())->method('clear');
    $this->lifecycle($session)->rotateId();
  }

  /**
   * False success, unchanged or empty IDs cannot authorize persisting tokens.
   */
  #[DataProvider('failures')]
  public function testFailedRotation(bool $result, string $newId): void {
    $session = $this->createMock(SessionInterface::class);
    $session->method('getId')->willReturnOnConsecutiveCalls('old-id', $newId, $newId);
    $session->method('migrate')->with(TRUE)->willReturn($result);
    $this->expectExceptionMessage('session_rotation_failed');
    $this->lifecycle($session)->rotateId();
  }

  /**
   * Failure cases from the storage migration boundary.
   */
  public static function failures(): array {
    return [[FALSE, 'old-id'], [TRUE, 'old-id'], [TRUE, '']];
  }

  /**
   * Storage exceptions do not expose a previous exception containing cookies.
   */
  public function testExceptionIsSanitized(): void {
    $session = $this->createMock(SessionInterface::class);
    $session->method('migrate')->willThrowException(new \RuntimeException('private-cookie'));
    try {
      $this->lifecycle($session)->rotateId();
      self::fail('Expected safe rotation failure.');
    }
    catch (GatewayException $error) {
      self::assertSame(503, $error->httpStatus());
      self::assertNull($error->getPrevious());
      self::assertStringNotContainsString('private-cookie', $error->getMessage());
    }
  }

  /**
   * Builds an existing request/session boundary with no global service lookup.
   */
  private function lifecycle(SessionInterface $session): DrupalTutorSessionLifecycle {
    $request = new Request();
    $request->setSession($session);
    $requests = new RequestStack();
    $requests->push($request);
    return new DrupalTutorSessionLifecycle($requests);
  }

}
