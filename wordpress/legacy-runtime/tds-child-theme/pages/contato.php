<?php
/**
 * Template Name: TDS — Contato
 */
defined('ABSPATH') || exit;
get_header();
?>

<!-- HERO CONTATO -->
<section class="tds-hero-sec">
  <div class="tds-hero-sec__inner">
    <h1>Entre em Contato</h1>
    <p>Tem dúvidas sobre o projeto, os cursos ou como participar? Nossa equipe está pronta para ajudar.</p>
  </div>
</section>

<!-- FORMULÁRIO + INFO -->
<section class="tds-section">
  <div class="tds-container">
    <div class="tds-split tds-split--wide-left">

      <!-- Formulário -->
      <div>
        <div class="tds-eyebrow">Envie uma mensagem</div>
        <h2 class="tds-title">Como podemos ajudar?</h2>

        <form class="tds-form" method="post" action="<?= esc_url(admin_url('admin-post.php')) ?>">
          <?php wp_nonce_field('tds_contato', 'tds_contato_nonce'); ?>
          <input type="hidden" name="action" value="tds_contato">

          <div class="tds-form__row">
            <div class="tds-form__group">
              <label class="tds-form__label" for="tds_nome">Nome completo<span class="tds-form__required">*</span></label>
              <input type="text" id="tds_nome" name="nome" placeholder="Seu nome" required>
            </div>
            <div class="tds-form__group">
              <label class="tds-form__label" for="tds_email">E-mail<span class="tds-form__required">*</span></label>
              <input type="email" id="tds_email" name="email" placeholder="seu@email.com" required>
            </div>
          </div>

          <div class="tds-form__group">
            <label class="tds-form__label" for="tds_telefone">Telefone / WhatsApp</label>
            <input type="tel" id="tds_telefone" name="telefone" placeholder="(63) 99999-9999">
          </div>

          <div class="tds-form__group">
            <label class="tds-form__label" for="tds_assunto">Assunto<span class="tds-form__required">*</span></label>
            <select id="tds_assunto" name="assunto" required>
              <option value="">Selecione um assunto...</option>
              <option value="inscricao">Inscrição nos cursos</option>
              <option value="certificado">Certificado e histórico</option>
              <option value="acesso">Problemas de acesso</option>
              <option value="parceria">Proposta de parceria</option>
              <option value="imprensa">Imprensa e comunicação</option>
              <option value="outro">Outro assunto</option>
            </select>
          </div>

          <div class="tds-form__group">
            <label class="tds-form__label" for="tds_mensagem">Mensagem<span class="tds-form__required">*</span></label>
            <textarea id="tds_mensagem" name="mensagem" rows="5" placeholder="Descreva sua dúvida ou mensagem..." required></textarea>
          </div>

          <?php if (isset($_GET['contato'])): ?>
            <div class="tds-form__notice tds-form__notice--<?= $_GET['contato'] === 'ok' ? 'success' : 'error' ?>">
              <?= $_GET['contato'] === 'ok' ? '✓ Mensagem enviada! Responderemos em breve.' : '✗ Erro ao enviar. Verifique os campos e tente novamente.' ?>
            </div>
          <?php endif; ?>
          <button type="submit" class="tds-btn tds-btn--lg" style="width:100%">
            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
            Enviar Mensagem
          </button>
          <p class="tds-form__hint">Respondemos em até 2 dias úteis.</p>
        </form>
      </div>

      <!-- Informações de contato -->
      <div>
        <div class="tds-eyebrow">Informações</div>
        <h2 class="tds-title">Outros canais</h2>

        <div class="tds-info-list">
          <div class="tds-info-item">
            <div class="tds-info-item__icon">
              <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
            </div>
            <div class="tds-info-item__content">
              <div class="tds-info-item__title">E-mail</div>
              <div class="tds-info-item__value">
                <a href="mailto:atendimento@ipexdesenvolvimento.cloud" style="color:inherit">atendimento@ipexdesenvolvimento.cloud</a><br>
                <small style="color:var(--tds-texto-fraco)">tdsdados@gmail.com · ipexdesenvolvimento@uft.edu.br</small>
              </div>
            </div>
          </div>
          <div class="tds-info-item">
            <div class="tds-info-item__icon tds-info-item__icon--verde">
              <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 13 19.79 19.79 0 0 1 1.61 4.44 2 2 0 0 1 3.58 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L7.91 9.91a16 16 0 0 0 6.18 6.18l1.27-.93a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
            </div>
            <div class="tds-info-item__content">
              <div class="tds-info-item__title">WhatsApp</div>
              <div class="tds-info-item__value"><a href="https://wa.me/5563993010823" target="_blank" rel="noopener" style="color:inherit">(63) 99301-0823</a></div>
            </div>
          </div>
          <div class="tds-info-item">
            <div class="tds-info-item__icon tds-info-item__icon--amarelo">
              <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/></svg>
            </div>
            <div class="tds-info-item__content">
              <div class="tds-info-item__title">Atendimento</div>
              <div class="tds-info-item__value">Segunda a sexta<br>8h às 18h (horário de Brasília)</div>
            </div>
          </div>
        </div>

        <div class="tds-eyebrow" style="margin-top:2rem">Campi UFT Envolvidos</div>
        <div class="tds-campus-list">
          <div class="tds-campus">
            <h4 class="tds-campus__nome">📍 Campus Araguaína</h4>
            <p class="tds-campus__info">Av. Paraguai, s/n, St. Cimba<br>Araguaína – TO, CEP 77824-838</p>
            <span class="tds-campus__tag">Atende: Território Bico do Papagaio</span>
          </div>
          <div class="tds-campus">
            <h4 class="tds-campus__nome">📍 Campus Palmas (Sede IPEX)</h4>
            <p class="tds-campus__info">Prédio Isabel Auler, Anexo 1<br>Palmas – TO</p>
            <span class="tds-campus__tag">Coordenação geral do projeto</span>
          </div>
          <div class="tds-campus">
            <h4 class="tds-campus__nome">📍 Campus Porto Nacional</h4>
            <p class="tds-campus__info">Rua 03, Quadra 17, s/n<br>Porto Nacional – TO, CEP 77500-000</p>
            <span class="tds-campus__tag">Atende: Território Jalapão</span>
          </div>
        </div>
      </div>

    </div>
  </div>
