<?php

defined( 'ABSPATH' ) || exit;

/** Central, public-only configuration. Integration switches are code defaults. */
final class TDS_Public_Config {
	const APP_URL_OPTION = 'tds_app_access_url';

	public static function get() {
		$url = get_option( self::APP_URL_OPTION, '' );
		return array(
			'app_access_url'  => self::validated_url( $url ),
			'integration_state' => array(
				'courses'  => 'unavailable',
				'analytics' => 'disabled',
				'support'  => 'disabled',
			),
		);
	}

	public static function validated_url( $value ) {
		$value = is_string( $value ) ? trim( $value ) : '';
		if ( '' === $value || ! wp_http_validate_url( $value ) ) {
			return '';
		}

		$parts = wp_parse_url( $value );
		if ( empty( $parts['scheme'] ) || ! in_array( strtolower( $parts['scheme'] ), array( 'https' ), true ) ) {
			return '';
		}

		return esc_url_raw( $value );
	}

	public static function integration_state( $integration, $state = null ) {
		$allowed = array( 'disabled', 'unavailable', 'ready', 'error' );
		if ( null !== $state && in_array( $state, $allowed, true ) ) {
			return $state;
		}

		$config = self::get();
		return isset( $config['integration_state'][ $integration ] ) ? $config['integration_state'][ $integration ] : 'unavailable';
	}
}
