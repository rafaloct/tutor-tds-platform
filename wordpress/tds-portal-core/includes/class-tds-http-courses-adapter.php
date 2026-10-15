<?php

defined( 'ABSPATH' ) || exit;

/** Anonymous public projection only. TDS_Courses_Service validates public fields. */
final class TDS_HTTP_Courses_Adapter implements TDS_Courses_Adapter_Interface {
	const MAX_RESPONSE_BYTES = 1048576;

	public function fetch_courses( $page = 1, $per_page = 12 ) {
		$unavailable = array( 'state' => 'unavailable' );
		if ( ! defined( 'TDS_PUBLIC_CATALOG_ENABLED' ) || true !== TDS_PUBLIC_CATALOG_ENABLED ) {
			return $unavailable;
		}
		$base = TDS_Public_Config::validated_base_url( get_option( TDS_Public_Config::API_URL_OPTION, '' ) );
		if ( '' === $base ) {
			return $unavailable;
		}
		$page = max( 1, (int) $page );
		$per_page = min( 50, max( 1, (int) $per_page ) );
		// Reject integer overflow rather than producing a floating-point query.
		if ( $page - 1 > intdiv( PHP_INT_MAX, $per_page ) ) {
			return array( 'state' => 'error' );
		}
		$offset = ( $page - 1 ) * $per_page;
		$url = $base . '/public/courses?offset=' . $offset . '&limit=' . $per_page;
		// Uses WordPress DNS/private-address validation, also applied by safe GET.
		if ( ! wp_http_validate_url( $url ) ) {
			return $unavailable;
		}
		$response = wp_safe_remote_get( $url, array(
			'timeout' => 5,
			'redirection' => 0,
			'sslverify' => true,
			'limit_response_size' => self::MAX_RESPONSE_BYTES + 1,
			'headers' => array( 'Accept' => 'application/json' ),
			'cookies' => array(),
		) );
		if ( is_wp_error( $response ) || 200 !== wp_remote_retrieve_response_code( $response ) ) {
			return array( 'state' => 'error' );
		}
		$body = wp_remote_retrieve_body( $response );
		if ( ! is_string( $body ) || '' === $body || strlen( $body ) > self::MAX_RESPONSE_BYTES ) {
			return array( 'state' => 'error' );
		}
		$payload = json_decode( $body, true, 32 );
		if ( JSON_ERROR_NONE !== json_last_error() || ! is_array( $payload )
			|| ! isset( $payload['offset'], $payload['limit'], $payload['total'], $payload['courses'] )
			|| $offset !== $payload['offset'] || $per_page !== $payload['limit']
			|| ! is_int( $payload['total'] ) || $payload['total'] < 0
			|| ! is_array( $payload['courses'] ) ) {
			return array( 'state' => 'error' );
		}
		// No raw upstream payload is cached, logged or returned by the REST controller.
		return array(
			'state' => 'ready',
			'courses' => $payload['courses'],
			'pagination' => array( 'page' => $page, 'per_page' => $per_page, 'total' => $payload['total'] ),
		);
	}
}
