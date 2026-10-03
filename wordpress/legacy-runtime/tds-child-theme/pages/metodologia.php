<?php
/**
 * Template Name: TDS — Metodologia
 */
defined('ABSPATH') || exit;
get_header();
?>

<!-- HERO METODOLOGIA -->
<section class="tds-hero-sec" id="main">
  <div class="tds-hero-sec__inner">
    <h1>Nossa Metodologia</h1>
    <p>Formação contextualizada, participativa e orientada pela prática — desenvolvida com tecnologias sociais adequadas às realidades do Cerrado, Bico do Papagaio e Jalapão.</p>
  </div>
</section>

<!-- PRINCÍPIOS PEDAGÓGICOS -->
<section class="tds-section">
  <div class="tds-container">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">Princípios</div>
      <h2 class="tds-title">A base do nosso jeito de ensinar</h2>
    </div>
    <div class="tds-grid tds-grid--4">
      <?php
      $principios = [
        ['🌱', 'Contextualizado', 'Conteúdo adaptado às realidades do Cerrado, Bico do Papagaio e Jalapão. Saberes locais são ponto de partida.'],
        ['🤲', 'Participativo', 'Aprendizes são protagonistas. Saberes populares e experiências comunitárias são valorizados na construção conjunta.'],
        ['⚡', 'Prático', 'Mais de 60% da carga em atividades aplicadas, estudos de caso reais e projetos no próprio território.'],
        ['🔄', 'Contínuo', 'Trilhas progressivas que se complementam, promovendo aprendizagem permanente e construção de autonomia gradual.'],
      ];
      foreach ($principios as [$icon, $title, $desc]): ?>
      <div class="tds-valor">
        <span class="tds-valor__icon"><?= $icon ?></span>
        <h3 class="tds-valor__title"><?= esc_html($title) ?></h3>
        <p class="tds-valor__text"><?= esc_html($desc) ?></p>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<!-- 5 TRILHAS DETALHADAS -->
<section class="tds-section tds-section--muted">
  <div class="tds-container">
    <div class="tds-section-header tds-section-header--center">
      <div class="tds-eyebrow">As 5 Trilhas Formativas</div>
      <h2 class="tds-title">Formação integral para cada realidade</h2>
      <p class="tds-subtitle">Cada trilha é um percurso completo com módulos progressivos, avaliações e projeto final de aplicação, combinando conhecimento técnico e saberes locais.</p>
    </div>

    <?php
    $trilhas = [
      [
        'num' => '01', 'cor' => '',
        'titulo' => 'Empreendedorismo Popular e Gestão de Negócios',
        'descricao' => 'Fortalece as habilidades gerenciais de autônomos e pequenos empreendedores (MEIs), ensinando planejamento financeiro, precificação, marketing digital e estratégias de vendas para garantir a sustentabilidade e o crescimento de seus negócios.',
        'modulos' => [
          'Fundamentos do empreendedorismo popular e solidário',
          'Plano de negócios simplificado para pequenos empreendedores',
          'Marketing digital, redes sociais e vendas online',
          'Finanças pessoais e gestão financeira do negócio',
          'Formalização (MEI), crédito (PRONAF) e políticas de apoio',
        ],
        'carga' => '40h', 'nivel' => 'Básico ao Avançado',
      ],
      [
        'num' => '02', 'cor' => 'verde',
        'titulo' => 'Cooperativismo Popular e Autogestão',
        'descricao' => 'Foca no fortalecimento de empreendimentos coletivos, capacitando agricultores e lideranças para a autogestão, governança democrática e comercialização coletiva, promovendo o desenvolvimento solidário nos territórios.',
        'modulos' => [
          'Princípios do cooperativismo e economia solidária',
          'Gestão democrática e governança participativa',
          'Organização financeira coletiva e contabilidade básica',
          'Comercialização coletiva e acesso a mercados locais',
          'Legislação cooperativa e formalização de cooperativas',
        ],
        'carga' => '36h', 'nivel' => 'Básico ao Intermediário',
      ],
      [
        'num' => '03', 'cor' => 'amarelo',
        'titulo' => 'Agricultura Familiar e Políticas Públicas Federais',
        'descricao' => 'Prepara agricultores familiares para acessar e fornecer produtos para programas governamentais importantes como o PAA e o PNAE, além de orientar sobre crédito rural e políticas de apoio à produção familiar.',
        'modulos' => [
          'Agricultura familiar: conceitos, desafios e potencialidades',
          'Acesso ao PNAE (Programa Nacional de Alimentação Escolar)',
          'Acesso ao PAA (Programa de Aquisição de Alimentos)',
          'PRONAF: crédito rural para a agricultura familiar',
          'Gestão da propriedade familiar e diversificação produtiva',
        ],
        'carga' => '48h', 'nivel' => 'Básico ao Avançado',
      ],
      [
        'num' => '04', 'cor' => 'roxo',
        'titulo' => 'Sistemas Produtivos Sustentáveis e Tecnologias Sociais',
        'descricao' => 'Capacita agricultores na implementação de sistemas sustentáveis como agroflorestas e bioinsumos, diversificando a produção e garantindo soberania alimentar e resiliência ambiental no Cerrado.',
        'modulos' => [
          'Sistemas agroflorestais (SAFs) e consórcios agroecológicos',
          'Bioinsumos: produção e uso de insumos biológicos locais',
          'Manejo sustentável do Cerrado e das Veredas',
          'Tecnologias sociais para soberania alimentar',
          'Boas práticas agrícolas e certificação ambiental',
        ],
        'carga' => '44h', 'nivel' => 'Intermediário ao Avançado',
      ],
      [
        'num' => '05', 'cor' => 'laranja',
        'titulo' => 'Inovação Agroecológica e Certificação',
        'descricao' => 'Ensina o uso de tecnologias digitais como geoprocessamento e drones, e processos de certificação participativa agroecológica, permitindo agregar valor, garantir rastreabilidade e acessar mercados diferenciados.',
        'modulos' => [
          'Agroecologia: bases científicas e princípios práticos',
          'Tecnologias digitais: geoprocessamento e drones no campo',
          'Certificação participativa agroecológica (OCS e SPG)',
          'Comunicação, difusão e registro de tecnologias sociais',
          'Projetos de inovação aplicados ao território',
        ],
        'carga' => '52h', 'nivel' => 'Intermediário ao Avançado',
      ],
    ];
    foreach ($trilhas as $t):
      $class = $t['cor'] ? 'tds-trilha-full tds-trilha-full--' . esc_attr($t['cor']) : 'tds-trilha-full';
    ?>
    <article class="<?= $class ?>">
      <header class="tds-trilha-full__header">
        <div class="tds-trilha-full__num"><?= esc_html($t['num']) ?></div>
        <div>
          <div class="tds-trilha-full__eyebrow">Trilha <?= esc_html($t['num']) ?></div>
          <h3 class="tds-trilha-full__title"><?= esc_html($t['titulo']) ?></h3>
          <div class="tds-trilha-full__meta">
            <span>⏱ <?= esc_html($t['carga']) ?></span>
            <span>📊 <?= esc_html($t['nivel']) ?></span>
          </div>
        </div>
      </header>
      <div class="tds-trilha-full__body">
        <div>
          <p class="tds-trilha-full__desc"><?= esc_html($t['descricao']) ?></p>
          <a href="<?= esc_url(get_permalink(get_page_by_path('cursos'))) ?>" class="tds-btn">Ver cursos desta trilha</a>
        </div>
        <div>
          <div class="tds-modulo-list__title">Módulos principais</div>
          <ul class="tds-modulo-list">
            <?php foreach ($t['modulos'] as $modulo): ?>
            <li><?= esc_html($modulo) ?></li>
            <?php endforeach; ?>
          </ul>
        </div>
      </div>
    </article>
    <?php endforeach; ?>
  </div>
