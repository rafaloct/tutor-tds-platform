<?php
/** Componentes reutilizáveis. Toda saída é escapada para o contexto HTML. */

defined( 'ABSPATH' ) || exit;

function tds_theme_logo_url( $mark = false ) {
	return get_stylesheet_directory_uri() . ( $mark ? '/assets/img/marca-tds.png' : '/assets/img/logo-tds.png' );
}

function tds_theme_brand() {
	$name = get_bloginfo( 'name', 'display' );
	echo '<a class="tds-brand" href="' . esc_url( home_url( '/' ) ) . '" rel="home">';
	if ( has_custom_logo() ) {
		$logo = wp_get_attachment_image( get_theme_mod( 'custom_logo' ), 'medium', false, array( 'class' => 'tds-brand__logo', 'alt' => $name, 'loading' => 'eager' ) );
		echo wp_kses_post( $logo );
	} else {
		echo '<img class="tds-brand__logo" src="' . esc_url( tds_theme_logo_url() ) . '" width="96" height="40" alt="' . esc_attr__( 'TDS — Territórios de Desenvolvimento Social e Inclusão Produtiva', 'tds-portal' ) . '" decoding="async">';
	}
	echo '<span class="tds-brand__text">' . esc_html( $name ) . '<span class="tds-brand__tagline">' . esc_html__( 'Portal público', 'tds-portal' ) . '</span></span>';
	echo '</a>';
}

function tds_theme_button( $label, $url, $variant = '', $attrs = array() ) {
	$class = 'tds-button' . ( $variant ? ' tds-button--' . sanitize_html_class( $variant ) : '' );
	$html = '<a class="' . esc_attr( $class ) . '" href="' . esc_url( $url ) . '"';
	foreach ( $attrs as $key => $value ) {
		$html .= ' ' . sanitize_key( $key ) . '="' . esc_attr( $value ) . '"';
	}
	return $html . '>' . esc_html( $label ) . '</a>';
}

function tds_theme_primary_nav() {
	echo '<nav id="tds-primary-nav" class="tds-nav" aria-label="' . esc_attr__( 'Navegação principal', 'tds-portal' ) . '">';
	wp_nav_menu(
		array(
			'theme_location' => 'tds-primary',
			'container'      => false,
			'menu_class'     => 'tds-nav__menu',
			'depth'          => 2,
			'fallback_cb'    => 'tds_theme_nav_fallback',
		)
	);
	$app_url = tds_theme_app_access_url();
	if ( '' !== $app_url ) {
		echo '<div class="tds-nav__cta">' . tds_theme_button( __( 'Acessar o app', 'tds-portal' ), $app_url, 'accent', array( 'rel' => 'noopener', 'data-tds-action' => 'app-access' ) ) . '</div>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
	}
	echo '</nav>';
}

/** Fallback quando não há menu atribuído: Início + páginas institucionais existentes. */
function tds_theme_nav_fallback() {
	$items = array( array( __( 'Início', 'tds-portal' ), home_url( '/' ), is_front_page() ) );
	foreach ( tds_theme_page_templates() as $template => $meta ) {
		$page = tds_theme_find_page_by_template( $template );
		if ( $page ) {
			$items[] = array( get_the_title( $page ), get_permalink( $page ), is_page( $page->ID ) );
		}
	}
	echo '<ul class="tds-nav__menu">';
	foreach ( $items as $item ) {
		echo '<li><a href="' . esc_url( $item[1] ) . '"' . ( $item[2] ? ' aria-current="page"' : '' ) . '>' . esc_html( $item[0] ) . '</a></li>';
	}
	echo '</ul>';
}

