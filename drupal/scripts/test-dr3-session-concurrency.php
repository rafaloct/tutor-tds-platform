#!/usr/bin/env php
<?php

/**
 * @file
 * Destructive ONLY to fixed tds_lock_qa database; opt-in local MySQL fixture.
 *
 * TDS_SESSION_MUTEX_QA=1 TDS_SESSION_MUTEX_SOCKET=/socket/mysqld.sock php ...
 * Uses no network, no passwords, no production configuration or real identities.
 */

declare(strict_types=1);

if (getenv('TDS_SESSION_MUTEX_QA') !== '1' || !getenv('TDS_SESSION_MUTEX_SOCKET')) {
  fwrite(STDERR, "SKIP: explicit disposable Unix-socket fixture required.\n");
  exit(2);
}

$root = dirname(__DIR__);
$loader = require $root . '/vendor/autoload.php';
$loader->addPsr4('Drupal\\mysql\\', $root . '/web/core/modules/mysql/src');
$loader->addPsr4('Drupal\\tds_tutor_gateway\\', $root . '/web/modules/custom/tds_tutor_gateway/src');
new Drupal\Core\Site\Settings([]);

use Drupal\Core\Database\Database;
use Drupal\Core\Session\SessionConfiguration;
use Drupal\tds_tutor_gateway\Lock\DatabaseSessionMutex;
use Drupal\tds_tutor_gateway\StackMiddleware\TutorSessionLock;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\Session\Session;
use Symfony\Component\HttpFoundation\Session\Storage\MockArraySessionStorage;
use Symfony\Component\HttpKernel\HttpKernelInterface;

$options = [
  'driver' => 'mysql',
  'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
  'database' => 'tds_lock_qa',
  'username' => 'root',
  'password' => '',
  'unix_socket' => getenv('TDS_SESSION_MUTEX_SOCKET'),
  'host' => 'localhost',
  'prefix' => '',
];
Database::addConnectionInfo('default', 'default', $options);
$db = Database::getConnection();
$mode = $argv[1] ?? 'coordinator';
if ($mode === 'http') {
  runHttpProof($db);
  exit;
}
$configuration = new SessionConfiguration();
$request = Request::create('https://portal.example.test/private');
$cookieName = $configuration->getOptions($request)['name'];
$request->cookies->set($cookieName, ($argv[2] ?? '') === 'other' ? 'synthetic-other' : 'synthetic-shared');
$mutex = new DatabaseSessionMutex($db);

if ($mode !== 'coordinator') {
  $kernel = new class($db, $mode) implements HttpKernelInterface {
    public function __construct(private $db, private string $mode) {}

    public function handle(Request $request, $type = self::MAIN_REQUEST, $catch = TRUE): Response {
      $token = $this->db->query('SELECT token FROM qa_session WHERE id=1')->fetchField();
      $this->db->insert('qa_events')->fields(['event' => 'read:' . $this->mode])->execute();
      $session = new class(new MockArraySessionStorage(), $this->db, $this->mode) extends Session {
        public function __construct($storage, private $db, private string $mode) {
          parent::__construct($storage);
        }

        public function save(): void {
          $this->db->update('qa_session')->fields(['token' => $this->get('token')])->condition('id', 1)->execute();
          $this->db->insert('qa_events')->fields(['event' => 'saved:' . $this->mode])->execute();
          parent::save();
        }
      };
      $session->set('token', $token);
      $request->setSession($session);
      if ($this->mode === 'refresh') {
        if ($token === 'old') {
          $updated = $this->db->update('qa_refresh')->fields(['used' => 1])->condition('used', 0)->execute();
          if ($updated !== 1) {
            throw new RuntimeException('refresh_replay');
          }
          $session->set('token', 'rotated');
          $this->db->insert('qa_events')->fields(['event' => 'rotated'])->execute();
          usleep(800000);
        }
      }
      elseif ($this->mode === 'logout') {
        $session->set('token', NULL);
        $this->db->insert('qa_events')->fields(['event' => 'logout-pending'])->execute();
        usleep(800000);
      }
      elseif ($this->mode === 'crash') {
        $this->db->insert('qa_events')->fields(['event' => 'crash-ready'])->execute();
        // Coordinator kills this worker while it owns the connection mutex.
        sleep(20);
      }
      elseif ($this->mode === 'disconnect') {
        $session->set('token', 'obsolete-overwrite');
        $id = (int) $this->db->query('SELECT CONNECTION_ID()')->fetchField();
        $this->db->query('KILL ' . $id);
      }
      elseif ($this->mode === 'exception') {
        $session->set('token', 'rotated-before-exception');
        throw new RuntimeException('synthetic upstream failure');
      }
      return new Response($session->get('token') ?? 'empty');
    }
  };
  $response = (new TutorSessionLock($kernel, $configuration, static fn () => $mutex))->handle($request);
  echo json_encode(['status' => $response->getStatusCode(), 'body' => $response->getContent()], JSON_THROW_ON_ERROR) . "\n";
  exit(0);
}