</section>

<!-- COMUNIDADES WHATSAPP -->
<section class="tds-section">
  <div class="tds-container">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">Comunidade</div>
      <h2 class="tds-title">Grupos do WhatsApp</h2>
      <p class="tds-subtitle">Entre no grupo do seu curso para receber avisos de oficinas, encontros ao vivo e trocar experiências com outros alunos.</p>
    </div>
    <div class="tds-grid tds-grid--4" style="margin-top:2rem">
      <?php
      $grupos = [
        ['🏠', 'Comunidade TDS',           'https://chat.whatsapp.com/REDACTED_LEGACY_INVITE'],
        ['🤖', 'IA e Inclusão Digital',    'https://chat.whatsapp.com/REDACTED_LEGACY_INVITE'],
        ['🍽️', 'Culinária Saudável',       'https://chat.whatsapp.com/REDACTED_LEGACY_INVITE'],
        ['🤝', 'Crédito e Cooperativismo', 'https://chat.whatsapp.com/REDACTED_LEGACY_INVITE'],
        ['📋', 'Planejamento Produtivo',   'https://chat.whatsapp.com/REDACTED_LEGACY_INVITE'],
        ['💰', 'Educação Financeira',      'https://chat.whatsapp.com/REDACTED_LEGACY_INVITE'],
        ['🎥', 'Áudio Visual',             'https://chat.whatsapp.com/REDACTED_LEGACY_INVITE'],
        ['📧', 'Fale por E-mail',           'mailto:atendimento@ipexdesenvolvimento.cloud'],
      ];
      foreach ($grupos as [$icon, $nome, $url]): ?>
      <a href="<?= esc_url($url) ?>" target="_blank" rel="noopener"
         class="tds-card" style="text-align:center;text-decoration:none;display:block;padding:1.25rem 1rem">
        <div style="font-size:1.75rem;margin-bottom:.5rem"><?= $icon ?></div>
        <div style="font-size:var(--tds-text-sm);font-weight:600;color:var(--tds-texto)"><?= esc_html($nome) ?></div>
      </a>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<!-- FAQ RÁPIDO -->
<section class="tds-section tds-section--muted">
  <div class="tds-container" style="max-width:800px">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">FAQ</div>
      <h2 class="tds-title">Perguntas frequentes</h2>
    </div>
    <?php
    $faqs = [
      ['Quem pode se inscrever nos cursos?', 'Pessoas em situação de vulnerabilidade social cadastradas no CadÚnico do MDS, residentes nos territórios do Bico do Papagaio e do Jalapão, em Tocantins.'],
      ['Os cursos são realmente gratuitos?', 'Sim, 100% gratuitos para os beneficiários elegíveis do projeto. A formação é financiada pelo Ministério do Desenvolvimento e Assistência Social (MDS).'],
      ['Preciso de computador para fazer os cursos?', 'Não necessariamente. Nossa plataforma é compatível com smartphones. Mas para uma melhor experiência, recomendamos o uso de tablet ou computador.'],
      ['Receberei certificado ao concluir?', 'Sim! Ao concluir cada trilha formativa, você recebe um certificado digital emitido pelo IPEX/UFT, com QR Code de verificação de autenticidade.'],
      ['Como faço para recuperar minha senha?', 'Na tela de login, clique em "Esqueci minha senha" e siga as instruções enviadas para seu e-mail cadastrado.'],
    ];
    ?>
    <div class="tds-faq">
    <?php foreach ($faqs as [$pergunta, $resposta]): ?>
      <details>
        <summary>
          <span><?= esc_html($pergunta) ?></span>
          <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24" aria-hidden="true"><polyline points="6 9 12 15 18 9"/></svg>
        </summary>
        <div class="tds-faq__content"><?= esc_html($resposta) ?></div>
      </details>
    <?php endforeach; ?>
    </div>
  </div>
</section>

<?php get_footer(); ?>
