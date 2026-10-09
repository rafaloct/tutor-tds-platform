<?php

declare(strict_types=1);

namespace Drupal\tds_health\Controller;

use Drupal\Core\Controller\ControllerBase;
use Drupal\Core\Database\Connection;
use Drupal\Core\Site\Settings;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;

/**
 * Endpoint simples de saude do portal para containers e monitoramento.
 *
 * Responde JSON em /health com status do Drupal e do banco exclusivo do
 * portal. Nunca expoe credenciais, PII ou dados academicos.
 */
final class HealthController extends ControllerBase {

  /**
   * Construtor.
   */
  public function __construct(
    private readonly Connection $database,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static($container->get('database'));
  }

  /**
   * Retorna o status do portal.
   *
   * Resposta propositalmente nao cacheavel (CacheableResponseInterface faria o
   * Drupal reescrever o Cache-Control; resposta simples preserva o no-store).
   *
   * @return \Symfony\Component\HttpFoundation\JsonResponse
   *   JSON com status, ambiente e estado do banco Drupal.
   */
  public function status(): JsonResponse {
    $database = 'up';
    $code = 200;

    try {
      $this->database->query('SELECT 1')->fetchField();
    }
    catch (\Throwable) {
      $database = 'down';
      $code = 503;
    }

    $response = new JsonResponse([
      'status' => $code === 200 ? 'ok' : 'degraded',
      'service' => 'tutor-tds-drupal',
      'environment' => Settings::get('tds_environment', 'unknown'),
      'database' => $database,
    ], $code);
    $response->headers->set('Cache-Control', 'no-store');

    return $response;
  }

}
