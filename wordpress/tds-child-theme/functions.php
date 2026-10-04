<?php
/**
 * TDS Portal Child — camada visual do portal público (WP-2).
 *
 * Consome somente TDS_Public_Config::get() e a REST pública do tds-portal-core.
 * Não cria options, endpoints, cadastro, matrícula, progresso ou certificado.
 */

defined( 'ABSPATH' ) || exit;

define( 'TDS_PORTAL_THEME_VERSION', '0.2.1' );

require_once get_stylesheet_directory() . '/inc/config.php';
require_once get_stylesheet_directory() . '/inc/setup.php';
require_once get_stylesheet_directory() . '/inc/template-tags.php';
require_once get_stylesheet_directory() . '/inc/home-components.php';
require_once get_stylesheet_directory() . '/inc/story-provider.php';
require_once get_stylesheet_directory() . '/inc/seo.php';
