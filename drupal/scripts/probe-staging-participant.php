#!/usr/bin/env php
<?php

/**
 * @file
 * Bounded real-staging client contract probe, NOT browser/session E2E.
 * Credentials only via private JSON stdin (preferred) or dedicated env vars.
 */

declare(strict_types=1);

ini_set('display_errors', '0');
ini_set('log_errors', '0');
const PROBE_ORIGIN = 'https://ead.ipexdesenvolvimento.cloud/tutor-staging-api';
const PROBE_SAMPLE_LIMIT = 5;

use Drupal\Component\Datetime\Time;
use Drupal\Component\Uuid\Php as PhpUuid;
use Drupal\Core\Site\Settings;
use Drupal\tds_tutor_gateway\Client\TutorApiClient;
use Drupal\tds_tutor_gateway\Exception\GatewayException;
use Drupal\tds_tutor_gateway\Session\TutorSessionLifecycleInterface;
use Drupal\tds_tutor_gateway\Session\TutorSessionManager;
use Drupal\tds_tutor_gateway\Storage\TutorTokenStoreInterface;
use Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet;
use GuzzleHttp\Client;
use Symfony\Component\EventDispatcher\EventDispatcher;

/**
 * Reject configuration before autoload, credential input or any HTTP client.
 */
function probeConfig(mixed $optIn, mixed $url, mixed $refresh): array {
  if ($optIn !== '1' || $url !== PROBE_ORIGIN || !in_array($refresh, ['', '0', '1', FALSE], TRUE)) {
    throw new RuntimeException('configuration_rejected');
  }
  return ['url' => $url, 'refresh' => $refresh === '1'];
}

/**
 * Strict private input; never return credentials as diagnostic output.
 */
function probeCredentials(string $json): array {
  if (strlen($json) > 8192) {
    throw new RuntimeException('credentials_rejected');
  }
  $data = json_decode($json, TRUE, 4, JSON_THROW_ON_ERROR);
  if (!is_array($data) || array_diff(array_keys($data), ['cpf', 'password']) !== []
    || !is_string($data['cpf'] ?? NULL) || $data['cpf'] === ''
    || !is_string($data['password'] ?? NULL) || $data['password'] === '') {
    throw new RuntimeException('credentials_rejected');
  }
  return $data;
}

/**
 * A context 404 is an unavailable contract, never a successful empty result.
 */
function probeGate(string $stage, int $status): string {
  return $status === 200 ? 'PASS' : ($stage === 'learning_context' && $status === 404 ? 'BLOCKED_CONTEXT' : 'BLOCKED');
}

/**
 * Guard self-test needs no dependencies, network or real credentials.
 */
function probeSelfTest(): void {
  $checks = 0;
  $reject = static function (callable $call) use (&$checks): void {
    try {
      $call();
    }
    catch (Throwable) {
      $checks++;
      return;
    }
    throw new RuntimeException('guard_test_failed');
  };
  foreach (['', PROBE_ORIGIN . '/', PROBE_ORIGIN . '?x=1', PROBE_ORIGIN . '#x', str_replace('https:', 'http:', PROBE_ORIGIN), 'https://ead.ipexdesenvolvimento.cloud', 'https://other.example/tutor-staging-api', str_replace('https://', 'https://user@', PROBE_ORIGIN)] as $url) {
    $reject(static fn () => probeConfig('1', $url, '0'));
  }
  $reject(static fn () => probeConfig('0', PROBE_ORIGIN, '0'));
  $reject(static fn () => probeConfig('1', PROBE_ORIGIN, 'true'));
  foreach (['{}', '[]', '{', '{"cpf":"synthetic","password":""}', '{"cpf":"synthetic","password":"private","url":"foreign"}', str_repeat('x', 8193)] as $json) {
    $reject(static fn () => probeCredentials($json));
  }
  if (probeConfig('1', PROBE_ORIGIN, '1')['refresh'] !== TRUE
    || probeCredentials('{"cpf":"synthetic","password":"private"}')['cpf'] !== 'synthetic'
    || probeGate('learning_context', 404) !== 'BLOCKED_CONTEXT'
    || probeGate('certificates', 404) !== 'BLOCKED') {
    throw new RuntimeException('guard_test_failed');
  }
  echo json_encode(['guard_checks' => $checks + 4, 'gate' => 'PASS', 'network_calls' => 0], JSON_THROW_ON_ERROR) . "\n";
}

