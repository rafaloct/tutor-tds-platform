<?php
/**
 * Template Name: TDS — Certificados
 * Template Post Type: page
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part(
	'template-parts/content',
	'page',
	array(
		'eyebrow' => __( 'Comprovação e certificados', 'tds-portal' ),
		'after'   => static function () {
			if ( has_shortcode( get_the_content(), 'tds_certificados' ) ) {
				return;
			}
			tds_theme_learner_certificates();
		},
	)
);
get_footer();
