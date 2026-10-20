<?php

defined( 'ABSPATH' ) || exit;

/**
 * Public, opt-in, read-only LearnPress material projection.
 *
 * WordPress is the ONLY editorial source. This endpoint never queries student
 * enrollment, answers, attempts, certificates, instructor PII or answer keys.
 */
final class TDS_LearnPress_Editorial {
	const NS = 'tds-learning/v1';
	const MAX_SECTIONS = 50;
	const MAX_ITEMS = 250;

	public static function register_routes() {
		register_rest_route( self::NS, '/courses/(?P<course_id>[1-9][0-9]{0,8})/curriculum', array(
			'methods' => WP_REST_Server::READABLE,
			'callback' => array( __CLASS__, 'curriculum' ),
			'permission_callback' => '__return_true',
			'args' => array( 'course_id' => array( 'type' => 'integer', 'minimum' => 1 ) ),
		) );
		register_rest_route( self::NS, '/courses/(?P<course_id>[1-9][0-9]{0,8})/lessons/(?P<lesson_id>[1-9][0-9]{0,8})', array(
			'methods' => WP_REST_Server::READABLE,
			'callback' => array( __CLASS__, 'lesson' ),
			'permission_callback' => '__return_true',
			'args' => array(
				'course_id' => array( 'type' => 'integer', 'minimum' => 1 ),
				'lesson_id' => array( 'type' => 'integer', 'minimum' => 1 ),
			),
		) );
	}

	private static function failure( $reason, $status = 404 ) {
		return new WP_Error( 'tds_editorial_' . $reason, 'Conteúdo indisponível.', array( 'status' => $status ) );
	}

	private static function public_post( $id, $type ) {
		$post = get_post( (int) $id );
		return $post && $post->post_type === $type && $post->post_status === 'publish' ? $post : null;
	}

	private static function title( $raw ) {
		return trim( wp_strip_all_tags( (string) $raw ) );
	}

	private static function valid_url( $url, $prefix ) {
		if ( ! is_string( $url ) || '' === $url || strlen( $url ) > 2000 ) {
			return false;
		}
		$parts = wp_parse_url( $url );
		$origin = wp_parse_url( home_url( '/' ) );
		if ( ! is_array( $parts ) || ! is_array( $origin ) ||
			! isset( $parts['scheme'], $parts['host'], $parts['path'], $origin['host'] ) ||
			$parts['scheme'] !== 'https' ||
			strtolower( $parts['host'] ) !== strtolower( $origin['host'] ) ||
			isset( $parts['user'] ) || isset( $parts['pass'] ) ||
			isset( $parts['query'] ) || isset( $parts['fragment'] ) ||
			isset( $parts['port'] ) ||
			strpos( $parts['path'], $prefix ) !== 0 ||
			strpos( $parts['path'], '..' ) !== false ) {
			return false;
		}
		return true;
	}

	private static function ipex_mp4( $lesson_id ) {
		$post = self::public_post( $lesson_id, 'lp_lesson' );
		if ( ! $post || strlen( (string) $post->post_content ) > 250000 ) {
			return null;
		}
		if ( ! preg_match( '#<video\\b[^>]*>(.*?)</video>#is', $post->post_content, $video ) ) {
			return null;
		}
		if ( ! preg_match( '#<source\\b[^>]*src="([^"]+)"[^>]*>#i', $video[1], $source ) ) {
			return null;
		}
		$url = html_entity_decode( $source[1], ENT_QUOTES, 'UTF-8' );
		$path = wp_parse_url( $url, PHP_URL_PATH );
		if ( ! self::valid_url( $url, '/wp-content/uploads/tutor-tds/' ) ||
			! is_string( $path ) || ! preg_match( '/\\.mp4$/iD', $path ) ) {
			return null;
		}
		if ( preg_match( '/%(2e|2f|5c)/i', $path ) ) {
			return null;
		}
		$result = array( 'provider' => 'ipex_mp4', 'source_url' => $url );
		if ( preg_match( '#<track\\b[^>]*kind="captions"[^>]*>#i', $video[1] ) ) {
			if ( ! preg_match( '#<track\\b[^>]*kind="captions"[^>]*src="([^"]+)"[^>]*>#i', $video[1], $track ) ||
				! preg_match( '/srclang="pt-BR"/i', $track[0] ) ) {
				return null;
			}
			$captions = html_entity_decode( $track[1], ENT_QUOTES, 'UTF-8' );
			$caption_path = wp_parse_url( $captions, PHP_URL_PATH );
			if ( ! self::valid_url( $captions, '/wp-content/uploads/tutor-tds/' ) ||
				! is_string( $caption_path ) || ! preg_match( '/\\.vtt$/iD', $caption_path ) ||
				preg_match( '/%(2e|2f|5c)/i', $caption_path ) ) {
				return null;
			}
			$result['captions_url'] = $captions;
		}
		return $result;
	}

