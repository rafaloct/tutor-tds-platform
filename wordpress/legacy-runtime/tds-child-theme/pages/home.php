<?php
/**
 * Template Name: TDS — Home Institucional
 */
defined('ABSPATH') || exit;
get_header();

$logo_dir = get_stylesheet_directory_uri() . '/assets/logos';
$logo_path = get_stylesheet_directory() . '/assets/logos';
?>

<!-- HERO PRINCIPAL -->
<section class="tds-hero" id="main">
  <div class="tds-hero__inner">
    <div class="tds-hero__badge">✨ Formação gratuita · Inclusão produtiva · Tocantins</div>
    <h1 class="tds-hero__title">Capacitação que <em>transforma</em> territórios</h1>
    <p class="tds-hero__subtitle">
      O Projeto TDS é uma ação da UFT/IPEX com o Ministério do Desenvolvimento e Assistência Social para promover inclusão produtiva em 36 municípios de Tocantins. Cursos 100% gratuitos para quem está no CadÚnico.
    </p>
    <div class="tds-hero__ctas">
      <a href="<?= esc_url(get_permalink(get_page_by_path('cursos'))) ?>" class="tds-btn tds-btn--amarelo tds-btn--lg">Ver Cursos Gratuitos</a>
      <a href="<?= esc_url(get_permalink(get_page_by_path('sobre'))) ?>" class="tds-btn tds-btn--ghost tds-btn--lg">Sobre o Projeto</a>
    </div>
    <div class="tds-hero__stats">
      <div class="tds-hero__stat">
        <span class="tds-hero__stat-num">36</span>
        <span class="tds-hero__stat-label">Municípios atendidos</span>
      </div>
      <div class="tds-hero__stat">
        <span class="tds-hero__stat-num">5</span>
        <span class="tds-hero__stat-label">Trilhas formativas</span>
      </div>
      <div class="tds-hero__stat">
        <span class="tds-hero__stat-num">100%</span>
        <span class="tds-hero__stat-label">Gratuito CadÚnico/PBF</span>
      </div>
      <div class="tds-hero__stat">
        <span class="tds-hero__stat-num">24</span>
        <span class="tds-hero__stat-label">Meses de execução</span>
      </div>
    </div>
  </div>
</section>

<!-- SOBRE O PROJETO -->
<section class="tds-section">
  <div class="tds-container">
    <div class="tds-split">
      <div>
        <div class="tds-eyebrow">O que é o TDS</div>
        <h2 class="tds-title">Inclusão produtiva para quem mais precisa</h2>
        <p class="tds-subtitle">
          O <strong>Projeto TDS</strong> é uma ação estruturante de extensão universitária da UFT, por meio do IPEX, em parceria com o MDS. Atua em 36 municípios do estado do Tocantins, com foco no <strong>Bico do Papagaio</strong> e no <strong>Jalapão</strong> — regiões de alta vulnerabilidade social.
        </p>
        <p class="tds-subtitle" style="margin-top:1rem">
          Por meio de trilhas formativas participativas, o projeto transforma o assistencialismo em autonomia — capacitando comunidades para gerir negócios, organizar cooperativas e acessar políticas públicas como o PNAE e o PAA.
        </p>
        <div style="margin-top:2rem;display:flex;gap:1rem;flex-wrap:wrap">
          <a href="<?= esc_url(get_permalink(get_page_by_path('sobre'))) ?>" class="tds-btn tds-btn--lg">Conheça o Projeto</a>
          <a href="<?= esc_url(get_permalink(get_page_by_path('metodologia'))) ?>" class="tds-btn tds-btn--ghost tds-btn--lg" style="color:var(--tds-texto)!important;border-color:var(--tds-borda-forte)!important">Ver Metodologia</a>
        </div>
      </div>
      <div class="tds-sobre-visual">
        <div class="tds-sobre-badge">
          <span class="tds-sobre-badge__icon">🎓</span>
          <div>
            <strong>Extensão universitária</strong>
            <span>UFT / IPEX — Centro Norte Brasileiro</span>
          </div>
        </div>
        <div class="tds-sobre-badge">
          <span class="tds-sobre-badge__icon">🏛️</span>
          <div>
            <strong>Financiamento federal</strong>
            <span>Ministério do Desenvolvimento e Assistência Social (MDS)</span>
          </div>
        </div>
        <div class="tds-sobre-badge">
          <span class="tds-sobre-badge__icon">🌱</span>
          <div>
            <strong>Público prioritário</strong>
            <span>Famílias CadÚnico / Bolsa Família</span>
          </div>
        </div>
        <div class="tds-sobre-badge">
          <span class="tds-sobre-badge__icon">📍</span>
          <div>
            <strong>Territórios</strong>
            <span>Bico do Papagaio &amp; Jalapão — Tocantins</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- 5 TRILHAS FORMATIVAS -->
