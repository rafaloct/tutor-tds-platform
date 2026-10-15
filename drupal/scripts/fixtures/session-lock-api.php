<?php

/**
 * @file
 * Synthetic loopback API and seed for disposable Drupal HTTP concurrency QA.
 * Never run against a real database. Requires explicit opt-in and Unix socket.
 */

declare(strict_types=1);

if (getenv('TDS_SESSION_MUTEX_QA') !== '1' || !getenv('TDS_SESSION_MUTEX_SOCKET')) {
  http_response_code(503);
  exit;
}
$db = new PDO('mysql:unix_socket=' . getenv('TDS_SESSION_MUTEX_SOCKET') . ';dbname=tds_lock_qa', 'root', '');
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
if (PHP_SAPI === 'cli' && ($argv[1] ?? '') === 'csrf') {
  // Read only the fixed disposable database. Token output is captured by the
  // fixture coordinator, never printed in its public result or persisted.
  require dirname(__DIR__, 2) . '/vendor/autoload.php';
  $path = $argv[2] ?? '';
  if (!in_array($path, ['tds/session/login', 'tds/session/logout'], TRUE)) {
    throw new RuntimeException('Unsupported fixture CSRF path.');
  }
  $id = NULL;
  foreach (file($argv[3], FILE_IGNORE_NEW_LINES) as $line) {
    $fields = explode("\t", $line);
    if (count($fields) === 7 && preg_match('/^S?SESS/', $fields[5])) {
      $id = $fields[6];
    }
  }
  if (!$id) {
    throw new RuntimeException('Synthetic cookie absent.');
  }
  $query = $db->prepare('SELECT session FROM sessions WHERE sid=?');
  $query->execute([Drupal\Component\Utility\Crypt::hashBase64($id)]);
  $data = $query->fetchColumn();
  if (!is_string($data) || $data === '') {
    throw new RuntimeException('Synthetic session absent.');
  }
  ini_set('session.use_cookies', '0');
  session_cache_limiter('');
  session_start();
  session_decode($data);
  $seed = $_SESSION['_sf2_meta']['s'] ?? NULL;
  session_abort();
  $privateKey = unserialize($db->query("SELECT value FROM key_value WHERE collection='state' AND name='system.private_key'")->fetchColumn(), ['allowed_classes' => FALSE]);
  if (!is_string($seed) || !is_string($privateKey) || $privateKey === '') {
    throw new RuntimeException('Synthetic CSRF material absent.');
  }
  echo Drupal\Component\Utility\Crypt::hmacBase64($path, $seed . $privateKey . 'synthetic-session-lock-fixture');
  exit;
}
if (PHP_SAPI === 'cli' && in_array($argv[1] ?? '', ['seed', 'seed-anonymous'], TRUE)) {
  $db->exec('CREATE TABLE IF NOT EXISTS qa_http_refresh (used INT NOT NULL)');
  $db->exec('DELETE FROM qa_http_refresh');
  $db->exec('INSERT INTO qa_http_refresh VALUES (0)');
  $rows = $db->query('SELECT sid, session FROM sessions')->fetchAll(PDO::FETCH_ASSOC);
  if (count($rows) !== 1) {
    throw new RuntimeException('Fixture requires exactly one disposable session.');
  }
  ini_set('session.use_cookies', '0');
  session_cache_limiter('');
  session_start();
  session_decode($rows[0]['session']);
  if (($argv[1] ?? '') === 'seed-anonymous') {
    // Keep the academic fixture but make core editorial login possible.
    $_SESSION['_sf2_attributes']['uid'] = 0;
    unset($_SESSION['_sf2_attributes']['check_logged_in']);
  }
  $_SESSION['_sf2_attributes']['tds_tutor_gateway.tokens'] = [
    'access_token' => 'synthetic-expired',
    'refresh_token' => 'synthetic-refresh-old',
    'expires_at' => 1,
  ];
  $data = session_encode();
  session_abort();
  $statement = $db->prepare('UPDATE sessions SET session=? WHERE sid=?');
  $statement->execute([$data, $rows[0]['sid']]);
  echo "Seeded one synthetic expired TDS session.\n";
  exit;
}
header('Content-Type: application/json');
if (($_SERVER['REQUEST_URI'] ?? '') === '/auth/login') {
  $payload = json_decode(file_get_contents('php://input'), TRUE);
  $person = $payload['cpf'] ?? '';
  if (!in_array($person, ['qa-person-a', 'qa-person-b'], TRUE) || ($payload['password'] ?? '') !== 'synthetic-valid-password') {
    http_response_code(401);
    echo '{"detail":"synthetic invalid credentials"}';
    exit;
  }
  echo json_encode([
    'access_token' => 'synthetic-' . $person,
    'refresh_token' => 'synthetic-refresh-' . $person,
    'token_type' => 'bearer',
    'expires_in' => 3600,
    'user' => ['id' => $person, 'name' => 'Synthetic QA', 'role' => 'student'],
  ], JSON_THROW_ON_ERROR);
}
elseif (in_array(parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH), ['/classes', '/certificates'], TRUE)
  && in_array($_SERVER['HTTP_AUTHORIZATION'] ?? '', ['Bearer synthetic-qa-person-a', 'Bearer synthetic-qa-person-b'], TRUE)) {
  echo json_encode([str_contains($_SERVER['REQUEST_URI'], '/classes') ? 'classes' : 'certificates' => []], JSON_THROW_ON_ERROR);
}
elseif (($_SERVER['REQUEST_URI'] ?? '') === '/auth/refresh') {
  $payload = json_decode(file_get_contents('php://input'), TRUE);
  if (($payload['refresh_token'] ?? '') !== 'synthetic-refresh-old' || $db->exec('UPDATE qa_http_refresh SET used=1 WHERE used=0') !== 1) {
    http_response_code(401);
    echo '{"detail":"synthetic replay rejected"}';
    exit;
  }
  usleep(1200000);
  echo json_encode([
    'access_token' => 'synthetic-current',
    'refresh_token' => 'synthetic-refresh-new',
    'token_type' => 'bearer',
    'expires_in' => 3600,
  ], JSON_THROW_ON_ERROR);
}
elseif (($_SERVER['REQUEST_URI'] ?? '') === '/auth/me' && in_array($_SERVER['HTTP_AUTHORIZATION'] ?? '', ['Bearer synthetic-qa-person-a', 'Bearer synthetic-qa-person-b'], TRUE)) {
  echo json_encode(['id' => substr($_SERVER['HTTP_AUTHORIZATION'], strlen('Bearer synthetic-')), 'name' => 'Synthetic QA', 'role' => 'student'], JSON_THROW_ON_ERROR);
}
elseif (($_SERVER['REQUEST_URI'] ?? '') === '/auth/me' && ($_SERVER['HTTP_AUTHORIZATION'] ?? '') === 'Bearer synthetic-current') {
  echo '{"id":"qa-user","name":"Synthetic QA","role":"student"}';
}
else {
  http_response_code(401);
  echo '{"detail":"synthetic missing session"}';
}
