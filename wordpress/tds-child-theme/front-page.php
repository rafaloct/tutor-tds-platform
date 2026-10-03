<?php
/**
 * Home do portal: hero institucional, acesso ao app, catálogo público
 * (estado real do contrato), notícias recentes e conteúdo editorial opcional.
 */

defined( 'ABSPATH' ) || exit;

get_header();
$tds_static_home = is_page();
$tds_programa = tds_theme_find_page_by_template( 'templates/programa.php' );
$tds_acessar = tds_theme_find_page_by_template( 'templates/acessar.php' );
?>
<main id="tds-main" class="tds-main" tabindex="-1">
	<section class="tds-hero" aria-labelledby="tds-hero-title">
		<div class="tds-container">
			<div class="tds-hero__inner">
				<p class="tds-eyebrow"><?php esc_html_e( 'Programa TDS', 'tds-portal' ); ?></p>
				<h1 id="tds-hero-title" class="tds-hero__title"><?php echo esc_html( $tds_static_home && has_excerpt() ? get_the_title() : get_bloginfo( 'name', 'display' ) ); ?></h1>
				<p class="tds-hero__lead"><?php echo esc_html( $tds_static_home && has_excerpt() ? get_the_excerpt() : get_bloginfo( 'description', 'display' ) ); ?></p>
				<div class="tds-hero__actions">
					<?php
					if ( $tds_programa ) {
						echo tds_theme_button( __( 'Conhecer o programa', 'tds-portal' ), get_permalink( $tds_programa ), 'accent' ); // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
					}
					if ( $tds_acessar ) {
						echo tds_theme_button( __( 'Como acessar o app', 'tds-portal' ), get_permalink( $tds_acessar ), 'outline' ); // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
					}
					?>
				</div>
			</div>
		</div>
	</section>

	<?php if ( $tds_static_home && '' !== trim( get_post_field( 'post_content', get_the_ID() ) ) ) : ?>
		<section class="tds-section tds-section--alt" aria-label="<?php esc_attr_e( 'Destaques editoriais', 'tds-portal' ); ?>">
			<div class="tds-container">
				<div class="tds-prose" style="max-width:none">
					<?php
					while ( have_posts() ) :
						the_post();
						the_content();
					endwhile;
					?>
				</div>
			</div>
		</section>
	<?php endif; ?>

	<section class="tds-section" aria-labelledby="tds-catalog-title">
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Cursos', 'tds-portal' ); ?></p>
				<h2 id="tds-catalog-title"><?php esc_html_e( 'Catálogo público', 'tds-portal' ); ?></h2>
				<p class="tds-lead"><?php esc_html_e( 'Ofertas publicadas pela plataforma Tutor TDS. Inscrição, frequência e certificado acontecem apenas no app oficial.', 'tds-portal' ); ?></p>
			</div>
			<?php tds_theme_catalog( 6 ); ?>
		</div>
	</section>

	<section class="tds-section tds-section--dark" aria-labelledby="tds-access-title">
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Acesso', 'tds-portal' ); ?></p>
				<h2 id="tds-access-title"><?php esc_html_e( 'Entre no app oficial', 'tds-portal' ); ?></h2>
				<p class="tds-lead"><?php esc_html_e( 'O acesso de participantes e equipe é feito pelo aplicativo Tutor TDS, com o canal oficial configurado pela coordenação.', 'tds-portal' ); ?></p>
			</div>
			<?php tds_theme_app_access(); ?>
		</div>
	</section>

	<?php
	$tds_news = new WP_Query( array( 'post_type' => 'post', 'posts_per_page' => 3, 'ignore_sticky_posts' => true, 'no_found_rows' => true ) );
	?>
	<section class="tds-section" aria-labelledby="tds-news-title">
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Notícias', 'tds-portal' ); ?></p>
				<h2 id="tds-news-title"><?php esc_html_e( 'Últimas do programa', 'tds-portal' ); ?></h2>
			</div>
			<?php if ( $tds_news->have_posts() ) : ?>
				<div class="tds-post-list">
					<?php
					while ( $tds_news->have_posts() ) :
						$tds_news->the_post();
						tds_theme_post_card( get_the_ID() );
					endwhile;
					wp_reset_postdata();
					?>
				</div>
			<?php else : ?>
				<?php tds_theme_state_notice( 'empty', array( 'title' => __( 'Nenhuma notícia publicada ainda', 'tds-portal' ), 'text' => __( 'A equipe editorial publica novidades por aqui sem precisar de atualização do app.', 'tds-portal' ) ) ); ?>
			<?php endif; ?>
		</div>
	</section>
</main>
<?php
get_footer();
