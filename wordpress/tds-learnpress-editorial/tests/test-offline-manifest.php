<?php
/** Real disposable filesystem + WP/LP stubs. No server, network or student data. */
declare( strict_types=1 );
require __DIR__ . '/test-contract.php';
require dirname( __DIR__ ) . '/includes/class-tds-offline-manifest.php';

$root = sys_get_temp_dir() . '/tds-offline-' . bin2hex( random_bytes( 6 ) );
mkdir( $root . '/tutor-tds/qa', 0700, true );
function wp_upload_dir( $time = null, $create = true ) {
	global $root;
	verify( false === $create, 'GET must not create uploads directories' );
	return array( 'basedir' => $root, 'baseurl' => 'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads', 'error' => false );
}
final class OfflineWPDB {
	public string $prefix = 'wp_';
	public string $last_error = '';
	public array $parents = array( '1356' );
	public bool $change_on_second_read = false;
	public int $reads = 0;
	public function prepare( $query, $id ) { verify( str_contains( $query, 'SELECT DISTINCT' ), 'unique existing LP parent query' ); return $query; }
	public function get_col( $query ) {
		$this->reads++;
		if ( $this->change_on_second_read && 2 === $this->reads ) { return array( '999' ); }
		return $this->parents;
	}
}
$wpdb = new OfflineWPDB();
$base = 'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/qa/';
function reset_offline_fixture( $captions = true ) {
	global $posts, $meta, $sections, $base, $root, $wpdb;
	$wpdb->parents = array( '1356' ); $wpdb->last_error = ''; $wpdb->reads = 0; $wpdb->change_on_second_read = false;
	$sections = array( array( 'id' => 80, 'title' => 'Sintético', 'items' => array( array( 'id' => 1425, 'type' => 'lp_lesson' ) ) ) );
	$posts[1356]->post_status = 'publish'; $posts[1425]->post_status = 'publish';
	$posts[1356]->post_password = ''; $posts[1425]->post_password = '';
	$posts[1425]->post_content = '<video><source src="' . $base . 'lesson.mp4">' .
		( $captions ? '<track kind="captions" src="' . $base . 'lesson.vtt" srclang="pt-BR">' : '' ) . '</video>';
	file_put_contents( $root . '/tutor-tds/qa/lesson.mp4', 'synthetic MP4 bytes - not a playback fixture' );
	file_put_contents( $root . '/tutor-tds/qa/lesson.vtt', "WEBVTT\n\n00:00.000 --> 00:01.000\nOlá\n" );
	$meta[1425] = array( '_tds_mobile_public' => '1', '_tds_mobile_rights_approved' => '1' );
	$meta[1425]['_tds_mobile_rights_source_fingerprint'] = TDS_LearnPress_Editorial::mp4_source_fingerprint( 1425 );
}
function offline_request( $etag = '', $course = 1356, $lesson = 1425 ) {
	$request = new WP_REST_Request( 'GET' ); $request['course_id'] = $course; $request['lesson_id'] = $lesson;
	$request->set_header( 'if-none-match', $etag );
	return TDS_Offline_Manifest::read( $request );
}
function prepare_offline() {
	global $meta;
	$record = TDS_Offline_Manifest::prepare_record( 1356, 1425 );
	verify( ! is_wp_error( $record ), 'fixture precomputed from actual local bytes' );
	$meta[1425][TDS_Offline_Manifest::META] = $record;
	return $record;
}
function denied( $reason, $response = null ) {
	$r = $response ?? offline_request();
	verify( is_wp_error( $r ) && 404 === $r->data['status'] && 'tds_offline_unavailable' === $r->code, $reason );
}
$start = $checks;
try {
	TDS_Offline_Manifest::register_routes();
	verify( count( $registered ) === 3, 'additive read-only route' );
	reset_offline_fixture();
	denied( 'no measured metadata => 404' );
	$record = prepare_offline();
	verify( $record['assets']['mp4']['sha256'] === hash_file( 'sha256', $root . '/tutor-tds/qa/lesson.mp4' ), 'real digest' );
	$before = $meta;
	$r = offline_request(); $body = $r->get_data();
	verify( 200 === $r->get_status(), 'measured approved unique-parent public lesson served' );
	verify( $meta === $before, 'GET has no metadata writes' );
	verify( array_keys( $body ) === array( 'schema_version', 'course_id', 'lesson_id', 'mobile_content', 'rights_approved', 'mp4', 'vtt', 'content_revision' ), 'exact Flutter top-level keys' );
	verify( array_keys( $body['mp4'] ) === array( 'url', 'length', 'sha256' ), 'exact Flutter asset keys' );
	verify( strlen( $body['content_revision'] ) === 64 && $body['mobile_content'] && $body['rights_approved'], 'revision + booleans' );
	verify( ! str_contains( json_encode( $body ), $root ) && ! str_contains( json_encode( $body ), 'identity' ), 'no filesystem metadata leak' );
	verify( 'no-store' === $r->headers['Cache-Control'], 'authorization responses not stored by intermediary' );
	verify( 304 === offline_request( $r->headers['ETag'] )->get_status(), 'strong validator matches' );
	verify( 304 === offline_request( 'W/' . $r->headers['ETag'] )->get_status(), 'weak validator matches' );
	verify( 200 === offline_request( '"wrong"' )->get_status(), 'wrong validator does not suppress body' );
	$meta[1425]['_tds_mobile_rights_approved'] = '0';
	denied( 'revocation checked before conditional response', offline_request( $r->headers['ETag'] ) );
	reset_offline_fixture( false ); prepare_offline();
	verify( ! isset( offline_request()->get_data()['vtt'] ), 'MP4-only lesson supported' );

	foreach ( array( '_tds_mobile_public', '_tds_mobile_rights_approved', '_tds_mobile_rights_source_fingerprint' ) as $key ) {
		reset_offline_fixture(); prepare_offline(); $meta[1425][$key] = '';
		denied( 'missing approval ' . $key );
	}
	foreach ( array( 1356, 1425 ) as $id ) {
		reset_offline_fixture(); prepare_offline(); $posts[$id]->post_password = 'synthetic'; denied( 'password protected post' );
	}
	foreach ( array( 'draft', 'private', 'trash' ) as $status ) {
		foreach ( array( 1356, 1425 ) as $id ) {
			reset_offline_fixture(); prepare_offline(); $posts[$id]->post_status = $status;
			denied( 'nonpublic course/lesson ' . $status );
		}
	}
	foreach ( array( array(), array( '999' ), array( '1356', '999' ) ) as $parents ) {
		reset_offline_fixture(); prepare_offline(); $wpdb->parents = $parents;
		denied( 'orphan, wrong or multiple parents' );
	}
	reset_offline_fixture(); prepare_offline(); $wpdb->last_error = 'synthetic database error'; denied( 'DB error closed' );
	reset_offline_fixture(); prepare_offline(); $meta[1425]['_tds_mobile_youtube_id'] = 'FG14ksTaMCE'; denied( 'YouTube never downloadable' );
	reset_offline_fixture(); prepare_offline(); $posts[1425]->post_content .= '<p>new edition</p>'; denied( 'lesson revision stale' );
	reset_offline_fixture(); prepare_offline(); $posts[1425]->post_content = str_replace( 'lesson.mp4', 'other.mp4', $posts[1425]->post_content ); denied( 'source swap invalidates approval' );
	reset_offline_fixture(); prepare_offline(); file_put_contents( $root . '/tutor-tds/qa/lesson.mp4', 'changed size' ); denied( 'changed byte count' );
	reset_offline_fixture(); prepare_offline(); touch( $root . '/tutor-tds/qa/lesson.mp4', time() + 20 ); denied( 'changed mtime' );
	reset_offline_fixture(); prepare_offline(); unlink( $root . '/tutor-tds/qa/lesson.vtt' ); denied( 'missing captions' );
	reset_offline_fixture(); file_put_contents( $root . '/tutor-tds/qa/lesson.vtt', 'not WebVTT' );
	denied( 'invalid VTT signature rejected during preparation', TDS_Offline_Manifest::prepare_record( 1356, 1425 ) );
	reset_offline_fixture(); file_put_contents( $root . '/tutor-tds/qa/lesson.vtt', "WEBVTT\n\n\xff" );
	denied( 'invalid UTF8 captions', TDS_Offline_Manifest::prepare_record( 1356, 1425 ) );
	reset_offline_fixture(); file_put_contents( $root . '/tutor-tds/qa/lesson.mp4', '' );
	denied( 'zero length', TDS_Offline_Manifest::prepare_record( 1356, 1425 ) );
	reset_offline_fixture(); $handle = fopen( $root . '/tutor-tds/qa/lesson.mp4', 'r+b' ); ftruncate( $handle, TDS_Offline_Manifest::MAX_MP4 + 1 ); fclose( $handle );
	denied( 'oversized sparse media rejected before hashing', TDS_Offline_Manifest::prepare_record( 1356, 1425 ) );
	reset_offline_fixture(); $handle = fopen( $root . '/tutor-tds/qa/lesson.mp4', 'rb' ); flock( $handle, LOCK_EX );
	denied( 'concurrent writer lock fails closed', TDS_Offline_Manifest::prepare_record( 1356, 1425 ) ); fclose( $handle );
	reset_offline_fixture(); prepare_offline(); $wpdb->reads = 0; $wpdb->change_on_second_read = true; denied( 'parent changes during read' );
	reset_offline_fixture(); $wpdb->reads = 0; $wpdb->change_on_second_read = true;
	denied( 'parent changes during hashing', TDS_Offline_Manifest::prepare_record( 1356, 1425 ) );
	foreach ( array( 'https://evil.test/a.mp4', 'http://127.0.0.1/a.mp4', $base . '../lesson.mp4', $base . '%2e%2e/lesson.mp4', $base . '%252e/lesson.mp4', $base . 'lesson.mp4?token=secret', $base . 'lesson.mp4#x', $base . '/lesson.mp4', $base . 'lesson.MP4' ) as $url ) {
		reset_offline_fixture(); $posts[1425]->post_content = '<video><source src="' . $url . '"></video>';
		$meta[1425]['_tds_mobile_rights_source_fingerprint'] = TDS_LearnPress_Editorial::mp4_source_fingerprint( 1425 );
		denied( 'hostile/noncanonical source', TDS_Offline_Manifest::prepare_record( 1356, 1425 ) );
	}
	foreach ( array( 0, -1, '1356evil', array(), 100000001 ) as $id ) { denied( 'invalid direct-call id', offline_request( '', $id ) ); }
	reset_offline_fixture(); prepare_offline(); $meta[1425][TDS_Offline_Manifest::META]['assets']['mp4']['sha256'] = 'bad'; denied( 'bad stored hash' );
	reset_offline_fixture(); prepare_offline(); $meta[1425][TDS_Offline_Manifest::META]['assets']['mp4']['length'] = '42'; denied( 'noninteger length' );
	reset_offline_fixture(); prepare_offline(); $meta[1425][TDS_Offline_Manifest::META]['assets']['extra'] = array(); denied( 'extra assets' );
	reset_offline_fixture(); prepare_offline();
	unlink( $root . '/tutor-tds/qa/lesson.mp4' ); symlink( $root . '/tutor-tds/qa/lesson.vtt', $root . '/tutor-tds/qa/lesson.mp4' );
	denied( 'symlink file even within root' ); unlink( $root . '/tutor-tds/qa/lesson.mp4' );
	reset_offline_fixture(); prepare_offline(); rename( $root . '/tutor-tds/qa', $root . '/tutor-tds/real' ); symlink( $root . '/tutor-tds/real', $root . '/tutor-tds/qa' );
	denied( 'symlink directory even within root' ); unlink( $root . '/tutor-tds/qa' ); rename( $root . '/tutor-tds/real', $root . '/tutor-tds/qa' );
	reset_offline_fixture(); prepare_offline(); link( $root . '/tutor-tds/qa/lesson.mp4', $root . '/alias.mp4' ); denied( 'hardlinked file' ); unlink( $root . '/alias.mp4' );
	reset_offline_fixture(); prepare_offline(); rename( $root . '/tutor-tds/qa/lesson.mp4', $root . '/old.mp4' ); copy( $root . '/old.mp4', $root . '/tutor-tds/qa/lesson.mp4' ); denied( 'same bytes replacement inode needs remeasure' ); unlink( $root . '/old.mp4' );
	// Export exact server JSON for a separate real Dart parser contract test.
	reset_offline_fixture(); prepare_offline();
	if ( getenv( 'TDS_MANIFEST_OUTPUT' ) ) { file_put_contents( getenv( 'TDS_MANIFEST_OUTPUT' ), json_encode( offline_request()->get_data(), JSON_UNESCAPED_SLASHES ) ); }
	echo 'PASS offline manifest ' . ( $checks - $start ) . " checks (filesystem + WP stubs; NOT live WP/Android)\n";
} finally {
	foreach ( glob( $root . '/tutor-tds/qa/*' ) as $path ) { unlink( $path ); }
	rmdir( $root . '/tutor-tds/qa' ); rmdir( $root . '/tutor-tds' ); rmdir( $root );
}
