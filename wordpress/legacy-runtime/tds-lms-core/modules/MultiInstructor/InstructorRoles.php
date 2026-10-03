<?php
namespace TDS\MultiInstructor;

class InstructorRoles {
    public function __construct() {
        add_action('add_meta_boxes',       [$this, 'add_co_instructor_box']);
        add_action('save_post_lp_course',  [$this, 'save_co_instructors'], 10, 2);
        add_filter('user_has_cap',         [$this, 'grant_course_access'],  10, 4);
    }

    public function add_co_instructor_box(): void {
        add_meta_box(
            'tds_co_instructors', 'Co-Instrutores TDS',
            [$this, 'render_co_instructor_box'], 'lp_course', 'side'
        );
    }

    public function render_co_instructor_box(\WP_Post $post): void {
        $saved = array_filter(array_map('intval', (array)(get_post_meta($post->ID, '_tds_co_instructors', true) ?: [])));
        wp_nonce_field('tds_co_instructors', 'tds_co_instructors_nonce');
        $instructors = get_users(['role__in' => ['administrator', 'lp_teacher', 'editor'], 'number' => 200]);
        echo '<select name="tds_co_instructors[]" multiple style="width:100%;height:120px">';
        foreach ($instructors as $u) {
            $selected = in_array($u->ID, $saved, true) ? ' selected' : '';
            echo '<option value="' . esc_attr($u->ID) . '"' . $selected . '>' . esc_html($u->display_name) . '</option>';
        }
        echo '</select>';
    }

    public function save_co_instructors(int $post_id, \WP_Post $post): void {
        if (!isset($_POST['tds_co_instructors_nonce']) || !wp_verify_nonce($_POST['tds_co_instructors_nonce'], 'tds_co_instructors')) return;
        if (!current_user_can('edit_post', $post_id)) return;
        $ids = isset($_POST['tds_co_instructors']) ? array_map('intval', (array) $_POST['tds_co_instructors']) : [];
        update_post_meta($post_id, '_tds_co_instructors', array_filter($ids));
    }

    public function grant_course_access(array $allcaps, array $caps, array $args, \WP_User $user): array {
        if (!in_array('edit_lp_course', $caps, true)) return $allcaps;
        $post_id = $args[2] ?? 0;
        if (!$post_id) return $allcaps;
        static $cache = [];
        if (!isset($cache[$post_id])) {
            $cache[$post_id] = array_map('intval', (array)(get_post_meta($post_id, '_tds_co_instructors', true) ?: []));
        }
        if (in_array($user->ID, $cache[$post_id], true)) {
            $allcaps['edit_lp_course'] = true;
        }
        return $allcaps;
    }
}
