<?php
/**
 * Cabeçalho do portal. Mantém os wrappers #page/#content/.ast-container
 * que os templates do Astra esperam encontrar fechados em footer.php.
 */

defined( 'ABSPATH' ) || exit;
?><!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
<meta charset="<?php bloginfo( 'charset' ); ?>">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
<a class="tds-skip-link" href="#tds-main"><?php esc_html_e( 'Pular para o conteúdo', 'tds-portal' ); ?></a>
<div id="page" class="hfeed site">
<header class="tds-header" data-tds-nav="basic">
	<div class="tds-container tds-header__inner">
		<?php tds_theme_brand(); ?>
		<button class="tds-nav-toggle" type="button" aria-expanded="false" aria-controls="tds-primary-nav" hidden>
			<span class="tds-nav-toggle__bars" aria-hidden="true"><span></span></span>
			<span class="tds-nav-toggle__label"><?php esc_html_e( 'Menu', 'tds-portal' ); ?></span>
		</button>
		<?php tds_theme_primary_nav(); ?>
	</div>
</header>
<div id="content" class="site-content">
<div class="ast-container">