</section>

<!-- EIXOS TRANSVERSAIS -->
<section class="tds-section">
  <div class="tds-container">
    <div class="tds-split">
      <div>
        <div class="tds-eyebrow">Eixos Transversais</div>
        <h2 class="tds-title">O que perpassa todas as trilhas</h2>
        <p class="tds-subtitle">Independente da trilha escolhida, todos os participantes desenvolvem competências fundamentais alinhadas aos valores do projeto e aos ODS da Agenda 2030.</p>
        <a href="<?= esc_url(get_permalink(get_page_by_path('cursos'))) ?>" class="tds-btn tds-btn--lg" style="margin-top:1.5rem;display:inline-flex">Acessar a Plataforma</a>
      </div>
      <div class="tds-stack tds-stack--sm" style="--flow:.75rem">
        <?php
        $eixos = [
          ['Gênero, diversidade e equidade', 'Perspectiva de equidade de gênero, raça e diversidade étnico-cultural em todas as práticas formativas.'],
          ['Cidadania e direitos sociais', 'Acesso às políticas sociais, documentação básica e participação democrática nas instâncias locais.'],
          ['Tecnologia digital básica', 'Letramento digital para uso da plataforma EAD, comunicação e registro das atividades produtivas.'],
          ['Sustentabilidade ambiental do Cerrado', 'Relação equilibrada com o meio ambiente como condição para a continuidade produtiva e cultural.'],
          ['Alinhamento com os ODS (Agenda 2030)', 'Todas as ações formativas são orientadas pelos Objetivos de Desenvolvimento Sustentável da ONU.'],
        ];
        foreach ($eixos as [$titulo, $desc]): ?>
        <div class="tds-eixo">
          <h4 class="tds-eixo__title"><?= esc_html($titulo) ?></h4>
          <p class="tds-eixo__text"><?= esc_html($desc) ?></p>
        </div>
        <?php endforeach; ?>
      </div>
    </div>
  </div>
</section>

<!-- CTA -->
<section class="tds-cta">
  <div class="tds-cta__inner">
    <h2>Escolha sua trilha formativa</h2>
    <p>Todas as trilhas são gratuitas para beneficiários do MDS/CadÚnico. Comece agora e transforme sua realidade.</p>
    <div class="tds-cta__btns">
      <a href="<?= esc_url(get_permalink(get_page_by_path('cursos'))) ?>" class="tds-btn tds-btn--amarelo tds-btn--lg">Ver Todos os Cursos</a>
      <a href="<?= esc_url(get_permalink(get_page_by_path('contato'))) ?>" class="tds-btn tds-btn--ghost tds-btn--lg">Tenho Dúvidas</a>
    </div>
  </div>
</section>

<?php get_footer(); ?>
