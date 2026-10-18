<?php

declare(strict_types=1);

namespace Drupal\tds_operator_portal\EventSubscriber;

use Drupal\tds_operator_portal\State\OperationsState;
use Drupal\tds_tutor_gateway\Event\TutorSessionClearedEvent;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

/**
 * Removes private operational state when the academic identity is cleared.
 */
final class OperationsSessionClearSubscriber implements EventSubscriberInterface {

  /**
   * Constructs the subscriber.
   */
  public function __construct(private readonly OperationsState $state) {}

  /**
   * {@inheritdoc}
   */
  public static function getSubscribedEvents(): array {
    return [TutorSessionClearedEvent::NAME => 'onSessionCleared'];
  }

  /**
   * Removes identity proof and pending commands before another account logs in.
   */
  public function onSessionCleared(TutorSessionClearedEvent $event): void {
    $this->state->clear();
  }

}