function tds_theme_footer_nav() {
	if ( has_nav_menu( 'tds-footer' ) ) {
		wp_nav_menu( array( 'theme_location' => 'tds-footer', 'container' => false, 'menu_class' => 'tds-footer__menu', 'depth' => 1 ) );
		return;
	}
	$templates = array( 'templates/privacidade.php', 'templates/direitos.php', 'templates/acessibilidade.php', 'templates/contato.php' );
	$links = array();
	foreach ( $templates as $template ) {
		$page = tds_theme_find_page_by_template( $template );
		if ( $page ) {
			$links[] = '<li><a href="' . esc_url( get_permalink( $page ) ) . '">' . esc_html( get_the_title( $page ) ) . '</a></li>';
		}
	}
	if ( $links ) {
		echo '<ul class="tds-footer__menu">' . implode( '', $links ) . '</ul>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped above
	}
}

/**
 * Aviso de estado. $state: loading | success | empty | stale | unavailable | error | disabled.
 * Erros usam role="alert"; demais usam role="status" (polite).
 */
function tds_theme_state_notice( $state, $args = array() ) {
	$states = array(
		'loading'     => array( '…', __( 'Carregando', 'tds-portal' ), __( 'Buscando informações atualizadas.', 'tds-portal' ) ),
		'empty'       => array( '0', __( 'Nada por aqui ainda', 'tds-portal' ), __( 'Quando houver conteúdo publicado, ele aparecerá nesta área.', 'tds-portal' ) ),
		'error'       => array( '!', __( 'Não foi possível carregar', 'tds-portal' ), __( 'Ocorreu uma falha temporária. Tente novamente mais tarde.', 'tds-portal' ) ),
		'unavailable' => array( 'i', __( 'Indisponível temporariamente', 'tds-portal' ), __( 'Esta informação ainda não está disponível no portal.', 'tds-portal' ) ),
		'stale'       => array( '↻', __( 'Última versão disponível', 'tds-portal' ), __( 'A fonte está temporariamente indisponível; este conteúdo pode estar desatualizado.', 'tds-portal' ) ),
		'disabled'    => array( 'i', __( 'Recurso não habilitado', 'tds-portal' ), __( 'Este recurso ainda não foi ativado para o portal público.', 'tds-portal' ) ),
		'success'     => array( '✓', __( 'Tudo certo', 'tds-portal' ), '' ),
	);
	if ( ! isset( $states[ $state ] ) ) {
		$state = 'unavailable';
	}
	list( $icon, $title, $text ) = $states[ $state ];
	$title = isset( $args['title'] ) ? $args['title'] : $title;
	$text = isset( $args['text'] ) ? $args['text'] : $text;
	$role = 'error' === $state ? 'alert' : 'status';
	$busy = 'loading' === $state ? ' aria-busy="true"' : '';
	echo '<div class="tds-state tds-state--' . esc_attr( $state ) . '" role="' . esc_attr( $role ) . '"' . $busy . ' data-tds-state="' . esc_attr( $state ) . '">'; // phpcs:ignore WordPress.Security.EscapeOutput -- $busy is a constant attribute
	echo '<span class="tds-state__icon" aria-hidden="true">' . esc_html( $icon ) . '</span>';
	echo '<div><p class="tds-state__title">' . esc_html( $title ) . '</p>';
	if ( '' !== $text ) {
		echo '<p class="tds-state__text">' . esc_html( $text ) . '</p>';
	}
	echo '</div>';
	if ( ! empty( $args['action_label'] ) && ! empty( $args['action_url'] ) ) {
		echo '<div class="tds-state__actions">' . tds_theme_button( $args['action_label'], $args['action_url'], 'outline' ) . '</div>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
	}
	echo '</div>';
}

/** CTA de acesso ao app: link oficial quando pronto; caso contrário, estado honesto. */
function tds_theme_app_access( $args = array() ) {
	$url = tds_theme_app_access_url();
	$state = tds_theme_integration_state( 'app' );
	echo '<div class="tds-app-access" data-tds-component="app-access" data-tds-state="' . esc_attr( $state ) . '">';
	if ( '' !== $url ) {
		echo '<div class="tds-cluster">';
		echo tds_theme_button( isset( $args['label'] ) ? $args['label'] : __( 'Acessar o app TDS', 'tds-portal' ), $url, isset( $args['variant'] ) ? $args['variant'] : 'accent', array( 'rel' => 'noopener', 'data-tds-action' => 'app-access', 'data-tds-event' => 'app_access_click' ) ); // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
		echo '<span class="tds-footer__note">' . esc_html__( 'Canal oficial configurado pela equipe do programa.', 'tds-portal' ) . '</span>';
		echo '</div>';
	} else {
		tds_theme_state_notice(
			$state,
			array(
				'title' => __( 'Acesso ao app em configuração', 'tds-portal' ),
				'text'  => __( 'O link oficial de acesso será publicado aqui quando estiver disponível. Desconfie de links recebidos por outros canais.', 'tds-portal' ),
			)
		);
	}
	echo '</div>';
}

