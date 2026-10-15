<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_operator_portal\Unit;

use Drupal\Tests\UnitTestCase;
use Drupal\tds_operator_portal\State\OperationsState;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Group;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpFoundation\Session\Session;
use Symfony\Component\HttpFoundation\Session\Storage\MockArraySessionStorage;

/**
 * Verifica privacidade e limpeza do estado do fluxo.
 */
#[CoversClass(OperationsState::class)]
#[Group('tds_operator_portal')]
final class OperationsStateTest extends UnitTestCase {

  /**
   * Senhas nunca entram no estado e logout pode limpar prova e snapshot.
   */
  public function testPasswordIsDiscardedAndLogoutMidFlowClearsState(): void {
    $stack = new RequestStack();
    $request = Request::create('/operacoes');
    $request->setSession(new Session(new MockArraySessionStorage()));
    $stack->push($request);
    $state = new OperationsState($stack);
    $state->save([
      'person_id' => 'person-1',
      'identity_proof' => 'signed-proof',
      'snapshot' => ['revision' => 1],
      'registration_password' => 'must-not-persist',
      'password' => 'must-not-persist-either',
    ]);
    self::assertArrayNotHasKey('password', $state->load());
    self::assertArrayNotHasKey('registration_password', $state->load());
    self::assertSame('signed-proof', $state->load()['identity_proof']);

    $state->clear();
    self::assertSame([], $state->load());
  }

}
