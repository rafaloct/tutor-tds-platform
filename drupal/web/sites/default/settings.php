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
  // Rereview ACP PR #177: a imagem da aplicacao declarada pelo ambiente deve
  // ser ref imutavel pinnada por digest (repo@sha256:<64-hex>); tag mutavel
  // nao pode subir em staging.
  $tds_image_ref = getenv('DRUPAL_STAGING_IMAGE_REF');
  if (!is_string($tds_image_ref) || preg_match('/^[^\s@]+@sha256:[0-9a-f]{64}$/', $tds_image_ref) !== 1) {
    throw new \RuntimeException(sprintf(
      'settings.php: DRUPAL_STAGING_IMAGE_REF deve ser referencia imutavel repo@sha256:<64-hex> quando DRUPAL_ENVIRONMENT="%s".',
      $tds_environment
    ));
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
$settings['file_private_path'] = 'sites/default/files/private';

// Identificador de ambiente lido pelo endpoint /health (tds_health).
$settings['tds_environment'] = $tds_environment;

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
