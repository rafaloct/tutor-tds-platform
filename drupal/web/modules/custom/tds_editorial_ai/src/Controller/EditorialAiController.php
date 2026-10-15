<?php

declare(strict_types=1);

namespace Drupal\tds_editorial_ai\Controller;

use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Drupal\Core\Session\AccountProxyInterface;
use Drupal\node\NodeInterface;
use Drupal\tds_editorial_ai\Client\EditorialAiClientInterface;
use Drupal\tds_editorial_ai\Exception\EditorialAiException;
use Drupal\tds_editorial_ai\Policy\EditorialAiPolicy;
use Drupal\tds_editorial_ai\Quota\EditorialAiQuotaInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

/**
 * Proposes text for a saved node without loading or sending its body content.
 */
final class EditorialAiController implements ContainerInjectionInterface {

  /**
   * Constructs the endpoint.
   */
  public function __construct(
    private readonly EditorialAiPolicy $policy,
    private readonly EditorialAiClientInterface $client,
    private readonly EditorialAiQuotaInterface $quota,
    private readonly AccountProxyInterface $account,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static(
      $container->get('tds_editorial_ai.policy'),
      $container->get('tds_editorial_ai.client'),
      $container->get('tds_editorial_ai.quota'),
      $container->get('current_user'),
    );
  }

  /**
   * Routing enforces header CSRF and node update access before dispatch.
   */
  public function suggest(Request $request, NodeInterface $node): JsonResponse {
    $reserved = FALSE;
    try {
      if (!$request->isMethod('POST')) {
        throw new EditorialAiException('method_not_allowed', 405);
      }
      $this->policy->authorize($node, $this->account);
      if ($request->getContentTypeFormat() !== 'json' || strlen($request->getContent()) > 24576) {
        throw new EditorialAiException('invalid_request', 422);
      }
      $data = json_decode($request->getContent(), TRUE, 4, JSON_THROW_ON_ERROR);
      if (!is_array($data) || count($data) !== 2 || !is_string($data['action'] ?? NULL) || !is_string($data['selection'] ?? NULL)) {
        throw new EditorialAiException('invalid_request', 422);
      }
      EditorialAiPolicy::validate($data['action'], $data['selection']);
      $this->quota->reserve((string) $this->account->id());
      $reserved = TRUE;
      $text = $this->client->suggest($data['action'], $data['selection']);
      return $this->response(['proposed_text' => $text]);
    }
    catch (\JsonException) {
      return $this->response(['error' => 'invalid_request'], 422);
    }
    catch (EditorialAiException $error) {
      return $this->response(['error' => $error->errorCode], $error->status);
    }
    catch (\Throwable) {
      return $this->response(['error' => 'editorial_unavailable'], 503);
    }
    finally {
      if ($reserved) {
        try {
          $this->quota->release();
        }
        catch (\Throwable) {
          return $this->response(['error' => 'editorial_unavailable'], 503);
        }
      }
    }
  }

  /**
   * All outcomes are private and no-store; JSON never renders provider HTML.
   */
  private function response(array $data, int $status = 200): JsonResponse {
    return new JsonResponse($data, $status, [
      'Cache-Control' => 'private, no-store, max-age=0',
      'Pragma' => 'no-cache',
      'X-Content-Type-Options' => 'nosniff',
    ]);
  }

}
