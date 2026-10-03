<?php
defined('ABSPATH') || exit;

// ─── Menu no painel ───────────────────────────────────────────────────────────
add_action('admin_menu', function (): void {
    add_menu_page(
        'Cadastrar Aluno — TDS',
        'Cadastrar Aluno',
        'edit_posts',
        'tds-cadastro-aluno',
        'tds_render_cadastro_aluno',
        'dashicons-groups',
        30
    );
});

// ─── Processamento do formulário ─────────────────────────────────────────────
add_action('admin_post_tds_cadastro_aluno', 'tds_handle_cadastro_aluno');

function tds_handle_cadastro_aluno(): void {
    if (!current_user_can('edit_posts')) {
        wp_die('Sem permissão.', 403);
    }
    if (!isset($_POST['tds_cadastro_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['tds_cadastro_nonce'])), 'tds_cadastro_aluno')) {
        wp_die('Requisição inválida.', 403);
    }

    $nome      = sanitize_text_field(wp_unslash($_POST['nome']      ?? ''));
    $email     = sanitize_email(wp_unslash($_POST['email']     ?? ''));
    $telefone  = sanitize_text_field(wp_unslash($_POST['telefone']  ?? ''));
    $curso_ids = array_map('intval', (array) ($_POST['curso_ids'] ?? []));
    $redirect  = admin_url('admin.php?page=tds-cadastro-aluno');

    if (!$nome || !is_email($email) || empty($curso_ids)) {
        wp_safe_redirect(add_query_arg('tds_erro', 'campos', $redirect));
        exit;
    }

    $existing = get_user_by('email', $email);

    if ($existing) {
        // Usuário já existe — apenas matricula nos novos cursos e reenvia e-mail
        $user_id = $existing->ID;
        $password = null;
        foreach ($curso_ids as $cid) {
            tds_matricular_learnpress($user_id, $cid);
        }
        tds_enviar_email_acesso($user_id, $email, $nome, $curso_ids, $password, $existing->user_login);
        wp_safe_redirect(add_query_arg(['tds_ok' => 'existente', 'tds_email' => rawurlencode($email)], $redirect));
        exit;
    }

    // Gerar username único a partir do primeiro nome
    $first    = strtolower(remove_accents(current(explode(' ', $nome))));
    $first    = preg_replace('/[^a-z0-9]/', '', $first);
    $username = tds_unique_username($first ?: 'aluno');
    $password = wp_generate_password(10, false);

    $user_id = wp_insert_user([
        'user_login'   => $username,
        'user_pass'    => $password,
        'user_email'   => $email,
        'display_name' => $nome,
        'first_name'   => $nome,
        'role'         => 'subscriber',
    ]);

    if (is_wp_error($user_id)) {
        wp_safe_redirect(add_query_arg('tds_erro', rawurlencode($user_id->get_error_message()), $redirect));
        exit;
    }

    // Salva telefone como meta
    if ($telefone) update_user_meta($user_id, 'tds_telefone', $telefone);

    // Matrícula nos cursos
    foreach ($curso_ids as $cid) {
        tds_matricular_learnpress($user_id, $cid);
    }

    // Envia e-mail
    tds_enviar_email_acesso($user_id, $email, $nome, $curso_ids, $password, $username);

    wp_safe_redirect(add_query_arg([
        'tds_ok'    => 'novo',
        'tds_email' => rawurlencode($email),
        'tds_user'  => rawurlencode($username),
    ], $redirect));
    exit;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function tds_unique_username(string $base): string {
    $candidate = $base;
    $i = 1;
    while (username_exists($candidate)) {
        $candidate = $base . $i++;
    }
    return $candidate;
}

function tds_matricular_learnpress(int $user_id, int $course_id): void {
    global $wpdb;
    $table = $wpdb->prefix . 'learnpress_user_items';

    $already = $wpdb->get_var($wpdb->prepare(
        "SELECT user_item_id FROM $table WHERE user_id = %d AND item_id = %d AND item_type = 'lp_course'",
        $user_id, $course_id
    ));
    if ($already) return;

    $wpdb->insert($table, [
        'user_id'      => $user_id,
        'item_id'      => $course_id,
        'item_type'    => 'lp_course',
        'status'       => 'enrolled',
        'graduation'   => 'in-progress',
        'access_level' => 50,
        'ref_id'       => 0,
        'ref_type'     => '',
        'parent_id'    => 0,
        'start_time'   => current_time('mysql'),
        'end_time'     => null,
    ], ['%d', '%d', '%s', '%s', '%s', '%d', '%d', '%s', '%d', '%s', '%s']);

    // Limpa cache do LearnPress para este usuário
    if (function_exists('learn_press_reset_user_course_items')) {
        learn_press_reset_user_course_items($user_id);
    }
    wp_cache_delete("lp-user-course-data-{$user_id}-{$course_id}");
}

function tds_enviar_email_acesso(int $user_id, string $email, string $nome, array $curso_ids, ?string $senha, string $username): void {
    $site_url    = home_url('/');
    $login_url   = wp_login_url($site_url);
    $primeiro    = current(explode(' ', $nome));
    $is_nova_conta = $senha !== null;

    // Monta lista de cursos
    $cursos_html = '';
    $cursos_txt  = '';
    foreach ($curso_ids as $cid) {
        $course = get_post($cid);
        if (!$course) continue;
        $url          = get_permalink($cid);
        $title        = esc_html($course->post_title);
        $cursos_html .= "<li style='margin-bottom:6px'>📚 <a href='{$url}' style='color:#f59e0b;font-weight:600'>{$title}</a></li>";
        $cursos_txt  .= "• {$course->post_title}: {$url}\n";
    }

    $assunto = $is_nova_conta
        ? "🎓 Sua conta TDS Capacitação foi criada — acesse agora!"
        : "📚 Você foi matriculado em novo curso — TDS Capacitação";

    ob_start(); ?>
<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:32px 16px">
  <tr><td align="center">
    <table width="100%" style="max-width:580px;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08)">

      <!-- Header -->
      <tr><td style="background:linear-gradient(135deg,#1e293b,#0f172a);padding:32px 40px;text-align:center">
        <div style="display:inline-flex;align-items:center;gap:8px">
          <span style="background:#f59e0b;color:#000;font-weight:900;font-size:18px;padding:6px 12px;border-radius:6px;letter-spacing:.5px">TDS</span>
          <span style="color:#fff;font-size:18px;font-weight:600">Capacitação</span>
        </div>
      </td></tr>

      <!-- Body -->
      <tr><td style="padding:40px 40px 32px">
        <h1 style="margin:0 0 8px;font-size:22px;color:#0f172a">
          <?php echo $is_nova_conta ? "Olá, {$primeiro}! Sua conta está pronta. 🎉" : "Olá, {$primeiro}! Nova matrícula disponível. 📚"; ?>
        </h1>
        <p style="margin:0 0 24px;color:#475569;font-size:15px;line-height:1.6">
          <?php if ($is_nova_conta): ?>
            Você foi cadastrado na plataforma de cursos do <strong>Projeto TDS — Territórios em Desenvolvimento Sustentável</strong> (UFT/IPEX). Veja abaixo seus dados de acesso:
          <?php else: ?>
            Você foi matriculado em um novo curso na plataforma TDS Capacitação. Acesse com suas credenciais já cadastradas.
          <?php endif; ?>
        </p>

        <?php if ($is_nova_conta): ?>
        <!-- Credenciais -->
        <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;margin-bottom:24px">
          <tr><td style="padding:20px 24px">
            <p style="margin:0 0 12px;font-size:13px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:.06em">Dados de acesso</p>
            <table width="100%" cellpadding="4" cellspacing="0">
              <tr>
                <td style="font-size:14px;color:#64748b;width:110px">Usuário:</td>
                <td style="font-size:15px;font-weight:700;color:#0f172a;font-family:monospace"><?php echo esc_html($username); ?></td>
              </tr>
              <tr>
                <td style="font-size:14px;color:#64748b">Senha:</td>
                <td style="font-size:15px;font-weight:700;color:#0f172a;font-family:monospace"><?php echo esc_html($senha); ?></td>
              </tr>
              <tr>
                <td style="font-size:14px;color:#64748b">E-mail:</td>
                <td style="font-size:15px;color:#0f172a"><?php echo esc_html($email); ?></td>
              </tr>
            </table>
          </td></tr>
        </table>
        <?php endif; ?>

        <!-- Cursos -->
        <p style="margin:0 0 8px;font-size:14px;font-weight:700;color:#0f172a">Seus cursos matriculados:</p>
        <ul style="margin:0 0 28px;padding-left:8px;color:#334155;font-size:14px;line-height:1.8;list-style:none">
          <?php echo $cursos_html; ?>
        </ul>

        <!-- CTA -->
        <div style="text-align:center;margin-bottom:28px">
          <a href="<?php echo esc_url($login_url); ?>" style="display:inline-block;background:#f59e0b;color:#000;font-weight:800;font-size:16px;padding:14px 36px;border-radius:8px;text-decoration:none">
            Acessar a Plataforma →
          </a>
        </div>

        <?php if ($is_nova_conta): ?>
        <div style="background:#fefce8;border:1px solid #fde047;border-radius:8px;padding:14px 18px;margin-bottom:24px">
          <p style="margin:0;font-size:13px;color:#713f12">
            <strong>💡 Recomendado:</strong> Após o primeiro acesso, altere sua senha em <strong>Minha Conta → Editar perfil</strong> para uma senha que só você saiba.
          </p>
        </div>
        <?php endif; ?>

        <p style="margin:0;font-size:14px;color:#64748b;line-height:1.6">
          Dúvidas? Fale conosco pelo WhatsApp
          <a href="https://wa.me/5563993010823" style="color:#f59e0b;font-weight:600">(63) 99301-0823</a>
          ou pela nossa <a href="https://chat.ipexdesenvolvimento.cloud" style="color:#f59e0b;font-weight:600">Central de Atendimento</a>.
        </p>
      </td></tr>

      <!-- Footer -->
      <tr><td style="background:#f8fafc;border-top:1px solid #e2e8f0;padding:20px 40px;text-align:center">
        <p style="margin:0;font-size:12px;color:#94a3b8">
          Projeto TDS — UFT / IPEX · Palmas, Tocantins<br>
          Parceria com o Ministério do Desenvolvimento e Assistência Social (MDS)
        </p>
      </td></tr>

    </table>
  </td></tr>
</table>
</body>
</html>
<?php
    $html = ob_get_clean();

    // Versão texto simples
    $txt = $is_nova_conta
        ? "Olá {$nome},\n\nSua conta na plataforma TDS Capacitação foi criada!\n\nDados de acesso:\nUsuário: {$username}\nSenha: {$senha}\nE-mail: {$email}\n\nCursos matriculados:\n{$cursos_txt}\nAcesse: {$login_url}\n\nDúvidas: (63) 99301-0823\n\nEquipe TDS — UFT/IPEX"
        : "Olá {$nome},\n\nVocê foi matriculado em um novo curso TDS Capacitação.\n\nCursos:\n{$cursos_txt}\nAcesse: {$login_url}\n\nDúvidas: (63) 99301-0823\n\nEquipe TDS — UFT/IPEX";

    $headers = [
        'Content-Type: text/html; charset=UTF-8',
        'From: TDS Capacitação <noreply@ipexdesenvolvimento.cloud>',
        'Reply-To: TDS Capacitação <ipexdesenvolvimento@uft.edu.br>',
    ];

    wp_mail($email, $assunto, $html, $headers);
}

// ─── Render da página admin ───────────────────────────────────────────────────
function tds_render_cadastro_aluno(): void {
    if (!current_user_can('edit_posts')) {
        wp_die('Sem permissão.');
    }

    $ok    = sanitize_text_field($_GET['tds_ok']    ?? '');
    $erro  = sanitize_text_field($_GET['tds_erro']  ?? '');
    $email = sanitize_email(rawurldecode($_GET['tds_email'] ?? ''));
    $user  = sanitize_text_field(rawurldecode($_GET['tds_user'] ?? ''));

    // Cursos publicados
    $cursos = get_posts([
        'post_type'      => 'lp_course',
        'post_status'    => 'publish',
        'posts_per_page' => -1,
        'orderby'        => 'title',
        'order'          => 'ASC',
    ]);

    // Últimas 20 matrículas
    global $wpdb;
    $recentes = $wpdb->get_results(
        "SELECT u.display_name, u.user_email, p.post_title AS curso, ui.start_time
         FROM {$wpdb->prefix}learnpress_user_items ui
         JOIN {$wpdb->users} u  ON u.ID = ui.user_id
         JOIN {$wpdb->posts} p  ON p.ID = ui.item_id
         WHERE ui.item_type = 'lp_course' AND ui.status = 'enrolled'
         ORDER BY ui.user_item_id DESC
         LIMIT 20"
    );
    ?>
    <div class="wrap">
      <h1 style="display:flex;align-items:center;gap:10px">
        <span style="background:#f59e0b;color:#000;font-weight:900;padding:3px 10px;border-radius:5px;font-size:14px">TDS</span>
        Cadastrar Aluno na Plataforma
      </h1>

      <?php if ($ok === 'novo'): ?>
        <div class="notice notice-success is-dismissible">
          <p>✅ <strong>Conta criada com sucesso!</strong> E-mail enviado para <strong><?php echo esc_html($email); ?></strong> com usuário <strong><?php echo esc_html($user); ?></strong> e senha temporária.</p>
        </div>
      <?php elseif ($ok === 'existente'): ?>
        <div class="notice notice-info is-dismissible">
          <p>ℹ️ Aluno já possuía conta. Matrícula(s) adicionada(s) e e-mail de confirmação enviado para <strong><?php echo esc_html($email); ?></strong>.</p>
        </div>
      <?php elseif ($erro === 'campos'): ?>
        <div class="notice notice-error is-dismissible"><p>❌ Preencha todos os campos obrigatórios e selecione pelo menos um curso.</p></div>
      <?php elseif ($erro): ?>
        <div class="notice notice-error is-dismissible"><p>❌ Erro: <?php echo esc_html($erro); ?></p></div>
      <?php endif; ?>

      <div style="display:grid;grid-template-columns:1fr 380px;gap:24px;margin-top:20px;align-items:start">

        <!-- Formulário -->
        <div style="background:#fff;border:1px solid #c3c4c7;border-radius:4px;padding:24px">
          <h2 style="margin-top:0;font-size:16px">Dados do aluno</h2>
          <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <?php wp_nonce_field('tds_cadastro_aluno', 'tds_cadastro_nonce'); ?>
            <input type="hidden" name="action" value="tds_cadastro_aluno">

            <table class="form-table" role="presentation">
              <tr>
                <th scope="row"><label for="tds_nome">Nome completo <span style="color:#d63638">*</span></label></th>
                <td><input type="text" id="tds_nome" name="nome" class="regular-text" placeholder="Ex.: Maria da Silva" required></td>
              </tr>
              <tr>
                <th scope="row"><label for="tds_email">E-mail <span style="color:#d63638">*</span></label></th>
                <td>
                  <input type="email" id="tds_email" name="email" class="regular-text" placeholder="aluno@email.com" required>
                  <p class="description">O e-mail de acesso e as credenciais serão enviados para este endereço.</p>
                </td>
              </tr>
              <tr>
                <th scope="row"><label for="tds_telefone">Telefone / WhatsApp</label></th>
                <td><input type="tel" id="tds_telefone" name="telefone" class="regular-text" placeholder="(63) 99999-9999"></td>
              </tr>
              <tr>
                <th scope="row"><label>Cursos <span style="color:#d63638">*</span></label></th>
                <td>
                  <?php if (empty($cursos)): ?>
                    <p style="color:#d63638">Nenhum curso publicado encontrado.</p>
                  <?php else: ?>
                    <div style="max-height:260px;overflow-y:auto;border:1px solid #8c8f94;border-radius:3px;padding:8px 12px;background:#fafafa">
                      <?php foreach ($cursos as $c): ?>
                        <label style="display:flex;align-items:center;gap:8px;padding:5px 0;cursor:pointer;font-size:14px;border-bottom:1px solid #f0f0f1">
                          <input type="checkbox" name="curso_ids[]" value="<?php echo $c->ID; ?>">
                          <?php echo esc_html($c->post_title); ?>
                        </label>
                      <?php endforeach; ?>
                    </div>
                    <p class="description">Marque um ou mais cursos. O aluno recebe acesso imediato a todos os selecionados.</p>
                  <?php endif; ?>
                </td>
              </tr>
            </table>

            <div style="margin-top:16px;padding:12px;background:#fff8e5;border-left:4px solid #f59e0b;font-size:13px;color:#713f12">
              <strong>📧 Como funciona:</strong> Se o e-mail ainda não tem conta, uma senha temporária é gerada e enviada ao aluno. Se já tiver conta, o aluno é matriculado nos novos cursos e recebe um aviso por e-mail.
            </div>

            <p style="margin-top:20px">
              <button type="submit" class="button button-primary button-large">
                Criar conta e matricular aluno →
              </button>
            </p>
          </form>
        </div>

        <!-- Coluna lateral: últimas matrículas -->
        <div>
          <div style="background:#fff;border:1px solid #c3c4c7;border-radius:4px;padding:20px">
            <h2 style="margin-top:0;font-size:15px">📋 Últimas matrículas</h2>
            <?php if (empty($recentes)): ?>
              <p style="color:#777;font-size:13px">Nenhuma matrícula registrada ainda.</p>
            <?php else: ?>
              <table style="width:100%;border-collapse:collapse;font-size:13px">
                <thead>
                  <tr style="border-bottom:2px solid #f0f0f1">
                    <th style="text-align:left;padding:6px 4px;color:#555">Aluno</th>
                    <th style="text-align:left;padding:6px 4px;color:#555">Curso</th>
                    <th style="text-align:left;padding:6px 4px;color:#555">Data</th>
                  </tr>
                </thead>
                <tbody>
                  <?php foreach ($recentes as $r): ?>
                    <tr style="border-bottom:1px solid #f0f0f1">
                      <td style="padding:6px 4px">
                        <strong><?php echo esc_html($r->display_name); ?></strong><br>
                        <span style="color:#999;font-size:11px"><?php echo esc_html($r->user_email); ?></span>
                      </td>
                      <td style="padding:6px 4px;color:#444;font-size:12px"><?php echo esc_html(wp_trim_words($r->curso, 6)); ?></td>
                      <td style="padding:6px 4px;color:#999;font-size:11px;white-space:nowrap">
                        <?php echo esc_html(date_i18n('d/m/y', strtotime($r->start_time))); ?>
                      </td>
                    </tr>
                  <?php endforeach; ?>
                </tbody>
              </table>
            <?php endif; ?>
          </div>

          <div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:4px;padding:16px;margin-top:16px;font-size:13px;color:#166534">
            <strong>✅ O aluno recebe por e-mail:</strong>
            <ul style="margin:8px 0 0;padding-left:18px;line-height:2">
              <li>Usuário de acesso</li>
              <li>Senha temporária</li>
              <li>Link direto para o curso</li>
              <li>Link da plataforma</li>
              <li>Contato de suporte (WhatsApp)</li>
            </ul>
          </div>
        </div>

      </div>
    </div>
    <?php
}
