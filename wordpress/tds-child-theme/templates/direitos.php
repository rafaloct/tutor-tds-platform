<?php
/**
 * Template Name: TDS — Direitos e exclusão de dados
 * Template Post Type: page
 *
 * O portal não coleta pedidos nem dados pessoais: apenas orienta e aponta
 * para o canal oficial quando o plugin o declarar disponível.
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part(
	'template-parts/content',
	'page',
	array(
		'eyebrow'       => __( 'Seus dados, seus direitos', 'tds-portal' ),
		'show_modified' => true,
		'after'         => static function () {
			echo '<h2>' . esc_html__( 'Como solicitar', 'tds-portal' ) . '</h2>';
			tds_theme_state_notice(
				tds_theme_integration_state( 'support' ),
				array(
					'title' => __( 'Canal de solicitação em configuração', 'tds-portal' ),
					'text'  => __( 'Pedidos de acesso, correção ou exclusão de dados serão recebidos pelo canal oficial de atendimento, publicado aqui quando estiver ativo. Este portal não coleta dados pessoais.', 'tds-portal' ),
				)
			);
		},
	)
);
get_footer();
