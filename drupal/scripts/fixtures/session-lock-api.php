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
if (($_SERVER['REQUEST_URI'] ?? '') === '/auth/refresh') {
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
elseif (($_SERVER['REQUEST_URI'] ?? '') === '/auth/me' && ($_SERVER['HTTP_AUTHORIZATION'] ?? '') === 'Bearer synthetic-current') {
  echo '{"id":"qa-user","name":"Synthetic QA","role":"student"}';
}
else {
  http_response_code(401);
  echo '{"detail":"synthetic missing session"}';
}
