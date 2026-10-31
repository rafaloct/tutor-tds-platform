<?php
namespace TDS\API;

class RestController {
    const NS = 'tds/v1';

    public function __construct() {
        add_action('rest_api_init', [$this, 'register_routes']);
    }

    public function authenticate_public(\WP_REST_Request $request): bool {
        $key = $request->get_header('X-API-Key');
        return $key !== null && $key !== '' && hash_equals(TDS_API_KEY, $key);
    }

    private function auth_callback(): callable {
        return function (\WP_REST_Request $request) {
            return $this->authenticate_public($request)
                ? true
                : new \WP_Error('forbidden', 'Invalid API key', ['status' => 403]);
        };
    }

    public function register_routes(): void {
        $auth = $this->auth_callback();

        register_rest_route(self::NS, '/progress/(?P<user_id>\d+)', [
            'methods'             => 'GET',
            'callback'            => [$this, 'get_user_progress'],
            'permission_callback' => $auth,
        ]);
        register_rest_route(self::NS, '/progress/(?P<user_id>\d+)/(?P<course_slug>[a-z0-9-]+)', [
            'methods'             => 'GET',
            'callback'            => [$this, 'get_course_progress'],
            'permission_callback' => $auth,
        ]);
        register_rest_route(self::NS, '/courses', [
            'methods'             => 'GET',
            'callback'            => [$this, 'get_courses'],
            'permission_callback' => $auth,
        ]);
        register_rest_route(self::NS, '/enroll', [
            'methods'             => 'POST',
            'callback'            => [$this, 'enroll_user'],
            'permission_callback' => $auth,
        ]);
        register_rest_route(self::NS, '/certificate/(?P<user_id>\d+)/(?P<course_slug>[a-z0-9-]+)', [
            'methods'             => 'GET',
            'callback'            => [$this, 'get_certificate'],
            'permission_callback' => $auth,
        ]);
        register_rest_route(self::NS, '/verify/(?P<hash>[a-f0-9]{64})', [
            'methods'             => 'GET',
            'callback'            => [$this, 'verify_certificate'],
            'permission_callback' => '__return_true',
        ]);
        register_rest_route(self::NS, '/user-by-phone/(?P<phone>[\d+\-\(\)\s]+)', [
            'methods'             => 'GET',
            'callback'            => [$this, 'get_user_by_phone'],
            'permission_callback' => $auth,
        ]);
    }

