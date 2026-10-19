<?php
/**
 * Standalone contract smoke with WordPress/LearnPress stubs.
 * Does not require database, credentials, Docker, or production installation.
 */
declare( strict_types=1 );
define( 'ABSPATH', '/mock/wordpress/' );
define( 'WPINC', 'wp-includes' );

final class WP_REST_Server { const READABLE = 'GET'; }
class WP_REST_Request implements ArrayAccess {
	private array $headers = array();
	public function __construct( public string $method = 'GET', public string $route = '' ) {}
	public array $params = array();
	public function offsetExists( $offset ): bool { return isset( $this->params[ $offset ] ); }
	public function offsetGet( $offset ): mixed { return $this->params[ $offset ] ?? null; }
	public function offsetSet( $offset, $value ): void { $this->params[ $offset ] = $value; }
	public function offsetUnset( $offset ): void { unset( $this->params[ $offset ] ); }
	public function get_header( $key ) { return $this->headers[ $key ] ?? ''; }
	public function set_header( $key, $value ) { $this->headers[ $key ] = $value; }
}
class WP_REST_Response {
	public array $headers = array();
	public function __construct( private mixed $data, private int $status = 200 ) {}
	public function get_data(): mixed { return $this->data; }
	public function get_status(): int { return $this->status; }
	public function header( $key, $value ): void { $this->headers[ $key ] = $value; }
}
class WP_Error {
	public function __construct( public string $code, public string $message, public array $data = array() ) {}
}

