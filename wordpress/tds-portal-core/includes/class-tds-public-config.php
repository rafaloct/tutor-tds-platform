<?php

defined( 'ABSPATH' ) || exit;

/** Central, public-only configuration. Integration switches are code defaults. */
final class TDS_Public_Config {
	const APP_URL_OPTION = 'tds_app_access_url';
	const GA4_OPTION = 'tds_ga4_measurement_id';
	const API_URL_OPTION = 'tds_public_api_base_url';
	const SUPPORT_URL_OPTION = 'tds_support_base_url';

	public static function get() {
		$url = self::validated_url( get_option( self::APP_URL_OPTION, '' ) );
		return array(
			'app_access_url'  => $url,
			'ga4_measurement_id' => self::validated_ga4_id( get_option( self::GA4_OPTION, '' ) ),
			'public_api_base_url' => self::validated_base_url( get_option( self::API_URL_OPTION, '' ) ),
			'support_base_url' => self::validated_base_url( get_option( self::SUPPORT_URL_OPTION, '' ) ),
			'integration_state' => array(
				'app' => '' === $url ? 'unavailable' : 'ready',
				'courses'  => 'unavailable',
				'analytics' => 'disabled',
				'support'  => 'disabled',
			),
		);
	}

	public static function validated_url( $value ) {
		$value = is_string( $value ) ? trim( $value ) : '';
		if ( '' === $value || preg_match( '/[\x00-\x20\x7f\\\\]/', $value ) || ! filter_var( $value, FILTER_VALIDATE_URL ) ) {
			return '';
		}

		$parts = wp_parse_url( $value );
		if ( empty( $parts['host'] ) || empty( $parts['scheme'] ) || 'https' !== strtolower( $parts['scheme'] ) || isset( $parts['user'] ) || isset( $parts['pass'] ) || ( isset( $parts['port'] ) && 443 !== $parts['port'] ) || false === strpos( $parts['host'], '.' ) || preg_match( '/\.(?:localhost|local|internal)$/i', $parts['host'] ) || ( filter_var( trim( $parts['host'], '[]' ), FILTER_VALIDATE_IP ) && ! filter_var( trim( $parts['host'], '[]' ), FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE ) ) ) {
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

	public static function validated_base_url( $value ) {
		$url = self::validated_url( $value );
		return false !== strpos( $url, '?' ) || false !== strpos( $url, '#' ) ? '' : rtrim( $url, '/' );
	}

	public static function validated_ga4_id( $value ) {
		return is_string( $value ) && preg_match( '/^G-[A-Z0-9]{6,20}$/D', $value ) ? $value : '';
	}
}
