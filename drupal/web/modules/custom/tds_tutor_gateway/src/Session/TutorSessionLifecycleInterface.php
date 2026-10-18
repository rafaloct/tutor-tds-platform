<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Session;

/**
 * Rotates the browser session boundary without removing editorial attributes.
 */
interface TutorSessionLifecycleInterface {

  /**
   * Destroys the previous session ID and preserves non-TDS session attributes.
   */
  public function rotateId(): void;

}
