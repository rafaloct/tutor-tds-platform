<?php
/**
 * Template Name: TDS — Privacidade
 * Template Post Type: page
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part( 'template-parts/content', 'page', array( 'eyebrow' => __( 'Política de privacidade', 'tds-portal' ), 'show_modified' => true ) );
get_footer();
