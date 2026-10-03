<?php
namespace TDS\Quiz;

class AdvancedQuiz {
    public function __construct() {
        add_action('add_meta_boxes', [$this, 'add_quiz_meta_boxes']);
        add_action('save_post_lp_quiz', [$this, 'save_quiz_meta'], 10, 2);
        add_filter('learn-press/question-meta-keys', [$this, 'add_question_meta_keys']);
        add_action('wp_enqueue_scripts', [$this, 'enqueue_quiz_scripts']);
        add_filter('learn-press/quiz-data', [$this, 'inject_timer_config'], 10, 2);
    }

    public function add_quiz_meta_boxes(): void {
        add_meta_box(
            'tds_quiz_settings', 'TDS — Configurações Avançadas',
            [$this, 'render_quiz_meta_box'], 'lp_quiz', 'side'
        );
    }

    public function render_quiz_meta_box(\WP_Post $post): void {
        $max_attempts = get_post_meta($post->ID, '_tds_quiz_max_attempts', true) ?: 3;
        $time_limit   = get_post_meta($post->ID, '_tds_quiz_time_limit', true) ?: 0;
        wp_nonce_field('tds_quiz_meta', 'tds_quiz_nonce');
        echo '<label>Tentativas máximas: <input type="number" name="tds_quiz_max_attempts" value="' . esc_attr($max_attempts) . '" min="1" style="width:60px"></label><br><br>';
        echo '<label>Tempo limite (min, 0=sem limite): <input type="number" name="tds_quiz_time_limit" value="' . esc_attr($time_limit) . '" min="0" style="width:60px"></label>';
    }

    public function save_quiz_meta(int $post_id, \WP_Post $post): void {
        if (!isset($_POST['tds_quiz_nonce']) || !wp_verify_nonce($_POST['tds_quiz_nonce'], 'tds_quiz_meta')) return;
        if (!current_user_can('edit_post', $post_id)) return;
        update_post_meta($post_id, '_tds_quiz_max_attempts', (int) ($_POST['tds_quiz_max_attempts'] ?? 3));
        update_post_meta($post_id, '_tds_quiz_time_limit',   (int) ($_POST['tds_quiz_time_limit'] ?? 0));
    }

    public function add_question_meta_keys(array $keys): array {
        return array_merge($keys, ['_tds_question_image', '_tds_question_explanation']);
    }

    public function enqueue_quiz_scripts(): void {
        if (!is_singular('lp_course')) return;
        wp_add_inline_script('learn-press', 'window.TDS_QUIZ_NONCE="' . wp_create_nonce('tds_quiz') . '";');
    }

    public function inject_timer_config(array $data, int $quiz_id): array {
        $limit = (int) get_post_meta($quiz_id, '_tds_quiz_time_limit', true);
        if ($limit > 0) $data['duration'] = $limit * 60;
        $data['retake_count'] = (int)(get_post_meta($quiz_id, '_tds_quiz_max_attempts', true) ?: 3);
        return $data;
    }
}
