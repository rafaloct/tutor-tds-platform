<?php
/**
 * Real LearnPress runtime QA for the integrated IPEX editorial adapter.
 *
 * Run only through WP-CLI against a fresh, disposable synthetic WordPress.
 * The script does not register or replace the native LearnPress REST route.
 */
defined( 'ABSPATH' ) || exit( 2 );

$GLOBALS['qa_passed'] = 0;

function qa_check( bool $condition, string $label ): void {
	if ( ! $condition ) {
		fwrite( STDERR, "FAIL: {$label}\n" );
		exit( 3 );
	}
	$GLOBALS['qa_passed']++;
	echo "PASS: {$label}\n";
}

function qa_request( string $route, string $etag = '' ): WP_REST_Response {
	$request = new WP_REST_Request( 'GET', $route );
	if ( '' !== $etag ) {
		$request->set_header( 'If-None-Match', $etag );
	}
	$response = rest_do_request( $request );
	qa_check( $response instanceof WP_REST_Response, "REST response object for {$route}" );
	return $response;
}

function qa_editor_save( int $lesson_id, string $content, string $youtube = '' ): void {
	$_POST = array(
		'tds_mobile_lesson_nonce'    => wp_create_nonce( 'tds_mobile_lesson_' . $lesson_id ),
		'tds_mobile_public'          => '1',
		'tds_mobile_rights_approved' => '1',
		'tds_mobile_youtube_id'      => $youtube,
		'tds_mobile_poster_url'      => '',
		'tds_mobile_captions_url'    => '',
	);
	$result = wp_update_post(
		array(
			'ID'           => $lesson_id,
			'post_content' => $content,
		),
		true
	);
	qa_check( ! is_wp_error( $result ) && $lesson_id === $result, 'LearnPress lesson save hook completed' );
}

function qa_media( int $course_id, int $lesson_id ): ?array {
	$response = qa_request( "/tds-learning/v1/courses/{$course_id}/lessons/{$lesson_id}" );
	qa_check( 200 === $response->get_status(), 'Authorized TDS lesson response is HTTP 200' );
	$data = $response->get_data();
	qa_check( is_array( $data ) && array_key_exists( 'media', $data ), 'TDS lesson response has bounded media field' );
	return $data['media'];
}

global $wp_version, $wpdb;
qa_check( '7.1.2' === $wp_version, 'WordPress 7.1.2 real core loaded' );
qa_check( defined( 'LEARNPRESS_VERSION' ) && '4.3.6' === LEARNPRESS_VERSION, 'LearnPress 4.3.6 real plugin loaded' );
qa_check( class_exists( 'LP_Section_CURD' ) && post_type_exists( 'lp_course' ) && post_type_exists( 'lp_lesson' ), 'LearnPress models and post types loaded' );
qa_check( class_exists( 'TDS_LearnPress_Editorial' ) && class_exists( 'TDS_LearnPress_Editorial_Admin' ), 'Integrated TDS adapter loaded' );
qa_check( defined( 'DB_ENGINE' ) && 'sqlite' === DB_ENGINE, 'Disposable SQLite database active' );
qa_check( defined( 'WP_HTTP_BLOCK_EXTERNAL' ) && WP_HTTP_BLOCK_EXTERNAL, 'External WordPress HTTP blocked' );
qa_check( 'http://127.0.0.1:18731' === home_url(), 'Loopback-only synthetic origin configured' );

$plugin_root = WP_PLUGIN_DIR . '/tds-learnpress-editorial';
$source_hashes = array(
	'tds-learnpress-editorial.php'                     => '0634e24dd1503e8e30904cf026540e7a1d89dad3c1bb1ffcfbc88144a17ec1d9',
	'includes/class-tds-learnpress-editorial.php'       => '97e6dfd30376dd506f993980d7df9935007987f8b40eadc003b2b6b1f5dc1560',
	'includes/class-tds-learnpress-editorial-admin.php' => 'eedf01c063ea3cd1718f92cc3e621b50b79705d374449d083701e1a7458be4da',
);
foreach ( $source_hashes as $relative => $expected ) {
	qa_check( hash_equals( $expected, hash_file( 'sha256', $plugin_root . '/' . $relative ) ), "Integrated source hash {$relative}" );
}

