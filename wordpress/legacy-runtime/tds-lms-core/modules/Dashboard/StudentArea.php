<?php
namespace TDS\Dashboard;

class StudentArea {
    public function __construct() {
        add_shortcode('tds_minha_area', [$this, 'render']);
        add_action('wp_enqueue_scripts', [$this, 'enqueue_assets']);
    }

    public function enqueue_assets(): void {
        if (!has_shortcode(get_post()?->post_content ?? '', 'tds_minha_area')) return;
        wp_enqueue_style('tds-dashboard', get_stylesheet_directory_uri() . '/assets/dashboard.css', [], '1.0');
    }

    public function render(): string {
        if (!is_user_logged_in()) {
            return '<p>Faça <a href="' . esc_url(wp_login_url(get_permalink())) . '">login</a> para acessar sua área.</p>';
        }

        $user_id = get_current_user_id();
        $user    = wp_get_current_user();
        $courses = get_posts(['post_type' => 'lp_course', 'posts_per_page' => -1, 'fields' => 'ids']);
        $lp_user = learn_press_get_user($user_id);

        $enrolled = [];
        foreach ($courses as $cid) {
            if (!$lp_user->has_enrolled_course($cid)) continue;
            $cd = $lp_user->get_course_data($cid);
            $enrolled[] = [
                'id'     => $cid,
                'title'  => get_the_title($cid),
                'slug'   => get_post_field('post_name', $cid),
                'pct'    => $cd ? $cd->get_percent_completion() : 0,
                'status' => $cd ? $cd->get_status() : '',
                'url'    => get_permalink($cid),
            ];
        }

        ob_start();
        include __DIR__ . '/views/student-area.php';
        return ob_get_clean();
    }
}