<section class="tds-section tds-section--muted">
  <div class="tds-container">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">Cursos gratuitos</div>
      <h2 class="tds-title">5 Trilhas Formativas</h2>
      <p class="tds-subtitle">Percursos estruturados de capacitação técnica, social e produtiva — criados com metodologias ativas e participativas, respeitando a cultura e a realidade de cada território.</p>
    </div>
    <div class="tds-grid tds-grid--3">
      <?php
      $trilhas = [
        ['🚀', 'Empreendedorismo Popular', 'Gestão de Negócios', 'Planejamento financeiro, marketing digital e estratégias de venda para autônomos, MEIs e pequenos empreendedores.', '40h'],
        ['🤝', 'Cooperativismo Popular', 'Autogestão e Solidariedade', 'Governança democrática, comercialização coletiva e sustentabilidade de cooperativas e associações comunitárias.', '36h'],
        ['🌾', 'Agricultura Familiar', 'Políticas Públicas Federais', 'Acesso ao PNAE, PAA e PRONAF. Capacitação para inclusão nos mercados institucionais de alimentos.', '48h'],
        ['♻️', 'Sistemas Produtivos Sustentáveis', 'Tecnologias Sociais', 'Agroflorestas, bioinsumos e sistemas sustentáveis para garantir soberania alimentar e resiliência ambiental.', '44h'],
        ['🔬', 'Inovação Agroecológica', 'Certificação e Tecnologia', 'Geoprocessamento, drones e certificação participativa para agregar valor e acessar mercados diferenciados.', '52h'],
      ];
      foreach ($trilhas as $i => [$icon, $title, $sub, $desc, $carga]): ?>
      <div class="tds-card tds-card--trilha">
        <div class="tds-card__num"><?= str_pad($i + 1, 2, '0', STR_PAD_LEFT) ?></div>
        <div class="tds-card__icon"><?= $icon ?></div>
        <h3 class="tds-card__title"><?= esc_html($title) ?></h3>
        <p class="tds-card__sub"><?= esc_html($sub) ?></p>
        <p class="tds-card__text"><?= esc_html($desc) ?></p>
        <div class="tds-card__meta">⏱ <?= esc_html($carga) ?></div>
      </div>
      <?php endforeach; ?>
      <div class="tds-card tds-card--cta-inline">
        <h3>Todas as trilhas são gratuitas</h3>
        <p>Para beneficiários do CadÚnico e do Programa Bolsa Família nos 36 municípios atendidos pelo projeto.</p>
        <a href="<?= esc_url(get_permalink(get_page_by_path('cursos'))) ?>" class="tds-btn tds-btn--amarelo" style="margin-top:1rem">Ver todos os cursos</a>
      </div>
    </div>
  </div>
</section>

<!-- PÚBLICO-ALVO -->
<section class="tds-section">
  <div class="tds-container">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">Para quem é</div>
      <h2 class="tds-title">Nosso público-alvo</h2>
    </div>
    <div class="tds-grid tds-grid--4">
      <?php
      $publicos = [
        ['👨‍👩‍👧', 'Famílias CadÚnico / PBF', 'Beneficiários do Bolsa Família e inscritos no Cadastro Único do MDS nos territórios do Bico do Papagaio e Jalapão.'],
        ['🌱', 'Agricultores Familiares', 'Pequenos produtores, assentados da reforma agrária e comunidades tradicionais que desejam ampliar e qualificar a produção.'],
        ['💼', 'Empreendedores Informais', 'Autônomos, MEIs e trabalhadores informais em busca de formalização, gestão e sustentabilidade financeira.'],
        ['🤲', 'Lideranças Comunitárias', 'Cooperativas populares, associações e lideranças que fortalecem a economia solidária nos territórios.'],
      ];
      foreach ($publicos as [$icon, $title, $desc]): ?>
      <div class="tds-valor">
        <span class="tds-valor__icon"><?= $icon ?></span>
        <h3 class="tds-valor__title"><?= esc_html($title) ?></h3>
        <p class="tds-valor__text"><?= esc_html($desc) ?></p>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<!-- PARCEIROS INSTITUCIONAIS -->
<section class="tds-section tds-section--muted">
  <div class="tds-container">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">Realização</div>
      <h2 class="tds-title">Quem torna o TDS possível</h2>
    </div>
    <div class="tds-parceiros-logos">
      <?php
      $parceiros = [
        ['logo-uft',   'Universidade Federal do Tocantins (UFT)'],
        ['logo-ipex',  'IPEX — Instituto de Pesquisa e Extensão UFT'],
        ['logo-fapto', 'FAPTO — Fundação de Amparo à Pesquisa do Tocantins'],
        ['logo-cdr',   'CDR'],
      ];
      foreach ($parceiros as [$slug, $alt]):
        $has_img = file_exists($logo_path . '/' . $slug . '.png');
      ?>
      <div class="tds-parceiro-logo">
        <?php if ($has_img): ?>
          <picture>
            <?php if (file_exists($logo_path . '/' . $slug . '.webp')): ?>
              <source srcset="<?= esc_url($logo_dir . '/' . $slug . '.webp') ?>" type="image/webp">
            <?php endif; ?>
            <img src="<?= esc_url($logo_dir . '/' . $slug . '.png') ?>" alt="<?= esc_attr($alt) ?>" loading="lazy" height="52">
          </picture>
        <?php else: ?>
          <span class="tds-parceiro-logo__text"><?= esc_html(str_replace('logo-', '', $slug)) ?></span>
        <?php endif; ?>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<!-- CTA FINAL -->
<section class="tds-cta">
  <div class="tds-cta__inner">
    <h2>Pronto para começar?</h2>
    <p>Acesse a plataforma, escolha sua trilha e transforme sua realidade. Totalmente gratuito para beneficiários do MDS nos territórios atendidos.</p>
    <div class="tds-cta__btns">
      <a href="<?= esc_url(get_permalink(get_page_by_path('cursos'))) ?>" class="tds-btn tds-btn--amarelo tds-btn--lg">Acessar os Cursos</a>
      <a href="<?= esc_url(get_permalink(get_page_by_path('contato'))) ?>" class="tds-btn tds-btn--ghost tds-btn--lg">Falar com a Equipe</a>
    </div>
  </div>
</section>

<?php get_footer(); ?>
