<?php
/**
 * Title: Catálogo público de cursos
 * Slug: tds-portal/catalogo-publico
 * Categories: tds-portal
 * Description: Lista os cursos publicados pela API pública, com estados de indisponibilidade, vazio e erro.
 */
?>
<!-- wp:group {"className":"tds-section","layout":{"type":"constrained"}} -->
<div class="wp-block-group tds-section">
<!-- wp:heading -->
<h2 class="wp-block-heading"><?php esc_html_e( 'Catálogo público', 'tds-portal' ); ?></h2>
<!-- /wp:heading -->
<!-- wp:shortcode -->
[tds_catalogo quantidade="6"]
<!-- /wp:shortcode -->
</div>
<!-- /wp:group -->