$posts = array(
	1356 => (object) array( 'ID'=>1356, 'post_type'=>'lp_course', 'post_status'=>'publish', 'post_title'=>'SAF', 'post_modified_gmt'=>'2026-10-17 21:00:00', 'post_content'=>'' ),
	1425 => (object) array( 'ID'=>1425, 'post_type'=>'lp_lesson', 'post_status'=>'publish', 'post_title'=>'Aula SAF', 'post_modified_gmt'=>'2026-10-17 21:00:00', 'post_content'=>'<h2>Agroecologia</h2><script>steal();</script><p>Texto seguro.</p>[private id=1]' ),
	1426 => (object) array( 'ID'=>1426, 'post_type'=>'lp_lesson', 'post_status'=>'draft', 'post_title'=>'Privado', 'post_modified_gmt'=>'2026-10-17 21:00:00', 'post_content'=>'Segredo' ),
	640  => (object) array( 'ID'=>640,  'post_type'=>'lp_quiz', 'post_status'=>'publish', 'post_title'=>'Quiz SAF', 'post_modified_gmt'=>'2026-10-17 21:00:00', 'post_content'=>'Gabarito secreto' ),
	641  => (object) array( 'ID'=>641,  'post_type'=>'lp_quiz', 'post_status'=>'draft', 'post_title'=>'Quiz oculto', 'post_modified_gmt'=>'2026-10-17 21:00:00', 'post_content'=>'Nota' ),
);
$meta = array();
$sections = array(
	array( 'id'=>80, 'title'=>'Assista em vídeo', 'items'=>array(
		array( 'id'=>1425, 'type'=>'lp_lesson', 'title'=>'Aula SAF' ),
		array( 'id'=>1426, 'type'=>'lp_lesson', 'title'=>'Privado' ),
		array( 'id'=>640, 'type'=>'lp_quiz', 'title'=>'Quiz SAF' ),
		array( 'id'=>641, 'type'=>'lp_quiz', 'title'=>'Quiz oculto' ),
	) ),
);
$registered = array();
$can_edit = true;
function get_post( $id ) { global $posts; return $posts[ $id ] ?? null; }
function get_post_meta( $id, $key, $single = true ) { global $meta; return $meta[ $id ][ $key ] ?? ''; }
function update_post_meta( $id, $key, $value ) { global $meta; $meta[ $id ][ $key ] = $value; }
function wp_strip_all_tags( $text ) { return strip_tags( (string) $text ); }
function home_url( $path = '/' ) { return 'https://ead.ipexdesenvolvimento.cloud' . $path; }
function get_permalink( $id ) {
	if ( 1356 === $id ) { return 'https://ead.ipexdesenvolvimento.cloud/courses/saf/'; }
	if ( 640 === $id ) { return 'https://ead.ipexdesenvolvimento.cloud/quizzes/quiz-saf/'; }
	return 'https://ead.ipexdesenvolvimento.cloud/lessons/aula/';
}
function wp_parse_url( $url, $part = -1 ) { return parse_url( $url, $part ); }
function wp_json_encode( $value, $opts = 0 ) { return json_encode( $value, $opts ); }
function is_wp_error( $value ) { return $value instanceof WP_Error; }
function rest_do_request( $request ) {
	global $sections;
	$match = array();
	if ( ! preg_match( '#^/learnpress/v1/courses/([0-9]+)$#', $request->route, $match ) ) {
		return new WP_Error( 'unknown_route', 'Error' );
	}
	return new WP_REST_Response( array( 'id'=>(int) $match[1], 'sections'=>$sections ), 200 );
}
function register_rest_route( $ns, $route, $args ) { global $registered; $registered[ $route ] = $args; }
function __return_true() { return true; }
// The real WP strip_shortcodes removes only registered shortcode names.
function strip_shortcodes( $raw ) { return $raw; }
function wp_kses( $raw, $allowed, $protocols ) {
	// Test stub: WordPress' actual wp_kses is stricter than this deterministic test.
	// Real wp_kses removes tags, not necessarily the contents of script tags.
	// Any remaining text must already have been removed by the plugin.
	$allowed_tags = '<' . implode( '><', array_keys( $allowed ) ) . '>';
	return strip_tags( $raw, $allowed_tags );
}
function add_meta_box( ...$unused ) {}
function current_user_can( $cap, $post_id = null ) { global $can_edit; return $can_edit; }
function wp_nonce_field( $action, $name ) {}
function checked( $value, $expected, $echo ) { return $value === $expected ? ' checked' : ''; }
function esc_attr( $value ) { return htmlspecialchars( (string) $value, ENT_QUOTES ); }
function sanitize_text_field( $s ) { return trim( strip_tags( (string) $s ) ); }
function wp_unslash( $s ) { return stripslashes( (string) $s ); }
function wp_verify_nonce( $nonce, $action ) { return 'validnonce' === $nonce; }
function wp_is_post_revision( $id ) { return false; }
function esc_url_raw( $url, $protocols = null ) { return filter_var( $url, FILTER_VALIDATE_URL ) ?: ''; }

require_once dirname( __DIR__ ) . '/includes/class-tds-learnpress-editorial.php';
require_once dirname( __DIR__ ) . '/includes/class-tds-learnpress-editorial-admin.php';

$checks = 0;
function verify( $condition, $reason ) {
	global $checks;
	$checks++;
	if ( ! $condition ) { fwrite( STDERR, 'FAIL: ' . $reason . "\n" ); exit( 2 ); }
}
function request_course( $id = 1356, $etag = '' ) {
	$request = new WP_REST_Request( 'GET' );
	$request['course_id'] = $id;
	if ( $etag ) { $request->set_header( 'if-none-match', $etag ); }
	return TDS_LearnPress_Editorial::curriculum( $request );
}
function request_lesson( $id = 1425, $etag = '' ) {
	$request = new WP_REST_Request( 'GET' );
	$request['course_id'] = 1356;
	$request['lesson_id'] = $id;
	if ( $etag ) { $request->set_header( 'if-none-match', $etag ); }
	return TDS_LearnPress_Editorial::lesson( $request );
}

