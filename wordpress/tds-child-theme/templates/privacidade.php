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
