<?php
/**
 * Template Name: TDS — Direitos e exclusão de dados
 * Template Post Type: page
 *
 * O portal não recebe pedidos nem dados pessoais. Ele mostra instruções
 * públicas e aponta para o canal externo oficial de exclusão de conta.
 */

defined( 'ABSPATH' ) || exit;

get_header();
get_template_part(
	'template-parts/content',
	'page',
	array(
		'eyebrow'       => __( 'Seus dados, seus direitos', 'tds-portal' ),
		'show_modified' => true,
		'before'        => static function () {
			?>
			<section class="tds-legal-brand" aria-labelledby="tds-legal-brand-title">
				<div class="tds-legal-brand__identity">
					<img class="tds-legal-brand__mark" src="<?php echo esc_url( tds_theme_logo_url( true ) ); ?>" width="88" height="72" alt="" loading="eager" decoding="async">
					<div>
						<p class="tds-eyebrow"><?php esc_html_e( 'TDS — Territórios de Desenvolvimento Social e Inclusão Produtiva', 'tds-portal' ); ?></p>
						<h2 id="tds-legal-brand-title" class="tds-legal-brand__title"><?php esc_html_e( 'Capacitação que transforma territórios', 'tds-portal' ); ?></h2>
						<p class="tds-legal-brand__text"><?php esc_html_e( 'Programa voltado à promoção do desenvolvimento social e à inclusão produtiva nos territórios do Tocantins.', 'tds-portal' ); ?></p>
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
			$deletion_url = 'https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html';
			?>
			<section class="tds-prose" aria-labelledby="tds-account-deletion">
				<h2 id="tds-account-deletion"><?php esc_html_e( 'Como excluir sua conta', 'tds-portal' ); ?></h2>

				<h3><?php esc_html_e( 'Dentro do aplicativo', 'tds-portal' ); ?></h3>
				<ol>
					<li><?php esc_html_e( 'Entre na sua conta Tutor TDS.', 'tds-portal' ); ?></li>
					<li><?php esc_html_e( 'Abra Configurações.', 'tds-portal' ); ?></li>
					<li><?php esc_html_e( 'Na seção Privacidade, escolha Excluir conta e dados.', 'tds-portal' ); ?></li>
					<li><?php esc_html_e( 'Leia o aviso exibido pelo aplicativo e confirme a exclusão.', 'tds-portal' ); ?></li>
				</ol>

				<h3><?php esc_html_e( 'Fora do aplicativo', 'tds-portal' ); ?></h3>
				<p><?php esc_html_e( 'Use a página externa oficial de exclusão. Ela apresenta o canal de solicitação e as informações sobre exclusão e eventual retenção de dados.', 'tds-portal' ); ?></p>
				<p>
					<a class="tds-button tds-button--outline" href="<?php echo esc_url( $deletion_url ); ?>">
						<?php esc_html_e( 'Abrir página externa de exclusão', 'tds-portal' ); ?>
					</a>
				</p>
				<p><?php esc_html_e( 'Este portal WordPress não recebe a solicitação, não pede senha e não coleta documentos.', 'tds-portal' ); ?></p>
			</section>
			<?php
		},
	)
);
get_footer();