function check(bool $condition, string $description): void {
  if (!$condition) {
    throw new RuntimeException('FAIL: ' . $description);
  }
  echo 'PASS: ' . $description . "\n";
}

function startWorker(string $mode, string $cookie = 'shared'): array {
  $pipes = [];
  $process = proc_open([PHP_BINARY, __FILE__, $mode, $cookie], [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
  fclose($pipes[0]);
  return [$process, $pipes];
}

function finishWorker(array $worker): array {
  [$process, $pipes] = $worker;
  $result = stream_get_contents($pipes[1]);
  $error = stream_get_contents($pipes[2]);
  fclose($pipes[1]);
  fclose($pipes[2]);
  $exit = proc_close($process);
  if ($exit !== 0 || $error !== '') {
    throw new RuntimeException('Worker failed; inspect synthetic fixture locally: ' . $error);
  }
  return json_decode($result, TRUE, 8, JSON_THROW_ON_ERROR);
}

function waitEvent($db, string $event): void {
  $deadline = microtime(TRUE) + 5;
  do {
    if ($db->query('SELECT COUNT(*) FROM qa_events WHERE event=:event', [':event' => $event])->fetchField()) {
      return;
    }
    usleep(10000);
  } while (microtime(TRUE) < $deadline);
  throw new RuntimeException('Fixture worker did not reach event: ' . $event);
}

// Fixed disposable tables in the explicitly named, local-only QA database.
$db->query('DROP TABLE IF EXISTS qa_session, qa_events, qa_refresh');
$db->query('CREATE TABLE qa_session (id INT PRIMARY KEY, token VARCHAR(64) NULL)');
$db->query('CREATE TABLE qa_refresh (used INT NOT NULL)');
$db->query('CREATE TABLE qa_events (id INT AUTO_INCREMENT PRIMARY KEY, event VARCHAR(80))');
$db->query("INSERT INTO qa_session VALUES (1, 'old')");
$db->query('INSERT INTO qa_refresh VALUES (0)');

$a = startWorker('refresh');
waitEvent($db, 'rotated');
$b = finishWorker(startWorker('refresh'));
check($b['status'] === 503, 'concurrent B rejected before reading stale refresh');
check((int) $db->query("SELECT COUNT(*) FROM qa_events WHERE event='read:refresh'")->fetchField() === 1, 'only A read the old snapshot');
check(finishWorker($a)['status'] === 200, 'A rotated and persisted successfully');
$b = finishWorker(startWorker('refresh'));
check($b === ['status' => 200, 'body' => 'rotated'], 'B retry reads rotated value, with no refresh replay');
check((int) $db->query("SELECT COUNT(*) FROM qa_events WHERE event='rotated'")->fetchField() === 1, 'exactly one rotation occurred');

$a = startWorker('logout');
waitEvent($db, 'logout-pending');
check(finishWorker(startWorker('read'))['status'] === 503, 'read blocked during logout persistence');
check(finishWorker($a)['body'] === 'empty', 'logout persisted empty session');
check(finishWorker(startWorker('read'))['body'] === 'empty', 'following request cannot resurrect logged-out tokens');

check(finishWorker(startWorker('exception'))['status'] === 503, 'exception emits sanitized unavailable response');
check(finishWorker(startWorker('read'))['body'] === 'rotated-before-exception', 'rotation persisted before exception released mutex');

check(finishWorker(startWorker('disconnect'))['status'] === 503, 'lost pinned connection never emits authenticated content');
check(finishWorker(startWorker('read'))['body'] === 'rotated-before-exception', 'lost pinned connection cannot persist stale snapshot');

$a = startWorker('crash');
waitEvent($db, 'crash-ready');
check(finishWorker(startWorker('read'))['status'] === 503, 'live owner keeps mutex without a lease');
// Different browser/session remains independent while the first is blocked.
check(finishWorker(startWorker('read', 'other'))['status'] === 200, 'different session remains available');
proc_terminate($a[0], 9);
foreach ($a[1] as $pipe) {
  if (is_resource($pipe)) {
    fclose($pipe);
  }
}
proc_close($a[0]);
usleep(50000);
check(finishWorker(startWorker('read'))['status'] === 200, 'process death closes connection and releases mutex');
$db->query('DROP TABLE qa_session, qa_events, qa_refresh');
echo "15 concurrency checks PASS; synthetic MySQL fixture only.\n";

/**
 * Tests real Drupal Session middleware/handler through concurrent HTTP workers.
 */
function runHttpProof($db): void {
  $cookie = getenv('TDS_SESSION_MUTEX_COOKIE_JAR') ?: '/tmp/tds168-session-cookie';
  $command = ['curl', '-sS', '--max-time', '10', '-b', $cookie, '-w', "\n%{http_code}", 'http://127.0.0.1:8871/tds/session/context'];
  $pipes = [];
  $a = proc_open($command, [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
  fclose($pipes[0]);
  $deadline = microtime(TRUE) + 5;
  do {
    $used = (int) $db->query('SELECT used FROM qa_http_refresh')->fetchField();
    if ($used === 1) {
      break;
    }
    usleep(10000);
  } while (microtime(TRUE) < $deadline);
  check($used === 1, 'real HTTP A reached upstream refresh with expired token');
  $otherPipes = [];
  $b = proc_open($command, [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $otherPipes);
  fclose($otherPipes[0]);
  $outB = stream_get_contents($otherPipes[1]);
  fclose($otherPipes[1]);
  fclose($otherPipes[2]);
  proc_close($b);
  check(str_ends_with($outB, "\n503"), 'real HTTP B rejected while A holds session read-to-save mutex');
  $outA = stream_get_contents($pipes[1]);
  fclose($pipes[1]);
  fclose($pipes[2]);
  proc_close($a);
  check(str_ends_with($outA, "\n200") && str_contains($outA, '"authenticated":true'), 'real HTTP A persisted rotated session and authenticated');
  $retry = [];
  $retryProcess = proc_open($command, [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $retry);
  fclose($retry[0]);
  $outRetry = stream_get_contents($retry[1]);
  fclose($retry[1]);
  fclose($retry[2]);
  proc_close($retryProcess);
  check(str_ends_with($outRetry, "\n200") && str_contains($outRetry, '"authenticated":true'), 'real HTTP B retry loaded newly persisted token without replay');
  check((int) $db->query('SELECT used FROM qa_http_refresh')->fetchField() === 1, 'real HTTP upstream refresh used exactly once');
  echo "5 real Drupal HTTP/session checks PASS; API synthetic.\n";
}
