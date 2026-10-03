<?php
/**
 * Template Name: TDS — Sobre Nós
 */
defined('ABSPATH') || exit;
get_header();
$logo_dir  = get_stylesheet_directory_uri() . '/assets/logos';
$logo_path = get_stylesheet_directory() . '/assets/logos';
?>

<!-- HERO SOBRE -->
<section class="tds-hero-sec" id="main">
  <div class="tds-hero-sec__inner">
    <h1>Território de Desenvolvimento Social</h1>
    <p>Conheça o projeto que une extensão universitária, tecnologia educacional e inclusão produtiva nos territórios mais vulneráveis de Tocantins.</p>
  </div>
</section>

<!-- MISSÃO / VISÃO / VALORES -->
<section class="tds-section">
  <div class="tds-container">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">Nossa Essência</div>
      <h2 class="tds-title">Missão, visão e valores</h2>
    </div>
    <div class="tds-grid tds-grid--3">
      <div class="tds-valor">
        <span class="tds-valor__icon">🎯</span>
        <h3 class="tds-valor__title">Missão</h3>
        <p class="tds-valor__text">Promover o desenvolvimento econômico e social sustentável por meio da inclusão socioprodutiva de populações em situação de vulnerabilidade, reduzindo a dependência de programas de transferência de renda e fortalecendo as capacidades locais, a agricultura familiar e o empreendedorismo popular.</p>
      </div>
      <div class="tds-valor">
        <span class="tds-valor__icon">🔭</span>
        <h3 class="tds-valor__title">Visão</h3>
        <p class="tds-valor__text">Consolidar um modelo de desenvolvimento territorial sustentável, inovador, participativo e replicável para outras regiões do Tocantins e do país, garantindo autonomia econômica, soberania alimentar e integração qualificada das comunidades vulneráveis aos mercados.</p>
      </div>
      <div class="tds-valor">
        <span class="tds-valor__icon">⭐</span>
        <h3 class="tds-valor__title">Valores</h3>
        <p class="tds-valor__text">Impacto e transformação social · Atuação dialógica e participativa · Sustentabilidade ambiental · Justiça social e direitos humanos · Alinhamento com os ODS da Agenda 2030 da ONU.</p>
      </div>
    </div>
  </div>
</section>

<!-- VALORES DETALHADOS -->
<section class="tds-section tds-section--muted">
  <div class="tds-container">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">Princípios</div>
      <h2 class="tds-title">O que guia nossa atuação</h2>
    </div>
    <div class="tds-grid tds-grid--2">
      <?php
      $valores = [
        ['💡', 'Impacto e Transformação Social', 'Compromisso efetivo com a redução das desigualdades históricas e a melhoria real das condições de vida das comunidades atendidas nos territórios do Bico do Papagaio e Jalapão.'],
        ['🗣️', 'Atuação Dialógica e Participativa', 'Valorização dos saberes populares e escuta ativa dos sujeitos sociais na construção conjunta de soluções adequadas à realidade territorial.'],
        ['🌿', 'Sustentabilidade Ambiental', 'Promoção da conservação dos recursos naturais do Cerrado, restauração florestal e adoção de práticas agroecológicas que garantam o futuro das comunidades.'],
        ['⚖️', 'Justiça Social e Direitos Humanos', 'Promoção da diversidade étnico-cultural, equidade de gênero e inclusão de grupos historicamente marginalizados nos processos produtivos.'],
        ['🌍', 'Alinhamento com a Agenda 2030', 'Incorporação dos ODS: erradicação da pobreza (ODS 1), agricultura sustentável (ODS 2), educação de qualidade (ODS 4), trabalho digno (ODS 8) e redução das desigualdades (ODS 10).'],
        ['🔬', 'Integração Ensino-Pesquisa-Extensão', 'Articulação orgânica entre a produção do conhecimento acadêmico da UFT e sua aplicação concreta na transformação da realidade socioeconômica local.'],
      ];
      foreach ($valores as [$icon, $title, $desc]): ?>
      <div style="background:var(--tds-surface);border-radius:var(--tds-radius);padding:1.5rem;border:1px solid var(--tds-borda);display:flex;gap:1rem;align-items:flex-start">
        <span style="font-size:1.75rem;flex-shrink:0;margin-top:.1rem"><?= $icon ?></span>
        <div>
          <h4 style="font-size:var(--tds-text-base);font-weight:700;color:var(--tds-bg-escuro);margin:0 0 .4rem"><?= esc_html($title) ?></h4>
          <p style="font-size:var(--tds-text-sm);color:var(--tds-texto-leve);margin:0;line-height:1.6"><?= esc_html($desc) ?></p>
        </div>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<!-- CONTEXTO TERRITORIAL -->
