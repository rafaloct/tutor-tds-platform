<?php

defined( 'ABSPATH' ) || exit;

/** Public IPEX bytes only. Preparation is explicit; GET never hashes or writes. */
final class TDS_Offline_Manifest {
	const META = '_tds_mobile_offline_integrity_v1';
	const PREFIX = '/wp-content/uploads/tutor-tds/';
	const MAX_MP4 = 524287999; // Same exclusive 500 MiB boundary as Flutter.
	const MAX_VTT = 2097152;

	public static function register_routes() {
		register_rest_route( TDS_LearnPress_Editorial::NS, '/courses/(?P<course_id>[1-9][0-9]{0,8})/lessons/(?P<lesson_id>[1-9][0-9]{0,8})/offline-manifest', array(
			'methods' => WP_REST_Server::READABLE,
			'callback' => array( __CLASS__, 'read' ),
			'permission_callback' => '__return_true',
			'args' => array(
				'course_id' => array( 'type' => 'integer', 'minimum' => 1, 'maximum' => 100000000 ),
				'lesson_id' => array( 'type' => 'integer', 'minimum' => 1, 'maximum' => 100000000 ),
			),
		) );
	}

	private static function unavailable() {
		return new WP_Error( 'tds_offline_unavailable', 'Download indisponível.', array( 'status' => 404 ) );
	}

	private static function id( $value ) {
		return ( is_int( $value ) || is_string( $value ) ) &&
			preg_match( '/^[1-9][0-9]{0,8}$/D', (string) $value ) && (int) $value <= 100000000;
	}

	private static function digest( $data ) {
		return hash( 'sha256', wp_json_encode( $data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ) );
	}

	private static function context( $course_id, $lesson_id ) {
		if ( ! self::id( $course_id ) || ! self::id( $lesson_id ) ) {
			return null;
		}
		foreach ( array( $course_id, $lesson_id ) as $id ) {
			$post = get_post( (int) $id );
			if ( ! $post || ! empty( $post->post_password ) ) { return null; }
		}
		global $wpdb;
		$parents = $wpdb->get_col( $wpdb->prepare(
			"SELECT DISTINCT s.section_course_id FROM {$wpdb->prefix}learnpress_section_items i " .
			"JOIN {$wpdb->prefix}learnpress_sections s ON s.section_id = i.section_id WHERE i.item_id = %d", $lesson_id
		) );
		if ( $wpdb->last_error || ! is_array( $parents ) || count( $parents ) !== 1 || (int) $parents[0] !== (int) $course_id ) {
			return null;
		}
		$request = new WP_REST_Request( 'GET' );
		$request['course_id'] = (int) $course_id;
		$request['lesson_id'] = (int) $lesson_id;
		$response = TDS_LearnPress_Editorial::lesson( $request );
		if ( is_wp_error( $response ) || 200 !== $response->get_status() ||
			get_post_meta( $lesson_id, '_tds_mobile_rights_approved', true ) !== '1' ) {
			return null;
		}
		$data = $response->get_data();
		$media = $data['media'] ?? null;
		$fingerprint = TDS_LearnPress_Editorial::mp4_source_fingerprint( $lesson_id );
		$approved = get_post_meta( $lesson_id, '_tds_mobile_rights_source_fingerprint', true );
		if ( ! is_array( $media ) || ( $media['provider'] ?? '' ) !== 'ipex_mp4' ||
			! is_string( $fingerprint ) || ! is_string( $approved ) || ! hash_equals( $fingerprint, $approved ) ) {
			return null;
		}
		return array( 'course_id' => (int) $course_id, 'lesson_id' => (int) $lesson_id,
			'source_revision' => $data['revision'], 'fingerprint' => $fingerprint,
			'urls' => array_filter( array( 'mp4' => $media['source_url'], 'vtt' => $media['captions_url'] ?? null ) ) );
	}

	/** Resolve only literal, canonical URLs into the existing local uploads tree. */
	private static function local_file( $url, $kind ) {
		if ( ! is_string( $url ) || strlen( $url ) > 2000 ||
			! preg_match( '#^https://ead\.ipexdesenvolvimento\.cloud/wp-content/uploads/tutor-tds/[A-Za-z0-9_/-]+\.' . $kind . '$#D', $url ) ||
			strpos( $url, '..' ) !== false || strpos( $url, '//' , 8 ) !== false ) {
			return null;
		}
		$uploads = wp_upload_dir( null, false ); // No directory creation in GET.
		if ( ! empty( $uploads['error'] ) || ( $uploads['baseurl'] ?? '' ) !== 'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads' ) {
			return null;
		}
		$base = $uploads['basedir'] ?? '';
		if ( ! is_string( $base ) || '' === $base || realpath( $base ) !== $base ) {
			return null;
		}
		$path = $base . '/tutor-tds/' . substr( parse_url( $url, PHP_URL_PATH ), strlen( self::PREFIX ) );
		// Reject a symlink at ANY level, even a link whose target stays in uploads.
		$cursor = $path;
		while ( dirname( $cursor ) !== $cursor ) {
			clearstatcache( true, $cursor );
			if ( is_link( $cursor ) ) { return null; }
			$cursor = dirname( $cursor );
		}
		clearstatcache( true, $path );
		$real = realpath( $path );
		$stat = @lstat( $path );
		if ( $real !== $path || ! is_array( $stat ) || ( $stat['mode'] & 0170000 ) !== 0100000 ||
			$stat['nlink'] !== 1 || $stat['size'] < 1 || $stat['size'] > ( 'mp4' === $kind ? self::MAX_MP4 : self::MAX_VTT ) ) {
			return null;
		}
		return array( 'path' => $path, 'identity' => self::identity( $stat ) );
	}

