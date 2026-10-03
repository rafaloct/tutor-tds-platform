<?php
/**
 * Plugin Name: TDS Portal Core
 * Description: Safe public portal foundation for the Tutor TDS site.
 * Version: 0.1.0
 * Requires PHP: 7.4
 */

defined( 'ABSPATH' ) || exit;

require_once __DIR__ . '/includes/class-tds-public-config.php';
require_once __DIR__ . '/includes/interface-tds-courses-adapter.php';
require_once __DIR__ . '/includes/class-tds-fake-courses-adapter.php';
require_once __DIR__ . '/includes/class-tds-courses-service.php';
require_once __DIR__ . '/includes/class-tds-public-courses-controller.php';
require_once __DIR__ . '/includes/class-tds-editorial-content.php';

add_action(
	'init',
	array( 'TDS_Editorial_Content', 'register' ),
);

add_action(
	'rest_api_init',
	static function () {
		( new TDS_Public_Courses_Controller( new TDS_Courses_Service( new TDS_Fake_Courses_Adapter() ) ) )->register_routes();
	}
);

add_action(
	'admin_init',
	static function () {
		$fields = array(
			TDS_Public_Config::APP_URL_OPTION => array( 'Acesso ao app TDS (HTTPS)', 'validated_url', 'url' ),
			TDS_Public_Config::GA4_OPTION => array( 'GA4 ID público (coleta desativada)', 'validated_ga4_id', 'text' ),
			TDS_Public_Config::API_URL_OPTION => array( 'API pública base (integração indisponível)', 'validated_base_url', 'url' ),
			TDS_Public_Config::SUPPORT_URL_OPTION => array( 'Suporte base (integração desativada)', 'validated_base_url', 'url' ),
		);
		foreach ( $fields as $name => $field ) {
			$sanitize = array( 'TDS_Public_Config', $field[1] );
			register_setting( 'general', $name, array( 'type' => 'string', 'show_in_rest' => false, 'sanitize_callback' => $sanitize, 'default' => '' ) );
			add_settings_field(
				$name, $field[0],
				static function () use ( $name, $field, $sanitize ) {
					if ( ! current_user_can( 'manage_options' ) ) { return; }
					$value = call_user_func( $sanitize, get_option( $name, '' ) );
					echo '<input type="' . esc_attr( $field[2] ) . '" class="regular-text" id="' . esc_attr( $name ) . '" name="' . esc_attr( $name ) . '" value="' . esc_attr( $value ) . '" aria-describedby="' . esc_attr( $name . '-help' ) . '">';
					echo '<p class="description" id="' . esc_attr( $name . '-help' ) . '">Somente configuração pública. Vazio ou inválido desativa o valor; não habilita integração.</p>';
				},
				'general', 'default', array( 'label_for' => $name )
			);
		}
	}
);
