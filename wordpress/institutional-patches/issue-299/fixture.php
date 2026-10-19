<?php
// Disposable database only. Never a production seed.
if (strpos(DB_NAME, 'tds_registration_299') !== 0 || get_option('home') !== 'http://tds-registration-299') {
    throw new Exception('Wrong fixture database/origin');
}
wp_set_current_user(1);
foreach (['cadastro' => 'pages/cadastro.php', 'cursos' => 'pages/catalogo.php', 'minha-area' => 'pages/minha-area.php'] as $slug => $template) {
    $page = get_page_by_path($slug);
    $id = $page ? $page->ID : wp_insert_post(['post_type' => 'page', 'post_status' => 'publish', 'post_name' => $slug, 'post_title' => 'QA ' . $slug], true);
    if (is_wp_error($id)) throw new Exception('Page fixture failed');
    update_post_meta($id, '_wp_page_template', $template);
}
if (get_post(614)) throw new Exception('Course fixture ID collision');
$id = wp_insert_post(['import_id' => 614, 'post_type' => 'lp_course', 'post_status' => 'publish', 'post_author' => 1, 'post_name' => 'qa-course-614', 'post_title' => 'QA synthetic course 614', 'post_content' => 'Synthetic enrollment QA'], true);
if ($id !== 614) throw new Exception('Course ID mismatch');
update_post_meta(614, '_lp_price', '0');
update_post_meta(614, '_lp_no_required_enroll', 'no');
update_post_meta(614, '_lp_course_repurchase', 'no');
update_post_meta(13, '_lp_preview', 'no');
wp_update_post(['ID' => 13, 'post_author' => 1, 'post_content' => 'QA_RESTRICTED_LESSON_299_MARKER']);
global $wpdb;
// Curriculum fixture only, not an enrollment write.
$wpdb->update($wpdb->prefix . 'learnpress_sections', ['section_course_id' => 614], ['section_course_id' => 12]);
clean_post_cache(614);
echo wp_json_encode(['course' => 614, 'status' => get_post_status(614), 'url' => get_permalink(614), 'registration_policy' => get_option('users_can_register'), 'theme' => get_option('stylesheet')]);
