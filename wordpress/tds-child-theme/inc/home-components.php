<?php
/**
 * Componentes da Home pública (WP-3 / Issue #43).
 *
 * Este arquivo não cria autoridade acadêmica, opções, endpoints ou CPTs.
 * Fontes editoriais futuras entram por filtros explícitos e falham fechadas.
 */

defined( 'ABSPATH' ) || exit;

/** Valida links públicos fornecidos por adapters/filtros do tema. Não faz request. */
function tds_theme_public_https_url( $value ) {
	if ( ! is_string( $value ) || '' === trim( $value ) ) {
		return '';
	}

	$url   = esc_url_raw( trim( $value ) );
	$parts = wp_parse_url( $url );
	if (
		'' === $url ||
		! is_array( $parts ) ||
		! isset( $parts['scheme'], $parts['host'] ) ||
		'https' !== strtolower( $parts['scheme'] ) ||
		'' === $parts['host'] ||
		isset( $parts['user'] ) ||
		isset( $parts['pass'] )
	) {
		return '';
	}

	return $url;
}

final class TDS_Theme_Portal_Stats_Provider {
	const MAX_ITEMS = 6;

	public static function get() {
		$raw = apply_filters( 'tds_portal_public_stats', array() );
		if ( ! is_array( $raw ) ) {
			return array();
		}

		$items = array();
		foreach ( $raw as $item ) {
			if ( ! is_array( $item ) ) {
				continue;
			}

			$label          = isset( $item['label'] ) ? sanitize_text_field( $item['label'] ) : '';
			$value          = isset( $item['value'] ) ? sanitize_text_field( $item['value'] ) : '';
			$source_label   = isset( $item['source_label'] ) ? sanitize_text_field( $item['source_label'] ) : '';
			$raw_source_url = isset( $item['source_url'] ) && is_string( $item['source_url'] ) ? trim( $item['source_url'] ) : '';
			$source_url     = tds_theme_public_https_url( $raw_source_url );

			if ( '' === $label || '' === $value || '' === $source_label ) {
				continue;
			}
			if ( '' !== $raw_source_url && '' === $source_url ) {
				continue;
			}

			$items[] = array(
				'label'        => $label,
				'value'        => $value,
				'source_label' => $source_label,
				'source_url'   => $source_url,
			);
			if ( count( $items ) >= self::MAX_ITEMS ) {
				break;
			}
		}

		return $items;
	}
}

/** Data attributes permitidos para um adapter de analytics futuro. Não envia rede. */
function tds_theme_event_attributes( $event, $public_slug = '' ) {
	$allowed = array(
		'portal_home_view',
		'course_card_click',
		'app_access_click',
		'tool_card_click',
		'news_click',
		'event_click',
		'material_click',
		'support_cta_click',
		'certificate_verify_cta_click',
	);
	if ( ! in_array( $event, $allowed, true ) ) {
		return '';
	}

	$html = ' data-tds-event="' . esc_attr( $event ) . '"';
	$slug = sanitize_title( $public_slug );
	if ( '' !== $slug ) {
		$html .= ' data-tds-public-slug="' . esc_attr( $slug ) . '"';
	}
	return $html;
}

function tds_theme_home_block_attributes( $order, $slug ) {
	return ' data-tds-home-block="' . esc_attr( sanitize_key( $slug ) ) . '" data-tds-home-order="' . esc_attr( (string) (int) $order ) . '"';
}

