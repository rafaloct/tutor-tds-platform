<?php
/** Formulário de busca acessível. */

defined( 'ABSPATH' ) || exit;

$tds_search_id = 'tds-search-' . wp_unique_id();
?>
<form class="tds-search-form" role="search" method="get" action="<?php echo esc_url( home_url( '/' ) ); ?>">
	<label class="tds-screen-reader-text" for="<?php echo esc_attr( $tds_search_id ); ?>"><?php esc_html_e( 'Pesquisar no portal', 'tds-portal' ); ?></label>
	<input id="<?php echo esc_attr( $tds_search_id ); ?>" type="search" name="s" value="<?php echo esc_attr( get_search_query() ); ?>" placeholder="<?php esc_attr_e( 'Pesquisar…', 'tds-portal' ); ?>">
	<button class="tds-button tds-button--outline" type="submit"><?php esc_html_e( 'Pesquisar', 'tds-portal' ); ?></button>
</form>
