<?php
/**
 * Plugin Name: Tutor TDS | Ditado acessível do site
 * Description: STT opcional em busca e contato, sem áudio ou serviços no backend do WordPress.
 * Version: 0.1.0
 * Requires PHP: 7.4
 * License: GPL-2.0-or-later
 * Text Domain: tds-site-stt
 */
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

add_action( 'wp_enqueue_scripts', function () {
    if ( is_admin() ) {
        return;
    }
    $base = plugin_dir_path( __FILE__ );
    $url  = plugin_dir_url( __FILE__ );
    $js   = 'assets/site-stt.js';
    $css  = 'assets/site-stt.css';

    wp_enqueue_style(
        'tds-site-stt',
        $url . $css,
        array(),
        (string) filemtime( $base . $css )
    );
    wp_enqueue_script(
        'tds-site-stt',
        $url . $js,
        array(),
        (string) filemtime( $base . $js ),
        true
    );
}, 30 );
