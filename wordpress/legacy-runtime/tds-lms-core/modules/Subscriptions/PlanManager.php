<?php
namespace TDS\Subscriptions;

class PlanManager {
    const PLAN_META = '_tds_subscription_plan';

    public function __construct() {
        add_action('woocommerce_order_status_completed', [$this, 'activate_subscription'], 10, 1);
        add_action('rest_api_init',                       [$this, 'register_mp_callback']);
    }

    public function activate_subscription(int $order_id): void {
        $order = wc_get_order($order_id);
        if (!$order) return;
        foreach ($order->get_items() as $item) {
            $pid  = $item->get_product_id();
            $plan = get_post_meta($pid, self::PLAN_META, true);
            if ($plan !== 'all_courses') continue;

            $user_id = $order->get_user_id();
            update_user_meta($user_id, '_tds_subscription_active', 1);
            update_user_meta($user_id, '_tds_subscription_order',  $order_id);
            $this->enroll_all_courses($user_id);
        }
    }

    private function enroll_all_courses(int $user_id): void {
        $courses = get_posts(['post_type' => 'lp_course', 'posts_per_page' => -1, 'fields' => 'ids']);
        $lp_user = learn_press_get_user($user_id);
        foreach ($courses as $cid) {
            if ($lp_user->has_enrolled_course($cid)) continue;
            $this->lp_enroll($user_id, (int) $cid);
        }
    }

    private function lp_enroll(int $user_id, int $course_id): void {
        $uc             = new \LearnPress\Models\UserItems\UserCourseModel();
        $uc->user_id    = $user_id;
        $uc->item_id    = $course_id;
        $uc->item_type  = LP_COURSE_CPT;
        $uc->ref_type   = '';
        $uc->status     = LP_COURSE_ENROLLED;
        $uc->graduation = LP_COURSE_GRADUATION_IN_PROGRESS;
        $uc->start_time = gmdate('Y-m-d H:i:s', time());
        $uc->save();
        do_action('learn-press/assigned-course-to-user', $uc);
    }

    public function register_mp_callback(): void {
        register_rest_route('tds/v1', '/mp-subscription-callback', [
            'methods'             => 'POST',
            'callback'            => [$this, 'handle_mp_subscription_callback'],
            'permission_callback' => '__return_true',
        ]);
    }

    public function handle_mp_subscription_callback(\WP_REST_Request $req): \WP_REST_Response {
        // Verify shared secret to prevent unauthenticated subscription changes
        $received_key = $req->get_header('X-API-Key') ?? $req->get_param('api_key') ?? '';
        if (!defined('TDS_API_KEY') || !hash_equals(TDS_API_KEY, $received_key)) {
            return new \WP_REST_Response(['error' => 'forbidden'], 403);
        }

        $data    = $req->get_json_params();
        $action  = $data['action'] ?? '';
        $ext_ref = $data['external_reference'] ?? '';

        $parts    = explode('_', $ext_ref);
        $user_id  = isset($parts[0]) ? (int) $parts[0] : 0;
        $order_id = isset($parts[1]) ? (int) $parts[1] : 0;

        if (!$user_id || !$order_id) {
            return new \WP_REST_Response(['error' => 'invalid_reference'], 400);
        }

        // Validate order belongs to user before updating subscription state
        $order = wc_get_order($order_id);
        if (!$order || (int) $order->get_user_id() !== $user_id) {
            return new \WP_REST_Response(['error' => 'forbidden'], 403);
        }

        if ($action === 'authorized') {
            update_user_meta($user_id, '_tds_subscription_active', 1);
        } elseif (in_array($action, ['cancelled', 'paused'], true)) {
            update_user_meta($user_id, '_tds_subscription_active', 0);
        }
        return new \WP_REST_Response(['ok' => true], 200);
    }
}
