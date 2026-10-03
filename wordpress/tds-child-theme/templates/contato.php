<?php
/**
 * Template Name: TDS — Contato
 * Template Post Type: page
 *
 * Sem formulário: contato institucional fica no conteúdo editorial e o
 * atendimento online depende do adapter de suporte (hoje desativado).
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part(
	'template-parts/content',
	'page',
	array(
		'eyebrow' => __( 'Fale com o programa', 'tds-portal' ),
		'after'   => static function () {
			echo '<h2>' . esc_html__( 'Atendimento online', 'tds-portal' ) . '</h2>';
			tds_theme_state_notice(
				tds_theme_integration_state( 'support' ),
				array(
					'title' => __( 'Atendimento online ainda não habilitado', 'tds-portal' ),
					'text'  => __( 'Quando o canal de suporte for ativado pela coordenação, o acesso aparecerá nesta página.', 'tds-portal' ),
				)
			);
		},
	)
);
get_footer();
