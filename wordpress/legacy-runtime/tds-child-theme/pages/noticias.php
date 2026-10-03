<?php
/**
 * Template Name: TDS — Notícias
 */
defined('ABSPATH') || exit;
get_header();

$cat_filter = isset($_GET['cat']) ? sanitize_key($_GET['cat']) : '';
$paged      = max(1, (int) get_query_var('paged', get_query_var('page', 1)));

$args = [
    'post_type'      => 'post',
    'post_status'    => 'publish',
    'posts_per_page' => 12,
    'paged'          => $paged,
    'orderby'        => 'date',
    'order'          => 'DESC',
];
if ($cat_filter) {
    $args['category_name'] = $cat_filter;
}
$query = new WP_Query($args);

$cats = [
    ''            => ['Tudo',                  ''],
    'noticias'    => ['Notícias',              'azul'],
    'visitas'     => ['Visitas',               'verde'],
    'comunicados' => ['Comunicados',           'laranja'],
    'eventos'     => ['Eventos',               'roxo'],
    'instagram'   => ['Instagram',             'rosa'],
];
$base_url = get_permalink();
?>

<section class="tds-hero-sec">
  <div class="tds-hero-sec__inner">
    <div class="tds-eyebrow">Projeto TDS</div>
    <h1>Notícias e Comunicados</h1>
    <p>Visitas às comunidades, eventos, comunicados e novidades do projeto em Tocantins.</p>
  </div>
</section>

<section class="tds-section">
  <div class="tds-container">

    <!-- Filtros de categoria -->
    <div class="tds-cat-filters">
      <?php foreach ($cats as $slug => [$label, $color]):
        $active = ($cat_filter === $slug);
        $url    = $slug ? add_query_arg('cat', $slug, $base_url) : $base_url;
      ?>
      <a href="<?= esc_url($url) ?>"
         class="tds-cat-pill tds-cat-pill--<?= esc_attr($color ?: 'all') ?><?= $active ? ' is-active' : '' ?>">
        <?= esc_html($label) ?>
      </a>
      <?php endforeach; ?>
    </div>

    <?php if ($query->have_posts()): ?>
    <div class="tds-posts-grid">
      <?php while ($query->have_posts()): $query->the_post();
        $cats_post = get_the_category();
        $first_cat = !empty($cats_post) ? $cats_post[0] : null;
        $cat_color = tds_cat_color($first_cat ? $first_cat->slug : '');
        $thumb_url = get_the_post_thumbnail_url(null, 'large');
      ?>
      <article class="tds-post-card">
        <a href="<?= esc_url(get_permalink()) ?>" class="tds-post-card__img-wrap" tabindex="-1" aria-hidden="true">
          <?php if ($thumb_url): ?>
            <img src="<?= esc_url($thumb_url) ?>" alt="<?= esc_attr(get_the_title()) ?>" loading="lazy">
          <?php else: ?>
            <div class="tds-post-card__img-placeholder tds-post-card__img-placeholder--<?= esc_attr($cat_color) ?>">
              <span><?= $first_cat ? esc_html($first_cat->name[0]) : 'T' ?></span>
            </div>
          <?php endif; ?>
        </a>
        <div class="tds-post-card__body">
          <?php if ($first_cat): ?>
          <a href="<?= esc_url(add_query_arg('cat', $first_cat->slug, $base_url)) ?>"
             class="tds-post-card__badge tds-post-card__badge--<?= esc_attr($cat_color) ?>">
            <?= esc_html($first_cat->name) ?>
          </a>
          <?php endif; ?>
          <time class="tds-post-card__date" datetime="<?= esc_attr(get_the_date('c')) ?>">
            <?= esc_html(get_the_date('d/m/Y')) ?>
          </time>
          <h2 class="tds-post-card__title">
            <a href="<?= esc_url(get_permalink()) ?>"><?= esc_html(get_the_title()) ?></a>
          </h2>
          <?php if (has_excerpt() || get_the_content()): ?>
          <p class="tds-post-card__excerpt"><?= esc_html(wp_trim_words(get_the_excerpt() ?: wp_strip_all_tags(get_the_content()), 18, '…')) ?></p>
          <?php endif; ?>
          <a href="<?= esc_url(get_permalink()) ?>" class="tds-post-card__link">Leia mais →</a>
        </div>
      </article>
      <?php endwhile; ?>
    </div>

    <!-- Paginação -->
    <?php if ($query->max_num_pages > 1):
      $big = 999999999;
      echo '<div class="tds-pagination">';
      echo paginate_links([
        'base'      => str_replace($big, '%#%', esc_url(get_pagenum_link($big))),
        'format'    => '?paged=%#%',
        'current'   => $paged,
        'total'     => $query->max_num_pages,
        'prev_text' => '← Anterior',
        'next_text' => 'Próxima →',
        'add_args'  => $cat_filter ? ['cat' => $cat_filter] : false,
      ]);
      echo '</div>';
    endif;
    wp_reset_postdata();

    else: ?>
    <div class="tds-empty-state">
      <span>📭</span>
      <p>Nenhuma publicação encontrada nesta categoria ainda.</p>
      <a href="<?= esc_url($base_url) ?>" class="tds-btn">Ver todas as notícias</a>
    </div>
    <?php endif; ?>

  </div>
</section>

<?php get_footer(); ?>
