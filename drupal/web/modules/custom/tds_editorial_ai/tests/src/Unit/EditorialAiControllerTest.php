<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_editorial_ai\Unit;

use Drupal\Core\Field\FieldItemListInterface;
use Drupal\Core\Session\AccountProxyInterface;
use Drupal\node\NodeInterface;
use Drupal\Tests\UnitTestCase;
use Drupal\tds_editorial_ai\Client\EditorialAiClientInterface;
use Drupal\tds_editorial_ai\Controller\EditorialAiController;
use Drupal\tds_editorial_ai\Policy\EditorialAiPolicy;
use Drupal\tds_editorial_ai\Quota\EditorialAiQuotaInterface;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;

/**
 * Exercises endpoint failures without a provider, database or outbound network.
 */
#[CoversClass(EditorialAiController::class)]
#[Group('tds_editorial_ai')]
final class EditorialAiControllerTest extends UnitTestCase {

  /**
   * Proposals never mutate entities; transport/release errors stay private.
   */
  public function testProposalAndFailureIsolation(): void {
    foreach (['success', 'transport_failure', 'release_failure', 'disabled', 'invalid', 'extra_field'] as $scenario) {
      $called = in_array($scenario, ['success', 'transport_failure', 'release_failure'], TRUE);
      $policy = new EditorialAiPolicy($this->getConfigFactoryStub(['tds_editorial_ai.settings' => ['enabled' => $scenario !== 'disabled']]));
      $account = $this->createMock(AccountProxyInterface::class);
      $account->method('isAuthenticated')->willReturn(TRUE);
      $account->method('hasPermission')->willReturn(TRUE);
      $account->method('id')->willReturn('42');
      $body = $this->createMock(FieldItemListInterface::class);
      $body->method('access')->willReturn(TRUE);
      $body->expects(self::never())->method('getValue');
      $node = $this->createMock(NodeInterface::class);
      $node->method('isNew')->willReturn(FALSE);
      $node->method('bundle')->willReturn('tds_faq');
      $node->method('access')->willReturn(TRUE);
      $node->method('hasField')->willReturn(TRUE);
      $node->method('get')->willReturn($body);
      $node->expects(self::never())->method('save');
      $node->expects(self::never())->method('set');
      $client = $this->createMock(EditorialAiClientInterface::class);
      $invocation = $client->expects($called ? self::once() : self::never())->method('suggest')->with('tone', 'Seleção explícita.');
      if ($scenario === 'transport_failure') {
        $invocation->willThrowException(new \RuntimeException('PRIVATE-ERROR-TEXT'));
      }
      else {
        $invocation->willReturn('<script>synthetic untrusted output</script>');
      }
      $quota = $this->createMock(EditorialAiQuotaInterface::class);
      $quota->expects($called ? self::once() : self::never())->method('reserve')->with('42');
      $release = $quota->expects($called ? self::once() : self::never())->method('release');
      if ($scenario === 'release_failure') {
        $release->willThrowException(new \RuntimeException('PRIVATE-RELEASE-TEXT'));
      }
      $payload = ['action' => 'tone', 'selection' => 'Seleção explícita.'];
      if ($scenario === 'extra_field') {
        $payload['model'] = 'unauthorized';
      }
      $request = Request::create('/synthetic', 'POST', [], [], [], ['CONTENT_TYPE' => 'application/json'], $scenario === 'invalid' ? 'invalid JSON' : json_encode($payload));
      $response = (new EditorialAiController($policy, $client, $quota, $account))->suggest($request, $node);
      self::assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
      self::assertStringNotContainsString('PRIVATE-', $response->getContent());
      self::assertStringNotContainsString('<script>', $response->getContent());
      self::assertSame('application/json', $response->headers->get('Content-Type'));
      self::assertSame($scenario === 'success' ? 200 : (in_array($scenario, ['invalid', 'extra_field'], TRUE) ? 422 : 503), $response->getStatusCode());
    }
  }

}