TDS_LearnPress_Editorial::register_routes();
verify( count( $registered ) === 2, 'Two routes registered' );
verify( $registered['/courses/(?P<course_id>[1-9][0-9]{0,8})/curriculum']['methods'] === 'GET', 'GET only' );
$r = request_course();
verify( $r->get_status() === 200, 'Course visible' );
$data = $r->get_data();
verify( $data['schema_version'] === 1 && $data['authority'] === 'learnpress', 'Schema and authority' );
verify( count( $data['sections'][0]['items'] ) === 2, 'Draft lesson and quiz are hidden' );
verify( $data['sections'][0]['items'][0]['id'] === 1425, 'Lesson ID stable' );
verify( $data['sections'][0]['items'][0]['mobile_content'] === false, 'Default public text OFF' );
verify( $data['sections'][0]['items'][0]['media'] === null, 'Default media OFF' );
verify( $data['sections'][0]['items'][1]['url'] === 'https://ead.ipexdesenvolvimento.cloud/quizzes/quiz-saf/', 'Quiz metadata only' );
verify( strpos( json_encode( $data ), 'Gabarito' ) === false, 'Quiz answers never exported' );
verify( strpos( json_encode( $data ), 'steal' ) === false, 'Text not exported in outline' );
verify( request_course( 1356, $r->headers['ETag'] )->get_status() === 304, 'ETag 304' );
verify( request_course( 999 )->code === 'tds_editorial_course_not_published', 'Unknown course 404' );
verify( request_lesson()->code === 'tds_editorial_lesson_not_authorized', 'Lesson content opt-in required' );

update_post_meta( 1425, '_tds_mobile_public', '1' );
$r2 = request_course();
verify( $r2->headers['ETag'] !== $r->headers['ETag'], 'Content opt-in invalidates ETag' );
$lesson = request_lesson();
verify( $lesson->get_status() === 200, 'Explicitly public lesson visible' );
$body = $lesson->get_data()['content_html'];
verify( strpos( $body, '<h2>Agroecologia</h2>' ) !== false, 'Allowed formatted content retained' );
verify( strpos( $body, '<script' ) === false && strpos( $body, 'steal()' ) === false, 'Unsafe HTML stripped' );
verify( strpos( $body, '[private' ) === false, 'Unknown shortcodes stripped' );
verify( strpos( $body, 'steal()' ) === false, 'Script content stripped before wp_kses' );
verify( request_lesson( 1426 )->code === 'tds_editorial_lesson_not_authorized', 'Draft lesson never exposed' );

update_post_meta( 1425, '_tds_mobile_youtube_id', 'FG14ksTaMCE' );
verify( request_lesson()->get_data()['media'] === null, 'Without rights no YouTube exposure' );
update_post_meta( 1425, '_tds_mobile_rights_approved', '1' );
verify( request_lesson()->get_data()['media']['video_id'] === 'FG14ksTaMCE', 'Approved YouTube only' );
verify( request_lesson( 1425, request_lesson()->headers['ETag'] )->get_status() === 304, 'Lesson ETag 304' );

$original_content = $posts[1425]->post_content;
$base = 'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/qa/';
$posts[1425]->post_content = '<video controls><source src="' . $base . 'lesson.mp4">'
    . '<track kind="captions" src="' . $base . 'lesson.vtt" srclang="pt-BR"></video>';
update_post_meta( 1425, '_tds_mobile_youtube_id', '' );
$mp4 = request_lesson()->get_data()['media'];
verify( $mp4['provider'] === 'ipex_mp4', 'IPEX MP4 alternative to YouTube' );
verify( $mp4['source_url'] === $base . 'lesson.mp4', 'IPEX video URL scoped' );
verify( $mp4['captions_url'] === $base . 'lesson.vtt', 'IPEX captions scoped' );
verify( request_lesson( 1425, request_lesson()->headers['ETag'] )->get_status() === 304, 'MP4 ETag 304' );
update_post_meta( 1425, '_tds_mobile_rights_approved', '0' );
verify( request_lesson()->get_data()['media'] === null, 'MP4 requires rights flag' );
update_post_meta( 1425, '_tds_mobile_rights_approved', '1' );
$posts[1425]->post_content = str_replace( 'ead.ipexdesenvolvimento.cloud', 'example.org', $posts[1425]->post_content );
verify( request_lesson()->get_data()['media'] === null, 'MP4 other host rejected' );
$posts[1425]->post_content = $original_content;
update_post_meta( 1425, '_tds_mobile_youtube_id', 'FG14ksTaMCE' );
$original_section = $sections;
$sections[0]['items'] = array( array( 'id'=>640, 'type'=>'lp_quiz', 'title'=>'Quiz SAF' ) );
verify( request_lesson()->code === 'tds_editorial_lesson_not_authorized', 'Removing from curriculum removes public lesson access' );
$sections = $original_section;
$posts[1356]->post_status = 'private';
verify( request_course()->code === 'tds_editorial_course_not_published', 'Private course is denied' );
$posts[1356]->post_status = 'publish';

