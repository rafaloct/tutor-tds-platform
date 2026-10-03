<?php
/** Página não encontrada. */

defined( 'ABSPATH' ) || exit;

get_header();
?>
<main id="tds-main" class="tds-main" tabindex="-1">
	<div class="tds-container tds-container--narrow tds-404">
		<p class="tds-404__code" aria-hidden="true">404</p>
		<h1><?php esc_html_e( 'Página não encontrada', 'tds-portal' ); ?></h1>
		<p class="tds-lead"><?php esc_html_e( 'O endereço pode ter mudado ou o conteúdo foi retirado. Use a navegação ou a busca para continuar.', 'tds-portal' ); ?></p>
		<?php get_search_form(); ?>
		<div class="tds-hero__actions" style="justify-content:center">
			<?php echo tds_theme_button( __( 'Ir para o início', 'tds-portal' ), home_url( '/' ) ); // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button ?>
		</div>
	</div>
</main>
<?php
get_footer();
