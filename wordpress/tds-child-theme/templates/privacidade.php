<?php
/**
 * Template Name: TDS — Privacidade
 * Template Post Type: page
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part(
	'template-parts/content',
	'page',
	array(
		'eyebrow'       => __( 'Política de privacidade', 'tds-portal' ),
		'show_modified' => true,
		'before'        => static function () {
			?>
			<section class="tds-legal-brand" aria-labelledby="tds-legal-brand-title">
				<div class="tds-legal-brand__identity">
					<img class="tds-legal-brand__mark" src="<?php echo esc_url( tds_theme_logo_url( true ) ); ?>" width="88" height="72" alt="" loading="eager" decoding="async">
					<div>
						<p class="tds-eyebrow"><?php esc_html_e( 'TDS — Territórios de Desenvolvimento Social e Inclusão Produtiva', 'tds-portal' ); ?></p>
						<h2 id="tds-legal-brand-title" class="tds-legal-brand__title"><?php esc_html_e( 'Capacitação que transforma territórios', 'tds-portal' ); ?></h2>
						<p class="tds-legal-brand__text"><?php esc_html_e( 'Inclusão produtiva para quem mais precisa.', 'tds-portal' ); ?></p>
					</div>
				</div>
				<ul class="tds-legal-brand__attributes" aria-label="<?php esc_attr_e( 'Atributos da marca TDS', 'tds-portal' ); ?>">
					<li class="tds-legal-brand__attribute tds-legal-brand__attribute--territory"><strong><?php esc_html_e( 'Território', 'tds-portal' ); ?></strong><span><?php esc_html_e( 'Tocantins como identidade geográfica central.', 'tds-portal' ); ?></span></li>
					<li class="tds-legal-brand__attribute tds-legal-brand__attribute--diversity"><strong><?php esc_html_e( 'Diversidade', 'tds-portal' ); ?></strong><span><?php esc_html_e( 'Pluralidade de pessoas e realidades sociais.', 'tds-portal' ); ?></span></li>
					<li class="tds-legal-brand__attribute tds-legal-brand__attribute--development"><strong><?php esc_html_e( 'Desenvolvimento', 'tds-portal' ); ?></strong><span><?php esc_html_e( 'Solidez institucional e progresso.', 'tds-portal' ); ?></span></li>
				</ul>
			</section>
			<?php
		},
		'after'         => static function () {
			$privacy_url = 'https://cartilhas.ipexdesenvolvimento.cloud/privacy.html';
			?>
			<section class="tds-prose" aria-labelledby="tds-privacy-official">
				<h2 id="tds-privacy-official"><?php esc_html_e( 'Versão pública oficial', 'tds-portal' ); ?></h2>
				<p><?php esc_html_e( 'Para consultar a Política de Privacidade completa publicada para o Tutor TDS, use o endereço oficial abaixo. Esta página do WordPress não solicita login nem coleta dados pessoais.', 'tds-portal' ); ?></p>
				<p>
					<a class="tds-button tds-button--outline" href="<?php echo esc_url( $privacy_url ); ?>">
						<?php esc_html_e( 'Abrir Política de Privacidade', 'tds-portal' ); ?>
					</a>
				</p>
			</section>
			<?php
		},
	)
);
get_footer();