	/** The same validated source is used by the editor and the public projection. */
	public static function mp4_source_fingerprint( $lesson_id ) {
		$media = self::ipex_mp4( $lesson_id );
		if ( null === $media ) {
			return null;
		}
		$captions = get_post_meta( $lesson_id, '_tds_mobile_captions_url', true );
		if ( '' !== $captions ) {
			$path = is_string( $captions ) ? wp_parse_url( $captions, PHP_URL_PATH ) : null;
			if ( ! self::valid_url( $captions, '/wp-content/uploads/' ) ||
				! is_string( $path ) || ! preg_match( '/\\.vtt$/iD', $path ) ||
				preg_match( '/%(2e|2f|5c)/i', $path ) ) {
				return null;
			}
		}
		return hash( 'sha256', wp_json_encode( array( $media, $captions ), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ) );
	}

	private static function media( $lesson_id ) {
		if ( get_post_meta( $lesson_id, '_tds_mobile_public', true ) !== '1' ||
			get_post_meta( $lesson_id, '_tds_mobile_rights_approved', true ) !== '1' ) {
			return null;
		}
		$youtube = (string) get_post_meta( $lesson_id, '_tds_mobile_youtube_id', true );
		if ( preg_match( '/^[a-zA-Z0-9_-]{11}$/D', $youtube ) ) {
			$media = array( 'provider' => 'youtube', 'video_id' => $youtube );
		} else {
			// All source videos already live in the IPEX LearnPress lesson body.
			// The YouTube upload quota must not block explicitly approved MP4.
			// Never export a video merely because its HTML contains <video>.
			$fingerprint = self::mp4_source_fingerprint( $lesson_id );
			$stored = get_post_meta( $lesson_id, '_tds_mobile_rights_source_fingerprint', true );
			if ( null === $fingerprint || ! is_string( $stored ) ||
				! hash_equals( $fingerprint, $stored ) ) {
				return null;
			}
			$media = self::ipex_mp4( $lesson_id );
		}
		foreach ( array( 'poster' => '_tds_mobile_poster_url', 'captions' => '_tds_mobile_captions_url' ) as $key => $meta ) {
			$url = get_post_meta( $lesson_id, $meta, true );
			if ( self::valid_url( $url, '/wp-content/uploads/' ) &&
				( 'poster' !== $key || preg_match( '/\.(png|jpe?g|webp)$/iD', wp_parse_url( $url, PHP_URL_PATH ) ) ) &&
				( 'captions' !== $key || preg_match( '/\.vtt$/iD', wp_parse_url( $url, PHP_URL_PATH ) ) ) ) {
				$media[ $key . '_url' ] = $url;
			}
		}
		return $media;
	}

	/**
	 * Reads existing LearnPress REST route internally instead of cloning DB state.
	 */
	private static function outline( $course_id ) {
		if ( ! self::public_post( $course_id, 'lp_course' ) ) {
			return self::failure( 'course_not_published' );
		}
		$request = new WP_REST_Request( 'GET', '/learnpress/v1/courses/' . $course_id );
		$response = rest_do_request( $request );
		if ( is_wp_error( $response ) || ! is_object( $response ) ||
			! method_exists( $response, 'get_status' ) || 200 !== $response->get_status() ) {
			return self::failure( 'upstream', 503 );
		}
		$source = $response->get_data();
		if ( ! is_array( $source ) || (int) ( $source['id'] ?? 0 ) !== $course_id ||
			! isset( $source['sections'] ) || ! is_array( $source['sections'] ) ||
			count( $source['sections'] ) > self::MAX_SECTIONS ) {
			return self::failure( 'invalid_curriculum', 503 );
		}
		$all_ids = array();
		$section_ids = array();
		$sections = array();
		$items_total = 0;
		foreach ( $source['sections'] as $section ) {
			if ( ! is_array( $section ) ) {
				return self::failure( 'invalid_section', 503 );
			}
			$sid = (int) ( $section['id'] ?? 0 );
			if ( $sid <= 0 || isset( $section_ids[ $sid ] ) ||
				! isset( $section['items'] ) || ! is_array( $section['items'] ) ) {
				return self::failure( 'invalid_section', 503 );
			}
			$section_ids[ $sid ] = true;
			$items = array();
			foreach ( $section['items'] as $item ) {
				if ( ! is_array( $item ) ) {
					return self::failure( 'invalid_item', 503 );
				}
				$items_total++;
				if ( $items_total > self::MAX_ITEMS ) {
					return self::failure( 'too_many_items', 503 );
				}
				$id = (int) ( $item['id'] ?? 0 );
				$type = $item['type'] ?? '';
				if ( $id <= 0 || ! in_array( $type, array( 'lp_lesson', 'lp_quiz' ), true ) ||
					isset( $all_ids[ $id ] ) ) {
					return self::failure( 'invalid_item', 503 );
				}
				$all_ids[ $id ] = true;
				$post = self::public_post( $id, $type );
				// A draft lesson/quiz must never leak through stale section records.
				if ( ! $post ) {
					continue;
				}
				$record = array(
					'id' => $id,
					'type' => $type,
					'title' => self::title( $post->post_title ),
					'revision' => $post->post_modified_gmt,
				);
				if ( 'lp_lesson' === $type ) {
					$record['mobile_content'] = get_post_meta( $id, '_tds_mobile_public', true ) === '1';
					$record['media'] = self::media( $id );
				} else {
					$link = get_permalink( $id );
					$record['url'] = self::valid_url( $link, '/quizzes/' ) ? $link : null;
					// Quiz questions/answers/grades are never exposed publicly.
				}
				$items[] = $record;
			}
			$sections[] = array(
				'id' => $sid,
				'title' => self::title( $section['title'] ?? '' ),
				'items' => $items,
			);
		}
		$post = get_post( $course_id );
		return array(
			'schema_version' => 1,
			'authority' => 'learnpress',
			'course_id' => $course_id,
			'title' => self::title( $post->post_title ),
			'course_url' => self::valid_url( get_permalink( $course_id ), '/courses/' ) ? get_permalink( $course_id ) : null,
			'sections' => $sections,
		);
	}

