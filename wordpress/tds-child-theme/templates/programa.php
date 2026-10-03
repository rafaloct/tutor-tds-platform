<?php
/**
 * Template Name: TDS — O Programa
 * Template Post Type: page
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part( 'template-parts/content', 'page', array( 'eyebrow' => __( 'Programa TDS', 'tds-portal' ) ) );
get_footer();