wp_set_current_user( 1 );
$counts = count_users();
qa_check( 1 === (int) $counts['total_users'], 'Only one synthetic WordPress user exists' );
qa_check( str_ends_with( (string) wp_get_current_user()->user_email, '@qa-synthetic.test' ), 'Synthetic-only user identity' );

// A fresh LearnPress install does not add its edit capabilities to the
// synthetic administrator. Mirror the institutional administrator policy only
// inside this disposable database, as established by the Issue #276 RBAC QA.
$administrator = get_role( 'administrator' );
qa_check( $administrator instanceof WP_Role, 'Synthetic administrator role exists' );
foreach ( array(
	'edit_lp_courses',
	'edit_others_lp_courses',
	'edit_published_lp_courses',
	'publish_lp_courses',
	'edit_lp_lessons',
	'edit_others_lp_lessons',
	'edit_published_lp_lessons',
	'publish_lp_lessons',
) as $capability ) {
	$administrator->add_cap( $capability );
}
wp_set_current_user( 0 );
wp_set_current_user( 1 );
qa_check( current_user_can( 'edit_lp_lessons' ) && current_user_can( 'edit_others_lp_lessons' ), 'Clone-only LearnPress administrator capabilities applied' );

$course_id = wp_insert_post(
	array(
		'post_type'   => 'lp_course',
		'post_status' => 'publish',
		'post_title'  => 'Curso IPEX sintético c853db0',
		'post_author' => 1,
	),
	true
);
qa_check( is_int( $course_id ) && $course_id > 0, 'Real LearnPress course post created' );

$section_curd = new LP_Section_CURD( $course_id );
$section_args = array(
	'section_name'        => 'Videoaulas sintéticas',
	'section_description' => 'Somente QA local.',
	'section_course_id'   => $course_id,
);
$section = $section_curd->create( $section_args );
$section_id = (int) ( $section['section_id'] ?? 0 );
qa_check( $section_id > 0, 'Real LearnPress section created through CURD' );

$base = 'https://127.0.0.1/wp-content/uploads/tutor-tds/qa/';
$html = static fn( string $mp4, ?string $vtt ): string => '<p>Aula sintética sem dados pessoais.</p><video controls><source src="' . $mp4 . '">' .
	( null === $vtt ? '' : '<track kind="captions" src="' . $vtt . '" srclang="pt-BR">' ) . '</video>';
$first_content = $html( $base . 'one.mp4', $base . 'one.vtt' );
$lesson_items = $section_curd->new_item(
	$section_id,
	array(
		'title'   => 'Aula MP4/VTT sintética',
		'type'    => LP_LESSON_CPT,
		'content' => $first_content,
		'status'  => 'publish',
	)
);
$lesson_id = (int) ( $lesson_items[0]['id'] ?? 0 );
qa_check( $lesson_id > 0 && 'lp_lesson' === get_post_type( $lesson_id ), 'Real LearnPress lesson created and assigned' );
qa_check( current_user_can( 'edit_post', $lesson_id ), 'Synthetic administrator can edit LearnPress lesson' );

$draft_items = $section_curd->new_item(
	$section_id,
	array(
		'title'   => 'Aula rascunho sintética',
		'type'    => LP_LESSON_CPT,
		'content' => '<p>Não publicar.</p>',
		'status'  => 'draft',
	)
);
$draft_last = is_array( $draft_items ) ? end( $draft_items ) : false;
$draft_id = (int) ( $draft_last['id'] ?? 0 );
qa_check( $draft_id > 0 && 'draft' === get_post_status( $draft_id ), 'Real LearnPress draft lesson created' );

$native = qa_request( "/learnpress/v1/courses/{$course_id}" );
$native_data = $native->get_data();
qa_check( 200 === $native->get_status(), 'Native LearnPress course route is HTTP 200' );
qa_check( is_array( $native_data ) && $course_id === (int) ( $native_data['id'] ?? 0 ) && ! empty( $native_data['sections'] ), 'Native LearnPress route returns real section data' );

