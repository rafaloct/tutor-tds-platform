<?php
/** Listagem compartilhada por index.php, archive.php e search.php. */

defined( 'ABSPATH' ) || exit;
?>
<main id="tds-main" class="tds-main" tabindex="-1">
	<header class="tds-page-header">
		<div class="tds-container">
			<p class="tds-eyebrow"><?php esc_html_e( 'Notícias', 'tds-portal' ); ?></p>
			<h1 class="tds-page-header__title">
				<?php
				if ( is_search() ) {
					/* translators: %s: search query */
					echo esc_html( sprintf( __( 'Resultados para “%s”', 'tds-portal' ), get_search_query() ) );
				} elseif ( is_archive() ) {
					echo esc_html( wp_strip_all_tags( get_the_archive_title() ) );
				} else {
					echo esc_html( is_home() && get_option( 'page_for_posts' ) ? get_the_title( (int) get_option( 'page_for_posts' ) ) : __( 'Notícias do programa', 'tds-portal' ) );
				}
				?>
			</h1>
			<?php if ( is_search() ) : ?>
				<?php get_search_form(); ?>
			<?php endif; ?>
		</div>
	</header>
	<div class="tds-content">
		<div class="tds-container">
			<?php if ( have_posts() ) : ?>
				<div class="tds-post-list">
					<?php
					while ( have_posts() ) :
						the_post();
						tds_theme_post_card( get_the_ID() );
					endwhile;
					?>
				</div>
				<?php
				the_posts_pagination(
					array(
						'class'              => 'tds-pagination',
						'screen_reader_text' => __( 'Paginação das notícias', 'tds-portal' ),
						'prev_text'          => __( 'Anterior', 'tds-portal' ),
						'next_text'          => __( 'Próxima', 'tds-portal' ),
					)
				);
			else :
				tds_theme_state_notice( 'empty', array( 'title' => is_search() ? __( 'Nenhum resultado encontrado', 'tds-portal' ) : __( 'Nenhuma notícia publicada ainda', 'tds-portal' ) ) );
			endif;
			?>
		</div>
	</div>
</main>
<?php
