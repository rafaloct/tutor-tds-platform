<?php
namespace TDS\Drip;

class Scheduler {
    public function __construct() {
        add_filter('learn-press/can-show-lesson-content', [$this, 'maybe_lock_lesson'], 10, 3);
        add_action('learn_press_user_enrolled_course',    [$this, 'schedule_unlocks'],  10, 2);
    }

    public function maybe_lock_lesson(bool $can_show, int $lesson_id, int $course_id): bool {
        if (!$can_show) return false;
        $unlock_days = (int) get_post_meta($lesson_id, '_tds_unlock_after_days', true);
        if (!$unlock_days) return $can_show;

        $user_id  = get_current_user_id();
        $enrolled = get_user_meta($user_id, "_lp_enrolled_{$course_id}", true);
        if (!$enrolled) return false;

        $unlock_ts = strtotime($enrolled) + ($unlock_days * DAY_IN_SECONDS);
        return time() >= $unlock_ts;
    }

    public function schedule_unlocks(int $user_id, int $course_id): void {
        update_user_meta($user_id, "_lp_enrolled_{$course_id}", gmdate('Y-m-d H:i:s'));
    }
}
