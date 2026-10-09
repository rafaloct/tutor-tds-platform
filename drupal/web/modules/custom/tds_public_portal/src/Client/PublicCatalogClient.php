<?php

declare(strict_types=1);

namespace Drupal\tds_public_portal\Client;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Component\Uuid\UuidInterface;
use Drupal\Core\Cache\CacheBackendInterface;
use Drupal\Core\Site\Settings;
use Drupal\tds_public_portal\Exception\CatalogException;
use Drupal\tds_public_portal\ValueObject\CatalogResult;
use GuzzleHttp\ClientInterface;
use GuzzleHttp\Exception\GuzzleException;
use Psr\Http\Message\ResponseInterface;

/**
 * Adapter server-side, anonimo e allowlisted para /public/courses*.
 */
final class PublicCatalogClient implements PublicCatalogClientInterface {

  private const FRESH_TTL = 60;
  private const STALE_TTL = 300;
  private const MAX_RESPONSE_BYTES = 1048576;

  /**
   * Construtor.
   */
  public function __construct(
    private readonly ClientInterface $httpClient,
    private readonly Settings $settings,
    private readonly UuidInterface $uuid,
    private readonly TimeInterface $time,
    private readonly CacheBackendInterface $cache,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function list(int $offset = 0, int $limit = 50): CatalogResult {
    if ($offset < 0 || $limit < 1 || $limit > 100) {
      return new CatalogResult(CatalogResult::UNAVAILABLE);
    }
    return $this->fetch('/public/courses', [
      'offset' => $offset,
      'limit' => $limit,
    ], TRUE);
  }

  /**
   * {@inheritdoc}
   */
  public function detail(string $slug): CatalogResult {
    if (!preg_match('/^[a-z0-9]+(?:-[a-z0-9]+)*$/', $slug)) {
      return new CatalogResult(CatalogResult::NOT_FOUND);
    }
    return $this->fetch('/public/courses/' . rawurlencode($slug), [], FALSE);
  }

  /**
   * Busca, valida e aplica cache fresh/stale isolado por ambiente e origem.
   *
   * @param string $path
   *   Path fixo allowlisted pelo metodo publico.
   * @param array<string, int> $query
   *   Query numerica allowlisted.
   * @param bool $collection
   *   TRUE para resposta paginada; FALSE para detalhe.
   */
  private function fetch(string $path, array $query, bool $collection): CatalogResult {
    try {
      $baseUrl = $this->baseUrl();
    }
    catch (CatalogException) {
      return new CatalogResult(CatalogResult::UNAVAILABLE);
    }

    $cacheId = $this->cacheId($baseUrl, $path, $query);
    $cached = $this->cache->get($cacheId);
    $cachedData = is_object($cached) && is_array($cached->data ?? NULL)
      ? $cached->data
      : NULL;
    $now = $this->time->getCurrentTime();
    if ($cachedData !== NULL
      && is_int($cachedData['fetched_at'] ?? NULL)
      && is_array($cachedData['payload'] ?? NULL)
      && $cachedData['fetched_at'] + self::FRESH_TTL >= $now) {
      return new CatalogResult(CatalogResult::FRESH, $cachedData['payload']);
    }

    try {
      $payload = $this->request($baseUrl, $path, $query);
      $sanitized = $collection
        ? $this->sanitizeCollection($payload)
        : $this->sanitizeCourse($payload);
      $this->cache->set(
        $cacheId,
        ['payload' => $sanitized, 'fetched_at' => $now],
        $now + self::FRESH_TTL + self::STALE_TTL,
        ['tds_public_catalog'],
      );
      return new CatalogResult(CatalogResult::FRESH, $sanitized);
    }
    catch (CatalogException $error) {
      if ($error->httpStatus === 404) {
        return new CatalogResult(CatalogResult::NOT_FOUND);
      }
      if ($cachedData !== NULL
        && is_int($cachedData['fetched_at'] ?? NULL)
        && is_array($cachedData['payload'] ?? NULL)
        && $cachedData['fetched_at'] + self::FRESH_TTL + self::STALE_TTL >= $now) {
        return new CatalogResult(CatalogResult::STALE, $cachedData['payload']);
      }
      return new CatalogResult(CatalogResult::UNAVAILABLE);
    }
  }

  /**
   * Executa GET sem auth, sem redirects e com um unico retry seguro.
   *
   * @param string $baseUrl
   *   Origem exata validada do ambiente.
   * @param string $path
   *   Path fixo allowlisted pelo metodo publico.
   * @param array<string, int> $query
   *   Query allowlisted.
   *
   * @return array<string, mixed>
   *   Objeto JSON.
   */
  private function request(string $baseUrl, string $path, array $query): array {
    $options = [
      'headers' => [
        'Accept' => 'application/json',
        'X-Request-ID' => $this->uuid->generate(),
      ],
      'query' => $query,
      'timeout' => 10,
      'connect_timeout' => 3,
      'allow_redirects' => FALSE,
      'http_errors' => FALSE,
    ];
    for ($attempt = 1; $attempt <= 2; $attempt++) {
      try {
        $response = $this->httpClient->request('GET', $baseUrl . $path, $options);
      }
      catch (GuzzleException $error) {
        if ($attempt < 2) {
          continue;
        }
        throw new CatalogException('api_unavailable', 503, $error);
      }
      if ($attempt < 2 && in_array($response->getStatusCode(), [502, 503, 504], TRUE)) {
        continue;
      }
      return $this->decode($response);
    }
    throw new CatalogException('api_unavailable', 503);
  }

  /**
   * Valida a URL exata do ambiente; HTTP so e aceito em loopback local.
   */
  private function baseUrl(): string {
    $value = $this->settings->get('tutor_api_base_url', '');
    if (!is_string($value) || $value === '') {
      throw new CatalogException('gateway_not_configured', 503);
    }
    $parts = parse_url($value);
    if (!is_array($parts)
      || isset($parts['user'])
      || isset($parts['pass'])
      || isset($parts['query'])
      || isset($parts['fragment'])) {
      throw new CatalogException('gateway_not_configured', 503);
    }
    $scheme = strtolower((string) ($parts['scheme'] ?? ''));
    $host = strtolower((string) ($parts['host'] ?? ''));
    $environment = (string) $this->settings->get('tds_environment', 'local');
    $loopback = in_array($host, ['localhost', '127.0.0.1', '::1'], TRUE);
    if ($host === '' || ($scheme !== 'https' && !($environment === 'local' && $scheme === 'http' && $loopback))) {
      throw new CatalogException('gateway_not_configured', 503);
    }
    return rtrim($value, '/');
  }

  /**
   * Chave inclui ambiente e origem; cache nunca mistura endpoints.
   *
   * @param string $baseUrl
   *   Origem exata validada do ambiente.
   * @param string $path
   *   Path fixo allowlisted pelo metodo publico.
   * @param array<string, int> $query
   *   Query allowlisted.
   */
  private function cacheId(string $baseUrl, string $path, array $query): string {
    ksort($query);
    $environment = (string) $this->settings->get('tds_environment', 'local');
    return 'tds_public_portal:' . hash('sha256', implode('|', [
      $environment,
      $baseUrl,
      $path,
      http_build_query($query),
    ]));
  }

  /**
   * Decodifica sem propagar corpo ou detalhe upstream.
   *
   * @return array<string, mixed>
   *   Objeto JSON.
   */
  private function decode(ResponseInterface $response): array {
    $status = $response->getStatusCode();
    if ($status === 404) {
      throw new CatalogException('not_found', 404);
    }
    if ($status < 200 || $status >= 300) {
      throw new CatalogException('api_unavailable', 503);
    }
    $body = (string) $response->getBody();
    if ($body === '' || strlen($body) > self::MAX_RESPONSE_BYTES) {
      throw new CatalogException('invalid_api_response', 502);
    }
    try {
      $decoded = json_decode($body, TRUE, 64, JSON_THROW_ON_ERROR);
    }
    catch (\JsonException $error) {
      throw new CatalogException('invalid_api_response', 502, $error);
    }
    if (!is_array($decoded) || array_is_list($decoded)) {
      throw new CatalogException('invalid_api_response', 502);
    }
    return $decoded;
  }

  /**
   * Sanitiza a resposta paginada.
   *
   * @param array<string, mixed> $payload
   *   Objeto JSON decodificado.
   *
   * @return array<string, mixed>
   *   Colecao allowlisted.
   */
  private function sanitizeCollection(array $payload): array {
    $courses = $payload['courses'] ?? NULL;
    $offset = $payload['offset'] ?? NULL;
    $limit = $payload['limit'] ?? NULL;
    $total = $payload['total'] ?? NULL;
    if (!is_array($courses) || !array_is_list($courses)
      || !is_int($offset) || $offset < 0
      || !is_int($limit) || $limit < 1 || $limit > 100
      || !is_int($total) || $total < 0) {
      throw new CatalogException('invalid_api_response', 502);
    }
    $sanitized = [];
    foreach ($courses as $course) {
      if (!is_array($course)) {
        throw new CatalogException('invalid_api_response', 502);
      }
      // Defesa em profundidade: draft/private nunca e renderizado mesmo que
      // uma resposta upstream defeituosa o inclua.
      if (($course['status'] ?? NULL) !== 'published') {
        continue;
      }
      $sanitized[] = $this->sanitizeCourse($course);
    }
    return [
      'courses' => $sanitized,
      'offset' => $offset,
      'limit' => $limit,
      'total' => $total,
    ];
  }

  /**
   * Sanitiza um curso publicado.
   *
   * @param array<string, mixed> $course
   *   Curso JSON decodificado.
   *
   * @return array<string, string|null>
   *   Curso limitado a PUBLIC_API_PORTAL_V1.
   */
  private function sanitizeCourse(array $course): array {
    $required = ['slug', 'title', 'status', 'published_version_label', 'updated_at'];
    foreach ($required as $field) {
      if (!is_string($course[$field] ?? NULL) || $course[$field] === '') {
        throw new CatalogException('invalid_api_response', 502);
      }
    }
    if ($course['status'] !== 'published'
      || !preg_match('/^[a-z0-9]+(?:-[a-z0-9]+)*$/', $course['slug'])) {
      throw new CatalogException('invalid_api_response', 502);
    }
    $result = [];
    foreach ($required as $field) {
      $result[$field] = $course[$field];
    }
    foreach (['summary', 'cover_public_url', 'public_workload_text', 'public_audience_text'] as $field) {
      $value = $course[$field] ?? NULL;
      if ($value !== NULL && !is_string($value)) {
        throw new CatalogException('invalid_api_response', 502);
      }
      $result[$field] = $value;
    }
    if (is_string($result['cover_public_url']) && !$this->isSafePublicUrl($result['cover_public_url'])) {
      $result['cover_public_url'] = NULL;
    }
    return $result;
  }

  /**
   * Capa publica aceita somente HTTPS sem credenciais.
   */
  private function isSafePublicUrl(string $url): bool {
    $parts = parse_url($url);
    return is_array($parts)
      && strtolower((string) ($parts['scheme'] ?? '')) === 'https'
      && is_string($parts['host'] ?? NULL)
      && $parts['host'] !== ''
      && !isset($parts['user'])
      && !isset($parts['pass']);
  }

}
