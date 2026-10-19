<?php
/**
 * Plugin Name: Tutor TDS — Ponte Editorial LearnPress
 * Description: Adaptador read-only e opt-in de conteúdo público LearnPress para o app Tutor TDS.
 * Version: 0.1.0
 * Requires PHP: 8.0
 * Text Domain: tds-learnpress-editorial
 */
defined( 'ABSPATH' ) || exit;

require_once __DIR__ . '/includes/class-tds-learnpress-editorial.php';
require_once __DIR__ . '/includes/class-tds-learnpress-editorial-admin.php';

add_action( 'rest_api_init', array( 'TDS_LearnPress_Editorial', 'register_routes' ) );
add_action( 'add_meta_boxes_lp_lesson', array( 'TDS_LearnPress_Editorial_Admin', 'register_box' ) );
add_action( 'save_post_lp_lesson', array( 'TDS_LearnPress_Editorial_Admin', 'save' ), 10, 2 );
