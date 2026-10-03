<?php
/**
 * Página institucional: cabeçalho + conteúdo editorial + bloco opcional.
 *
 * @var array $args { eyebrow, show_modified, after (callable) }
 */

defined( 'ABSPATH' ) || exit;

$args = wp_parse_args( $args, array( 'eyebrow' => '', 'show_modified' => false, 'after' => null ) );
?>
<main id="tds-main" class="tds-main" tabindex="-1">
	<?php
	while ( have_posts() ) :
		the_post();
		tds_theme_page_hero( array( 'eyebrow' => $args['eyebrow'], 'show_modified' => $args['show_modified'] ) );
		?>
		<div class="tds-content">
			<div class="tds-container tds-container--narrow">
				<div class="tds-prose">
					<?php the_content(); ?>
				</div>
				<?php
				if ( is_callable( $args['after'] ) ) {
					call_user_func( $args['after'] );
				}
				?>
			</div>
		</div>
		<?php
	endwhile;
	?>
</main>
