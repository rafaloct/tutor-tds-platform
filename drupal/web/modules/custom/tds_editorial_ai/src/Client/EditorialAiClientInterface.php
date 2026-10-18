<?php

declare(strict_types=1);

namespace Drupal\tds_editorial_ai\Client;

/**
 * Stateless editorial transport; no history, identity, academic data or tools.
 */
interface EditorialAiClientInterface {

  /**
   * Returns plain proposed text without saving or publishing it.
   */
  public function suggest(string $action, string $selection): string;

}
