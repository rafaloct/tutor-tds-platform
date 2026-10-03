<?php
defined('ABSPATH') || exit;
get_header();

$filter_free = isset($_GET['tipo']) && $_GET['tipo'] === 'gratis';
$filter_paid = isset($_GET['tipo']) && $_GET['tipo'] === 'pago';

$meta_query = [];
if ($filter_free) $meta_query = [['key' => '_lp_price', 'value' => '0', 'compare' => '<=', 'type' => 'NUMERIC']];
if ($filter_paid) $meta_query = [['key' => '_lp_price', 'value' => '0', 'compare' => '>', 'type' => 'NUMERIC']];

$courses = get_posts(['post_type' => 'lp_course', 'posts_per_page' => -1, 'post_status' => 'publish', 'meta_query' => $meta_query]);
?>
<div class="entry-content" style="max-width:1100px;margin:2rem auto;padding:0 1rem">
  <h1 style="color:var(--tds-bg-escuro)">Catálogo de Cursos</h1>

  <div style="margin-bottom:1.5rem;display:flex;gap:.5rem">
    <a href="?" class="tds-btn" style="background:<?= !$filter_free && !$filter_paid ? 'var(--tds-bg-escuro)' : '#ccc' ?>">Todos</a>
    <a href="?tipo=gratis" class="tds-btn" style="background:<?= $filter_free ? 'var(--tds-verde)' : '#ccc' ?>">Gratuitos</a>
    <a href="?tipo=pago"   class="tds-btn" style="background:<?= $filter_paid ? 'var(--tds-azul)' : '#ccc' ?>">Pagos</a>
  </div>

  <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:1.5rem">
    <?php foreach ($courses as $course):
      $price = get_post_meta($course->ID, '_lp_price', true);
      $is_free = !$price || (float)$price <= 0;
    ?>
    <div class="tds-course-card" style="display:flex;flex-direction:column">
      <?php if (has_post_thumbnail($course->ID)): ?>
        <img src="<?= esc_url(get_the_post_thumbnail_url($course->ID, 'medium')) ?>"
             alt="<?= esc_attr($course->post_title) ?>"
             style="border-radius:6px;margin-bottom:.75rem;width:100%;object-fit:cover;height:160px">
      <?php else: ?>
        <div style="height:160px;background:#eee;border-radius:6px;margin-bottom:.75rem;display:flex;align-items:center;justify-content:center;color:#999">Sem imagem</div>
      <?php endif; ?>
      <h3 style="margin:0 0 .5rem;font-size:1rem"><?= esc_html($course->post_title) ?></h3>
      <div style="margin-top:auto;padding-top:.75rem;display:flex;justify-content:space-between;align-items:center">
        <span class="tds-btn" style="background:<?= $is_free ? 'var(--tds-verde)' : 'var(--tds-azul)' ?>;cursor:default">
          <?= $is_free ? 'Gratuito' : 'R$ ' . number_format((float)$price, 2, ',', '.') ?>
        </span>
        <a href="<?= esc_url(get_permalink($course->ID)) ?>" class="tds-btn">Ver curso</a>
      </div>
    </div>
    <?php endforeach; ?>
  </div>
</div>
<?php get_footer(); ?>