    public function get_user_progress(\WP_REST_Request $req): \WP_REST_Response {
        $user_id = (int) $req['user_id'];
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT ui.item_id, ui.status, ui.graduation, p.post_name, p.post_title
             FROM {$wpdb->prefix}learnpress_user_items ui
             JOIN {$wpdb->posts} p ON p.ID = ui.item_id AND p.post_status = 'publish'
             WHERE ui.user_id = %d AND ui.item_type = %s",
            $user_id, LP_COURSE_CPT
        ));
        $data = array_map(fn($r) => [
            'course_id'    => (int) $r->item_id,
            'course_slug'  => $r->post_name,
            'course_title' => $r->post_title,
            'status'       => $r->status,
            'graduation'   => $r->graduation,
            'progress_pct' => null,
        ], $rows ?: []);
        return new \WP_REST_Response($data, 200);
    }

    public function get_course_progress(\WP_REST_Request $req): \WP_REST_Response {
        $user_id     = (int) $req['user_id'];
        $course_slug = sanitize_text_field($req['course_slug']);
        $course      = get_page_by_path($course_slug, OBJECT, 'lp_course');
        if (!$course) return new \WP_REST_Response(['error' => 'Course not found'], 404);

        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare(
            "SELECT status, graduation, start_time
             FROM {$wpdb->prefix}learnpress_user_items
             WHERE user_id = %d AND item_id = %d AND item_type = %s
             ORDER BY user_item_id DESC LIMIT 1",
            $user_id, $course->ID, LP_COURSE_CPT
        ));
        if (!$row) {
            return new \WP_REST_Response(['error' => 'User not enrolled'], 403);
        }
        return new \WP_REST_Response([
            'user_id'        => $user_id,
            'course_id'      => $course->ID,
            'course_slug'    => $course_slug,
            'course_title'   => get_the_title($course->ID),
            'status'         => $row->status,
            'graduation'     => $row->graduation,
            'progress_pct'   => null,
            'current_lesson' => null,
            'enrolled_at'    => $row->start_time,
        ], 200);
    }

    public function get_courses(\WP_REST_Request $req): \WP_REST_Response {
        $posts = get_posts(['post_type' => 'lp_course', 'posts_per_page' => -1, 'post_status' => 'publish']);
        $data  = array_map(fn($c) => [
            'id'      => $c->ID,
            'slug'    => $c->post_name,
            'title'   => $c->post_title,
            'price'   => (float)(get_post_meta($c->ID, '_lp_price', true) ?: 0),
            'is_free' => !get_post_meta($c->ID, '_lp_price', true),
        ], $posts);
        return new \WP_REST_Response($data, 200);
    }

    public function enroll_user(\WP_REST_Request $req): \WP_REST_Response {
        $user_id     = (int) $req->get_param('user_id');
        $course_slug = sanitize_text_field($req->get_param('course_slug'));
        if ($user_id <= 0) return new \WP_REST_Response(['error' => 'Invalid user_id'], 400);
        $course      = get_page_by_path($course_slug, OBJECT, 'lp_course');
        if (!$course) return new \WP_REST_Response(['error' => 'Course not found'], 404);

        $lp_user = learn_press_get_user($user_id);
        if ($lp_user->has_enrolled_course($course->ID)) {
            return new \WP_REST_Response(['message' => 'Already enrolled'], 200);
        }

        $uc             = new \LearnPress\Models\UserItems\UserCourseModel();
        $uc->user_id    = $user_id;
        $uc->item_id    = $course->ID;
        $uc->item_type  = LP_COURSE_CPT;
        $uc->ref_type   = '';
        $uc->status     = LP_COURSE_ENROLLED;
        $uc->graduation = LP_COURSE_GRADUATION_IN_PROGRESS;
        $uc->start_time = gmdate('Y-m-d H:i:s', time());
        $uc->save();
        do_action('learn-press/assigned-course-to-user', $uc);
        return new \WP_REST_Response(['success' => true, 'enrolled_at' => $uc->start_time], 201);
    }

    public function get_certificate(\WP_REST_Request $req): mixed {
        $user_id     = (int) $req['user_id'];
        $course_slug = sanitize_text_field($req['course_slug']);
        $path        = WP_CONTENT_DIR . "/uploads/tds-certificates/{$user_id}-{$course_slug}.pdf";
        if (!file_exists($path)) return new \WP_REST_Response(['error' => 'Certificate not found'], 404);
        header('Content-Type: application/pdf');
        $safe_slug = preg_replace('/[^a-z0-9\-]/', '', $course_slug);
        header('Content-Disposition: attachment; filename="certificado-' . $safe_slug . '.pdf"');
        readfile($path);
        exit;
    }

    public function verify_certificate(\WP_REST_Request $req): \WP_REST_Response {
        global $wpdb;
        $hash = sanitize_text_field($req['hash']);
        $cert = $wpdb->get_row($wpdb->prepare(
            "SELECT user_id, course_slug, issued_at FROM {$wpdb->prefix}tds_certificates WHERE hash = %s",
            $hash
        ));
        if (!$cert) return new \WP_REST_Response(['valid' => false], 404);
        $user   = get_user_by('id', $cert->user_id);
        $course = get_page_by_path($cert->course_slug, OBJECT, 'lp_course');
        return new \WP_REST_Response([
            'valid'        => true,
            'student_name' => $user?->display_name ?? 'N/A',
            'course_title' => $course ? get_the_title($course->ID) : $cert->course_slug,
            'issued_at'    => $cert->issued_at,
        ], 200);
    }

    public function get_user_by_phone(\WP_REST_Request $req): \WP_REST_Response {
        global $wpdb;
        $phone_clean = preg_replace('/\D/', '', sanitize_text_field($req['phone']));
        $user_id     = $wpdb->get_var($wpdb->prepare(
            "SELECT user_id FROM {$wpdb->usermeta}
             WHERE meta_key = 'billing_phone'
               AND REGEXP_REPLACE(meta_value, '[^0-9]', '') = %s LIMIT 1",
            $phone_clean
        ));
        if (!$user_id) {
            $user_id = $wpdb->get_var($wpdb->prepare(
                "SELECT user_id FROM {$wpdb->usermeta}
                 WHERE meta_key = '_tds_phone'
                   AND REGEXP_REPLACE(meta_value, '[^0-9]', '') = %s LIMIT 1",
                $phone_clean
            ));
        }
        if (!$user_id) return new \WP_REST_Response(['found' => false], 404);
        $user = get_user_by('id', $user_id);
        return new \WP_REST_Response([
            'found'        => true,
            'user_id'      => (int) $user_id,
            'display_name' => $user->display_name,
            'email'        => $user->user_email,
        ], 200);
    }
}
