<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Event;

use Symfony\Contracts\EventDispatcher\Event;

/**
 * Notifica limpeza ou troca da sessao TDS sem expor tokens.
 */
final class TutorSessionClearedEvent extends Event {

  public const NAME = 'tds_tutor_gateway.session_cleared';

}
