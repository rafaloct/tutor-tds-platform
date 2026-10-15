<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_editorial_ai\Unit;

use Drupal\Core\Field\FieldItemListInterface;
use Drupal\Core\Session\AccountInterface;
use Drupal\node\NodeInterface;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_editorial_ai\Exception\EditorialAiException;
use Drupal\tds_editorial_ai\Policy\EditorialAiPolicy;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;

/**
 * Verifies server-side authorization independent of button visibility.
 */
#[CoversClass(EditorialAiPolicy::class)]
#[Group('tds_editorial_ai')]
final class EditorialAiPolicyTest extends UnitTestCase {

  /**
   * Validates characters, not byte length, and rejects caller-defined actions.
   */
  public function testUnicodeAndActionLimits(): void {
    EditorialAiPolicy::validate('summarize', str_repeat('á', 4000));
    foreach ([
      ['summarize', str_repeat('á', 4001)],
      ['publish', 'Texto'],
      ['tone', '  '],
      ['tone', "\xff"],
    ] as [$action, $selection]) {
      try {
        EditorialAiPolicy::validate($action, $selection);
        self::fail('Unsafe request accepted.');
      }
      catch (EditorialAiException $error) {
        self::assertSame('invalid_request', $error->errorCode);
      }
    }
  }

  /**
   * Covers each independent access condition and a saved allowed node.
   */
  public function testAccessBoundaries(): void {
    $scenarios = [
      'allowed', 'disabled', 'anonymous', 'permission', 'new',
      'bundle', 'node_access', 'missing_body', 'field_access',
    ];
    foreach ($scenarios as $scenario) {
      $policy = new EditorialAiPolicy($this->getConfigFactoryStub(['tds_editorial_ai.settings' => ['enabled' => $scenario !== 'disabled']]));
      $account = $this->createMock(AccountInterface::class);
      $account->method('isAuthenticated')->willReturn($scenario !== 'anonymous');
      $account->method('hasPermission')->willReturn($scenario !== 'permission');
      $body = $this->createMock(FieldItemListInterface::class);
      $body->method('access')->willReturn($scenario !== 'field_access');
      $node = $this->createMock(NodeInterface::class);
      $node->method('isNew')->willReturn($scenario === 'new');
      $node->method('bundle')->willReturn($scenario === 'bundle' ? 'tds_event' : 'tds_news');
      $node->method('access')->willReturn($scenario !== 'node_access');
      $node->method('hasField')->with('body')->willReturn($scenario !== 'missing_body');
      $node->method('get')->with('body')->willReturn($body);
      $node->expects(self::never())->method('save');
      try {
        $policy->authorize($node, $account);
        self::assertSame('allowed', $scenario);
      }
      catch (EditorialAiException $error) {
        self::assertSame($scenario === 'disabled' ? 'pilot_disabled' : 'access_denied', $error->errorCode);
        self::assertNotSame('allowed', $scenario);
      }
    }
  }

}
