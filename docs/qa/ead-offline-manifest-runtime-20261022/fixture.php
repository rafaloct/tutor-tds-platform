<?php
/** WP-CLI only, run-owned disposable DB. Native LearnPress; no stub routes. */
defined( 'ABSPATH' ) || exit( 2 );
if ( ! defined( 'WP_CLI' ) || ! WP_CLI || ! getenv( 'TDS_OFFLINE_RUNTIME_QA' ) ||
	'local' !== wp_get_environment_type() || ! defined( 'WP_HTTP_BLOCK_EXTERNAL' ) || ! WP_HTTP_BLOCK_EXTERNAL ) {
	throw new RuntimeException( 'Disposable runtime guard failed' );
}
wp_set_current_user( 1 );
if ( ! current_user_can( 'manage_options' ) || 1 !== (int) count_users()['total_users'] ||
	! str_ends_with( wp_get_current_user()->user_email, '@qa-synthetic.test' ) ) {
	throw new RuntimeException( 'Synthetic administrator guard failed' );
}
function qa_save( $lesson, $content ) {
	$_POST = array( 'tds_mobile_lesson_nonce' => wp_create_nonce( 'tds_mobile_lesson_' . $lesson ),
		'tds_mobile_public' => '1', 'tds_mobile_rights_approved' => '1', 'tds_mobile_youtube_id' => '',
		'tds_mobile_poster_url' => '', 'tds_mobile_captions_url' => '' );
	$result = wp_update_post( array( 'ID' => $lesson, 'post_content' => $content ), true );
	if ( is_wp_error( $result ) ) { throw new RuntimeException( 'Synthetic save failed' ); }
}
function qa_prepare( $ids ) {
	$record = TDS_Offline_Manifest::prepare_record( $ids['course'], $ids['lesson'] );
	if ( is_wp_error( $record ) ) {
		throw new RuntimeException( 'Integrity preparation failed: ' . wp_json_encode( array( 'code' => $record->get_error_code(), 'course_status' => get_post_status( $ids['course'] ), 'lesson_status' => get_post_status( $ids['lesson'] ), 'rights' => get_post_meta( $ids['lesson'], '_tds_mobile_rights_approved', true ), 'source_match' => TDS_LearnPress_Editorial::mp4_source_fingerprint( $ids['lesson'] ) === get_post_meta( $ids['lesson'], '_tds_mobile_rights_source_fingerprint', true ) ) ) );
	}
	update_post_meta( $ids['lesson'], TDS_Offline_Manifest::META, $record );
	return $record;
}
function qa_academic() {
	global $wpdb;
	$result = array();
	foreach ( array( 'learnpress_user_items', 'learnpress_user_itemmeta', 'learnpress_order_items', 'learnpress_order_itemmeta' ) as $table ) {
		$rows = $wpdb->get_results( "SELECT * FROM {$wpdb->prefix}{$table}", ARRAY_A );
		if ( $wpdb->last_error ) { throw new RuntimeException( 'Academic table unavailable' ); }
		$result[$table] = array( 'count' => count( $rows ), 'sha256' => hash( 'sha256', wp_json_encode( $rows ) ) );
	}
	return $result;
}
$action = $args[0] ?? '';
$ids = get_option( 'tds_offline_qa_ids', array() );
$uploads = wp_upload_dir();
$dir = $uploads['basedir'] . '/tutor-tds/qa';
$base = 'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/qa/';
global $wpdb, $wp_version;
$result = array( 'action' => $action );
switch ( $action ) {
	case 'seed':
		if ( $ids || '6.7.2' !== $wp_version || '4.3.6' !== LEARNPRESS_VERSION ) { throw new RuntimeException( 'Unexpected fixture/version' ); }
		$role = get_role( 'administrator' );
		foreach ( array( 'edit_lp_courses', 'edit_others_lp_courses', 'edit_published_lp_courses', 'publish_lp_courses',
			'edit_lp_lessons', 'edit_others_lp_lessons', 'edit_published_lp_lessons', 'publish_lp_lessons' ) as $cap ) { $role->add_cap( $cap ); }
		wp_set_current_user( 0 ); wp_set_current_user( 1 );
		$course = wp_insert_post( array( 'post_type' => 'lp_course', 'post_title' => 'Synthetic offline manifest QA', 'post_status' => 'publish', 'post_author' => 1 ), true );
		if ( is_wp_error( $course ) ) { throw new RuntimeException( 'Course seed failed' ); }
		$curd = new LP_Section_CURD( $course );
		$section_args = array( 'section_name' => 'Synthetic bytes', 'section_description' => 'Disposable integration', 'section_course_id' => $course );
		$section = $curd->create( $section_args );
		$content = '<p>Synthetic lesson.</p><video><source src="' . $base . 'lesson.mp4"><track kind="captions" src="' . $base . 'lesson.vtt" srclang="pt-BR"></video>';
		$items = $curd->new_item( (int) $section['section_id'], array( 'title' => 'Synthetic lesson', 'type' => LP_LESSON_CPT, 'content' => $content, 'status' => 'publish' ) );
		$ids = array( 'course' => (int) $course, 'lesson' => (int) $items[0]['id'], 'section' => (int) $section['section_id'] );
		wp_update_post( array( 'ID' => $ids['lesson'], 'post_author' => 1 ) );
		update_option( 'tds_offline_qa_ids', $ids, false );
		wp_mkdir_p( $dir );
		file_put_contents( $dir . '/lesson.mp4', 'synthetic MP4 bytes - not a playback fixture' );
		file_put_contents( $dir . '/lesson.vtt', "WEBVTT\n\n00:00.000 --> 00:01.000\nOlá\n" );
		qa_save( $ids['lesson'], $content ); qa_save( $ids['lesson'], $content );
		$result += array( 'ids' => $ids, 'wordpress' => $wp_version, 'learnpress' => LEARNPRESS_VERSION,
			'public' => get_post_meta( $ids['lesson'], '_tds_mobile_public', true ),
			'rights' => get_post_meta( $ids['lesson'], '_tds_mobile_rights_approved', true ),
			'parent_status' => get_post_status( $ids['course'] ), 'academic' => qa_academic() );
		break;
	case 'diagnose':
		$native = rest_do_request( new WP_REST_Request( 'GET', '/learnpress/v1/courses/' . $ids['course'] ) );
		$lesson_request = new WP_REST_Request( 'GET' ); $lesson_request['course_id'] = $ids['course']; $lesson_request['lesson_id'] = $ids['lesson'];
		$editorial = TDS_LearnPress_Editorial::lesson( $lesson_request );
		$result['parents'] = $wpdb->get_col( $wpdb->prepare( "SELECT DISTINCT s.section_course_id FROM {$wpdb->prefix}learnpress_section_items i JOIN {$wpdb->prefix}learnpress_sections s ON s.section_id=i.section_id WHERE i.item_id=%d", $ids['lesson'] ) );
		$result['native_sections'] = $native->get_data()['sections'] ?? null;
		$result['editorial_status'] = is_wp_error( $editorial ) ? $editorial->get_error_data()['status'] : $editorial->get_status();
		$result['editorial_code'] = is_wp_error( $editorial ) ? $editorial->get_error_code() : null;
		$result['file_stat'] = array_intersect_key( lstat( $dir . '/lesson.mp4' ), array_flip( array( 'mode', 'size', 'nlink' ) ) );
		$result += array( 'active_plugins' => get_option( 'active_plugins' ), 'lp_class' => class_exists( 'LP_Jwt_RestApi' ), 'lp_tables_ready' => get_option( 'learn_press_check_tables' ), 'native_status' => $native->get_status(), 'native_code' => $native->get_data()['code'] ?? null, 'namespaces' => rest_get_server()->get_namespaces() );
		break;
	case 'prepare':
		$record = qa_prepare( $ids );
		$result['asset_count'] = count( $record['assets'] );
		break;
	case 'snapshot':
		$result['academic'] = qa_academic();
		$result['record_hash'] = hash( 'sha256', wp_json_encode( get_post_meta( $ids['lesson'], TDS_Offline_Manifest::META, true ) ) );
		break;
	case 'revoke': update_post_meta( $ids['lesson'], '_tds_mobile_rights_approved', '0' ); break;
	case 'restore': update_post_meta( $ids['lesson'], '_tds_mobile_rights_approved', '1' ); break;
	case 'revise': qa_save( $ids['lesson'], get_post( $ids['lesson'] )->post_content . '<p>New synthetic revision.</p>' ); break;
	case 'replace':
		file_put_contents( $dir . '/replacement.mp4', 'replacement synthetic bytes with another length' );
		rename( $dir . '/replacement.mp4', $dir . '/lesson.mp4' );
		break;
	case 'draft': wp_update_post( array( 'ID' => $ids['lesson'], 'post_status' => 'draft' ) ); break;
	case 'publish': wp_update_post( array( 'ID' => $ids['lesson'], 'post_status' => 'publish' ) ); break;
	case 'reattach':
		if ( ! current_user_can( 'edit_lp_course', $ids['course'] ) || ! current_user_can( 'edit_post', $ids['lesson'] ) ) { throw new RuntimeException( 'Synthetic reattachment authorization denied' ); }
		$curd = new LP_Section_CURD( $ids['course'] );
		$curd->add_items_section( $ids['section'], array( array( 'id' => $ids['lesson'], 'type' => LP_LESSON_CPT ) ) );
		$result['association_restored'] = (int) $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM {$wpdb->prefix}learnpress_section_items WHERE section_id=%d AND item_id=%d", $ids['section'], $ids['lesson'] ) );
		break;
	case 'review':
		qa_save( $ids['lesson'], get_post( $ids['lesson'] )->post_content );
		qa_save( $ids['lesson'], get_post( $ids['lesson'] )->post_content );
		wp_update_post( array( 'ID' => $ids['course'], 'post_status' => 'publish' ) );
		$result += array( 'course_status' => get_post_status( $ids['course'] ), 'lesson_status' => get_post_status( $ids['lesson'] ), 'rights' => get_post_meta( $ids['lesson'], '_tds_mobile_rights_approved', true ) );
		break;
	case 'protect': wp_update_post( array( 'ID' => $ids['course'], 'post_password' => 'synthetic-only' ) ); break;
	case 'unprotect': wp_update_post( array( 'ID' => $ids['course'], 'post_password' => '' ) ); break;
	case 'share':
		$other = wp_insert_post( array( 'post_type' => 'lp_course', 'post_status' => 'publish', 'post_title' => 'Synthetic second parent', 'post_author' => 1 ), true );
		$curd = new LP_Section_CURD( $other );
		$section_args = array( 'section_name' => 'Shared synthetic lesson', 'section_description' => '', 'section_course_id' => $other );
		$section = $curd->create( $section_args );
		$wpdb->insert( $wpdb->prefix . 'learnpress_section_items', array( 'section_id' => (int) $section['section_id'], 'item_id' => $ids['lesson'], 'item_order' => 1 ) );
		if ( $wpdb->last_error ) { throw new RuntimeException( 'Second parent fixture failed' ); }
		$ids['shared_section'] = (int) $section['section_id']; update_option( 'tds_offline_qa_ids', $ids, false );
		break;
	case 'unshare':
		$wpdb->delete( $wpdb->prefix . 'learnpress_section_items', array( 'section_id' => $ids['shared_section'], 'item_id' => $ids['lesson'] ) );
		break;
	default: throw new RuntimeException( 'Unknown fixture action' );
}
echo wp_json_encode( array( 'qa' => $result ), JSON_UNESCAPED_SLASHES ) . "\n";
