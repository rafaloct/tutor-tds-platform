<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Controller;

use Drupal\Core\Controller\ControllerBase;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\TutorSessionManagerInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

/**
 * Superficie web minima; nunca serializa bearer ou refresh token.
 */
final class TutorSessionController extends ControllerBase {

  /**
   * Construtor.
   */
  public function __construct(
    private readonly TutorSessionManagerInterface $sessionManager,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static($container->get('tds_tutor_gateway.session_manager'));
  }

  /**
   * Cria/troca sessao TDS server-side.
   */
  public function login(Request $request): JsonResponse {
    try {
      $payload = json_decode($request->getContent(), TRUE, 8, JSON_THROW_ON_ERROR);
      if (!is_array($payload) || !is_string($payload['cpf'] ?? NULL) || !is_string($payload['password'] ?? NULL)) {
        throw new GatewayException('invalid_request', 422);
      }
      return $this->response([
        'authenticated' => TRUE,
        'user' => $this->sessionManager->login($payload['cpf'], $payload['password']),
      ]);
    }
    catch (\JsonException) {
      return $this->error(new GatewayException('invalid_request', 422));
    }
    catch (GatewayException $error) {
      return $this->error($error);
    }
  }

  /**
   * Retorna somente PublicUser, com refresh transparente server-side.
   */
  public function context(): JsonResponse {
    try {
      return $this->response([
        'authenticated' => TRUE,
        'user' => $this->sessionManager->context(),
      ]);
    }
    catch (GatewayException $error) {
      return $this->error($error);
    }
  }

  /**
   * Descarta imediatamente os tokens server-side da sessao Drupal.
   */
  public function logout(): JsonResponse {
    $this->sessionManager->logout();
    return $this->response(['authenticated' => FALSE]);
  }

  /**
   * Resposta privada e nao cacheavel.
   */
  private function response(array $payload, int $status = 200): JsonResponse {
    $response = new JsonResponse($payload, $status);
    $response->headers->set('Cache-Control', 'no-store, private');
    $response->headers->set('Pragma', 'no-cache');
    return $response;
  }

  /**
   * Mapeia somente codigo sanitizado.
   */
  private function error(GatewayException $error): JsonResponse {
    return $this->response(['error' => $error->publicCode()], $error->httpStatus());
  }

}
