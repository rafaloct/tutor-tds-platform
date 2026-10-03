<?php
// Real core integration. Point only at the disposable QA installation.
$root = getenv('TDS_WP_QA_ROOT');
if (!$root || !is_file($root . '/wp-config.php') || !is_file($root . '/.tds-disposable-qa') || trim(file_get_contents($root . '/.tds-disposable-qa')) !== 'tds-wp2-local-synthetic-only') { throw new RuntimeException('Missing disposable TDS_WP_QA_ROOT marker'); }
require $root . '/wp-load.php';
if (wp_get_environment_type() !== 'local' || home_url() !== 'http://127.0.0.1:18742' || !defined('DB_ENGINE') || DB_ENGINE !== 'sqlite') {
    throw new RuntimeException('Refusing non-QA environment');
}
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/template.php';
do_action('admin_init');
$checks = 0;
function verify_qa($condition, $message) {
    if (!$condition) { throw new RuntimeException('FAIL ' . $message); }
    ++$GLOBALS['checks'];
}
if (($argv[1] ?? '') === 'reload') {
    verify_qa(get_option('tds_app_access_url') === 'https://play.google.com/store/apps/details?id=org.example.synthetic', 'option persisted across PHP process');
    verify_qa(get_option('tds_ga4_measurement_id') === 'G-ABCDEFGHIJ', 'GA4 persisted');
    echo "PASS $checks real WordPress reload assertions\n";
    exit;
}
verify_qa(is_plugin_active('tds-portal-core/tds-portal-core.php'), 'plugin active in real core');
verify_qa(is_wp_error(wp_remote_get('https://example.invalid')), 'WordPress HTTP egress blocked');
verify_qa(wp_mail('synthetic@example.invalid', 'sink test', 'synthetic'), 'mail intercepted by QA sink');
$server = rest_get_server();
foreach ([['GET', [], 503], ['GET', ['page' => 0], 400], ['GET', ['page' => 'abc'], 400], ['GET', ['per_page' => 51], 400], ['GET', ['per_page' => -1], 400], ['POST', [], 404], ['DELETE', [], 404]] as [$method, $params, $status]) {
    $request = new WP_REST_Request($method, '/tds-portal/v1/public/courses');
    $request->set_query_params($params);
    $response = $server->dispatch($request);
    verify_qa($response->get_status() === $status, "REST $method " . json_encode($params));
    if (!$params && $method === 'GET') {
        verify_qa($response->get_data()['pagination'] === ['page' => 1, 'per_page' => 12, 'total' => 0], 'core supplies default pagination');
        verify_qa($response->get_data()['state'] === 'unavailable', 'real core default unavailable');
    }
}
update_option('tds_app_access_url', 'https://play.google.com/store/apps/details?id=org.example.synthetic');
verify_qa(TDS_Public_Config::get()['integration_state']['app'] === 'ready', 'save valid app option');
update_option('tds_app_access_url', 'javascript:alert(1)');
verify_qa(get_option('tds_app_access_url') === '', 'registered sanitizer rejects unsafe app');
update_option('tds_app_access_url', 'https://play.google.com/store/apps/details?id=org.example.synthetic');
update_option('tds_ga4_measurement_id', 'private-token');
verify_qa(get_option('tds_ga4_measurement_id') === '', 'GA4 unsafe value rejected');
update_option('tds_ga4_measurement_id', 'G-ABCDEFGHIJ');
update_option('tds_public_api_base_url', 'https://api.example.org/?token=x');
verify_qa(get_option('tds_public_api_base_url') === '', 'base URL query rejected');
update_option('tds_public_api_base_url', 'https://api.example.org/');
update_option('tds_support_base_url', 'https://support.example.org/');
verify_qa(TDS_Public_Config::get()['integration_state']['analytics'] === 'disabled' && TDS_Public_Config::get()['integration_state']['support'] === 'disabled' && TDS_Public_Config::get()['integration_state']['courses'] === 'unavailable', 'valid config cannot activate integrations');
wp_set_current_user(get_user_by('login', 'qa_subscriber')->ID);
verify_qa(!current_user_can('manage_options'), 'subscriber lacks settings capability');
wp_set_current_user(get_user_by('login', 'qa_admin')->ID);
verify_qa(current_user_can('manage_options'), 'admin settings capability');
verify_qa(wp_verify_nonce(wp_create_nonce('general-options'), 'general-options') !== false && wp_verify_nonce('invalid', 'general-options') === false, 'real nonce primitives');
echo "PASS $checks real WordPress core assertions (SQLite local only)\n";