function tds_theme_home_collection( $filter, $event = '', $show_state_badge = false ) {
	$payload = apply_filters(
		$filter,
		array(
			'state' => 'unavailable',
			'items' => array(),
		)
	);
	$remote_states = array( 'loading', 'success', 'empty', 'stale', 'unavailable' );

	if ( is_array( $payload ) && array_key_exists( 'state', $payload ) ) {
		$state = in_array( $payload['state'], $remote_states, true ) ? $payload['state'] : 'unavailable';
		$raw   = isset( $payload['items'] ) && is_array( $payload['items'] ) ? $payload['items'] : array();
	} else {
		// Compatibilidade temporária com providers WP-3 que retornam somente a lista.
		$raw   = is_array( $payload ) ? $payload : array();
		$state = $raw ? 'success' : 'unavailable';
	}

	echo '<div class="tds-home-collection" data-tds-component="' . esc_attr( sanitize_key( $filter ) ) . '" data-tds-state="' . esc_attr( $state ) . '">';

	if ( 'loading' === $state || 'unavailable' === $state ) {
		tds_theme_state_notice( $state );
		echo '</div>';
		return;
	}
	if ( 'empty' === $state || ! $raw ) {
		tds_theme_state_notice( 'empty' );
		echo '</div>';
		return;
	}
	if ( 'stale' === $state ) {
		tds_theme_state_notice( 'stale' );
	}

	$allowed_states = array( 'available', 'coming_soon', 'restricted', 'hidden' );
	$rendered       = 0;
	echo '<div class="tds-grid">';
	foreach ( $raw as $item ) {
		if ( ! is_array( $item ) ) {
			continue;
		}
		$state = isset( $item['state'] ) && in_array( $item['state'], $allowed_states, true ) ? $item['state'] : 'available';
		if ( 'hidden' === $state ) {
			continue;
		}

		$title = isset( $item['title'] ) ? sanitize_text_field( $item['title'] ) : '';
		$text  = isset( $item['text'] ) ? sanitize_text_field( $item['text'] ) : '';
		$url   = isset( $item['url'] ) ? tds_theme_public_https_url( $item['url'] ) : '';
		$slug  = isset( $item['slug'] ) ? sanitize_title( $item['slug'] ) : '';
		if ( '' === $title ) {
			continue;
		}

		$state_attr = ' data-tds-item-state="' . esc_attr( $state ) . '"';
		if ( $show_state_badge ) {
			$state_attr .= ' data-tds-tool-state="' . esc_attr( $state ) . '"';
		}
		echo '<article class="tds-card tds-home-card"' . $state_attr . '>'; // phpcs:ignore WordPress.Security.EscapeOutput -- composed from escaped constants.
		echo '<div class="tds-card__body">';
		if ( $show_state_badge ) {
			echo '<span class="tds-badge">' . esc_html( tds_theme_tool_state_label( $state ) ) . '</span>';
		}
		echo '<h3 class="tds-card__title">' . esc_html( $title ) . '</h3>';
		if ( '' !== $text ) {
			echo '<p class="tds-card__text">' . esc_html( $text ) . '</p>';
		}
		if ( 'available' === $state && '' !== $url ) {
			echo '<a class="tds-card__link" href="' . esc_url( $url ) . '"' . tds_theme_event_attributes( $event, $slug ) . '>' . esc_html__( 'Saiba mais', 'tds-portal' ) . '</a>'; // phpcs:ignore WordPress.Security.EscapeOutput -- helper escapes attributes.
		}
		echo '</div></article>';
		$rendered++;
	}
	echo '</div>';

	if ( 0 === $rendered ) {
		tds_theme_state_notice( 'empty' );
	}
	echo '</div>';
}
function tds_theme_tool_state_label( $state ) {
	$labels = array(
		'available'   => __( 'Disponível', 'tds-portal' ),
		'coming_soon' => __( 'Em preparação', 'tds-portal' ),
		'restricted'  => __( 'Acesso restrito', 'tds-portal' ),
		'hidden'      => __( 'Oculto', 'tds-portal' ),
	);
	return isset( $labels[ $state ] ) ? $labels[ $state ] : $labels['available'];
}

