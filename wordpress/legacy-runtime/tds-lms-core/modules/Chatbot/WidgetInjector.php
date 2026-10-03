<?php
namespace TDS\Chatbot;

class WidgetInjector {
    public function __construct() {
        add_action('learn-press/after-lesson-content', [$this, 'inject_widget'], 20);
    }

    public function inject_widget(): void {
        if (!is_user_logged_in()) return;

        global $post;
        if (!($post instanceof \WP_Post)) return;
        $course_id = learn_press_get_course_id($post->ID);
        if (!$course_id) return;

        $user_id = get_current_user_id();
        $lp_user = learn_press_get_user($user_id);
        if (!$lp_user->has_enrolled_course($course_id)) return;

        $course_slug = get_post_field('post_name', $course_id);
        $session_id  = 'aluno-' . $user_id . '-curso-' . $course_slug;
        $base_url    = rtrim(TDS_ANYTHINGLLM_URL, '/');

        echo $this->render($base_url, $course_slug, $session_id);
    }

    public function render(string $base_url, string $course_slug, string $session_id): string {
        return sprintf(
            '<div class="tds-chatbot-wrapper" style="margin-top:2rem;">
                <script
                    data-embed-id="%s"
                    data-base-api-url="%s/api/embed"
                    data-session-id="%s"
                    src="%s/embed/anythingllm-chat-widget.min.js">
                </script>
            </div>',
            esc_attr($course_slug),
            esc_url($base_url),
            esc_attr($session_id),
            esc_url($base_url)
        );
    }
}
