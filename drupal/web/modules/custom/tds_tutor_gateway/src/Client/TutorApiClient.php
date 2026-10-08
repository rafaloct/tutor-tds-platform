<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Client;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Component\Uuid\UuidInterface;
use Drupal\Core\Site\Settings;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet;
use GuzzleHttp\ClientInterface;
use GuzzleHttp\Exception\GuzzleException;
use Psr\Http\Message\ResponseInterface;

/**
 * Cliente HTTP fechado aos endpoints de sessao observados da FastAPI.
 */
final class TutorApiClient implements TutorApiClientInterface {

  private const MAX_RESPONSE_BYTES = 1048576;

  /**
   * Construtor.
   */
  public function __construct(
    private readonly ClientInterface $httpClient,
    private readonly Settings $settings,
    private readonly UuidInterface $uuid,
    private readonly TimeInterface $time,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function login(string $cpf, string $password): array {
    if ($cpf === '' || $password === '') {
      throw new GatewayException('invalid_credentials', 422);
    }
    try {
      $payload = $this->request('POST', '/auth/login', [
        'cpf' => $cpf,
        'password' => $password,
      ]);
    }
    catch (GatewayException $error) {
      if ($error->httpStatus() === 401 || $error->httpStatus() === 403) {
        throw new GatewayException('invalid_credentials', 401, $error);
      }
      throw $error;
    }
    return [
      'tokens' => $this->tokens($payload),
      'user' => $this->user($payload['user'] ?? NULL),
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function refresh(string $refreshToken): TutorTokenSet {
    if ($refreshToken === '') {
      throw new GatewayException('session_expired', 401);
    }
    return $this->tokens($this->request('POST', '/auth/refresh', [
      'refresh_token' => $refreshToken,
    ]));
  }

  /**
   * {@inheritdoc}
   */
  public function me(string $accessToken): array {
    if ($accessToken === '') {
      throw new GatewayException('session_expired', 401);
    }
    return $this->user($this->request('GET', '/auth/me', NULL, $accessToken, TRUE));
  }

  /**
   * Executa request com redirect desligado e retry somente para GET seguro.
   *
   * @return array<string, mixed>
   *   JSON validado como objeto.
   */
  private function request(
    string $method,
    string $path,
    ?array $json = NULL,
    ?string $accessToken = NULL,
    bool $retrySafe = FALSE,
  ): array {
    $allowed = ['/auth/login', '/auth/refresh', '/auth/me'];
    if (!in_array($path, $allowed, TRUE)) {
      throw new \LogicException('Endpoint nao permitido pelo cliente tipado.');
    }
    $headers = [
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'X-Request-ID' => $this->uuid->generate(),
    ];
    if ($accessToken !== NULL) {
      $headers['Authorization'] = 'Bearer ' . $accessToken;
    }
    $options = [
      'headers' => $headers,
      'timeout' => 10,
      'connect_timeout' => 3,
      'allow_redirects' => FALSE,
      'http_errors' => FALSE,
    ];
    if ($json !== NULL) {
      $options['json'] = $json;
    }

    $attempts = $retrySafe && in_array($method, ['GET', 'HEAD'], TRUE) ? 2 : 1;
    for ($attempt = 1; $attempt <= $attempts; $attempt++) {
      try {
        $response = $this->httpClient->request(
          $method,
          $this->baseUrl() . $path,
          $options,
        );
      }
      catch (GuzzleException $error) {
        if ($attempt < $attempts) {
          continue;
        }
        throw new GatewayException('api_unavailable', 503, $error);
      }
      if ($attempt < $attempts && in_array($response->getStatusCode(), [502, 503, 504], TRUE)) {
        continue;
      }
      return $this->decode($response);
    }
    throw new GatewayException('api_unavailable', 503);
  }

  /**
   * Retorna a URL exata configurada pelo ambiente, validada fail-closed.
   */
  private function baseUrl(): string {
    $value = $this->settings->get('tutor_api_base_url', '');
    if (!is_string($value) || $value === '') {
      throw new GatewayException('gateway_not_configured', 503);
    }
    $parts = parse_url($value);
    if (!is_array($parts)
      || isset($parts['user'])
      || isset($parts['pass'])
      || isset($parts['query'])
      || isset($parts['fragment'])) {
      throw new GatewayException('gateway_not_configured', 503);
    }
    $scheme = strtolower((string) ($parts['scheme'] ?? ''));
    $host = strtolower((string) ($parts['host'] ?? ''));
    $environment = (string) $this->settings->get('tds_environment', 'local');
    $loopback = in_array($host, ['localhost', '127.0.0.1', '::1'], TRUE);
    if ($host === '' || ($scheme !== 'https' && !($environment === 'local' && $scheme === 'http' && $loopback))) {
      throw new GatewayException('gateway_not_configured', 503);
    }
    // A unica origem permitida e a URL exata fornecida pelo ambiente. Caminho
    // base e porta sao preservados; requests nao aceitam URL do usuario.
    return rtrim($value, '/');
  }

  /**
   * Decodifica sem propagar corpo sensivel ou detalhe upstream.
   *
   * @return array<string, mixed>
   *   Objeto JSON.
   */
  private function decode(ResponseInterface $response): array {
    $status = $response->getStatusCode();
    if ($status < 200 || $status >= 300) {
      throw match ($status) {
        401 => new GatewayException('invalid_or_expired_session', 401),
        403 => new GatewayException('access_denied', 403),
        422 => new GatewayException('invalid_request', 422),
        429 => new GatewayException('rate_limited', 429),
        502, 503, 504 => new GatewayException('api_unavailable', 503),
        default => new GatewayException('api_error', 502),
      };
    }
    $body = (string) $response->getBody();
    if ($body === '' || strlen($body) > self::MAX_RESPONSE_BYTES) {
      throw new GatewayException('invalid_api_response', 502);
    }
    try {
      $decoded = json_decode($body, TRUE, 64, JSON_THROW_ON_ERROR);
    }
    catch (\JsonException $error) {
      throw new GatewayException('invalid_api_response', 502, $error);
    }
    if (!is_array($decoded) || array_is_list($decoded)) {
      throw new GatewayException('invalid_api_response', 502);
    }
    return $decoded;
  }

  /**
   * Valida TokenResponse observado na FastAPI.
   */
  private function tokens(array $payload): TutorTokenSet {
    $access = $payload['access_token'] ?? NULL;
    $refresh = $payload['refresh_token'] ?? NULL;
    $type = $payload['token_type'] ?? NULL;
    $expires = $payload['expires_in'] ?? NULL;
    if (!is_string($access) || $access === ''
      || !is_string($refresh) || $refresh === ''
      || strtolower((string) $type) !== 'bearer'
      || !is_int($expires) || $expires <= 0) {
      throw new GatewayException('invalid_api_response', 502);
    }
    return new TutorTokenSet(
      $access,
      $refresh,
      $this->time->getCurrentTime() + $expires,
    );
  }

  /**
   * Reduz PublicUser aos tres campos observados.
   *
   * @return array{id: string, name: string, role: string}
   *   Usuario publico.
   */
  private function user(mixed $payload): array {
    if (!is_array($payload)) {
      throw new GatewayException('invalid_api_response', 502);
    }
    $id = $payload['id'] ?? NULL;
    $name = $payload['name'] ?? NULL;
    $role = $payload['role'] ?? NULL;
    if (!is_string($id) || $id === '' || !is_string($name) || $name === '' || !is_string($role) || $role === '') {
      throw new GatewayException('invalid_api_response', 502);
    }
    return ['id' => $id, 'name' => $name, 'role' => $role];
  }

}
