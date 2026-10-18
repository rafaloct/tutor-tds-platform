<?php

declare(strict_types=1);

namespace Drupal\Tests\tds_participant_portal\Unit;

use Drupal\Tests\UnitTestCase;
use PHPUnit\Framework\Attributes\Group;

/**
 * Guarda os landmarks, status e foco minimos do template autenticado.
 */
#[Group('tds_participant_portal')]
final class ParticipantAreaAccessibilityTest extends UnitTestCase {

  /**
   * Template e CSS mantem estrutura acessivel sem depender de JS.
   */
  public function testTemplateHasAccessibleStructure(): void {
    $root = dirname(__DIR__, 3);
    $template = file_get_contents($root . '/templates/tds-participant-area.html.twig');
    $css = file_get_contents($root . '/css/participant-area.css');

    self::assertIsString($template);
    self::assertStringContainsString('<h1', $template);
    self::assertStringContainsString('<h2', $template);
    self::assertStringContainsString('role="alert"', $template);
    self::assertStringContainsString('role="status"', $template);
    self::assertStringContainsString('<progress', $template);
    self::assertStringContainsString(':focus-visible', (string) $css);
  }

}