	private static function identity( $stat ) {
		return array_intersect_key( $stat, array_flip( array( 'dev', 'ino', 'mode', 'nlink', 'size', 'mtime', 'ctime' ) ) );
	}

	/** Offline preparation: trusted operator calls this on immutable local bytes.
	 * Returns a record without persisting it or changing editorial approval.
	 */
	public static function prepare_record( $course_id, $lesson_id ) {
		$context = self::context( $course_id, $lesson_id );
		if ( null === $context ) { return self::unavailable(); }
		$assets = array();
		foreach ( $context['urls'] as $kind => $url ) {
			$file = self::local_file( $url, $kind );
			if ( null === $file ) { return self::unavailable(); }
			$handle = @fopen( $file['path'], 'rb' );
			if ( false === $handle ) { return self::unavailable(); }
			try {
				if ( ! flock( $handle, LOCK_SH | LOCK_NB ) || self::identity( fstat( $handle ) ) !== $file['identity'] ) {
					return self::unavailable();
				}
				$hash = hash_init( 'sha256' );
				$length = hash_update_stream( $hash, $handle, $file['identity']['size'] + 1 );
				$sha = hash_final( $hash );
				$after = self::local_file( $url, $kind );
				if ( $length !== $file['identity']['size'] || null === $after || $after['identity'] !== $file['identity'] ||
					self::identity( fstat( $handle ) ) !== $file['identity'] ) { return self::unavailable(); }
				if ( 'vtt' === $kind ) {
					rewind( $handle );
					$text = stream_get_contents( $handle, self::MAX_VTT + 1 );
					if ( ! is_string( $text ) || ! preg_match( '/^(?:\xEF\xBB\xBF)?WEBVTT(?:[ \t][^\r\n]*)?(?:\r\n|\n|\r)/', $text ) ||
						! preg_match( '//u', $text ) || strpos( $text, "\0" ) !== false || hash( 'sha256', $text ) !== $sha ) { return self::unavailable(); }
				}
				$assets[ $kind ] = array( 'url' => $url, 'length' => $length, 'sha256' => $sha, 'identity' => $file['identity'] );
			} finally {
				fclose( $handle );
			}
		}
		if ( $context !== self::context( $course_id, $lesson_id ) ) { return self::unavailable(); }
		return array( 'schema_version' => 1, 'context' => $context, 'assets' => $assets );
	}

	public static function read( $request ) {
		$context = self::context( $request['course_id'], $request['lesson_id'] );
		if ( null === $context ) { return self::unavailable(); }
		$record = get_post_meta( $context['lesson_id'], self::META, true );
		if ( ! is_array( $record ) || ( $record['schema_version'] ?? null ) !== 1 ||
			( $record['context'] ?? null ) !== $context || ! is_array( $record['assets'] ?? null ) ||
			array_keys( $record['assets'] ) !== array_keys( $context['urls'] ) ) { return self::unavailable(); }
		$payload = array( 'schema_version' => 1, 'course_id' => $context['course_id'], 'lesson_id' => $context['lesson_id'],
			'mobile_content' => true, 'rights_approved' => true );
		foreach ( $context['urls'] as $kind => $url ) {
			$asset = $record['assets'][ $kind ];
			$file = self::local_file( $url, $kind );
			if ( ! is_array( $asset ) || null === $file || ( $asset['url'] ?? null ) !== $url ||
				( $asset['identity'] ?? null ) !== $file['identity'] || ( $asset['length'] ?? null ) !== $file['identity']['size'] ||
				! is_string( $asset['sha256'] ?? null ) || ! preg_match( '/^[a-f0-9]{64}$/D', $asset['sha256'] ) ) { return self::unavailable(); }
			$payload[ $kind ] = array( 'url' => $url, 'length' => $asset['length'], 'sha256' => $asset['sha256'] );
		}
		if ( isset( $payload['vtt'] ) && $payload['vtt']['sha256'] === $payload['mp4']['sha256'] ) { return self::unavailable(); }
		if ( $context !== self::context( $context['course_id'], $context['lesson_id'] ) ||
			$record !== get_post_meta( $context['lesson_id'], self::META, true ) ) { return self::unavailable(); }
		foreach ( $context['urls'] as $kind => $url ) {
			$file = self::local_file( $url, $kind );
			if ( null === $file || $file['identity'] !== $record['assets'][ $kind ]['identity'] ) { return self::unavailable(); }
		}
		// Exact Flutter keys; validators live in headers, never extra JSON fields.
		$payload['content_revision'] = self::digest( array( $context, $payload ) );
		$etag = '"' . self::digest( $payload ) . '"';
		$validator = trim( (string) $request->get_header( 'if-none-match' ), " \t" );
		$status = $validator === $etag || $validator === 'W/' . $etag ? 304 : 200;
		$response = new WP_REST_Response( 304 === $status ? null : $payload, $status );
		$response->header( 'ETag', $etag );
		$response->header( 'Cache-Control', 'no-store' );
		$response->header( 'X-Content-Type-Options', 'nosniff' );
		return $response;
	}
}