<section class="tds-section">
  <div class="tds-container">
    <div class="tds-split">
      <div>
        <div class="tds-eyebrow">Territórios de atuação</div>
        <h2 class="tds-title">Onde o TDS atua</h2>
        <p class="tds-subtitle">O projeto atua em 36 municípios do Tocantins, com foco nas regiões do Bico do Papagaio e do Jalapão — escolhidas pelos maiores índices de vulnerabilidade social e concentração de beneficiários do CadÚnico.</p>
        <div class="tds-territorio-list" style="margin-top:1.5rem">
          <div class="tds-territorio">
            <h4 class="tds-territorio__title">📍 Bico do Papagaio</h4>
            <p class="tds-territorio__text">Região nordeste do Tocantins, fronteira com Pará e Maranhão. Forte presença de comunidades quilombolas, pescadores artesanais e agricultores familiares. Uma das regiões com maior concentração de beneficiários do Bolsa Família no estado.</p>
          </div>
          <div class="tds-territorio">
            <h4 class="tds-territorio__title">📍 Jalapão</h4>
            <p class="tds-territorio__text">Extremo leste do Tocantins, conhecida pela beleza do Cerrado e pelo artesanato do capim-dourado. Alto potencial agroturístico e produtivo, com significativa população no CadÚnico e dependente de transferência de renda.</p>
          </div>
        </div>
      </div>
      <div class="tds-mapa">
        <div class="tds-mapa__emoji">🗺️</div>
        <div class="tds-mapa__estado">Tocantins — TO</div>
        <div class="tds-mapa__dados">
          <strong>36 municípios</strong> de atuação<br>
          <strong>2 territórios</strong> prioritários<br>
          <strong>24 meses</strong> de execução<br>
          <strong>Cerrado e Veredas</strong> como bioma principal
        </div>
      </div>
    </div>
  </div>
</section>

<!-- PARCEIROS INSTITUCIONAIS -->
<section class="tds-section tds-section--muted">
  <div class="tds-container">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">Parceria Institucional</div>
      <h2 class="tds-title">Quem torna o TDS possível</h2>
    </div>
    <div class="tds-grid tds-grid--2">
      <?php
      $parceiros = [
        ['logo-uft',   'UFT',   'azul',  'Universidade Federal do Tocantins (via IPEX)', 'Responsável pela concepção pedagógica, produção dos conteúdos das trilhas formativas e emissão dos certificados digitais com QR Code de verificação de autenticidade.'],
        ['logo-ipex',  'IPEX',  'verde', 'IPEX — Instituto de Pesquisa e Extensão, Centro Norte Brasileiro', 'Coordenação geral do projeto. Responsável pela articulação metodológica, mobilização das comunidades e execução das atividades nos territórios atendidos.'],
        [null,         'MDS',   'azul',  'Ministério do Desenvolvimento e Assistência Social (MDS)', 'Financiador principal. Identifica e mobiliza os beneficiários junto ao Cadastro Único e ao Programa Bolsa Família nos 36 municípios atendidos.'],
        ['logo-fapto', 'FAPTO', 'muted', 'Fundação de Amparo à Pesquisa do Tocantins (FAPTO)', 'Apoio à pesquisa aplicada e gestão administrativa e financeira dos recursos do projeto no Bico do Papagaio e Jalapão.'],
      ];
      foreach ($parceiros as [$slug, $badge, $cor, $title, $text]):
        $has_img = $slug && file_exists($logo_path . '/' . $slug . '.png');
      ?>
      <div class="tds-card tds-card--side">
        <?php if ($has_img): ?>
        <div style="min-width:80px;display:flex;align-items:center;justify-content:center;padding:.5rem;background:var(--tds-bg-muted);border-radius:var(--tds-radius-sm)">
          <picture>
            <?php if (file_exists($logo_path . '/' . $slug . '.webp')): ?>
              <source srcset="<?= esc_url($logo_dir . '/' . $slug . '.webp') ?>" type="image/webp">
            <?php endif; ?>
            <img src="<?= esc_url($logo_dir . '/' . $slug . '.png') ?>" alt="<?= esc_attr($title) ?>" loading="lazy" style="max-height:44px;width:auto;max-width:80px">
          </picture>
        </div>
        <?php else: ?>
        <div class="tds-card__badge tds-card__badge--<?= esc_attr($cor) ?>"><?= esc_html($badge) ?></div>
        <?php endif; ?>
        <div>
          <h3 class="tds-card__title"><?= esc_html($title) ?></h3>
          <p class="tds-card__text"><?= esc_html($text) ?></p>
        </div>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<!-- CTA -->
<section class="tds-cta">
  <div class="tds-cta__inner">
    <h2>Quer saber mais sobre o projeto?</h2>
    <p>Entre em contato com nossa equipe ou acesse os cursos disponíveis na plataforma.</p>
    <div class="tds-cta__btns">
      <a href="<?= esc_url(get_permalink(get_page_by_path('contato'))) ?>" class="tds-btn tds-btn--amarelo tds-btn--lg">Falar com a Equipe</a>
      <a href="<?= esc_url(get_permalink(get_page_by_path('metodologia'))) ?>" class="tds-btn tds-btn--ghost tds-btn--lg">Ver Metodologia</a>
    </div>
  </div>
</section>

<?php get_footer(); ?>
