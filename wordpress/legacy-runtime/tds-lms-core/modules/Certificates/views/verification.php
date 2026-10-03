<?php
$valid  = !empty($cert);
$user   = $valid ? get_user_by('id', $cert->user_id) : null;
$course = $valid ? get_page_by_path($cert->course_slug, OBJECT, 'lp_course') : null;
?><!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<title>Verificação de Certificado — TDS</title>
<style>
  body{font-family:Inter,sans-serif;background:#1d1b74;color:#fff;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}
  .card{background:rgba(255,255,255,.08);border-radius:12px;padding:2.5rem;max-width:480px;width:100%;text-align:center}
  .icon{font-size:3rem;margin-bottom:1rem}
  h1{color:#F6D746;font-size:1.5rem;margin-bottom:.5rem}
  p{color:rgba(255,255,255,.7);margin:.25rem 0}
  .valid-badge{display:inline-block;padding:.4rem 1rem;border-radius:20px;font-weight:600;margin-bottom:1rem}
  .valid{background:#18CF10;color:#fff}
  .invalid{background:#FF341B;color:#fff}
</style>
</head>
<body>
<div class="card">
  <?php if ($valid): ?>
    <div class="icon">&#x2705;</div>
    <span class="valid-badge valid">Certificado Válido</span>
    <h1><?php echo esc_html($user ? $user->display_name : '—'); ?></h1>
    <p>Curso: <strong><?php echo esc_html($course ? get_the_title($course->ID) : $cert->course_slug); ?></strong></p>
    <p>Emitido em: <?php echo esc_html(date_i18n('d/m/Y', strtotime($cert->issued_at))); ?></p>
    <p style="margin-top:1rem;font-size:.75rem;color:rgba(255,255,255,.4)">Hash: <?php echo esc_html($hash); ?></p>
  <?php else: ?>
    <div class="icon">&#x274C;</div>
    <span class="valid-badge invalid">Certificado Inválido</span>
    <h1>Certificado não encontrado</h1>
    <p>Este hash não corresponde a nenhum certificado emitido.</p>
  <?php endif; ?>
</div>
</body>
</html>
