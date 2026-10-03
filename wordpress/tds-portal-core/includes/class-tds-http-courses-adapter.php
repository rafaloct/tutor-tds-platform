<?php

defined( 'ABSPATH' ) || exit;

/**
 * Server-side adapter for the explicit FastAPI public projection.
 *
 * No browser credentials, no admin token and no direct PostgreSQL access.
 */
final class TDS_HTTP_Courses_Adapter implements TDS_Courses_Adapter_Interface {
	const FRESH_TTL = 60;
	const STALE_TTL = 300;

	private $base_url;
	private $timeout;

	public function __construct( $base_url, $timeout = 5 ) {
		$this->base_url = class_exists( 'TDS_Public_Config' ) ? TDS_Public_Config::validated_base_url( $base_url ) : '';
		$this->timeout  = max( 1, min( 10, (int) $timeout ) );
	}

	public function fetch_courses( $page = 1, $per_page = 12 ) {
		$page     = max( 1, absint( $page ) );
		$per_page = min( 50, max( 1, absint( $per_page ) ) );
		$offset   = ( $page - 1 ) * $per_page;
		$url      = $this->base_url . '/public/courses?offset=' . $offset . '&limit=' . $per_page;

		$fresh = $this->cache_get( 'catalog:fresh:' . $url );
		if ( is_array( $fresh ) ) {
			return $fresh;
		}

		$response = $this->request_json( $url );
		if ( is_array( $response ) && 200 === $response['status'] ) {
			$body = $response['body'];
			if (
				is_array( $body ) &&
				isset( $body['courses'], $body['offset'], $body['limit'], $body['total'] ) &&
				is_array( $body['courses'] ) &&
				is_int( $body['offset'] ) &&
				is_int( $body['limit'] ) &&
				is_int( $body['total'] ) &&
				$body['offset'] === $offset &&
				$body['limit'] === $per_page &&
				$body['total'] >= 0
			) {
				$result = array(
					'state'      => 'ready',
					'courses'    => array_values( $body['courses'] ),
					'pagination' => array(
						'page'     => $page,
						'per_page' => $per_page,
						'total'    => $body['total'],
					),
				);
				$this->cache_set( 'catalog:fresh:' . $url, $result, self::FRESH_TTL );
				$this->cache_set( 'catalog:stale:' . $url, $result, self::STALE_TTL );
				return $result;
			}
		}

		$stale = $this->cache_get( 'catalog:stale:' . $url );
		if ( is_array( $stale ) ) {
			return $stale;
		}

		return array(
			'state'      => 'error',
			'courses'    => array(),
			'pagination' => array( 'page' => $page, 'per_page' => $per_page, 'total' => 0 ),
		);
	}

	public function fetch_course( $slug ) {
		$slug = is_string( $slug ) ? trim( $slug ) : '';
		if ( '' === $slug || ! preg_match( '/^[a-z0-9]+(?:-[a-z0-9]+)*$/D', $slug ) ) {
			return array( 'state' => 'not_found', 'course' => null );
		}
		$url   = $this->base_url . '/public/courses/' . rawurlencode( $slug );
		$fresh = $this->cache_get( 'detail:fresh:' . $url );
		if ( is_array( $fresh ) ) {
			return $fresh;
		}

		$response = $this->request_json( $url );
		if ( is_array( $response ) && 404 === $response['status'] ) {
			$this->cache_delete( 'detail:fresh:' . $url );
			$this->cache_delete( 'detail:stale:' . $url );
			return array( 'state' => 'not_found', 'course' => null );
		}
		if ( is_array( $response ) && 200 === $response['status'] && is_array( $response['body'] ) ) {
			$result = array( 'state' => 'ready', 'course' => $response['body'] );
			$this->cache_set( 'detail:fresh:' . $url, $result, self::FRESH_TTL );
			$this->cache_set( 'detail:stale:' . $url, $result, self::STALE_TTL );
			return $result;
		}

		$stale = $this->cache_get( 'detail:stale:' . $url );
		if ( is_array( $stale ) ) {
			return $stale;
		}

		return array( 'state' => 'error', 'course' => null );
	}

	private function request_json( $url ) {
		if ( '' === $this->base_url || 0 !== strpos( $url, $this->base_url . '/public/courses' ) ) {
			return null;
		}
		$response = wp_safe_remote_get(
			$url,
			array(
				'timeout'     => $this->timeout,
				'redirection' => 0,
				'headers'     => array( 'Accept' => 'application/json' ),
				'user-agent'  => 'TutorTDS-Portal/1.0',
			)
		);
		if ( is_wp_error( $response ) ) {
			return null;
		}
		$status = (int) wp_remote_retrieve_response_code( $response );
		$body   = wp_remote_retrieve_body( $response );
		if ( 404 === $status ) {
			return array( 'status' => 404, 'body' => null );
		}
		if ( 200 !== $status || ! is_string( $body ) || '' === $body ) {
			return array( 'status' => $status, 'body' => null );
		}
		$decoded = json_decode( $body, true );
		return array( 'status' => 200, 'body' => is_array( $decoded ) ? $decoded : null );
	}

	private function key( $key ) {
		return 'tds_p5_' . md5( $key );
	}

	private function cache_get( $key ) {
		return get_transient( $this->key( $key ) );
	}

	private function cache_set( $key, $value, $ttl ) {
		set_transient( $this->key( $key ), $value, $ttl );
	}

	private function cache_delete( $key ) {
		delete_transient( $this->key( $key ) );
	}
}