$curriculum = qa_request( "/tds-learning/v1/courses/{$course_id}/curriculum" );
$curriculum_data = $curriculum->get_data();
qa_check( 200 === $curriculum->get_status() && 'learnpress' === ( $curriculum_data['authority'] ?? '' ), 'TDS curriculum consumes native LearnPress route' );
$ids = array();
foreach ( $curriculum_data['sections'] ?? array() as $curriculum_section ) {
	foreach ( $curriculum_section['items'] ?? array() as $item ) {
		$ids[] = (int) ( $item['id'] ?? 0 );
	}
}
qa_check( in_array( $lesson_id, $ids, true ) && ! in_array( $draft_id, $ids, true ), 'Published lesson included and draft omitted' );
$etag = (string) ( $curriculum->get_headers()['ETag'] ?? '' );
qa_check( '' !== $etag && 304 === qa_request( "/tds-learning/v1/courses/{$course_id}/curriculum", $etag )->get_status(), 'TDS curriculum ETag returns HTTP 304' );
qa_check( 404 === qa_request( "/tds-learning/v1/courses/{$course_id}/lessons/{$lesson_id}" )->get_status(), 'Lesson is closed before editorial opt-in' );

qa_editor_save( $lesson_id, $first_content );
qa_check( null === qa_media( $course_id, $lesson_id ), 'First MP4/VTT submission remains unapproved' );
qa_editor_save( $lesson_id, $first_content );
$media = qa_media( $course_id, $lesson_id );
qa_check( is_array( $media ) && 'ipex_mp4' === ( $media['provider'] ?? '' ) && $base . 'one.mp4' === ( $media['source_url'] ?? '' ) && $base . 'one.vtt' === ( $media['captions_url'] ?? '' ), 'Second submission approves MP4 and pt-BR VTT' );

$second_content = $html( $base . 'two.mp4', $base . 'one.vtt' );
qa_editor_save( $lesson_id, $second_content );
qa_check( null === qa_media( $course_id, $lesson_id ), 'MP4 change revokes prior fingerprint' );
qa_editor_save( $lesson_id, $second_content );
qa_check( $base . 'two.mp4' === ( qa_media( $course_id, $lesson_id )['source_url'] ?? '' ), 'Changed MP4 requires second approval' );

$third_content = $html( $base . 'two.mp4', $base . 'two.vtt' );
qa_editor_save( $lesson_id, $third_content );
qa_check( null === qa_media( $course_id, $lesson_id ), 'VTT change revokes prior fingerprint' );
qa_editor_save( $lesson_id, $third_content );
qa_check( $base . 'two.vtt' === ( qa_media( $course_id, $lesson_id )['captions_url'] ?? '' ), 'Changed VTT requires second approval' );

$no_vtt = $html( $base . 'silent.mp4', null );
qa_editor_save( $lesson_id, $no_vtt );
qa_editor_save( $lesson_id, $no_vtt );
$media = qa_media( $course_id, $lesson_id );
qa_check( is_array( $media ) && $base . 'silent.mp4' === ( $media['source_url'] ?? '' ) && ! isset( $media['captions_url'] ), 'MP4 without VTT remains valid without fabricated caption' );

qa_editor_save( $lesson_id, '<p>YouTube editorial alternativo.</p>', 'FG14ksTaMCE' );
qa_check( null === qa_media( $course_id, $lesson_id ), 'First YouTube source change revokes rights' );
qa_editor_save( $lesson_id, '<p>YouTube editorial alternativo.</p>', 'FG14ksTaMCE' );
$media = qa_media( $course_id, $lesson_id );
qa_check( is_array( $media ) && 'youtube' === ( $media['provider'] ?? '' ) && 'FG14ksTaMCE' === ( $media['video_id'] ?? '' ), 'Second submission approves YouTube alternative' );

$user_items_table = $wpdb->prefix . 'learnpress_user_items';
$academic_rows = (int) $wpdb->get_var( "SELECT COUNT(*) FROM {$user_items_table}" );
qa_check( 0 === $academic_rows, 'Editorial playback fixture creates no enrollment or progress row' );

$_POST = array();
echo wp_json_encode(
	array(
		'result'            => 'LEARNPRESS_REAL_INTEGRATED_QA_PASS',
		'passes'            => $GLOBALS['qa_passed'],
		'wordpress'         => $wp_version,
		'learnpress'        => LEARNPRESS_VERSION,
		'course_id'         => $course_id,
		'lesson_id'         => $lesson_id,
		'draft_lesson_id'   => $draft_id,
		'external_http_off' => true,
	),
	JSON_UNESCAPED_SLASHES
) . "\n";
