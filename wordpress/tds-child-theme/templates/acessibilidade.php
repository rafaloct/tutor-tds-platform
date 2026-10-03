<?php
/**
 * Template Name: TDS — Acessibilidade
 * Template Post Type: page
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part( 'template-parts/content', 'page', array( 'eyebrow' => __( 'Declaração de acessibilidade', 'tds-portal' ), 'show_modified' => true ) );
get_footer();
