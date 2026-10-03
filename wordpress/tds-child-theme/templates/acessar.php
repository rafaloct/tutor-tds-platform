<?php
/**
 * Template Name: TDS — Acessar o app
 * Template Post Type: page
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part(
	'template-parts/content',
	'page',
	array(
		'eyebrow' => __( 'Acesso ao app oficial', 'tds-portal' ),
		'after'   => static function () {
			echo '<h2>' . esc_html__( 'Canal oficial', 'tds-portal' ) . '</h2>';
			tds_theme_app_access();
		},
	)
);
get_footer();