$_POST = array(
	'tds_mobile_lesson_nonce'=>'validnonce',
	'tds_mobile_public'=>'1',
	'tds_mobile_rights_approved'=>'1',
	'tds_mobile_youtube_id'=>'123456789ab',
	'tds_mobile_poster_url'=>'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/poster.jpg',
	'tds_mobile_captions_url'=>'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/a.vtt',
);
TDS_LearnPress_Editorial_Admin::save( 1425, $posts[1425] );
verify( get_post_meta( 1425, '_tds_mobile_rights_approved' ) === '0', 'Changing video resets rights even if checkbox remains checked' );
TDS_LearnPress_Editorial_Admin::save( 1425, $posts[1425] );
verify( get_post_meta( 1425, '_tds_mobile_rights_approved' ) === '1', 'Explicit second review can approve same ID' );
verify( request_lesson()->get_data()['media']['poster_url'] !== null, 'Approved WordPress poster' );
$_POST['tds_mobile_lesson_nonce'] = 'invalidnonce';
$_POST['tds_mobile_public'] = '';
TDS_LearnPress_Editorial_Admin::save( 1425, $posts[1425] );
verify( get_post_meta( 1425, '_tds_mobile_public' ) === '1', 'Invalid nonce cannot change publication' );
$can_edit = false;
$_POST['tds_mobile_lesson_nonce'] = 'validnonce';
TDS_LearnPress_Editorial_Admin::save( 1425, $posts[1425] );
verify( get_post_meta( 1425, '_tds_mobile_public' ) === '1', 'Unprivileged caller cannot change publication' );

// Corrupted external source data must fail closed without PHP warnings or disclosure.
$sections[] = 42;
verify( request_course()->code === 'tds_editorial_invalid_section', 'Malformed section rejected' );
$sections = $original_section;
$sections[0]['items'][] = 'invalid nonarray';
verify( request_course()->code === 'tds_editorial_invalid_item', 'Malformed section item rejected' );
$sections = $original_section;
// The source course revision changes when LearnPress editors modify titles.
$before = request_course()->headers['ETag'];
$posts[1425]->post_title = 'Aula SAF atualizada no LearnPress';
verify( request_course()->headers['ETag'] !== $before, 'Edited lesson title changes ETag without deployment' );
$_POST = array( 'tds_mobile_lesson_nonce' => array( 'invalid' ) );
$can_edit = true;
TDS_LearnPress_Editorial_Admin::save( 1425, $posts[1425] );
verify( get_post_meta( 1425, '_tds_mobile_public' ) === '1', 'Malformed nonce ignored safely' );
$_POST = array( 'tds_mobile_lesson_nonce' => 'validnonce', 'tds_mobile_youtube_id' => array( 'malformed' ) );
TDS_LearnPress_Editorial_Admin::save( 1425, $posts[1425] );
verify( get_post_meta( 1425, '_tds_mobile_rights_approved' ) === '0', 'Malformed video input cannot leave rights approved' );

update_post_meta( 1425, '_tds_mobile_public', '1' );
$posts[1425]->post_content = str_repeat( 'X', 250001 );
verify( request_lesson()->code === 'tds_editorial_lesson_too_large', 'Oversized lesson is denied' );

echo 'PHP_EDITORIAL_CONTRACT_TESTS_PASS=' . $checks . "\n";
