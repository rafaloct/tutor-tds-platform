<?php
/**
 * Base SEO: descrição, Open Graph e canonical da Home. Sem analytics.
 * Desligada automaticamente quando um plugin SEO conhecido estiver ativo.
 */

defined( 'ABSPATH' ) || exit;

function tds_theme_seo_enabled() {
	$plugin_active = defined( 'RANK_MATH_VERSION' ) || defined( 'WPSEO_VERSION' ) || defined( 'AIOSEO_VERSION' );
	return (bool) apply_filters( 'tds_theme_seo_enabled', ! $plugin_active );
}

function tds_theme_seo_description() {
	if ( is_singular() ) {
		$post = get_queried_object();
		$text = has_excerpt( $post ) ? get_the_excerpt( $post ) : wp_strip_all_tags( strip_shortcodes( $post->post_content ) );
		return wp_trim_words( $text, 30, '…' );
	}
	return get_bloginfo( 'description', 'display' );
}

add_action(
	'wp_head',
	static function () {
		if ( ! tds_theme_seo_enabled() ) {
			return;
		}
		$description = tds_theme_seo_description();
		$url = is_singular() ? get_permalink() : home_url( '/' );
		$image = is_singular() && has_post_thumbnail() ? get_the_post_thumbnail_url( null, 'large' ) : tds_theme_logo_url();
		$title = wp_get_document_title();
		if ( '' !== $description ) {
			echo '<meta name="description" content="' . esc_attr( $description ) . '">' . "\n";
		}
		if ( is_front_page() ) {
			echo '<link rel="canonical" href="' . esc_url( home_url( '/' ) ) . '">' . "\n";
		}
		echo '<meta property="og:type" content="' . ( is_singular( 'post' ) ? 'article' : 'website' ) . '">' . "\n";
		echo '<meta property="og:site_name" content="' . esc_attr( get_bloginfo( 'name', 'display' ) ) . '">' . "\n";
		echo '<meta property="og:title" content="' . esc_attr( $title ) . '">' . "\n";
		echo '<meta property="og:description" content="' . esc_attr( $description ) . '">' . "\n";
		echo '<meta property="og:url" content="' . esc_url( $url ) . '">' . "\n";
		echo '<meta property="og:image" content="' . esc_url( $image ) . '">' . "\n";
		echo '<meta property="og:locale" content="pt_BR">' . "\n";
		echo '<meta name="twitter:card" content="summary_large_image">' . "\n";
	},
	5
);
