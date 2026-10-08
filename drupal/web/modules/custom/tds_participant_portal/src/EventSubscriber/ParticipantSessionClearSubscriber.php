<?php

declare(strict_types=1);

namespace Drupal\tds_participant_portal\EventSubscriber;

use Drupal\tds_participant_portal\Cache\ParticipantSessionCacheInterface;
use Drupal\tds_tutor_gateway\Event\TutorSessionClearedEvent;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

/**
 * Remove o cache privado na troca de conta, logout ou refresh recusado.
 */
final class ParticipantSessionClearSubscriber implements EventSubscriberInterface {

  /**
   * Construtor.
   */
  public function __construct(
    private readonly ParticipantSessionCacheInterface $cache,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function getSubscribedEvents(): array {
    return [TutorSessionClearedEvent::NAME => 'onSessionCleared'];
  }

  /**
   * Limpa o snapshot da mesma sessao.
   */
  public function onSessionCleared(TutorSessionClearedEvent $event): void {
    $this->cache->clear();
  }

}
