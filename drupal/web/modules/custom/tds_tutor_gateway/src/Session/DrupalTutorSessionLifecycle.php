<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Session;

use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Symfony\Component\HttpFoundation\RequestStack;

/**
 * Regenerates the Drupal cookie while retaining the separate editorial login.
 */
final class DrupalTutorSessionLifecycle implements TutorSessionLifecycleInterface {

  /**
   * Constructs the lifecycle without starting a session.
   */
  public function __construct(private readonly RequestStack $requests) {}

  /**
   * {@inheritdoc}
   */
  public function rotateId(): void {
    try {
      $session = $this->requests->getSession();
      $oldId = $session->getId();
      // migrate(TRUE) destroys the old record; invalidate() would log out CMS.
      if (!$session->migrate(TRUE) || $session->getId() === '' || $session->getId() === $oldId) {
        throw new \RuntimeException('rotation_not_completed');
      }
    }
    catch (\Throwable) {
      // A failed rotation never authorizes saving newly issued Tutor tokens.
      throw new GatewayException('session_rotation_failed', 503);
    }
  }

}
