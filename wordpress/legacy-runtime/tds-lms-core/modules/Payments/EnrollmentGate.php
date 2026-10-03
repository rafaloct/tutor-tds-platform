<?php
namespace TDS\Payments;

class EnrollmentGate {
    public function __construct() {
        add_action('template_redirect', [$this, 'maybe_auto_enroll']);
        add_action('woocommerce_payment_complete', [$this, 'enroll_after_payment'], 10, 1);
    }

    public function maybe_auto_enroll(): void {
        if (!is_singular('lp_course') || !is_user_logged_in()) return;
        $course_id = get_the_ID();
        if (get_post_meta($course_id, '_lp_price', true)) return;

        $user_id = get_current_user_id();
        $lp_user = learn_press_get_user($user_id);
        if ($lp_user->has_enrolled_course($course_id)) return;

        $this->lp_enroll($user_id, $course_id);
    }

    public function enroll_after_payment(int $order_id): void {
        $order = wc_get_order($order_id);
        if (!$order) return;
        $user_id = $order->get_user_id();
        foreach ($order->get_items() as $item) {
            $product_id = $item->get_product_id();
            $course_id  = (int) get_post_meta($product_id, '_lp_course_id', true);
            if (!$course_id) continue;
            $lp_user = learn_press_get_user($user_id);
            if ($lp_user->has_enrolled_course($course_id)) continue;
            $this->lp_enroll($user_id, $course_id);
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
}
