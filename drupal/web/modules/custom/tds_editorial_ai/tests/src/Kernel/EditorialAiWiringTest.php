<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_editorial_ai\Kernel;

use Drupal\Core\Access\AccessResult;
use Drupal\Core\Access\CsrfRequestHeaderAccessCheck;
use Drupal\Core\Routing\RouteMatch;
use Drupal\Core\Session\AccountInterface;
use Drupal\KernelTests\KernelTestBase;
use Drupal\node\NodeInterface;
use Drupal\tds_editorial_ai\Client\EditorialAiClientInterface;
use Drupal\tds_editorial_ai\Controller\EditorialAiController;
use Drupal\tds_editorial_ai\Quota\EditorialAiQuotaInterface;
use PHPUnit\Framework\Attributes\Group;
use PHPUnit\Framework\Attributes\RunTestsInSeparateProcesses;
use Symfony\Component\HttpFoundation\Request;

/**
 * Exercises real service wiring, installed defaults and compiled route checks.
 */
#[Group('tds_editorial_ai')]
#[RunTestsInSeparateProcesses]
final class EditorialAiWiringTest extends KernelTestBase {

  /**
   * {@inheritdoc}
   */
  protected static $modules = [
    'system', 'user', 'field', 'node', 'filter', 'text', 'tds_editorial_ai',
  ];

  /**
   * Uses in-memory SQLite regardless of the suite's mysql default.
   */
  protected function setUp(): void {
    // Each test runs in its own PHP process; no other suite loses its DB URL.
    putenv('SIMPLETEST_DB=sqlite://localhost/:memory:');
    parent::setUp();
  }

  /**
   * Service construction and a disabled request never invoke HTTP or quota.
   */
  public function testWiringAndDisabledDefault(): void {
    $this->installConfig(['tds_editorial_ai']);
    self::assertFalse($this->config('tds_editorial_ai.settings')->get('enabled'));
    self::assertInstanceOf(EditorialAiClientInterface::class, $this->container->get('tds_editorial_ai.client'));
    self::assertInstanceOf(EditorialAiQuotaInterface::class, $this->container->get('tds_editorial_ai.quota'));
    $client = $this->createMock(EditorialAiClientInterface::class);
    $client->expects(self::never())->method('suggest');
    $quota = $this->createMock(EditorialAiQuotaInterface::class);
    $quota->expects(self::never())->method('reserve');
    $this->container->set('tds_editorial_ai.client', $client);
    $this->container->set('tds_editorial_ai.quota', $quota);
    $node = $this->createMock(NodeInterface::class);
    $node->expects(self::never())->method('save');
    $request = Request::create('/synthetic', 'POST', [], [], [], ['CONTENT_TYPE' => 'application/json'], '{"action":"tone","selection":"synthetic"}');
    $response = EditorialAiController::create($this->container)->suggest($request, $node);
    self::assertSame(503, $response->getStatusCode());
    self::assertSame(['error' => 'pilot_disabled'], json_decode($response->getContent(), TRUE));
    self::assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
  }

  /**
   * The compiled route applies real Drupal permission, entity and CSRF checks.
   */
  public function testCompiledRouteChecks(): void {
    $route = $this->container->get('router.route_provider')->getRouteByName('tds_editorial_ai.suggest');
    self::assertSame(['POST'], $route->getMethods());
    self::assertSame('TRUE', $route->getRequirement('_csrf_request_header_token'));
    $scenarios = [
      'valid', 'missing_csrf', 'invalid_csrf',
      'missing_permission', 'node_denied', 'anonymous',
    ];
    foreach ($scenarios as $scenario) {
      $account = $this->createMock(AccountInterface::class);
      $account->method('isAuthenticated')->willReturn($scenario !== 'anonymous');
      $account->method('hasPermission')->willReturn(!in_array($scenario, ['missing_permission', 'anonymous'], TRUE));
      $node = $this->createMock(NodeInterface::class);
      $node->method('access')->with('update', $account, TRUE)->willReturn($scenario === 'node_denied' ? AccessResult::forbidden() : AccessResult::allowed());
      $request = Request::create('https://fixture.invalid/tds/editorial-ai/suggest/42', 'POST');
      // Reproduce session-cookie authentication without a browser or real user.
      $options = $this->container->get('session_configuration')->getOptions($request);
      $request->cookies->set($options['name'], 'synthetic-session');
      if ($scenario !== 'missing_csrf') {
        $token = $this->container->get('csrf_token')->get(CsrfRequestHeaderAccessCheck::TOKEN_KEY);
        $request->headers->set('X-CSRF-Token', $scenario === 'invalid_csrf' ? 'invalid' : $token);
      }
      $match = new RouteMatch('tds_editorial_ai.suggest', $route, ['node' => $node], ['node' => '42']);
      $allowed = $this->container->get('access_manager')->check($match, $account, $request);
      self::assertSame($scenario === 'valid', $allowed, $scenario);
    }
  }

}
