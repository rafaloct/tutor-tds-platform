<?php
/** QA-only MU plugin. Never package with the theme or install in production. */
defined('ABSPATH') || exit;
if (strpos(DB_NAME, 'tds_registration_299r_') !== 0) {
    http_response_code(503);
    exit('QA database identity mismatch');
}
$GLOBALS['tds_qa_mail_blocked'] = 0;
$GLOBALS['tds_qa_http_blocked'] = 0;
function tds_qa_block_mail($return, $attributes) {
    ++$GLOBALS['tds_qa_mail_blocked'];
    error_log('QA299_MAIL_SHORT_CIRCUIT');
    return true;
}
function tds_qa_block_http() {
    ++$GLOBALS['tds_qa_http_blocked'];
    return new WP_Error('qa_network_blocked', 'External requests disabled in synthetic QA');
}
add_filter('pre_wp_mail', 'tds_qa_block_mail', PHP_INT_MAX, 2);
add_filter('pre_http_request', 'tds_qa_block_http', PHP_INT_MAX);
add_action('phpmailer_init', function () {
    throw new RuntimeException('QA_MAIL_TRANSPORT_REACHED_STOP');
}, -PHP_INT_MAX);
if (PHP_SAPI !== 'cli') {
    header('X-TDS-QA-Boot: apache-isolation-v2');
    error_log('QA299_APACHE_BOOT');
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST' && !is_file('/tmp/qa299-posts-enabled')) {
        http_response_code(503);
        exit('QA POST gate closed');
    }
}
add_filter('template_include', function ($template) {
    $name = basename(dirname($template)) . '/' . basename($template);
    if (!headers_sent()) header('X-TDS-QA-Template: ' . $name);
    error_log('QA299_TEMPLATE=' . $name);
    return $template;
}, PHP_INT_MAX);
add_action('init', function () {
    if (PHP_SAPI === 'cli' || ($_GET['tds_qa_probe'] ?? '') !== '1') return;
    $mail_filter = has_filter('pre_wp_mail', 'tds_qa_block_mail') !== false;
    $http_filter = has_filter('pre_http_request', 'tds_qa_block_http') !== false;
    if (!$mail_filter || !$http_filter) {
        http_response_code(503);
        exit('QA isolation filters missing');
    }
    // The native calls must be short-circuited; the transport guard stops any regression.
    $mail = wp_mail('qa-sink@qa-synthetic.test', 'Synthetic QA transport probe', 'No delivery permitted');
    $http = wp_remote_get('https://qa-egress.invalid/', ['timeout' => 1]);
    $page = get_page_by_path('cadastro');
    wp_send_json([
        'sapi' => PHP_SAPI,
        'mu_loaded' => true,
        'mail_short_circuit' => $mail === true && $GLOBALS['tds_qa_mail_blocked'] === 1,
        'http_short_circuit' => is_wp_error($http) && $http->get_error_code() === 'qa_network_blocked',
        'theme' => get_option('stylesheet'),
        'home' => get_option('home'),
        'siteurl' => get_option('siteurl'),
        'page_template' => $page ? get_post_meta($page->ID, '_wp_page_template', true) : null,
        'post_gate_open' => is_file('/tmp/qa299-posts-enabled'),
    ]);
});
