<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Storage;

use Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet;

/**
 * Store de tokens TDS isolado por sessao Drupal.
 */
interface TutorTokenStoreInterface {

  /**
   * Le os tokens da sessao atual.
   */
  public function load(): ?TutorTokenSet;

  /**
   * Substitui atomicamente os tokens da sessao atual.
   */
  public function save(TutorTokenSet $tokens): void;

  /**
   * Remove o contexto TDS local.
   */
  public function clear(): void;

}