function tds_theme_home_journey() {
	$steps = array(
		array(
			'title' => __( 'Conheça as formações publicadas', 'tds-portal' ),
			'text'  => __( 'O portal apresenta informações públicas; a plataforma acadêmica continua separada.', 'tds-portal' ),
		),
		array(
			'title' => __( 'Acesse pelo canal oficial', 'tds-portal' ),
			'text'  => __( 'Participantes entram no Tutor TDS pelo acesso configurado oficialmente pelo programa.', 'tds-portal' ),
		),
		array(
			'title' => __( 'Estude e acompanhe sua jornada', 'tds-portal' ),
			'text'  => __( 'Atividades, conteúdos e informações pessoais permanecem no aplicativo e na API autorizada.', 'tds-portal' ),
		),
		array(
			'title' => __( 'Use os registros oficiais', 'tds-portal' ),
			'text'  => __( 'Matrícula, frequência e certificados não são calculados nem alterados por este portal público.', 'tds-portal' ),
		),
	);

	echo '<ol class="tds-journey" aria-label="' . esc_attr__( 'Como o portal se conecta à jornada TDS', 'tds-portal' ) . '">';
	foreach ( $steps as $index => $step ) {
		echo '<li class="tds-journey__item">';
		echo '<span class="tds-journey__number" aria-hidden="true">' . esc_html( (string) ( $index + 1 ) ) . '</span>';
		echo '<div><h3>' . esc_html( $step['title'] ) . '</h3><p>' . esc_html( $step['text'] ) . '</p></div>';
		echo '</li>';
	}
	echo '</ol>';
}

function tds_theme_portal_stats( $items = null ) {
	$items = is_array( $items ) ? $items : TDS_Theme_Portal_Stats_Provider::get();
	if ( ! $items ) {
		return false;
	}

	echo '<div class="tds-stats" data-tds-component="public-stats" data-tds-state="success">';
	foreach ( $items as $item ) {
		echo '<article class="tds-stat">';
		echo '<p class="tds-stat__value">' . esc_html( $item['value'] ) . '</p>';
		echo '<h3 class="tds-stat__label">' . esc_html( $item['label'] ) . '</h3>';
		echo '<p class="tds-stat__source">';
		if ( '' !== $item['source_url'] ) {
			echo '<a href="' . esc_url( $item['source_url'] ) . '" rel="noopener">' . esc_html( $item['source_label'] ) . '</a>';
		} else {
			echo esc_html( $item['source_label'] );
		}
		echo '</p></article>';
	}
	echo '</div>';
	return true;
}

function tds_theme_certificate_cta() {
	$url = tds_theme_public_https_url( apply_filters( 'tds_portal_certificate_verify_url', '' ) );
	echo '<div class="tds-service-cta" data-tds-component="certificate-verify">';
	if ( '' === $url ) {
		tds_theme_state_notice(
			'unavailable',
			array(
				'title' => __( 'Verificação oficial ainda não conectada', 'tds-portal' ),
				'text'  => __( 'O portal não emite nem aprova certificados. A consulta será exibida apenas quando o verificador oficial estiver configurado.', 'tds-portal' ),
			)
		);
	} else {
		echo tds_theme_button(
			__( 'Verificar certificado', 'tds-portal' ),
			$url,
			'outline',
			array(
				'rel'            => 'noopener',
				'data-tds-event' => 'certificate_verify_cta_click',
			)
		); // phpcs:ignore WordPress.Security.EscapeOutput -- button helper escapes attributes.
	}
	echo '</div>';
}

function tds_theme_support_cta() {
	$config = tds_theme_public_config();
	$state  = tds_theme_integration_state( 'support' );
	$url    = isset( $config['support_base_url'] ) && is_string( $config['support_base_url'] ) ? $config['support_base_url'] : '';

	echo '<div class="tds-service-cta" data-tds-component="support" data-tds-state="' . esc_attr( $state ) . '">';
	if ( 'ready' === $state && '' !== $url ) {
		echo tds_theme_button(
			__( 'Abrir suporte', 'tds-portal' ),
			$url,
			'outline',
			array(
				'rel'            => 'noopener',
				'data-tds-event' => 'support_cta_click',
			)
		); // phpcs:ignore WordPress.Security.EscapeOutput -- button helper escapes attributes.
	} else {
		tds_theme_state_notice(
			'disabled' === $state ? 'unavailable' : $state,
			array(
				'title' => __( 'Suporte público ainda não conectado', 'tds-portal' ),
				'text'  => __( 'Nenhuma conversa ou dado de contato é enviado enquanto o adapter oficial de suporte não estiver habilitado.', 'tds-portal' ),
			)
		);
	}
	echo '</div>';
}
