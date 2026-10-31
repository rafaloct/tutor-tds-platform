<?php
namespace TDS\Payments;

defined('ABSPATH') || exit;

/**
 * Optional, explicit LearnPress enrollment for published free courses.
 *
 * Public lessons stay readable without enrollment. An enrollment is written
 * only after the student submits a course-specific request or signs up
 * through the course-specific public CTA.
 */
class EnrollmentGate {
    // The nine optional-enrollment TDS courses; other courses retain native LearnPress buttons.
    private const OPTIONAL_TDS_COURSES = [614, 1298, 1307, 1314, 1321, 1328, 1335, 1343, 1356];
    private ?int $signupCourseId = null;
    private bool $signupEnrolled = false;

    public function __construct() {
        // Do NOT enroll by merely visiting a course page.
        add_action('learn-press/after-course-buttons', [$this, 'render_optin'], 30);
        // LearnPress 4.3 modern layout builds the right column via this filter,
        // bypassing the classic buttons.php template and its action hooks.
        add_filter('learn-press/single-course/modern/section_right', [$this, 'render_modern_optin'], 30, 3);
        add_action('admin_post_tds_course_enroll', [$this, 'submit_optin']);

        // Keep course intent through the existing public /cadastro/ form,
        // without changing the site's global WordPress registration setting.
        add_filter('admin_url', [$this, 'carry_signup_course'], 10, 3);
        add_filter('login_url', [$this, 'carry_login_course'], 10, 3);
        add_filter('register_url', [$this, 'public_register_url']);
        add_action('login_form_register', [$this, 'redirect_native_registration']);
        add_action('user_register', [$this, 'enroll_new_signup'], 20, 1);
        add_filter('wp_redirect', [$this, 'redirect_after_signup'], 10, 2);

        // Preserve independent payment-based enrollment (if enabled later).
        add_action('woocommerce_payment_complete', [$this, 'enroll_after_payment'], 10, 1);
    }

    private function valid_course(int $course_id): bool {
        if ($course_id <= 0 || get_post_type($course_id) !== 'lp_course' ||
            get_post_status($course_id) !== 'publish') {
            return false;
        }
        $price = get_post_meta($course_id, '_lp_price', true);
        return ($price === '' || $price === false || $price === null ||
            (is_numeric($price) && (float) $price <= 0.0));
    }

    private function selected_course(): int {
        $id = isset($_GET['tds_curso']) ? absint(wp_unslash($_GET['tds_curso'])) : 0;
        return $this->valid_course($id) ? $id : 0;
    }

    private function signup_intent_course(): int {
        if (sanitize_key(wp_unslash($_POST['action'] ?? '')) !== 'tds_cadastro') {
            return 0;
        }
        $id = $this->selected_course();
        if (!$id) return 0;
        $token = sanitize_text_field(wp_unslash($_GET['tds_enroll_token'] ?? ''));
        if (!$token || !wp_verify_nonce($token, 'tds_public_signup_' . $id)) {
            return 0;
        }
        return $id;
    }

    public function render_modern_optin(array $section, $course, $user): array {
        if (!array_key_exists('buttons', $section)) return $section;
        ob_start();
        $this->render_optin();
        $cta = ob_get_clean();
        if ($cta !== '') {
            $section['buttons'] = (string) $section['buttons'] . $cta;
        }
        return $section;
    }

    public function render_optin(): void {
        if (!is_singular('lp_course')) return;
        $course_id = (int) get_the_ID();
        if (!$this->valid_course($course_id) ||
            !in_array($course_id, self::OPTIONAL_TDS_COURSES, true)) return;

        echo '<div class="tds-enrollment-optin" style="margin:1rem 0;padding:1rem;border:1px solid #cbd5e1;border-radius:8px">';
        echo '<p style="margin:0 0 .75rem">As aulas são abertas. A inscrição é opcional e permite acompanhar sua matrícula neste curso.</p>';

        if (!is_user_logged_in()) {
            $register = add_query_arg('tds_curso', $course_id, home_url('/cadastro/'));
            echo '<a class="button lp-button" href="' . esc_url($register) . '">Inscrever-me gratuitamente</a>';
            echo ' <span style="display:inline-block;margin:.5rem 0">Já tem conta? ';
            echo '<a href="' . esc_url(wp_login_url(get_permalink($course_id))) . '">Entrar para se inscrever</a></span>';
        } elseif ($this->is_enrolled(get_current_user_id(), $course_id)) {
            echo '<p role="status" style="margin:0">Você já está inscrito neste curso. <a href="' .
                esc_url(get_permalink(get_option('learn_press_profile_page_id'))) .
                '">Ver Minha Área</a></p>';
        } else {
            echo '<form method="post" action="' . esc_url(admin_url('admin-post.php')) . '">';
            echo '<input type="hidden" name="action" value="tds_course_enroll">';
            echo '<input type="hidden" name="tds_curso" value="' . esc_attr((string) $course_id) . '">';
            wp_nonce_field('tds_course_enroll_' . $course_id, 'tds_course_enroll_nonce');
            echo '<button type="submit" class="button lp-button">Confirmar minha inscrição gratuita</button>';
            echo '</form>';
        }
        if (isset($_GET['tds_inscricao'])) {
            $status = sanitize_key(wp_unslash($_GET['tds_inscricao']));
            if ($status === 'ok' && is_user_logged_in() &&
                $this->is_enrolled(get_current_user_id(), $course_id)) {
                echo '<p role="status">Inscrição confirmada. Você já pode acompanhar este curso na Minha Área.</p>';
            } elseif ($status === 'erro') {
                echo '<p role="alert">Não foi possível concluir a inscrição. Tente novamente ou fale com o suporte.</p>';
            }
        }
        echo '</div>';
    }

