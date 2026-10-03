<?php
/** Rodapé institucional. Fecha os wrappers abertos em header.php. */

defined( 'ABSPATH' ) || exit;
?>
</div><!-- .ast-container -->
</div><!-- #content -->
<footer class="tds-footer">
	<div class="tds-container">
		<div class="tds-footer__grid">
			<div>
				<img class="tds-brand__mark" src="<?php echo esc_url( tds_theme_logo_url( true ) ); ?>" width="41" height="36" alt="" loading="lazy" decoding="async">
				<p class="tds-footer__note"><?php echo esc_html( get_bloginfo( 'description', 'display' ) ); ?></p>
				<p class="tds-footer__note"><?php esc_html_e( 'Portal público e editorial do Programa TDS. Matrícula, frequência, progresso e certificados são tratados exclusivamente pela plataforma Tutor TDS.', 'tds-portal' ); ?></p>
			</div>
			<nav aria-label="<?php esc_attr_e( 'Institucional', 'tds-portal' ); ?>">
				<p class="tds-footer__title"><?php esc_html_e( 'Institucional', 'tds-portal' ); ?></p>
				<?php tds_theme_footer_nav(); ?>
			</nav>
			<div>
				<p class="tds-footer__title"><?php esc_html_e( 'Acesso', 'tds-portal' ); ?></p>
				<?php tds_theme_app_access( array( 'variant' => 'outline' ) ); ?>
			</div>
		</div>
		<div class="tds-footer__bottom">
			<span>&copy; <?php echo esc_html( gmdate( 'Y' ) ); ?> <?php echo esc_html( get_bloginfo( 'name', 'display' ) ); ?></span>
			<a href="#page"><?php esc_html_e( 'Voltar ao topo', 'tds-portal' ); ?></a>
		</div>
	</div>
</footer>
</div><!-- #page -->
<?php wp_footer(); ?>
</body>
</html>
