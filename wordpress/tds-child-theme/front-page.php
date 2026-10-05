<?php
/**
 * Home pública WP-3: 14 slots funcionais com degradação segura.
 *
 * Nenhum bloco cria matrícula, frequência, certificado ou dado acadêmico.
 * Slots sem fonte aprovada exibem estado explícito ou ficam ocultos (stats).
 */

defined( 'ABSPATH' ) || exit;

require_once get_stylesheet_directory() . '/inc/story-provider.php';

get_header();
$tds_static_home = is_page();
$tds_programa    = tds_theme_find_page_by_template( 'templates/programa.php' );
$tds_acessar     = tds_theme_find_page_by_template( 'templates/acessar.php' );
$tds_stats       = TDS_Theme_Portal_Stats_Provider::get();
?>
<main id="tds-main" class="tds-main" tabindex="-1" data-tds-event="portal_home_view">
	<section class="tds-hero" aria-labelledby="tds-hero-title"<?php echo tds_theme_home_block_attributes( 1, 'hero' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-hero__inner">
				<p class="tds-eyebrow"><?php esc_html_e( 'Territórios de Desenvolvimento Social e Inclusão Produtiva', 'tds-portal' ); ?></p>
				<h1 id="tds-hero-title" class="tds-hero__title"><?php echo esc_html( $tds_static_home && has_excerpt() ? get_the_title() : get_bloginfo( 'name', 'display' ) ); ?></h1>
				<p class="tds-hero__lead"><?php echo esc_html( $tds_static_home && has_excerpt() ? get_the_excerpt() : get_bloginfo( 'description', 'display' ) ); ?></p>
				<div class="tds-hero__actions">
					<?php
					if ( $tds_programa ) {
						echo tds_theme_button( __( 'Conhecer o programa', 'tds-portal' ), get_permalink( $tds_programa ), 'accent' ); // phpcs:ignore WordPress.Security.EscapeOutput
					}
					if ( $tds_acessar ) {
						echo tds_theme_button( __( 'Como acessar o app', 'tds-portal' ), get_permalink( $tds_acessar ), 'outline' ); // phpcs:ignore WordPress.Security.EscapeOutput
					}
					?>
				</div>
			</div>
			<?php if ( $tds_static_home && '' !== trim( get_post_field( 'post_content', get_the_ID() ) ) ) : ?>
				<div class="tds-home-editorial tds-prose">
					<?php
					while ( have_posts() ) :
						the_post();
						the_content();
					endwhile;
					?>
				</div>
			<?php endif; ?>
		</div>
	</section>

	<section class="tds-section tds-section--alt" aria-labelledby="tds-journey-title"<?php echo tds_theme_home_block_attributes( 2, 'journey' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Território', 'tds-portal' ); ?></p>
				<h2 id="tds-journey-title"><?php esc_html_e( 'Uma jornada que começa ouvindo o território', 'tds-portal' ); ?></h2>
				<p class="tds-lead"><?php esc_html_e( 'O TDS conecta escuta local, formação e acompanhamento para aproximar as ações de inclusão produtiva das realidades de cada território.', 'tds-portal' ); ?></p>
			</div>
			<?php tds_theme_home_journey(); ?>
		</div>
	</section>

	<section class="tds-section" aria-labelledby="tds-areas-title"<?php echo tds_theme_home_block_attributes( 3, 'areas' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Formação', 'tds-portal' ); ?></p>
				<h2 id="tds-areas-title"><?php esc_html_e( 'Formações conectadas às demandas locais', 'tds-portal' ); ?></h2>
				<p class="tds-lead"><?php esc_html_e( 'As áreas apresentadas aqui dependem de conteúdo editorial publicado e validado pelo programa.', 'tds-portal' ); ?></p>
			</div>
			<?php tds_theme_home_collection( 'tds_portal_home_areas' ); ?>
		</div>
	</section>

	<section class="tds-section tds-section--alt" aria-labelledby="tds-catalog-title"<?php echo tds_theme_home_block_attributes( 4, 'courses' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Cursos', 'tds-portal' ); ?></p>
				<h2 id="tds-catalog-title"><?php esc_html_e( 'Veja as formações publicadas pelo programa', 'tds-portal' ); ?></h2>
				<p class="tds-lead"><?php esc_html_e( 'O catálogo reúne somente cursos publicados pela fonte oficial. Dados pessoais, matrícula, frequência e certificação permanecem fora deste portal público.', 'tds-portal' ); ?></p>
			</div>
			<?php tds_theme_catalog( 6 ); ?>
		</div>
	</section>

	<section class="tds-section" aria-labelledby="tds-tools-title"<?php echo tds_theme_home_block_attributes( 5, 'tools' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Tecnologia', 'tds-portal' ); ?></p>
				<h2 id="tds-tools-title"><?php esc_html_e( 'Tecnologia como meio, não como fim', 'tds-portal' ); ?></h2>
				<p class="tds-lead"><?php esc_html_e( 'Aplicativo, materiais e canais digitais apoiam a jornada. O foco permanece nas formações, nas pessoas e nos territórios.', 'tds-portal' ); ?></p>
			</div>
			<?php tds_theme_home_collection( 'tds_portal_home_tools', 'tool_card_click', true ); ?>
		</div>
	</section>

	<?php if ( $tds_stats ) : ?>
		<section class="tds-section tds-section--dark" aria-labelledby="tds-stats-title"<?php echo tds_theme_home_block_attributes( 6, 'stats' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
			<div class="tds-container">
				<div class="tds-section-header">
					<p class="tds-eyebrow"><?php esc_html_e( 'Evidências', 'tds-portal' ); ?></p>
					<h2 id="tds-stats-title"><?php esc_html_e( 'Resultados que podem ser verificados', 'tds-portal' ); ?></h2>
					<p class="tds-lead"><?php esc_html_e( 'O portal só apresenta números quando a fonte pública e a proveniência estão identificadas.', 'tds-portal' ); ?></p>
				</div>
				<?php tds_theme_portal_stats( $tds_stats ); ?>
			</div>
		</section>
	<?php endif; ?>

	<section class="tds-section" aria-labelledby="tds-stories-title"<?php echo tds_theme_home_block_attributes( 7, 'stories' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Territórios', 'tds-portal' ); ?></p>
				<h2 id="tds-stories-title"><?php esc_html_e( 'Ações e experiências que ajudam a contar o programa', 'tds-portal' ); ?></h2>
				<p class="tds-lead"><?php esc_html_e( 'Histórias entram no portal somente quando houver fonte editorial adequada e autorização para os registros utilizados.', 'tds-portal' ); ?></p>
			</div>
			<?php tds_theme_home_collection( 'tds_portal_home_stories' ); ?>
		</div>
	</section>

	<?php $tds_news = new WP_Query( array( 'post_type' => 'post', 'posts_per_page' => 3, 'ignore_sticky_posts' => true, 'no_found_rows' => true ) ); ?>
	<section class="tds-section tds-section--alt" aria-labelledby="tds-news-title"<?php echo tds_theme_home_block_attributes( 8, 'news' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Ações recentes', 'tds-portal' ); ?></p>
				<h2 id="tds-news-title"><?php esc_html_e( 'O que está acontecendo no TDS', 'tds-portal' ); ?></h2>
			</div>
			<?php if ( $tds_news->have_posts() ) : ?>
				<div class="tds-post-list">
					<?php
					while ( $tds_news->have_posts() ) :
						$tds_news->the_post();
						tds_theme_post_card( get_the_ID(), 3, 'news_click' );
					endwhile;
					wp_reset_postdata();
					?>
				</div>
			<?php else : ?>
				<?php tds_theme_state_notice( 'empty', array( 'title' => __( 'Nenhuma notícia publicada ainda', 'tds-portal' ) ) ); ?>
			<?php endif; ?>
		</div>
	</section>

	<section class="tds-section" aria-labelledby="tds-agenda-title"<?php echo tds_theme_home_block_attributes( 9, 'agenda' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header"><p class="tds-eyebrow"><?php esc_html_e( 'Agenda', 'tds-portal' ); ?></p><h2 id="tds-agenda-title"><?php esc_html_e( 'Próximas ações e encontros públicos', 'tds-portal' ); ?></h2></div>
			<?php tds_theme_home_collection( 'tds_portal_home_events', 'event_click' ); ?>
		</div>
	</section>

	<section class="tds-section tds-section--alt" aria-labelledby="tds-library-title"<?php echo tds_theme_home_block_attributes( 10, 'library' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header"><p class="tds-eyebrow"><?php esc_html_e( 'Biblioteca', 'tds-portal' ); ?></p><h2 id="tds-library-title"><?php esc_html_e( 'Materiais para acompanhar e aprofundar', 'tds-portal' ); ?></h2></div>
			<?php tds_theme_home_collection( 'tds_portal_home_materials', 'material_click' ); ?>
		</div>
	</section>

	<section class="tds-section" aria-labelledby="tds-partners-title"<?php echo tds_theme_home_block_attributes( 11, 'partners' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header"><p class="tds-eyebrow"><?php esc_html_e( 'Cooperação', 'tds-portal' ); ?></p><h2 id="tds-partners-title"><?php esc_html_e( 'Uma rede construída com instituições e territórios', 'tds-portal' ); ?></h2><p class="tds-lead"><?php esc_html_e( 'Parceiros aparecem somente quando houver publicação institucional aprovada.', 'tds-portal' ); ?></p></div>
			<?php tds_theme_home_collection( 'tds_portal_home_partners' ); ?>
		</div>
	</section>

	<section class="tds-section tds-section--dark" aria-labelledby="tds-access-title"<?php echo tds_theme_home_block_attributes( 12, 'app-access' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header">
				<p class="tds-eyebrow"><?php esc_html_e( 'Continuidade', 'tds-portal' ); ?></p>
				<h2 id="tds-access-title"><?php esc_html_e( 'Continue sua jornada no Tutor TDS', 'tds-portal' ); ?></h2>
				<p class="tds-lead"><?php esc_html_e( 'O aplicativo complementa as formações e concentra a experiência autenticada de participantes e equipe.', 'tds-portal' ); ?></p>
			</div>
			<?php tds_theme_app_access(); ?>
		</div>
	</section>

	<section class="tds-section" aria-labelledby="tds-certificate-title"<?php echo tds_theme_home_block_attributes( 13, 'certificate' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header"><p class="tds-eyebrow"><?php esc_html_e( 'Certificados', 'tds-portal' ); ?></p><h2 id="tds-certificate-title"><?php esc_html_e( 'Consulte certificados pelo canal oficial', 'tds-portal' ); ?></h2></div>
			<?php tds_theme_certificate_cta(); ?>
		</div>
	</section>

	<section class="tds-section tds-section--alt" aria-labelledby="tds-support-title"<?php echo tds_theme_home_block_attributes( 14, 'support' ); // phpcs:ignore WordPress.Security.EscapeOutput ?>>
		<div class="tds-container">
			<div class="tds-section-header"><p class="tds-eyebrow"><?php esc_html_e( 'Acompanhamento', 'tds-portal' ); ?></p><h2 id="tds-support-title"><?php esc_html_e( 'Precisa de orientação?', 'tds-portal' ); ?></h2><p class="tds-lead"><?php esc_html_e( 'O suporte público orienta o próximo passo sem expor informações acadêmicas no portal.', 'tds-portal' ); ?></p></div>
			<?php tds_theme_support_cta(); ?>
		</div>
	</section>
</main>
<?php
get_footer();
