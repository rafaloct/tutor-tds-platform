<?php
/** Suporte do tema, assets, menus, patterns e integração mínima com o Astra. */

defined( 'ABSPATH' ) || exit;

add_action(
	'after_setup_theme',
	static function () {
		load_theme_textdomain( 'tds-portal', get_stylesheet_directory() . '/languages' );
		add_theme_support( 'title-tag' );
		add_theme_support( 'post-thumbnails' );
		add_theme_support( 'responsive-embeds' );
		add_theme_support( 'align-wide' );
		add_theme_support( 'custom-logo', array( 'height' => 80, 'width' => 240, 'flex-height' => true, 'flex-width' => true ) );
		add_theme_support( 'html5', array( 'search-form', 'gallery', 'caption', 'style', 'script', 'navigation-widgets' ) );
		add_theme_support( 'editor-styles' );
		add_editor_style( 'assets/css/editor.css' );
		add_theme_support(
			'editor-color-palette',
			array(
				array( 'name' => __( 'TDS Azul', 'tds-portal' ), 'slug' => 'tds-primary', 'color' => '#093af4' ),
				array( 'name' => __( 'TDS Escuro', 'tds-portal' ), 'slug' => 'tds-dark', 'color' => '#071650' ),
				array( 'name' => __( 'TDS Amarelo', 'tds-portal' ), 'slug' => 'tds-accent', 'color' => '#f6d846' ),
				array( 'name' => __( 'TDS Verde', 'tds-portal' ), 'slug' => 'tds-success', 'color' => '#18d010' ),
				array( 'name' => __( 'Tinta', 'tds-portal' ), 'slug' => 'tds-ink', 'color' => '#262626' ),
				array( 'name' => __( 'Superfície', 'tds-portal' ), 'slug' => 'tds-surface', 'color' => '#ffffff' ),
			)
		);
		register_nav_menus(
			array(
				'tds-primary' => __( 'TDS — Navegação principal', 'tds-portal' ),
				'tds-footer'  => __( 'TDS — Rodapé institucional', 'tds-portal' ),
			)
		);
		remove_theme_support( 'core-block-patterns' );
	}
);

add_action(
	'wp_enqueue_scripts',
	static function () {
		$deps = wp_style_is( 'astra-theme-css', 'registered' ) ? array( 'astra-theme-css' ) : array();
		wp_enqueue_style( 'tds-portal-child', get_stylesheet_uri(), $deps, TDS_PORTAL_THEME_VERSION );
		wp_enqueue_script( 'tds-portal-navigation', get_stylesheet_directory_uri() . '/assets/js/navigation.js', array(), TDS_PORTAL_THEME_VERSION, array( 'in_footer' => true, 'strategy' => 'defer' ) );
	},
	20
);

add_action(
	'init',
	static function () {
		register_block_pattern_category( 'tds-portal', array( 'label' => __( 'Portal TDS', 'tds-portal' ) ) );
		add_shortcode( 'tds_acesso_app', 'tds_theme_shortcode_app_access' );
		add_shortcode( 'tds_catalogo', 'tds_theme_shortcode_catalog' );
		add_shortcode( 'tds_estado', 'tds_theme_shortcode_state' );
	}
);

add_filter(
	'body_class',
	static function ( array $classes ) {
		$classes[] = 'tds-portal';
		return $classes;
	}
);

// O tema controla cabeçalho, título e largura; o Astra não deve duplicá-los.
add_filter( 'astra_page_layout', static function () { return 'no-sidebar'; } );
add_filter( 'astra_the_post_title_enabled', '__return_false' );
add_filter( 'astra_featured_image_enabled', '__return_false' );

remove_action( 'wp_head', 'wp_generator' );

/** Metadados dos templates institucionais previstos na Issue #42. */
function tds_theme_page_templates() {
	return array(
		'templates/acessar.php'       => array( 'label' => __( 'Acessar o app', 'tds-portal' ), 'eyebrow' => __( 'Acesso', 'tds-portal' ) ),
		'templates/programa.php'      => array( 'label' => __( 'O Programa', 'tds-portal' ), 'eyebrow' => __( 'Programa TDS', 'tds-portal' ) ),
		'templates/privacidade.php'   => array( 'label' => __( 'Privacidade', 'tds-portal' ), 'eyebrow' => __( 'Política', 'tds-portal' ) ),
		'templates/direitos.php'      => array( 'label' => __( 'Direitos e exclusão', 'tds-portal' ), 'eyebrow' => __( 'Seus dados', 'tds-portal' ) ),
		'templates/acessibilidade.php' => array( 'label' => __( 'Acessibilidade', 'tds-portal' ), 'eyebrow' => __( 'Compromisso', 'tds-portal' ) ),
		'templates/contato.php'       => array( 'label' => __( 'Contato', 'tds-portal' ), 'eyebrow' => __( 'Fale com o programa', 'tds-portal' ) ),
	);
}

/** Primeira página publicada que usa o template indicado, ou null. */
function tds_theme_find_page_by_template( $template ) {
	static $cache = array();
	if ( array_key_exists( $template, $cache ) ) {
		return $cache[ $template ];
	}
	$pages = get_posts(
		array(
			'post_type'      => 'page',
			'post_status'    => 'publish',
			'posts_per_page' => 1,
			'orderby'        => 'menu_order',
			'order'          => 'ASC',
			'meta_key'       => '_wp_page_template',
			'meta_value'     => $template,
			'no_found_rows'  => true,
		)
	);
	$cache[ $template ] = $pages ? $pages[0] : null;
	return $cache[ $template ];
}
