<?php
/**
 * Template Name: TDS — Meus cursos
 * Template Post Type: page
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part(
	'template-parts/content',
	'page',
	array(
		'eyebrow' => __( 'Conta EAD', 'tds-portal' ),
		'after'   => static function () {
			if ( has_shortcode( get_the_content(), 'tds_meus_cursos' ) ) {
				return;
			}
			tds_theme_learner_courses();
		},
	)
);
get_footer();
