<?php

declare(strict_types=1);

namespace Drupal\tds_operator_portal\State;

use Symfony\Component\HttpFoundation\RequestStack;

/**
 * Estado privado do fluxo operacional na sessao Drupal atual.
 */
final class OperationsState {

  private const KEY = 'tds_operator_portal.flow';

  public function __construct(
    private readonly RequestStack $requestStack,
  ) {}

  /**
   * Retorna o fluxo atual.
   *
   * @return array<string, mixed>
   *   Estado privado.
   */
  public function load(): array {
    $value = $this->requestStack->getSession()->get(self::KEY, []);
    return is_array($value) ? $value : [];
  }

  /**
   * Substitui o fluxo, que nunca deve conter senha.
   *
   * @param array<string, mixed> $state
   *   Novo estado.
   */
  public function save(array $state): void {
    unset($state['password'], $state['registration_password']);
    $this->requestStack->getSession()->set(self::KEY, $state);
  }

  /**
   * Remove busca, prova de identidade, snapshot e comando pendente.
   */
  public function clear(): void {
    $this->requestStack->getSession()->remove(self::KEY);
  }

}
