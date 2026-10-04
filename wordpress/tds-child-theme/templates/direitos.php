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
