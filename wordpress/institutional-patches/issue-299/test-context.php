<?php
// Pure boundary tests; not a replacement for HTTP WordPress/LearnPress QA.
define('ABSPATH', __DIR__);
function home_url($path) { return 'https://qa-synthetic.test' . $path; }
function add_query_arg($key, $value, $url) { return $url . '?' . urlencode($key) . '=' . urlencode($value); }
function wp_parse_url($url) { return parse_url($url); }
function wp_validate_redirect($url, $fallback) { return $url; }
function get_post($id) { return $GLOBALS['posts'][$id] ?? null; }
function get_permalink($post) { return $GLOBALS['permalink']; }
require __DIR__ . '/tds-registration-course.php';
$posts = [614 => (object)['ID'=>614, 'post_type'=>'lp_course', 'post_status'=>'publish', 'post_password'=>'']];
$permalink = 'https://qa-synthetic.test/courses/qa/';
$passed = 0;
function verify($name, $condition) {
    if (!$condition) { fwrite(STDERR, "FAIL $name\n"); exit(1); }
    ++$GLOBALS['passed']; echo "PASS $name\n";
}
verify('no course preserves default', tds_registration_course_context([])['url'] === home_url('/minha-area/'));
verify('published course accepted', tds_registration_course_context(['tds_curso'=>'614'])['id'] === 614);
foreach (['', '0', '-614', '614x', '0614', ' 614', '614.0', '999999999999999999999999', 'https://evil.invalid', ['614'], null, '9999'] as $i => $bad) {
    verify('invalid input ' . $i, tds_registration_course_context(['tds_curso'=>$bad])['invalid']);
}
foreach (['draft', 'pending', 'private', 'trash'] as $status) {
    $posts[614]->post_status = $status;
    verify('nonpublished ' . $status, tds_registration_course_context(['tds_curso'=>'614'])['invalid']);
}
$posts[614]->post_status = 'publish';
$posts[614]->post_type = 'post';
verify('wrong post type', tds_registration_course_context(['tds_curso'=>'614'])['invalid']);
$posts[614]->post_type = 'lp_course';
$posts[614]->post_password = 'synthetic';
verify('password protected', tds_registration_course_context(['tds_curso'=>'614'])['invalid']);
$posts[614]->post_password = '';
foreach (['https://evil.invalid/course', 'http://qa-synthetic.test/course', 'https://qa-synthetic.test:8443/course', 'https://user@qa-synthetic.test/course', '//qa-synthetic.test/course', false] as $i => $url) {
    $permalink = $url;
    verify('unsafe permalink ' . $i, tds_registration_course_context(['tds_curso'=>'614'])['invalid']);
}
$permalink = 'https://qa-synthetic.test/courses/qa/';
verify('user redirect ignored', tds_registration_course_context(['tds_curso'=>'614', 'redirect_to'=>'https://evil.invalid/'])['url'] === $permalink);
echo "TOTAL=$passed PASS\n";
