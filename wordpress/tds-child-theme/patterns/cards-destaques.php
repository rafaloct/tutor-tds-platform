<?php
/**
 * Title: Três destaques
 * Slug: tds-portal/cards-destaques
 * Categories: tds-portal
 * Description: Grade de três cartões editoriais com título e texto.
 */
?>
<!-- wp:group {"className":"tds-grid","layout":{"type":"default"}} -->
<div class="wp-block-group tds-grid">
<?php for ( $tds_i = 1; $tds_i <= 3; $tds_i++ ) : ?>
<!-- wp:group {"className":"tds-card"} -->
<div class="wp-block-group tds-card"><!-- wp:group {"className":"tds-card__body"} -->
<div class="wp-block-group tds-card__body"><!-- wp:heading {"level":3,"className":"tds-card__title"} -->
<h3 class="wp-block-heading tds-card__title"><?php echo esc_html( sprintf( /* translators: %d: card number */ __( 'Destaque %d', 'tds-portal' ), $tds_i ) ); ?></h3>
<!-- /wp:heading -->
<!-- wp:paragraph {"className":"tds-card__text"} -->
<p class="tds-card__text"><?php esc_html_e( 'Texto curto do destaque. Evite dados pessoais e promessas acadêmicas.', 'tds-portal' ); ?></p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:group -->
<?php endfor; ?>
</div>
<!-- /wp:group -->
