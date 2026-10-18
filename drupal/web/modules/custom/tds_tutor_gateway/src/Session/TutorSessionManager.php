<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Session;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\tds_tutor_gateway\Client\TutorApiClientInterface;
use Drupal\tds_tutor_gateway\Event\TutorSessionClearedEvent;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Storage\TutorTokenStoreInterface;
use Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet;
use Symfony\Contracts\EventDispatcher\EventDispatcherInterface;

/**
 * Orquestra login, refresh rotativo, troca de usuario e logout local.
 */
final class TutorSessionManager implements TutorSessionManagerInterface {

  private const REFRESH_SKEW_SECONDS = 30;

  /**
   * Construtor.
   */
  public function __construct(
    private readonly TutorApiClientInterface $client,
    private readonly TutorTokenStoreInterface $store,
    private readonly TimeInterface $time,
    private readonly EventDispatcherInterface $eventDispatcher,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function login(string $cpf, string $password): array {
    // Falha de novo login nunca preserva tokens do usuario anterior.
    $this->clear();
    $result = $this->client->login($cpf, $password);
    $this->store->save($result['tokens']);
    return $result['user'];
  }

  /**
   * {@inheritdoc}
   */
  public function context(): array {
    $tokens = $this->tokens();
    try {
      return $this->client->me($tokens->accessToken);
    }
    catch (GatewayException $error) {
      if ($error->httpStatus() !== 401) {
        throw $error;
      }
      $tokens = $this->rotate($tokens->refreshToken);
      return $this->client->me($tokens->accessToken);
    }
  }

  /**
   * {@inheritdoc}
   */
  public function get(string $path, array $query = []): array {
    $tokens = $this->tokens();
    try {
      return $this->client->get($path, $query, $tokens->accessToken);
    }
    catch (GatewayException $error) {
      if ($error->httpStatus() !== 401) {
        throw $error;
      }
      $tokens = $this->rotate($tokens->refreshToken);
      return $this->client->get($path, $query, $tokens->accessToken);
    }
  }

  /**
   * {@inheritdoc}
   */
  public function logout(): void {
    // A API ainda nao possui /auth/logout; a invalidacao garantida desta
    // fatia e local e imediata. A ausencia upstream permanece documentada.
    $this->clear();
  }

  /**
   * Carrega token e o renova antes da margem de expiracao.
   */
  private function tokens(): TutorTokenSet {
    $tokens = $this->store->load();
    if ($tokens === NULL) {
      throw new GatewayException('session_required', 401);
    }
    if ($tokens->expiresAt <= $this->time->getRequestTime() + self::REFRESH_SKEW_SECONDS) {
      return $this->rotate($tokens->refreshToken);
    }
    return $tokens;
  }

  /**
   * Limpa tokens e avisa consumidores de estado privado da mesma sessao.
   */
  private function clear(): void {
    $this->store->clear();
    $this->eventDispatcher->dispatch(
      new TutorSessionClearedEvent(),
      TutorSessionClearedEvent::NAME,
    );
  }

  /**
   * Rotaciona o refresh de uso unico e limpa estado quando ele e recusado.
   */
  private function rotate(string $refreshToken): TutorTokenSet {
    try {
      $tokens = $this->client->refresh($refreshToken);
      $this->store->save($tokens);
      return $tokens;
    }
    catch (GatewayException $error) {
      if ($error->httpStatus() === 401 || $error->httpStatus() === 403) {
        $this->clear();
      }
      throw $error;
    }
  }

}
