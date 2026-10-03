<?php
/**
 * Title: Chamada de acesso ao app
 * Slug: tds-portal/cta-acesso-app
 * Categories: tds-portal
 * Description: Seção com o link oficial de acesso ao app, lido da configuração pública. Oculta o botão quando o link não está configurado.
 */
?>
<!-- wp:group {"align":"full","className":"tds-section tds-section--dark","layout":{"type":"constrained"}} -->
<div class="wp-block-group alignfull tds-section tds-section--dark">
<!-- wp:heading {"className":"has-tds-surface-color has-text-color"} -->
<h2 class="wp-block-heading has-tds-surface-color has-text-color"><?php esc_html_e( 'Entre no app oficial', 'tds-portal' ); ?></h2>
<!-- /wp:heading -->
<!-- wp:shortcode -->
[tds_acesso_app]
<!-- /wp:shortcode -->
</div>
<!-- /wp:group -->
