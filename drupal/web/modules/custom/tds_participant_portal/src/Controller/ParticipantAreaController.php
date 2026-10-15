<?php

declare(strict_types=1);

namespace Drupal\tds_participant_portal\Controller;

use Drupal\Core\Controller\ControllerBase;
use Drupal\tds_participant_portal\Service\ParticipantAreaProviderInterface;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Renderiza a area complementar sem persistir dados academicos no Drupal.
 */
final class ParticipantAreaController extends ControllerBase {

  /**
   * Construtor.
   */
  public function __construct(
    private readonly ParticipantAreaProviderInterface $provider,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static($container->get('tds_participant_portal.provider'));
  }

  /**
   * Retorna a area do participante com mensagens sanitizadas.
   *
   * @return array<string, mixed>
   *   Render array nao cacheavel.
   */
  public function dashboard(): array {
    try {
      $data = $this->provider->dashboard();
      $variables = [
        'state' => $data['state'],
        'message' => NULL,
        'user' => $data['user'],
        'classes' => $data['classes'],
        'certificates' => $data['certificates'],
      ];
    }
    catch (GatewayException $error) {
      $variables = [
        'state' => $this->viewState($error),
        'message' => $this->message($error),
        'user' => NULL,
        'classes' => [],
        'certificates' => [],
      ];
    }

    return [
      '#theme' => 'tds_participant_area',
      '#state' => $variables['state'],
      '#message' => $variables['message'],
      '#user' => $variables['user'],
      '#classes' => $variables['classes'],
      '#certificates' => $variables['certificates'],
      '#attached' => [
        'library' => ['tds_participant_portal/participant-area'],
      ],
      '#cache' => ['max-age' => 0],
    ];
  }

  /**
   * Mapeia status sem propagar detalhe upstream.
   */
  private function viewState(GatewayException $error): string {
    return match ($error->httpStatus()) {
      401 => 'session_required',
      403 => 'access_denied',
      default => 'unavailable',
    };
  }

  /**
   * Retorna texto constante e seguro.
   */
  private function message(GatewayException $error): string {
    return match ($error->httpStatus()) {
      401 => 'Entre novamente para acessar seus dados.',
      403 => 'A FastAPI nao autorizou este acesso.',
      default => 'Sua area esta temporariamente indisponivel.',
    };
  }

}
