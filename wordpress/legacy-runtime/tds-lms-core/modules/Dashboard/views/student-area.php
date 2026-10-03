<?php
// Variables: $user, $enrolled (array), $user_id
?>
<div class="tds-dashboard">
  <div class="tds-dashboard__header">
    <h2>Olá, <?= esc_html($user->display_name) ?></h2>
    <p><?= count($enrolled) ?> curso(s) matriculado(s)</p>
  </div>
  <div class="tds-dashboard__courses">
    <?php foreach ($enrolled as $c): ?>
    <div class="tds-course-card <?= $c['status'] === 'finished' ? 'tds-course-card--done' : '' ?>">
      <h3><a href="<?= esc_url($c['url']) ?>"><?= esc_html($c['title']) ?></a></h3>
      <div class="tds-progress">
        <div class="tds-progress__bar" style="width:<?= (int)$c['pct'] ?>%"></div>
      </div>
      <span class="tds-progress__label"><?= (int)$c['pct'] ?>% concluído</span>
      <?php if ($c['status'] === 'finished'): ?>
        <a href="<?= esc_url(home_url('/wp-json/tds/v1/certificate/' . $user_id . '/' . $c['slug'])) ?>"
           class="tds-btn tds-btn--green" target="_blank">Baixar Certificado</a>
      <?php else: ?>
        <a href="<?= esc_url($c['url']) ?>" class="tds-btn">Continuar</a>
      <?php endif; ?>
    </div>
    <?php endforeach; ?>
    <?php if (empty($enrolled)): ?>
      <p>Você ainda não está matriculado em nenhum curso. <a href="<?= esc_url(home_url('/cursos')) ?>">Ver catálogo</a></p>
    <?php endif; ?>
  </div>
</div>