function tds_theme_course_card( array $course ) {
	$title = isset( $course['title'] ) ? $course['title'] : '';
	$cover = isset( $course['cover_public_url'] ) ? $course['cover_public_url'] : '';
	echo '<article class="tds-card" data-tds-course="' . esc_attr( isset( $course['slug'] ) ? $course['slug'] : '' ) . '">';
	if ( '' !== $cover ) {
		echo '<div class="tds-card__media"><img src="' . esc_url( $cover ) . '" alt="" loading="lazy" decoding="async" width="640" height="360"></div>';
	} else {
		echo '<div class="tds-card__media tds-card__media--placeholder" aria-hidden="true"><img src="' . esc_url( tds_theme_logo_url( true ) ) . '" alt="" loading="lazy" decoding="async" width="135" height="120"></div>';
	}
	echo '<div class="tds-card__body">';
	if ( ! empty( $course['published_version_label'] ) ) {
		echo '<span class="tds-badge tds-badge--success">' . esc_html( $course['published_version_label'] ) . '</span>';
	}
	echo '<h3 class="tds-card__title">' . esc_html( $title ) . '</h3>';
	if ( ! empty( $course['summary'] ) ) {
		echo '<p class="tds-card__text">' . esc_html( $course['summary'] ) . '</p>';
	}
	$meta = array();
	if ( ! empty( $course['public_workload_text'] ) ) {
		$meta[] = '<li><span class="tds-screen-reader-text">' . esc_html__( 'Carga horária:', 'tds-portal' ) . ' </span>' . esc_html( $course['public_workload_text'] ) . '</li>';
	}
	if ( ! empty( $course['public_audience_text'] ) ) {
		$meta[] = '<li><span class="tds-screen-reader-text">' . esc_html__( 'Público:', 'tds-portal' ) . ' </span>' . esc_html( $course['public_audience_text'] ) . '</li>';
	}
	if ( $meta ) {
		echo '<ul class="tds-card__meta">' . implode( '', $meta ) . '</ul>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped above
	}
	echo '</div></article>';
}

/** Catálogo público: grade quando ready, estados nos demais casos. */
function tds_theme_catalog( $per_page = 6 ) {
	$catalog = tds_theme_public_catalog( $per_page );
	$state = $catalog['state'];
	echo '<div class="tds-catalog" data-tds-component="catalog" data-tds-state="' . esc_attr( $state ) . '">';
	if ( 'ready' === $state && count( $catalog['courses'] ) > 0 ) {
		echo '<div class="tds-grid">';
		foreach ( $catalog['courses'] as $course ) {
			if ( is_array( $course ) ) {
				tds_theme_course_card( $course );
			}
		}
		echo '</div>';
	} elseif ( 'ready' === $state ) {
		tds_theme_state_notice( 'empty', array( 'title' => __( 'Nenhum curso publicado no momento', 'tds-portal' ), 'text' => __( 'Novas ofertas aparecerão aqui assim que forem publicadas pela equipe pedagógica.', 'tds-portal' ) ) );
	} elseif ( 'error' === $state ) {
		tds_theme_state_notice( 'error', array( 'title' => __( 'Não foi possível carregar o catálogo', 'tds-portal' ) ) );
	} else {
		tds_theme_state_notice( $state, array( 'title' => __( 'Catálogo indisponível temporariamente', 'tds-portal' ), 'text' => __( 'O catálogo de cursos é publicado pela plataforma Tutor TDS e ainda não está conectado a este portal.', 'tds-portal' ) ) );
	}
	echo '</div>';
}

