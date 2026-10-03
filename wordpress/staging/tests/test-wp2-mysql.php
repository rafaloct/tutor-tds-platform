<?php
$root = getenv('TDS_WP_QA_ROOT');
if (!$root || !is_file($root . '/.tds-mysql-qa') || trim(file_get_contents($root . '/.tds-mysql-qa')) !== 'tds-wp2-local-mysql-synthetic-only') { throw new RuntimeException('Missing MySQL QA marker'); }
$mode = $argv[1] ?? 'seed';
if ($mode === 'install') { define('WP_INSTALLING', true); }
require $root . '/wp-load.php';
if (wp_get_environment_type() !== 'local' || DB_HOST !== '127.0.0.1:13342' || !in_array(DB_NAME, ['wp2_qa', 'wp2_restore'], true) || defined('DB_ENGINE')) { throw new RuntimeException('Refusing non-QA MySQL target'); }
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/template.php';
$checks = 0;
function mysql_check($ok, $label) { if (!$ok) { throw new RuntimeException('FAIL ' . $label); } ++$GLOBALS['checks']; }
if ($mode === 'install') {
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    wp_install('Synthetic MySQL WP2', 'qa_admin', 'qa@example.invalid', false, '', 'Synthetic-QA-Only-20261003!');
    activate_plugin('tds-portal-core/tds-portal-core.php');
    echo "PASS MySQL WordPress installed\n";
    exit;
}
global $wpdb;
mysql_check(strpos($wpdb->db_version(), '8.4.11') === 0, 'actual MySQL version');
mysql_check((string)get_option('blog_public') === '0', 'noindex stored');
mysql_check(is_wp_error(wp_remote_get('https://example.invalid')), 'WordPress egress blocked');
mysql_check(wp_mail('qa@example.invalid', 'synthetic', 'discard'), 'mail discard hook');
if ($mode === 'deactivate') {
    deactivate_plugins('tds-portal-core/tds-portal-core.php');
    mysql_check(!is_plugin_active('tds-portal-core/tds-portal-core.php'), 'deactivated');
} elseif ($mode === 'inactive') {
    mysql_check(!class_exists('TDS_Public_Config'), 'deactivated plugin absent after restart');
    mysql_check(rest_get_server()->dispatch(new WP_REST_Request('GET', '/tds-portal/v1/public/courses'))->get_status() === 404, 'deactivated route absent');
    mysql_check(get_option('tds_app_access_url') === 'https://example.org/mysql-app', 'option retained inert');
    activate_plugin('tds-portal-core/tds-portal-core.php');
} else {
    do_action('admin_init');
    mysql_check(is_plugin_active('tds-portal-core/tds-portal-core.php'), 'active plugin on MySQL');
    if ($mode === 'seed') {
        update_option('tds_app_access_url', 'https://example.org/mysql-app');
        update_option('tds_ga4_measurement_id', 'G-ABCDEFGHIJ');
        $id = wp_insert_post(['post_type'=>'page', 'post_status'=>'publish', 'post_title'=>'Synthetic recovery marker', 'post_name'=>'synthetic-recovery-marker', 'post_content'=>'No real participant data']);
        mysql_check($id > 0, 'synthetic editorial page persisted');
    }
    mysql_check(get_option('tds_app_access_url') === 'https://example.org/mysql-app', 'MySQL option persists');
    mysql_check(get_option('tds_ga4_measurement_id') === 'G-ABCDEFGHIJ', 'GA4 option persists inactive');
    mysql_check(get_page_by_path('synthetic-recovery-marker') !== null, 'editorial page persists');
    $reply = rest_get_server()->dispatch(new WP_REST_Request('GET', '/tds-portal/v1/public/courses'));
    mysql_check($reply->get_status() === 503 && $reply->get_data()['state'] === 'unavailable', 'MySQL route fallback');
    mysql_check(TDS_Public_Config::get()['integration_state']['analytics'] === 'disabled' && TDS_Public_Config::get()['integration_state']['support'] === 'disabled', 'integrations stay off');
}
echo "PASS $checks MySQL assertions ($mode)\n";
