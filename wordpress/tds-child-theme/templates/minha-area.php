<?php
/**
 * Template Name: TDS — Minha área
 * Template Post Type: page
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part(
	'template-parts/content',
	'page',
	array(
		'eyebrow' => __( 'Sua área de estudo', 'tds-portal' ),
		'after'   => static function () {
			if ( has_shortcode( get_the_content(), 'tds_minha_area' ) ) {
				return;
			}
			tds_theme_learner_area();
		},
	)
);
get_footer();
