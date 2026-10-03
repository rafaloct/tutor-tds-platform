<?php
/** Notícia individual. */

defined( 'ABSPATH' ) || exit;

get_header();
?>
<main id="tds-main" class="tds-main" tabindex="-1">
	<?php
	while ( have_posts() ) :
		the_post();
		$categories = get_the_category();
		tds_theme_page_hero(
			array(
				'eyebrow'       => $categories ? $categories[0]->name : __( 'Notícia', 'tds-portal' ),
				'show_modified' => false,
			)
		);
		?>
		<article <?php post_class( 'tds-content' ); ?>>
			<div class="tds-container tds-container--narrow">
				<p class="tds-page-header__meta"><time datetime="<?php echo esc_attr( get_the_date( DATE_W3C ) ); ?>"><?php echo esc_html( get_the_date() ); ?></time></p>
				<?php if ( has_post_thumbnail() ) : ?>
					<figure class="tds-prose"><?php the_post_thumbnail( 'large', array( 'loading' => 'eager', 'decoding' => 'async' ) ); ?></figure>
				<?php endif; ?>
				<div class="tds-prose"><?php the_content(); ?></div>
				<footer class="tds-entry-footer">
					<a href="<?php echo esc_url( get_post_type_archive_link( 'post' ) ? get_post_type_archive_link( 'post' ) : home_url( '/' ) ); ?>"><?php esc_html_e( 'Voltar para as notícias', 'tds-portal' ); ?></a>
				</footer>
			</div>
		</article>
		<?php
	endwhile;
	?>
</main>
<?php
get_footer();