function tds_theme_page_hero( $args = array() ) {
	$eyebrow = isset( $args['eyebrow'] ) ? $args['eyebrow'] : '';
	$title = isset( $args['title'] ) ? $args['title'] : get_the_title();
	$lead = isset( $args['lead'] ) ? $args['lead'] : ( has_excerpt() ? get_the_excerpt() : '' );
	echo '<header class="tds-page-header"><div class="tds-container tds-container--narrow">';
	if ( '' !== $eyebrow ) {
		echo '<p class="tds-eyebrow">' . esc_html( $eyebrow ) . '</p>';
	}
	echo '<h1 class="tds-page-header__title">' . esc_html( $title ) . '</h1>';
	if ( '' !== $lead ) {
		echo '<p class="tds-lead">' . esc_html( wp_strip_all_tags( $lead ) ) . '</p>';
	}
	if ( ! empty( $args['show_modified'] ) ) {
		echo '<p class="tds-page-header__meta">' . esc_html( sprintf( /* translators: %s: date */ __( 'Última atualização: %s', 'tds-portal' ), get_the_modified_date() ) ) . '</p>';
	}
	echo '</div></header>';
}

function tds_theme_post_card( $post_id, $heading_level = 2, $event = '' ) {
	$has_thumb     = has_post_thumbnail( $post_id );
	$heading_level = 3 === (int) $heading_level ? 3 : 2;
	echo '<article class="tds-card tds-card--link">';
	if ( $has_thumb ) {
		echo '<div class="tds-card__media">' . get_the_post_thumbnail( $post_id, 'medium_large', array( 'loading' => 'lazy', 'decoding' => 'async' ) ) . '</div>';
	}
	echo '<div class="tds-card__body">';
	echo '<ul class="tds-card__meta"><li><time datetime="' . esc_attr( get_the_date( DATE_W3C, $post_id ) ) . '">' . esc_html( get_the_date( '', $post_id ) ) . '</time></li></ul>';
	$event_attrs = function_exists( 'tds_theme_event_attributes' ) ? tds_theme_event_attributes( $event, get_post_field( 'post_name', $post_id ) ) : '';
	echo '<h' . esc_attr( (string) $heading_level ) . ' class="tds-card__title"><a href="' . esc_url( get_permalink( $post_id ) ) . '"' . $event_attrs . '>' . esc_html( get_the_title( $post_id ) ) . '</a></h' . esc_attr( (string) $heading_level ) . '>'; // phpcs:ignore WordPress.Security.EscapeOutput -- event helper escapes allowlisted attributes.
	echo '<p class="tds-card__text">' . esc_html( wp_trim_words( get_the_excerpt( $post_id ), 28 ) ) . '</p>';
	echo '</div></article>';
}

function tds_theme_shortcode_app_access( $atts ) {
	$atts = shortcode_atts( array( 'label' => '', 'variant' => 'accent' ), $atts, 'tds_acesso_app' );
	$args = array( 'variant' => $atts['variant'] );
	if ( '' !== $atts['label'] ) {
		$args['label'] = $atts['label'];
	}
	ob_start();
	tds_theme_app_access( $args );
	return ob_get_clean();
}

function tds_theme_shortcode_catalog( $atts ) {
	$atts = shortcode_atts( array( 'quantidade' => 6 ), $atts, 'tds_catalogo' );
	ob_start();
	tds_theme_catalog( (int) $atts['quantidade'] );
	return ob_get_clean();
}

function tds_theme_shortcode_state( $atts ) {
	$atts = shortcode_atts( array( 'estado' => 'unavailable', 'titulo' => '', 'texto' => '' ), $atts, 'tds_estado' );
	$args = array();
	if ( '' !== $atts['titulo'] ) {
		$args['title'] = $atts['titulo'];
	}
	if ( '' !== $atts['texto'] ) {
		$args['text'] = $atts['texto'];
	}
	ob_start();
	tds_theme_state_notice( $atts['estado'], $args );
	return ob_get_clean();
}
