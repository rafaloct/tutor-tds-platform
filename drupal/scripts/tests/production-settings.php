<?php
/** Standalone focused runtime checks; argument 1 is Composer autoload.php. */
declare(strict_types=1);
require $argv[1];
require dirname(__DIR__, 2) . '/web/modules/custom/tds_tutor_gateway/src/EventSubscriber/ProductionSessionGateSubscriber.php';
use Drupal\Core\Site\Settings;
use Drupal\tds_tutor_gateway\EventSubscriber\ProductionSessionGateSubscriber;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\HttpKernelInterface;
$n = 0;
function verify(bool $ok): void { global $n; if (!$ok) { throw new RuntimeException('check failed'); } $n++; }
function config(array $override = []): array {
  foreach (array_replace([
    'DRUPAL_ENVIRONMENT' => 'production', 'DRUPAL_DB_NAME' => 'test',
    'DRUPAL_DB_USER' => 'test', 'DRUPAL_DB_PASSWORD' => 'synthetic',
    'DRUPAL_DB_HOST' => 'db', 'DRUPAL_HASH_SALT' => 'synthetic',
    'DRUPAL_TRUSTED_HOSTS' => '^portal.example$',
    'DRUPAL_IMAGE_REF' => 'sha256:' . str_repeat('a', 64),
    'DRUPAL_STAGING_IMAGE_REF' => '', 'DRUPAL_PRIVATE_PATH' => '',
    'DRUPAL_REVERSE_PROXY_ADDRESSES' => '', 'TDS_ACADEMIC_SESSION_ENABLED' => '',
  ], $override) as $k => $v) { putenv("$k=$v"); }
  $settings = [];
  $app_root = dirname(__DIR__, 2) . '/web'; $site_path = 'sites/default';
  require "$app_root/$site_path/settings.php";
  return $settings;
}
$s = config(); verify($s['file_private_path'] === '/var/www/private');
verify($s['tds_production_sessions_enabled'] === FALSE); verify(!isset($s['reverse_proxy']));
foreach ([
  ['DRUPAL_IMAGE_REF' => 'latest'], ['DRUPAL_ENVIRONMENT' => 'staging'],
  ['DRUPAL_PRIVATE_PATH' => 'relative'], ['DRUPAL_PRIVATE_PATH' => '/var/www/private/../html/web/files'],
  ['DRUPAL_PRIVATE_PATH' => dirname(__DIR__, 2) . '/web/files'],
  ['DRUPAL_DB_PASSWORD' => 'drupal-dev-only'],
  ...array_map(fn($v) => ['DRUPAL_REVERSE_PROXY_ADDRESSES' => $v], ['*', '0.0.0.0/0', '::/0', '172.18.0.0/0', '172.18.0.0/33', 'example.com', '172.18.0.2,']),
] as $bad) {
  $rejected = FALSE; try { config($bad); } catch (RuntimeException) { $rejected = TRUE; } verify($rejected);
}
verify(config(['DRUPAL_REVERSE_PROXY_ADDRESSES' => '172.18.0.2,fd00::2/128'])['reverse_proxy'] === TRUE);
verify(config(['DRUPAL_ENVIRONMENT' => 'staging', 'DRUPAL_STAGING_IMAGE_REF' => 'registry/drupal@sha256:' . str_repeat('b', 64)])['tds_environment'] === 'staging');
verify(config(['DRUPAL_ENVIRONMENT' => 'local'])['skip_permissions_hardening'] === TRUE);
verify(config(['DRUPAL_IMAGE_REF' => 'registry/drupal@sha256:' . str_repeat('b', 64)])['tds_environment'] === 'production');
$kernel = new class implements HttpKernelInterface {
  public function handle(Request $request, int $type = self::MAIN_REQUEST, bool $catch = TRUE): Response { return new Response(); }
};
foreach ([
  ['production', FALSE, '/tds/session/login', '', TRUE],
  ['production', FALSE, '/tds/session/context', '', TRUE],
  ['production', FALSE, '/tds/session/logout', '', TRUE],
  ['production', FALSE, '/alias', 'tds_tutor_gateway.login', TRUE],
  ['production', FALSE, '/%74ds/session/login', '', TRUE],
  ['production', FALSE, '/minha-area', '', TRUE],
  ['production', FALSE, '/operacoes/', '', TRUE],
  ['production', FALSE, '/meus-certificados', '', TRUE],
  ['production', FALSE, '/tds/support/identity', '', TRUE],
  ['production', FALSE, '/tds/support/frame', '', TRUE],
  ['production', FALSE, '/alias', 'tds_participant_portal.dashboard', TRUE],
  ['production', FALSE, '/alias', 'tds_operator_portal.operations', TRUE],
  ['production', FALSE, '/alias', 'tds_support_certificates.certificates', TRUE],
  ['production', FALSE, '/suporte', 'tds_support_certificates.support', FALSE],
  ['production', FALSE, '/verificar-certificado', 'tds_support_certificates.public', FALSE],
  ['production', FALSE, '/portal', '', FALSE], ['production', FALSE, '/health', '', FALSE],
  ['production', TRUE, '/tds/session/login', '', FALSE], ['production', 'true', '/tds/session/login', '', TRUE],
  ['staging', FALSE, '/tds/session/login', '', FALSE], ['local', FALSE, '/tds/session/login', '', FALSE],
] as [$env, $flag, $path, $route, $blocked]) {
  $gate = new ProductionSessionGateSubscriber(new Settings(['tds_environment' => $env, 'tds_production_sessions_enabled' => $flag]));
  $r = Request::create($path); $r->attributes->set('_route', $route);
  $event = new RequestEvent($kernel, $r, HttpKernelInterface::MAIN_REQUEST); $gate->onRequest($event);
  verify($event->hasResponse() === $blocked);
  if ($blocked) {
    $response = $event->getResponse(); verify($response->getStatusCode() === 403);
    $response->headers->set('Cache-Control', 'public, max-age=3600');
    $gate->onResponse(new ResponseEvent($kernel, $r, HttpKernelInterface::MAIN_REQUEST, $response));
    verify($response->headers->hasCacheControlDirective('no-store'));
  }
}
printf("PASS %d production runtime checks\n", $n);
