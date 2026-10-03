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

add_action(
	'rest_api_init',
	static function () {
		( new TDS_Public_Courses_Controller( new TDS_Courses_Service( new TDS_Fake_Courses_Adapter() ) ) )->register_routes();
	}
);

add_action(
	'admin_init',
	static function () {
		register_setting(
			'general',
			TDS_Public_Config::APP_URL_OPTION,
			array(
				'type' => 'string',
				'show_in_rest' => false,
				'sanitize_callback' => array( 'TDS_Public_Config', 'validated_url' ),
				'default' => '',
			)
		);
		add_settings_field(
			TDS_Public_Config::APP_URL_OPTION,
			'Acesso ao app TDS (HTTPS)',
			static function () {
				if ( ! current_user_can( 'manage_options' ) ) { return; }
				$config = TDS_Public_Config::get();
				echo '<input type="url" class="regular-text" id="tds_app_access_url" name="tds_app_access_url" value="' . esc_attr( $config['app_access_url'] ) . '" aria-describedby="tds-app-help">';
				echo '<p class="description" id="tds-app-help">URL pública oficial. Vazio ou inválido mantém o acesso indisponível.</p>';
			},
			'general',
			'default',
			array( 'label_for' => TDS_Public_Config::APP_URL_OPTION )
		);
	}
);