	private static function respond( $payload, $request ) {
		$revision = hash( 'sha256', wp_json_encode( $payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES ) );
		$etag = '"' . $revision . '"';
		// GET revalidation uses weak comparison (RFC 9110, 13.1.2).
		// Match only the complete current validator, never a substring.
		$validator = trim( (string) $request->get_header( 'if-none-match' ), " \t" );
		$unmodified = $validator === $etag || $validator === 'W/' . $etag;
		$response = new WP_REST_Response( $unmodified ? null : array_merge( $payload, array( 'revision' => $revision ) ), $unmodified ? 304 : 200 );
		$response->header( 'ETag', $etag );
		$response->header( 'Cache-Control', 'public, max-age=0, must-revalidate' );
		$response->header( 'X-Content-Type-Options', 'nosniff' );
		return $response;
	}

	public static function curriculum( $request ) {
		$id = (int) $request['course_id'];
		$payload = self::outline( $id );
		if ( is_wp_error( $payload ) ) {
			return $payload;
		}
		return self::respond( $payload, $request );
	}

	public static function lesson( $request ) {
		$cid = (int) $request['course_id'];
		$id = (int) $request['lesson_id'];
		$outline = self::outline( $cid );
		if ( is_wp_error( $outline ) ) {
			return $outline;
		}
		$found = false;
		foreach ( $outline['sections'] as $section ) {
			foreach ( $section['items'] as $item ) {
				if ( $item['id'] === $id && $item['type'] === 'lp_lesson' ) {
					$found = true;
					break 2;
				}
			}
		}
		if ( ! $found || ! self::public_post( $id, 'lp_lesson' ) ||
			get_post_meta( $id, '_tds_mobile_public', true ) !== '1' ) {
			return self::failure( 'lesson_not_authorized' );
		}
		$post = get_post( $id );
		// Bounded public projection: reject unexpectedly large editorial payloads.
		if ( strlen( (string) $post->post_content ) > 250000 ) {
			return self::failure( 'lesson_too_large', 413 );
		}
		// No the_content filter: it may execute shortcodes and private embeds.
		// WordPress wp_kses strips <script> tags but *retains their text*.
		// Drop whole active/embed elements before allowing any public HTML.
		$raw = preg_replace(
			'#<\s*(script|style|iframe|object|embed|form|svg)\b[^>]*>.*?<\s*/\s*\1\s*>#is',
			'',
			$post->post_content
		);
		$raw = is_string( $raw ) ? strip_shortcodes( $raw ) : '';
		// strip_shortcodes() only removes registered shortcodes. Do not leak
		// custom/unregistered shortcode tags to visitors of public lessons.
		$raw = preg_replace( '/\[(?:\/?)[a-z][^\]]*\]/iu', '', $raw );
		$raw = is_string( $raw ) ? $raw : '';
		$allowed = array(
			'p' => array(), 'br' => array(), 'strong' => array(), 'em' => array(),
			'ul' => array(), 'ol' => array(), 'li' => array(),
			'h2' => array(), 'h3' => array(), 'h4' => array(),
			'blockquote' => array(), 'a' => array( 'href' => true ),
		);
		$html = wp_kses( $raw, $allowed, array( 'https' ) );
		$payload = array(
			'schema_version' => 1,
			'authority' => 'learnpress',
			'course_id' => $cid,
			'lesson_id' => $id,
			'title' => self::title( $post->post_title ),
			'content_html' => $html,
			'media' => self::media( $id ),
		);
		return self::respond( $payload, $request );
	}
}
