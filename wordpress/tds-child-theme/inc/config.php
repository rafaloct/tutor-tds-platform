<?php
/**
 * Leitura da configuração pública. Única ponte do tema com o plugin.
 *
 * Com o plugin inativo tudo é "unavailable"/"disabled": o tema oculta os
 * componentes dependentes em vez de inventar valores.
 */

defined( 'ABSPATH' ) || exit;

function tds_theme_public_config_defaults() {
	return array(
		'app_access_url'      => '',
		'ga4_measurement_id'  => '',
		'public_api_base_url' => '',
		'support_base_url'    => '',
		'integration_state'   => array(
			'app'       => 'unavailable',
			'courses'   => 'unavailable',
			'analytics' => 'disabled',
			'support'   => 'disabled',
		),
	);
}

function tds_theme_public_config() {
	static $config = null;
	if ( null !== $config ) {
		return $config;
	}
	$defaults = tds_theme_public_config_defaults();
	if ( ! class_exists( 'TDS_Public_Config' ) || ! method_exists( 'TDS_Public_Config', 'get' ) ) {
		$config = $defaults;
		return $config;
	}
	$value = TDS_Public_Config::get();
	$config = is_array( $value ) ? array_replace_recursive( $defaults, $value ) : $defaults;
	return $config;
}

function tds_theme_integration_state( $integration ) {
	$config = tds_theme_public_config();
	$state = isset( $config['integration_state'][ $integration ] ) ? $config['integration_state'][ $integration ] : 'unavailable';
	return in_array( $state, array( 'disabled', 'unavailable', 'ready', 'error' ), true ) ? $state : 'unavailable';
}

/** URL de acesso ao app somente quando o plugin a declara pronta. */
function tds_theme_app_access_url() {
	$config = tds_theme_public_config();
	return 'ready' === tds_theme_integration_state( 'app' ) && is_string( $config['app_access_url'] ) ? $config['app_access_url'] : '';
}

/**
 * Catálogo público via rota REST do plugin, despachada internamente.
 * Retorna sempre a forma { state, courses, pagination, error }.
 */
function tds_theme_public_catalog( $per_page = 6, $page = 1 ) {
	$fallback = array(
		'state'      => 'unavailable',
		'courses'    => array(),
		'pagination' => array( 'page' => max( 1, (int) $page ), 'per_page' => max( 1, (int) $per_page ), 'total' => 0 ),
		'error'      => array( 'code' => 'catalog_unavailable', 'message' => '' ),
	);
	if ( ! class_exists( 'TDS_Public_Courses_Controller' ) || ! function_exists( 'rest_do_request' ) ) {
		return $fallback;
	}
	$request = new WP_REST_Request( 'GET', '/tds-portal/v1/public/courses' );
	$request->set_query_params( array( 'page' => max( 1, (int) $page ), 'per_page' => min( 50, max( 1, (int) $per_page ) ) ) );
	$response = rest_do_request( $request );
	if ( ! ( $response instanceof WP_REST_Response ) ) {
		return $fallback;
	}
	$data = rest_get_server()->response_to_data( $response, false );
	if ( ! is_array( $data ) || ! isset( $data['state'] ) || ! in_array( $data['state'], array( 'ready', 'unavailable', 'disabled', 'error' ), true ) ) {
		$fallback['state'] = 'error';
		return $fallback;
	}
	$data['courses'] = isset( $data['courses'] ) && is_array( $data['courses'] ) && 'ready' === $data['state'] ? $data['courses'] : array();
	$data['pagination'] = isset( $data['pagination'] ) && is_array( $data['pagination'] ) ? array_merge( $fallback['pagination'], $data['pagination'] ) : $fallback['pagination'];
	return $data;
}
