<?php

/**
 * @file
 * Settings do portal Drupal Tutor TDS, dirigidos por variaveis de ambiente.
 *
 * DR-2 / Issue #163. Nenhum segredo aqui: credenciais, salt e endpoints chegam
 * via env (ver drupal/.env.example). O banco declarado e o MariaDB exclusivo
 * do Drupal; o PostgreSQL do Tutor TDS nunca e referenciado neste arquivo.
 */

// phpcs:ignoreFile

// Fail-closed (review ACP PR #177): fora de "local" as variaveis sensiveis sao
// obrigatorias e os defaults inseguros de dev sao rejeitados — o site NAO sobe
// com configuracao de desenvolvimento.
$tds_environment = getenv('DRUPAL_ENVIRONMENT') ?: 'local';

if ($tds_environment !== 'local') {
  $tds_required = [
    'DRUPAL_DB_NAME' => [],
    'DRUPAL_DB_USER' => [],
    'DRUPAL_DB_PASSWORD' => ['drupal-dev-only'],
    'DRUPAL_DB_HOST' => [],
    'DRUPAL_HASH_SALT' => ['drupal-local-dev-salt-insecure'],
    'DRUPAL_TRUSTED_HOSTS' => [],
  ];
  foreach ($tds_required as $tds_var => $tds_forbidden) {
    $tds_value = getenv($tds_var);
    if ($tds_value === FALSE || $tds_value === '' || in_array($tds_value, $tds_forbidden, TRUE)) {
      throw new \RuntimeException(sprintf(
        'settings.php: %s obrigatoria (e nao pode usar o default inseguro de dev) quando DRUPAL_ENVIRONMENT="%s".',
        $tds_var,
        $tds_environment
      ));
    }
  }
  // Production can use the actual local image ID when built on the VPS.
  // Staging retains its registry digest contract.
  $tds_image_var = $tds_environment === 'production' ? 'DRUPAL_IMAGE_REF' : 'DRUPAL_STAGING_IMAGE_REF';
  $tds_image_ref = getenv($tds_image_var);
  $tds_image_pattern = $tds_environment === 'production'
    ? '/^(?:[^\s@]+@)?sha256:[0-9a-f]{64}$/'
    : '/^[^\s@]+@sha256:[0-9a-f]{64}$/';
  if (!is_string($tds_image_ref) || preg_match($tds_image_pattern, $tds_image_ref) !== 1) {
    throw new \RuntimeException('settings.php: immutable image reference required in ' . $tds_image_var);
  }
}

$databases['default']['default'] = [
  'database' => getenv('DRUPAL_DB_NAME') ?: 'drupal',
  'username' => getenv('DRUPAL_DB_USER') ?: 'drupal',
  'password' => getenv('DRUPAL_DB_PASSWORD') ?: 'drupal-dev-only',
  'host' => getenv('DRUPAL_DB_HOST') ?: 'db',
  'port' => (int) (getenv('DRUPAL_DB_PORT') ?: 3306),
  'driver' => getenv('DRUPAL_DB_DRIVER') ?: 'mysql',
  'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
  'autoload' => 'core/modules/mysql/src/Driver/Database/mysql/',
  'prefix' => '',
  'collation' => 'utf8mb4_general_ci',
];

$settings['hash_salt'] = getenv('DRUPAL_HASH_SALT') ?: 'drupal-local-dev-salt-insecure';

$settings['update_free_access'] = FALSE;
$settings['container_yamls'][] = $app_root . '/' . $site_path . '/services.yml';
$settings['entity_update_batch_size'] = 50;
$settings['entity_update_backup'] = TRUE;

$settings['config_sync_directory'] = '../config/sync';
$settings['file_public_path'] = 'sites/default/files';
$tds_private_path = getenv('DRUPAL_PRIVATE_PATH') ?: ($tds_environment === 'production' ? '/var/www/private' : 'sites/default/files/private');
if ($tds_environment === 'production') {
  // Require an absolute, normalized path outside the public document root.
  $tds_public_root = rtrim(realpath($app_root) ?: $app_root, '/');
  $tds_resolved_private = realpath($tds_private_path) ?: $tds_private_path;
  if (!str_starts_with($tds_private_path, '/') || str_contains($tds_private_path, "\0")
    || preg_match('~(?:^|/)\.\.?(?:/|$)|//~', $tds_private_path)
    || $tds_resolved_private === $tds_public_root
    || str_starts_with($tds_resolved_private, $tds_public_root . '/')) {
    throw new \RuntimeException('settings.php: DRUPAL_PRIVATE_PATH must be outside the webroot.');
  }
}
$settings['file_private_path'] = $tds_private_path;

// Identificador de ambiente lido pelo endpoint /health (tds_health).
$settings['tds_environment'] = $tds_environment;
// Explicit opt-in only after the authenticated-production acceptance gate.
$settings['tds_production_sessions_enabled'] = getenv('TDS_ACADEMIC_SESSION_ENABLED') === 'true';

$tds_proxies = getenv('DRUPAL_REVERSE_PROXY_ADDRESSES');
if ($tds_proxies !== FALSE && $tds_proxies !== '') {
  $tds_proxy_addresses = array_map('trim', explode(',', $tds_proxies));
  foreach ($tds_proxy_addresses as $tds_proxy) {
    $tds_parts = explode('/', $tds_proxy);
    $tds_ip = $tds_parts[0];
    $tds_max_prefix = filter_var($tds_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) ? 32 : 128;
    if (!filter_var($tds_ip, FILTER_VALIDATE_IP) || count($tds_parts) > 2
      || in_array($tds_ip, ['0.0.0.0', '::'], TRUE)
      || (isset($tds_parts[1]) && (!ctype_digit($tds_parts[1]) || (int) $tds_parts[1] < 1 || (int) $tds_parts[1] > $tds_max_prefix))) {
      throw new \RuntimeException('settings.php: explicit proxy IP addresses or restricted CIDRs required.');
    }
  }
  $settings['reverse_proxy'] = TRUE;
  $settings['reverse_proxy_addresses'] = $tds_proxy_addresses;
  // Trust only the headers supplied by our configured Traefik proxy.
  $settings['reverse_proxy_trusted_headers'] = \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_FOR
    | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PROTO
    | \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_PORT;
}

// URL base da API Tutor TDS (BFF). Vazia = integracao ainda nao configurada.
$settings['tutor_api_base_url'] = getenv('TUTOR_API_BASE_URL') ?: '';

$trusted = getenv('DRUPAL_TRUSTED_HOSTS');
$settings['trusted_host_patterns'] = $trusted
  ? array_values(array_filter(array_map('trim', explode(',', $trusted))))
  : ['^localhost$', '^127\.0\.0\.1$'];

if ($tds_environment === 'local') {
  $settings['skip_permissions_hardening'] = TRUE;
}

$settings['config_exclude_modules'] = ['devel', 'stage_file_proxy'];
$settings['migrate_node_migrate_type_classic'] = FALSE;

if (file_exists($app_root . '/' . $site_path . '/settings.local.php')) {
  include $app_root . '/' . $site_path . '/settings.local.php';
}
