<?php
defined('ABSPATH') || exit;
get_header();

if (!is_user_logged_in()) {
    wp_redirect(wp_login_url(get_permalink()));
    exit;
}

$user_id = get_current_user_id();
global $wpdb;
$certs = $wpdb->get_results($wpdb->prepare(
    "SELECT course_slug, hash, issued_at FROM {$wpdb->prefix}tds_certificates WHERE user_id = %d ORDER BY issued_at DESC",
    $user_id
));
?>
<div class="entry-content" style="max-width:800px;margin:2rem auto;padding:0 1rem">
  <h1 style="color:var(--tds-bg-escuro)">Meus Certificados</h1>
  <?php if (empty($certs)): ?>
    <p>Você ainda não possui certificados. <a href="<?= esc_url(home_url('/cursos')) ?>">Ver cursos →</a></p>
  <?php else: ?>
    <?php foreach ($certs as $cert):
      $course = get_page_by_path($cert->course_slug, OBJECT, 'lp_course');
    ?>
    <div class="tds-course-card" style="display:flex;justify-content:space-between;align-items:center">
      <div>
        <strong><?= esc_html($course ? get_the_title($course->ID) : $cert->course_slug) ?></strong>
        <div style="font-size:.8rem;color:#666">Emitido em: <?= esc_html(wp_date('d/m/Y', strtotime($cert->issued_at))) ?></div>
      </div>
      <div style="display:flex;gap:.5rem">
        <a href="<?= esc_url(home_url("/wp-json/tds/v1/certificate/{$user_id}/{$cert->course_slug}")) ?>"
           class="tds-btn tds-btn--green" target="_blank">⬇ PDF</a>
        <a href="<?= esc_url(home_url('/verificar/' . $cert->hash)) ?>"
           class="tds-btn" target="_blank">🔍 Verificar</a>
      </div>
    </div>
    <?php endforeach; ?>
  <?php endif; ?>
</div>
<?php get_footer(); ?>