try {
  if (($argv[1] ?? '') === '--self-test' && count($argv) === 2) {
    probeSelfTest();
    exit(0);
  }
  if (count($argv) !== 1 || PHP_SAPI !== 'cli') {
    throw new RuntimeException('configuration_rejected');
  }
  $config = probeConfig(getenv('TDS_STAGING_QA'), getenv('TDS_STAGING_PROBE_URL'), getenv('TDS_STAGING_PROBE_REFRESH'));
  // Do not allow interactive input to accidentally echo a password on a TTY.
  $mode = getenv('TDS_STAGING_PROBE_CREDENTIALS');
  if ($mode === 'stdin' && (!function_exists('stream_isatty') || !stream_isatty(STDIN))) {
    $credentials = probeCredentials(stream_get_contents(STDIN, 8193));
  }
  elseif ($mode === 'env') {
    $credentials = probeCredentials(json_encode([
      'cpf' => getenv('TDS_STAGING_PROBE_CPF'),
      'password' => getenv('TDS_STAGING_PROBE_PASSWORD'),
    ], JSON_THROW_ON_ERROR));
    putenv('TDS_STAGING_PROBE_CPF');
    putenv('TDS_STAGING_PROBE_PASSWORD');
    unset($_ENV['TDS_STAGING_PROBE_CPF'], $_ENV['TDS_STAGING_PROBE_PASSWORD']);
  }
  else {
    throw new RuntimeException('configuration_rejected');
  }
  $root = dirname(__DIR__);
  $loader = require $root . '/vendor/autoload.php';
  $loader->addPsr4('Drupal\\tds_tutor_gateway\\', $root . '/web/modules/custom/tds_tutor_gateway/src');
  $time = new Time();
  $client = new TutorApiClient(
    new Client(['allow_redirects' => FALSE, 'verify' => TRUE, 'debug' => FALSE]),
    new Settings(['tds_environment' => 'staging', 'tutor_api_base_url' => $config['url']]),
    new PhpUuid(),
    $time,
  );
  $store = new class implements TutorTokenStoreInterface {
    private ?TutorTokenSet $tokens = NULL;
    public function load(): ?TutorTokenSet { return $this->tokens; }
    public function save(TutorTokenSet $tokens): void { $this->tokens = $tokens; }
    public function clear(): void { $this->tokens = NULL; }
  };
  // No native session is started: this probe does not validate cookie lifecycle.
  $lifecycle = new class implements TutorSessionLifecycleInterface {
    public function rotateId(): void {}
  };
  $manager = new TutorSessionManager($client, $store, $time, new EventDispatcher(), $lifecycle);
  $results = [];
  $blocked = FALSE;
  $run = static function (string $stage, callable $call) use (&$results, &$blocked): ?array {
    try {
      $value = $call();
      $results[] = ['stage' => $stage, 'status' => 200, 'gate' => 'PASS'];
      return $value;
    }
    catch (GatewayException $error) {
      $results[] = ['stage' => $stage, 'status' => $error->httpStatus(), 'gate' => probeGate($stage, $error->httpStatus())];
    }
    catch (Throwable) {
      $results[] = ['stage' => $stage, 'status' => 0, 'gate' => 'BLOCKED'];
    }
    $blocked = TRUE;
    return NULL;
  };
  try {
    $login = $run('login', static fn () => $manager->login($credentials['cpf'], $credentials['password']));
    unset($credentials);
    $counts = ['classes_returned' => NULL, 'classes_sampled' => 0, 'certificates_returned' => NULL];
    if ($login !== NULL) {
      $identity = $run('auth_me', static fn () => $manager->context());
      if ($identity === NULL || $identity['id'] !== $login['id']) {
        $blocked = TRUE;
        $results[] = ['stage' => 'identity_consistency', 'status' => 0, 'gate' => 'BLOCKED'];
      }
      $classes = $run('enrolled_classes', static function () use ($manager): array {
        $page = $manager->get('/classes', ['enrolled_only' => 'true']);
        if (!is_array($page['classes'] ?? NULL) || !array_is_list($page['classes'])) {
          throw new GatewayException('invalid_api_response', 502);
        }
        return $page['classes'];
      });
      if ($classes !== NULL) {
        $counts['classes_returned'] = count($classes);
        if ($classes === []) {
          $blocked = TRUE;
          $results[] = ['stage' => 'context_coverage', 'status' => 0, 'gate' => 'BLOCKED'];
        }
        foreach (array_slice($classes, 0, PROBE_SAMPLE_LIMIT) as $class) {
          $id = is_array($class) ? ($class['id'] ?? NULL) : NULL;
          if (!is_string($id) || !preg_match('/^[A-Za-z0-9][A-Za-z0-9_-]{0,119}$/D', $id)) {
            $blocked = TRUE;
            $results[] = ['stage' => 'class_contract', 'status' => 502, 'gate' => 'BLOCKED'];
            continue;
          }
          $counts['classes_sampled']++;
          $run('learning_context', static fn () => $manager->get('/classes/' . $id . '/learning-context'));
          $run('course', static fn () => $manager->get('/classes/' . $id . '/course'));
        }
      }
      $certificates = $run('certificates', static function () use ($manager): array {
        $page = $manager->get('/certificates');
        if (!is_array($page['certificates'] ?? NULL) || !array_is_list($page['certificates'])) {
          throw new GatewayException('invalid_api_response', 502);
        }
        return $page['certificates'];
      });
      $counts['certificates_returned'] = $certificates === NULL ? NULL : count($certificates);
      if ($config['refresh'] && $store->load() !== NULL) {
        $run('refresh_and_auth_me', static function () use ($store, $manager): array {
          $previous = $store->load();
          $store->save(new TutorTokenSet($previous->accessToken, $previous->refreshToken, 0));
          $user = $manager->context();
          if ($store->load() === NULL || hash_equals($previous->refreshToken, $store->load()->refreshToken)) {
            throw new GatewayException('invalid_api_response', 502);
          }
          return $user;
        });
      }
    }
  }
  finally {
    // Memory cleanup only; upstream refresh revocation is not claimed.
    $store->clear();
    unset($login, $identity, $classes, $class, $certificates);
  }
  echo json_encode([
    'scope' => 'staging_client_contract_only',
    'gate' => $blocked ? 'BLOCKED' : 'PASS_SAMPLED_CONTRACT',
    'sample_limit' => PROBE_SAMPLE_LIMIT,
    'counts' => $counts,
    'results' => $results,
  ], JSON_THROW_ON_ERROR) . "\n";
  exit($blocked ? 2 : 0);
}
catch (Throwable) {
  // Never print exception messages, request URIs, bodies, identities or traces.
  echo "{\"scope\":\"staging_client_contract_only\",\"gate\":\"BLOCKED\",\"stage\":\"runner_configuration_or_runtime\"}\n";
  exit(2);
}
