<?php
/**
 * Provider editorial de histórias para a Home pública.
 *
 * WP-4 mantém histórias como posts nativos do WordPress. Esta ponte lê somente
 * posts publicados na categoria "historias" e alimenta o filtro WP-3 já
 * existente. Nenhum conteúdo é criado automaticamente.
 */

defined( 'ABSPATH' ) || exit;

/**
 * Expõe até três histórias publicadas para o slot da Home.
 *
 * Se outro provider já resolveu o filtro, preserva o resultado existente.
 */
function tds_theme_home_stories_provider( $payload ) {
	if (
		is_array( $payload ) &&
		isset( $payload['state'] ) &&
		'unavailable' !== $payload['state']
	) {
		return $payload;
	}

	$query = new WP_Query(
		array(
			'post_type'           => 'post',
			'post_status'         => 'publish',
			'posts_per_page'      => 3,
			'category_name'       => 'historias',
			'ignore_sticky_posts' => true,
			'no_found_rows'       => true,
			'orderby'             => 'date',
			'order'               => 'DESC',
		)
	);

	if ( ! $query->have_posts() ) {
		return array(
			'state' => 'empty',
			'items' => array(),
		);
	}

	$items = array();
	while ( $query->have_posts() ) {
		$query->the_post();
		$post_id = get_the_ID();
		$title   = get_the_title( $post_id );
		$url     = get_permalink( $post_id );
		$slug    = get_post_field( 'post_name', $post_id );
		$excerpt = has_excerpt( $post_id )
			? get_the_excerpt( $post_id )
			: wp_trim_words( wp_strip_all_tags( get_post_field( 'post_content', $post_id ) ), 28 );

		if ( '' === trim( (string) $title ) || ! is_string( $url ) || '' === $url ) {
			continue;
		}

		$items[] = array(
			'title' => $title,
			'text'  => $excerpt,
			'url'   => $url,
			'slug'  => $slug,
			'state' => 'available',
		);
	}
	wp_reset_postdata();

	return array(
		'state' => $items ? 'success' : 'empty',
		'items' => $items,
	);
}

add_filter( 'tds_portal_home_stories', 'tds_theme_home_stories_provider', 10, 1 );
