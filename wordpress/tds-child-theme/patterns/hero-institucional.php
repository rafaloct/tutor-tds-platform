<?php
/**
 * Title: Hero institucional
 * Slug: tds-portal/hero-institucional
 * Categories: tds-portal
 * Description: Bloco de abertura com chamada, texto curto e botões.
 */
?>
<!-- wp:group {"align":"full","backgroundColor":"tds-dark","textColor":"tds-surface","className":"tds-hero","layout":{"type":"constrained","contentSize":"760px"}} -->
<div class="wp-block-group alignfull tds-hero has-tds-surface-color has-tds-dark-background-color has-text-color has-background">
<!-- wp:paragraph {"className":"tds-eyebrow"} -->
<p class="tds-eyebrow"><?php esc_html_e( 'Programa TDS', 'tds-portal' ); ?></p>
<!-- /wp:paragraph -->
<!-- wp:heading {"level":1,"className":"tds-hero__title"} -->
<h1 class="wp-block-heading tds-hero__title"><?php esc_html_e( 'Formação e inclusão produtiva nos territórios', 'tds-portal' ); ?></h1>
<!-- /wp:heading -->
<!-- wp:paragraph {"className":"tds-hero__lead"} -->
<p class="tds-hero__lead"><?php esc_html_e( 'Substitua este texto pela apresentação oficial do programa, em linguagem simples.', 'tds-portal' ); ?></p>
<!-- /wp:paragraph -->
<!-- wp:buttons {"className":"tds-hero__actions"} -->
<div class="wp-block-buttons tds-hero__actions">
<!-- wp:button {"backgroundColor":"tds-accent","textColor":"tds-ink"} -->
<div class="wp-block-button"><a class="wp-block-button__link has-tds-ink-color has-tds-accent-background-color has-text-color has-background wp-element-button" href="#"><?php esc_html_e( 'Conhecer o programa', 'tds-portal' ); ?></a></div>
<!-- /wp:button -->
</div>
<!-- /wp:buttons -->
</div>
<!-- /wp:group -->
