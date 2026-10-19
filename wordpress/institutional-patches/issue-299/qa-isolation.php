<?php
// Only copied to the disposable QA clone, never part of the promotion patch.
defined('ABSPATH') || exit;
add_filter('pre_wp_mail', '__return_true', PHP_INT_MAX);
add_filter('pre_http_request', function () {
    return new WP_Error('qa_network_blocked', 'External requests disabled in synthetic QA');
}, PHP_INT_MAX);
add_filter('template_include', function ($template) {
    error_log('QA299_TEMPLATE=' . basename(dirname($template)) . '/' . basename($template));
    return $template;
}, PHP_INT_MAX);
