<?php
/**
 * Single post template — TDS design system
 */
defined('ABSPATH') || exit;
get_header();

$cats     = get_the_category();
$first    = !empty($cats) ? $cats[0] : null;
$color    = tds_cat_color($first ? $first->slug : '');
$thumb    = get_the_post_thumbnail_url(null, 'full');
$share_url = rawurlencode(get_permalink());
$share_txt = rawurlencode(get_the_title() . ' — ' . get_permalink());
$news_url  = get_permalink(get_page_by_path('noticias'));
?>

<article class="tds-single-post">

  <!-- Breadcrumb -->
  <div class="tds-breadcrumb">
    <div class="tds-container">
      <a href="<?= esc_url(home_url('/')) ?>">Início</a>
      <span aria-hidden="true"> / </span>
      <a href="<?= esc_url($news_url) ?>">Notícias</a>
      <?php if ($first): ?>
      <span aria-hidden="true"> / </span>
      <a href="<?= esc_url(add_query_arg('cat', $first->slug, $news_url)) ?>"><?= esc_html($first->name) ?></a>
      <?php endif; ?>
    </div>
  </div>

  <!-- Header do post -->
  <div class="tds-post-header">
    <div class="tds-container tds-post-header__inner">
      <?php if ($first): ?>
      <span class="tds-post-card__badge tds-post-card__badge--<?= esc_attr($color) ?>" style="margin-bottom:.75rem;display:inline-block">
        <?= esc_html($first->name) ?>
      </span>
      <?php endif; ?>
      <h1 class="tds-post-header__title"><?= esc_html(get_the_title()) ?></h1>
      <div class="tds-post-header__meta">
        <time datetime="<?= esc_attr(get_the_date('c')) ?>"><?= esc_html(get_the_date('d \d\e F \d\e Y')) ?></time>
        <?php if (get_the_author()): ?>
        <span class="tds-post-header__sep" aria-hidden="true">·</span>
        <span>Por <?= esc_html(get_the_author()) ?></span>
        <?php endif; ?>
      </div>
    </div>
  </div>

  <!-- Imagem destaque -->
  <?php if ($thumb): ?>
  <div class="tds-post-thumb">
    <img src="<?= esc_url($thumb) ?>" alt="<?= esc_attr(get_the_title()) ?>">
  </div>
  <?php endif; ?>

  <!-- Conteúdo -->
  <div class="tds-container">
    <div class="tds-post-content">
      <?php the_content(); ?>
    </div>

    <!-- Compartilhar -->
    <div class="tds-post-share">
      <span>Compartilhar:</span>
      <a href="https://wa.me/?text=<?= $share_txt ?>" target="_blank" rel="noopener" class="tds-post-share__btn tds-post-share__btn--whatsapp" aria-label="Compartilhar no WhatsApp">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
        WhatsApp
      </a>
    </div>

    <!-- Navegação anterior/próxima -->
    <nav class="tds-post-nav" aria-label="Posts anteriores e próximos">
      <?php
      $prev = get_previous_post();
      $next = get_next_post();
      ?>
      <div class="tds-post-nav__item tds-post-nav__item--prev">
        <?php if ($prev): ?>
        <span class="tds-post-nav__label">← Anterior</span>
        <a href="<?= esc_url(get_permalink($prev)) ?>" class="tds-post-nav__title"><?= esc_html(get_the_title($prev)) ?></a>
        <?php endif; ?>
      </div>
      <div class="tds-post-nav__item tds-post-nav__item--next" style="text-align:right">
        <?php if ($next): ?>
        <span class="tds-post-nav__label">Próximo →</span>
        <a href="<?= esc_url(get_permalink($next)) ?>" class="tds-post-nav__title"><?= esc_html(get_the_title($next)) ?></a>
        <?php endif; ?>
      </div>
    </nav>

    <div style="text-align:center;margin-top:2rem">
      <a href="<?= esc_url($news_url) ?>" class="tds-btn tds-btn--ghost">← Voltar para Notícias</a>
    </div>
  </div>

</article>

<?php get_footer(); ?>
