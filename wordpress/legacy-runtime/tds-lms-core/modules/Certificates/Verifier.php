<?php
namespace TDS\Certificates;

class Verifier {
    public function __construct() {
        add_action('init', [$this, 'add_rewrite_rule']);
        add_filter('query_vars', fn($vars) => array_merge($vars, ['tds_verify_hash']));
        add_action('template_redirect', [$this, 'maybe_render_verification']);
    }

    public function add_rewrite_rule(): void {
        add_rewrite_rule('^verificar/([a-f0-9]{64})/?$', 'index.php?tds_verify_hash=$matches[1]', 'top');
    }

    public function maybe_render_verification(): void {
        $hash = get_query_var('tds_verify_hash');
        if (!$hash) return;

        global $wpdb;
        $cert = $wpdb->get_row($wpdb->prepare(
            "SELECT user_id, course_slug, issued_at FROM {$wpdb->prefix}tds_certificates WHERE hash = %s", $hash
        ));

        status_header(200);
        include __DIR__ . '/views/verification.php';
        exit;
    }
}
