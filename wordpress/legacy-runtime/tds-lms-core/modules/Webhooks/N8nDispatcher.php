<?php
namespace TDS\Webhooks;

class N8nDispatcher {
    public function __construct() {
        add_action('learnpress_user_enrolled_course',  [$this, 'on_enrolled'],        10, 2);
        add_action('learnpress_user_completed-lesson', [$this, 'on_lesson_complete'], 10, 3);
        add_action('learnpress_user_completed-quiz',   [$this, 'on_quiz_complete'],   10, 3);
        add_action('learnpress_user_finish_course',    [$this, 'on_course_finish'],   10, 3);
    }

    public function build_payload_public(string $event, int $user_id, int $course_id, array $extra = []): array {
        $user  = get_user_by('id', $user_id);
        $phone = get_user_meta($user_id, '_tds_phone', true)
              ?: get_user_meta($user_id, 'billing_phone', true);

        return array_merge([
            'event'       => $event,
            'user_id'     => $user_id,
            'course_id'   => $course_id,
            'course_slug' => get_post_field('post_name', $course_id),
            'user_name'   => $user ? $user->display_name : '',
            'user_email'  => $user ? $user->user_email : '',
            'user_phone'  => $phone ?: '',
            'timestamp'   => gmdate('c'),
        ], $extra);
    }

    private function fire(string $endpoint, array $payload): void {
        $url = rtrim(TDS_N8N_URL, '/') . '/' . ltrim($endpoint, '/');
        wp_remote_post($url, [
            'headers'  => [
                'Content-Type'  => 'application/json',
                'Authorization' => 'Bearer ' . TDS_API_KEY,
            ],
            'body'     => wp_json_encode($payload),
            'timeout'  => 5,
            'blocking' => false,
        ]);
    }

    public function on_enrolled(int $user_id, int $course_id): void {
        $this->fire('lp-enrolled', $this->build_payload_public('enrolled', $user_id, $course_id));
    }

    public function on_lesson_complete(int $user_id, int $course_id, int $lesson_id): void {
        $lp_user = learn_press_get_user($user_id);
        $cd      = $lp_user->get_course_data($course_id);
        $this->fire('lp-lesson-complete', $this->build_payload_public('lesson_complete', $user_id, $course_id, [
            'lesson_id'    => $lesson_id,
            'lesson_title' => get_the_title($lesson_id),
            'progress_pct' => $cd ? $cd->get_percent_completion() : 0,
        ]));
    }

    public function on_quiz_complete(int $user_id, int $course_id, int $quiz_id): void {
        $lp_user   = learn_press_get_user($user_id);
        $item_data = $lp_user->get_item_data($quiz_id, $course_id);
        $this->fire('lp-quiz-complete', $this->build_payload_public('quiz_complete', $user_id, $course_id, [
            'quiz_id' => $quiz_id,
            'score'   => $item_data ? $item_data->get_result('mark') : 0,
            'passed'  => $item_data ? ($item_data->get_graduation() === 'passed') : false,
        ]));
    }

    public function on_course_finish(int $user_id, int $course_id): void {
        $lp_user = learn_press_get_user($user_id);
        $cd      = $lp_user->get_course_data($course_id);
        $this->fire('lp-course-finish', $this->build_payload_public('course_finish', $user_id, $course_id, [
            'graduation'      => $cd ? $cd->get_graduation() : '',
            'completion_date' => gmdate('Y-m-d'),
        ]));
    }
}