    public function submit_optin(): void {
        $course_id = isset($_POST['tds_curso']) ? absint(wp_unslash($_POST['tds_curso'])) : 0;
        if (!$this->valid_course($course_id)) {
            wp_die('Curso indisponível para inscrição gratuita.', '', ['response' => 403]);
        }
        if (!is_user_logged_in()) {
            wp_safe_redirect(wp_login_url(get_permalink($course_id)));
            exit;
        }
        check_admin_referer('tds_course_enroll_' . $course_id, 'tds_course_enroll_nonce');
        $ok = $this->enroll_user(get_current_user_id(), $course_id);
        wp_safe_redirect(add_query_arg('tds_inscricao', $ok ? 'ok' : 'erro', get_permalink($course_id)), 303);
        exit;
    }

    public function public_register_url(string $original_url): string {
        $id = is_singular('lp_course') ? (int) get_the_ID() : $this->selected_course();
        $url = home_url('/cadastro/');
        return $this->valid_course($id) ? add_query_arg('tds_curso', $id, $url) : $url;
    }

    public function redirect_native_registration(): void {
        // /wp-login.php?action=register would otherwise show "registration disabled",
        // although the authorized institutional /cadastro/ form works independently.
        wp_safe_redirect($this->public_register_url(''), 302);
        exit;
    }

    public function carry_signup_course(string $url, string $path, $blog_id = null): string {
        if ($path !== 'admin-post.php' || !is_page('cadastro')) return $url;
        $id = $this->selected_course();
        if (!$id) return $url;
        return add_query_arg([
            'tds_curso' => $id,
            'tds_enroll_token' => wp_create_nonce('tds_public_signup_' . $id),
        ], $url);
    }

    public function carry_login_course(string $login_url, string $redirect, bool $force_reauth): string {
        if (!is_page('cadastro')) return $login_url;
        $id = $this->selected_course();
        return $id ? add_query_arg('redirect_to', get_permalink($id), $login_url) : $login_url;
    }

    public function enroll_new_signup(int $user_id): void {
        $id = $this->signup_intent_course();
        if (!$id || $user_id <= 0) return;
        $this->signupCourseId = $id;
        $this->signupEnrolled = $this->enroll_user($user_id, $id);
    }

    public function redirect_after_signup(string $location, int $status): string {
        if ($this->signupCourseId && strpos($location, home_url('/minha-area/')) === 0 &&
            strpos($location, 'cadastro=ok') !== false) {
            return add_query_arg(
                'tds_inscricao',
                $this->signupEnrolled ? 'ok' : 'erro',
                get_permalink($this->signupCourseId)
            );
        }
        // Existing email: preserve which course the visitor wanted, then
        // the "Entrar" link on /cadastro/ returns to the intended course.
        if (strpos($location, home_url('/cadastro/')) === 0 &&
            strpos($location, 'cadastro=email') !== false) {
            $id = $this->signup_intent_course();
            if ($id) return add_query_arg('tds_curso', $id, $location);
        }
        return $location;
    }

    private function is_enrolled(int $user_id, int $course_id): bool {
        if (!function_exists('learn_press_get_user')) return false;
        $lp_user = learn_press_get_user($user_id);
        return $lp_user && $lp_user->has_enrolled_course($course_id);
    }

    private function enroll_user(int $user_id, int $course_id): bool {
        if (!$this->valid_course($course_id) || $user_id <= 0) return false;
        if ($this->is_enrolled($user_id, $course_id)) return true;
        return $this->lp_enroll($user_id, $course_id);
    }

    public function enroll_after_payment(int $order_id): void {
        if (!function_exists('wc_get_order')) return;
        $order = wc_get_order($order_id);
        if (!$order) return;
        $user_id = (int) $order->get_user_id();
        foreach ($order->get_items() as $item) {
            $product_id = $item->get_product_id();
            $course_id = (int) get_post_meta($product_id, '_lp_course_id', true);
            if (!$course_id || !$user_id) continue;
            if ($this->is_enrolled($user_id, $course_id)) continue;
            $this->lp_enroll($user_id, $course_id);
        }
    }

    private function lp_enroll(int $user_id, int $course_id): bool {
        if (!class_exists('\LearnPress\Models\UserItems\UserCourseModel')) return false;
        try {
            $uc = new \LearnPress\Models\UserItems\UserCourseModel();
            $uc->user_id = $user_id;
            $uc->item_id = $course_id;
            $uc->item_type = LP_COURSE_CPT;
            $uc->ref_type = '';
            $uc->status = LP_COURSE_ENROLLED;
            $uc->graduation = LP_COURSE_GRADUATION_IN_PROGRESS;
            $uc->start_time = gmdate('Y-m-d H:i:s', time());
            $saved = $uc->save();
            if ($saved === false) return false;
            do_action('learn-press/assigned-course-to-user', $uc);
            return true;
        } catch (\Throwable $e) {
            // Do not disclose personal data, access tokens or stack traces.
            error_log('TDS LearnPress enrollment failed for published course.');
            return false;
        }
    }
}
