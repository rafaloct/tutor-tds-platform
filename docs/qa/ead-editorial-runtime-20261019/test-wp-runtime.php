<?php
/** WordPress-core runtime QA with a synthetic LearnPress curriculum route. */
declare( strict_types=1 );

$root = getenv( 'TDS_WP_QA_ROOT' );
if ( ! is_string( $root ) || ! is_file( $root . '/wp-load.php' ) ) {
	fwrite( STDERR, "Disposable WordPress root required.\n" );
	exit( 2 );
}
require $root . '/wp-load.php';
require dirname( __DIR__, 3 ) . '/wordpress/tds-learnpress-editorial/tds-learnpress-editorial.php';

function qa_check( bool $pass, string $label ): void {
	if ( ! $pass ) {
		fwrite( STDERR, "FAIL: $label\n" );
		exit( 3 );
	}
	echo "PASS: $label\n";
}
function qa_request( string $route, string $etag = '' ): WP_REST_Response {
	$request = new WP_REST_Request( 'GET', $route );
	if ( '' !== $etag ) {
		$request->set_header( 'If-None-Match', $etag );
	}
	return rest_do_request( $request );
}
function qa_save( int $lesson, string $content, bool $rights = true, string $youtube = '' ): void {
	$_POST = array(
		'tds_mobile_lesson_nonce' => wp_create_nonce( 'tds_mobile_lesson_' . $lesson ),
		'tds_mobile_public' => '1',
		'tds_mobile_youtube_id' => $youtube,
	);
	if ( $rights ) {
		$_POST['tds_mobile_rights_approved'] = '1';
	}
	wp_update_post( array( 'ID' => $lesson, 'post_content' => $content ) );
}
function qa_media( string $route ): ?array {
	$response = qa_request( $route );
	qa_check( 200 === $response->get_status(), 'Authorized lesson REST 200' );
	return $response->get_data()['media'];
}

wp_set_current_user( 1 );
qa_check( current_user_can( 'manage_options' ), 'Synthetic editor is administrator' );
qa_check( 'https://ead.ipexdesenvolvimento.cloud' === home_url(), 'Synthetic home origin is IPEX HTTPS' );
register_post_type( 'lp_course', array( 'public' => true, 'rewrite' => array( 'slug' => 'courses' ) ) );
register_post_type( 'lp_lesson', array( 'public' => true, 'rewrite' => array( 'slug' => 'lessons' ) ) );
$course = wp_insert_post( array( 'post_type' => 'lp_course', 'post_status' => 'publish', 'post_title' => 'Curso sintético 290' ), true );
$lesson = wp_insert_post( array( 'post_type' => 'lp_lesson', 'post_status' => 'publish', 'post_title' => 'Aula sintética 290' ), true );
qa_check( is_int( $course ) && is_int( $lesson ), 'Synthetic WordPress posts persisted' );
add_action( 'rest_api_init', static function () use ( $course, $lesson ): void {
	register_rest_route( 'learnpress/v1', '/courses/(?P<id>\d+)', array(
		'methods' => WP_REST_Server::READABLE,
		'permission_callback' => '__return_true',
		'callback' => static function () use ( $course, $lesson ): WP_REST_Response {
			return new WP_REST_Response( array( 'id' => $course, 'sections' => array(
				array( 'id' => 1, 'title' => 'Seção sintética', 'items' => array(
					array( 'id' => $lesson, 'type' => 'lp_lesson', 'title' => 'Aula sintética 290' ),
				) ),
			) ), 200 );
		},
	) );
} );
$route = "/tds-learning/v1/courses/$course/lessons/$lesson";
$outline = "/tds-learning/v1/courses/$course/curriculum";
$base = 'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/qa/';
$html = static fn( string $mp4, string $vtt ): string => '<p>Aula sintética.</p><video controls><source src="' . $mp4 . '"><track kind="captions" src="' . $vtt . '" srclang="pt-BR"></video>';
$first = $html( $base . 'one.mp4', $base . 'one.vtt' );
qa_save( $lesson, $first );
qa_check( '0' === get_post_meta( $lesson, '_tds_mobile_rights_approved', true ), 'First editor submission does not approve MP4' );
qa_check( null === qa_media( $route ), 'First submission REST media closed' );
qa_save( $lesson, $first );
$media = qa_media( $route );
qa_check( 'ipex_mp4' === $media['provider'] && $base . 'one.vtt' === $media['captions_url'], 'Second submission approves HTTPS MP4/VTT' );
$response = qa_request( $route );
$etag = $response->get_headers()['ETag'];
qa_check( 304 === qa_request( $route, $etag )->get_status(), 'Authorized lesson REST 304' );
qa_check( 200 === qa_request( $outline )->get_status(), 'Authorized curriculum REST 200' );
$_POST = array();
wp_update_post( array( 'ID' => $lesson, 'post_content' => $html( $base . 'imported.mp4', $base . 'one.vtt' ) ) );
qa_check( null === qa_media( $route ), 'Out-of-metabox source replacement fails closed' );

$changed = $html( $base . 'two.mp4', $base . 'one.vtt' );
qa_save( $lesson, $changed );
qa_check( null === qa_media( $route ), 'MP4 swap invalidates rights' );
qa_check( 200 === qa_request( $route, $etag )->get_status(), 'Changed media invalidates prior ETag' );
qa_save( $lesson, $changed );
qa_check( $base . 'two.mp4' === qa_media( $route )['source_url'], 'MP4 reapproval requires second submission' );
$changed = $html( $base . 'two.mp4', $base . 'two.vtt' );
qa_save( $lesson, $changed );
qa_check( null === qa_media( $route ), 'VTT swap invalidates rights' );
qa_save( $lesson, $changed );
qa_check( $base . 'two.vtt' === qa_media( $route )['captions_url'], 'VTT reapproval requires second submission' );
qa_save( $lesson, $changed, false );
qa_check( null === qa_media( $route ), 'Explicit rights revocation closes media' );

foreach ( array(
	'wrong host' => $html( 'https://example.invalid/two.mp4', $base . 'two.vtt' ),
	'HTTP origin' => $html( str_replace( 'https:', 'http:', $base ) . 'two.mp4', $base . 'two.vtt' ),
	'wrong path' => $html( 'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/other/two.mp4', $base . 'two.vtt' ),
	'encoded traversal' => $html( $base . '%2e%2e/two.mp4', $base . 'two.vtt' ),
	'wrong VTT host' => $html( $base . 'two.mp4', 'https://example.invalid/two.vtt' ),
) as $label => $invalid ) {
	qa_save( $lesson, $invalid );
	qa_save( $lesson, $invalid );
	qa_check( null === qa_media( $route ), "$label denied after two submissions" );
}
qa_save( $lesson, '<p>YouTube legado.</p>', true, 'FG14ksTaMCE' );
qa_check( null === qa_media( $route ), 'Switch to YouTube resets rights' );
qa_save( $lesson, '<p>YouTube legado.</p>', true, 'FG14ksTaMCE' );
qa_check( 'FG14ksTaMCE' === qa_media( $route )['video_id'], 'YouTube legacy reapproval works' );
$_POST = array();
update_post_meta( $lesson, '_tds_mobile_public', '0' );
$revoked = qa_request( $route );
qa_check( 404 === $revoked->get_status() && 'tds_editorial_lesson_not_authorized' === $revoked->get_data()['code'], 'Revoked public lesson REST blocked' );
qa_check( 200 === qa_request( $outline )->get_status(), 'Curriculum remains public without lesson content' );
echo "WP_CORE_RUNTIME_QA_PASS\n";
