<?php
require_once get_stylesheet_directory() . '/includes/admin-cadastro-aluno.php';

// Theme support
add_action('after_setup_theme', function (): void {
    add_theme_support('post-thumbnails');
    add_theme_support('title-tag');
    set_post_thumbnail_size(800, 500, true);
});

add_action('wp_enqueue_scripts', function (): void {
    wp_enqueue_style('tds-fonts', 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap', [], null);
    wp_enqueue_style('tds-parent', get_template_directory_uri() . '/style.css');
    wp_enqueue_style('tds-child',  get_stylesheet_uri(), ['tds-parent'], '2.6.0');

    if (file_exists(get_stylesheet_directory() . '/assets/js/tds-course.js')) {
        wp_enqueue_script('tds-course-js', get_stylesheet_directory_uri() . '/assets/js/tds-course.js', ['jquery'], '1.0.0', true);
    }
}, 20);

// Mapa de cores por categoria
function tds_cat_color(string $slug): string {
    return [
        'noticias'    => 'azul',
        'visitas'     => 'verde',
        'comunicados' => 'laranja',
        'eventos'     => 'roxo',
        'instagram'   => 'rosa',
    ][$slug] ?? 'azul';
}

// Força layout sem sidebar para templates TDS e posts
add_filter('astra_page_layout', function (string $layout): string {
    if (is_single() || is_category() || is_home()) return 'no-sidebar';
    if (is_page()) {
        $tpl = get_post_meta(get_the_ID(), '_wp_page_template', true);
        $full_width = [
            'pages/home.php', 'pages/sobre.php', 'pages/metodologia.php',
            'pages/contato.php', 'pages/tutorial.php', 'pages/noticias.php',
        ];
        if (in_array($tpl, $full_width, true)) return 'no-sidebar';
    }
    return $layout;
});

// Remove título H1 padrão do Astra nos posts e páginas TDS
add_filter('astra_the_post_title_enabled', function (bool $enabled): bool {
    if (is_single()) return false;
    if (is_page()) {
        $tpl = get_post_meta(get_the_ID(), '_wp_page_template', true);
        $no_title = [
            'pages/home.php', 'pages/sobre.php', 'pages/metodologia.php',
            'pages/contato.php', 'pages/tutorial.php', 'pages/noticias.php',
        ];
        if (in_array($tpl, $no_title, true)) return false;
    }
    return $enabled;
});

// Viewport meta tag correta
add_action('wp_head', function (): void {
    echo '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">' . "\n";
}, 1);

// Esconde o header padrão do Astra (substituímos pelo customizado)
add_action('wp_head', function (): void {
    echo "<style id=\"tds-hide-astra-header\">
      #masthead, .ast-above-header-wrap, .ast-below-header-wrap,
      .ast-primary-header-bar, .main-header-bar-wrap { display: none !important; }
      body { padding-top: 0 !important; }
    </style>\n";
}, 99);

// Header customizado — logo compacta + menu hamburger sempre recolhível
add_action('wp_body_open', function (): void {
    $menu_exists = has_nav_menu('primary');
    ?>
<a href="#main" class="tds-skip-link">Pular para o conteúdo</a>
<header class="tds-header" role="banner">
  <div class="tds-header__inner">
    <a href="<?= esc_url(home_url('/')) ?>" class="tds-header__brand" aria-label="TDS Capacitação — Início">
      <span class="tds-header__brand-mark" aria-hidden="true">TDS</span>
      <span class="tds-header__brand-text">Capacitação</span>
    </a>

    <input type="checkbox" id="tds-menu-toggle" class="tds-menu-toggle" aria-hidden="true">
    <label for="tds-menu-toggle" class="tds-menu-btn" aria-label="Abrir menu">
      <span class="tds-menu-btn__bars" aria-hidden="true">
        <span class="tds-menu-btn__bar"></span>
        <span class="tds-menu-btn__bar"></span>
        <span class="tds-menu-btn__bar"></span>
      </span>
      <span class="tds-menu-btn__label">Menu</span>
    </label>

    <label for="tds-menu-toggle" class="tds-nav-backdrop" aria-hidden="true"></label>

    <nav class="tds-nav" aria-label="Menu principal">
      <div class="tds-nav__search">
        <form role="search" method="get" class="tds-search-form" action="<?= esc_url(home_url('/')) ?>">
          <label>
            <span class="screen-reader-text">Pesquisar por:</span>
            <input type="search" class="tds-search-field" placeholder="O que você quer aprender?" value="<?= get_search_query() ?>" name="s">
          </label>
          <button type="submit" class="tds-search-submit" aria-label="Pesquisar">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
          </button>
        </form>
      </div>

      <?php if ($menu_exists): ?>
        <?php
        wp_nav_menu([
            'theme_location' => 'primary',
            'container'      => false,
            'menu_class'     => 'tds-nav__menu',
            'fallback_cb'    => false,
            'depth'          => 1,
        ]);
        ?>
      <?php else: ?>
        <ul class="tds-nav__menu">
          <li><a href="<?= esc_url(home_url('/')) ?>">Início</a></li>
          <?php foreach (['sobre' => 'Sobre', 'metodologia' => 'Metodologia', 'cursos' => 'Cursos', 'tutorial' => 'Como Funciona', 'contato' => 'Contato'] as $slug => $label):
              $p = get_page_by_path($slug);
              if ($p): ?>
            <li><a href="<?= esc_url(get_permalink($p)) ?>"><?= esc_html($label) ?></a></li>
          <?php endif; endforeach; ?>
        </ul>
      <?php endif; ?>

      <div class="tds-nav__cta">
        <?php if (is_user_logged_in()): ?>
          <a href="<?= esc_url(home_url('/minha-area/')) ?>" class="tds-btn tds-btn--amarelo">Minha Área</a>
          <a href="<?= esc_url(wp_logout_url(home_url())) ?>" class="tds-btn tds-btn--ghost">Sair</a>
        <?php else: ?>
          <a href="<?= esc_url(wp_login_url(home_url())) ?>" class="tds-btn tds-btn--amarelo">Entrar</a>
          <a href="<?= esc_url(wp_registration_url()) ?>" class="tds-btn tds-btn--ghost">Cadastrar</a>
        <?php endif; ?>
      </div>
    </nav>
  </div>
</header>
    <?php
}, 5);

// JS mínimo: fecha menu em ESC, em clique de link, e atualiza aria-label
add_action('wp_footer', function (): void {
    ?>
<script>
(function(){
  // Menu Toggle
  var t = document.getElementById('tds-menu-toggle');
  var btn = document.querySelector('.tds-menu-btn');
  if(t && btn) {
    function sync(){
      btn.setAttribute('aria-label', t.checked ? 'Fechar menu' : 'Abrir menu');
      btn.setAttribute('aria-expanded', t.checked ? 'true' : 'false');
    }
    t.addEventListener('change', sync);
    sync();
    document.querySelectorAll('.tds-nav a').forEach(function(a){
      a.addEventListener('click', function(){ t.checked = false; sync(); });
    });
    document.addEventListener('keydown', function(e){
      if(e.key === 'Escape' && t.checked){ t.checked = false; sync(); }
    });
  }

  // FAQ Accordion (Smooth transition)
  document.querySelectorAll('.tds-faq details').forEach(function(details) {
    var summary = details.querySelector('summary');
    var content = details.querySelector('.tds-faq__content');
    if(!summary || !content) return;

    summary.addEventListener('click', function(e) {
      if (details.open) {
        e.preventDefault();
        content.style.opacity = '0';
        content.style.transform = 'translateY(-8px)';
        setTimeout(function() { details.open = false; }, 300);
      } else {
        // Content styles are handled by CSS [open] selector, but we can ensure clean entry
        content.style.opacity = '0';
        content.style.transform = 'translateY(-8px)';
      }
    });
  });
})();
</script>
    <?php
}, 100);

// Registra todos os templates de página TDS
add_filter('theme_page_templates', function (array $templates): array {
    return array_merge($templates, [
        'pages/home.php'         => 'TDS — Home Institucional',
        'pages/sobre.php'        => 'TDS — Sobre Nós',
        'pages/metodologia.php'  => 'TDS — Metodologia',
        'pages/contato.php'      => 'TDS — Contato',
        'pages/tutorial.php'     => 'TDS — Tutorial LearnPress',
        'pages/noticias.php'     => 'TDS — Notícias',
        'pages/minha-area.php'   => 'TDS — Minha Área',
        'pages/certificados.php' => 'TDS — Certificados',
        'pages/catalogo.php'     => 'TDS — Catálogo de Cursos',
        'pages/guia-editor.php'  => 'TDS — Guia do Editor',
        'pages/guia-chatwoot.php' => 'TDS — Guia do Chatwoot',
    ]);
});

add_filter('template_include', function (string $template): string {
    if (is_page()) {
        $allowed = [
            'pages/home.php',
            'pages/sobre.php',
            'pages/metodologia.php',
            'pages/contato.php',
            'pages/tutorial.php',
            'pages/noticias.php',
            'pages/minha-area.php',
            'pages/certificados.php',
            'pages/catalogo.php',
            'pages/guia-editor.php',
            'pages/guia-chatwoot.php',
        ];
        $tpl = get_post_meta(get_the_ID(), '_wp_page_template', true);
        if ($tpl && in_array($tpl, $allowed, true)) {
            $path = get_stylesheet_directory() . '/' . $tpl;
            if (file_exists($path)) return $path;
        }
    }
    return $template;
});

// Força remetente autorizado no Poste.io (SMTP rejeita From de outro domínio)
add_filter('wp_mail_from',      fn() => 'noreply@ipexdesenvolvimento.cloud');
add_filter('wp_mail_from_name', fn() => 'TDS Capacitação');

// SMTP: desabilita verificação SSL para comunicação interna com Poste.io
// Processa formulário de contato
add_action('admin_post_tds_contato',        'tds_handle_contato');
add_action('admin_post_nopriv_tds_contato', 'tds_handle_contato');

function tds_handle_contato(): void {
    if (!isset($_POST['tds_contato_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['tds_contato_nonce'])), 'tds_contato')) {
        wp_die('Requisição inválida.', 403);
    }
    $nome     = sanitize_text_field(wp_unslash($_POST['nome']     ?? ''));
    $email    = sanitize_email(wp_unslash($_POST['email']    ?? ''));
    $telefone = sanitize_text_field(wp_unslash($_POST['telefone'] ?? ''));
    $assunto  = sanitize_text_field(wp_unslash($_POST['assunto']  ?? ''));
    $mensagem = sanitize_textarea_field(wp_unslash($_POST['mensagem'] ?? ''));

    if (!$nome || !is_email($email) || !$assunto || !$mensagem) {
        wp_safe_redirect(add_query_arg('contato', 'erro', wp_get_referer()));
        exit;
    }

    $to      = 'tdsdados@gmail.com';
    $subject = '[TDS Contato] ' . $assunto . ' — ' . $nome;
    $body    = "Nome: $nome\nE-mail: $email\nTelefone: $telefone\nAssunto: $assunto\n\nMensagem:\n$mensagem";
    $headers = [
        'Content-Type: text/plain; charset=UTF-8',
        "Reply-To: $nome <$email>",
        'From: TDS Contato <noreply@ipexdesenvolvimento.cloud>',
        'Cc: atendimento@ipexdesenvolvimento.cloud',
    ];

    wp_mail($to, $subject, $body, $headers);

    wp_safe_redirect(add_query_arg('contato', 'ok', wp_get_referer()));
    exit;
}

add_action('phpmailer_init', function (PHPMailer\PHPMailer\PHPMailer $phpmailer): void {
    $phpmailer->SMTPOptions = [
        'ssl' => [
            'verify_peer'      => false,
            'verify_peer_name' => false,
            'allow_self_signed' => true,
        ],
    ];
});

// ============================================================
// SEO — Open Graph fallback + robots.txt aprimorado
// ============================================================

// Open Graph para páginas sem imagem (fallback com logo TDS)
add_action('wp_head', function (): void {
    $logo = get_stylesheet_directory_uri() . '/assets/logos/logo-tds.png';
    $has_rm = defined('RANK_MATH_VERSION'); // Rank Math já emite OG quando ativo

    if (!$has_rm) {
        $title = is_singular() ? get_the_title() : get_bloginfo('name');
        $desc  = is_singular() ? (get_the_excerpt() ?: get_bloginfo('description')) : get_bloginfo('description');
        $url   = is_singular() ? get_permalink() : home_url('/');
        $img   = (is_singular() && has_post_thumbnail()) ? get_the_post_thumbnail_url(null, 'large') : $logo;
        ?>
<meta property="og:type"        content="<?= is_singular('post') ? 'article' : 'website' ?>">
<meta property="og:title"       content="<?= esc_attr($title) ?>">
<meta property="og:description" content="<?= esc_attr(wp_trim_words($desc, 20)) ?>">
<meta property="og:url"         content="<?= esc_url($url) ?>">
<meta property="og:image"       content="<?= esc_url($img) ?>">
<meta property="og:locale"      content="pt_BR">
<meta property="og:site_name"   content="TDS Capacitação">
        <?php
    }

    // Google Search Console — adicione o código de verificação abaixo quando disponível
    // define('TDS_GSC_VERIFICATION', 'google_XXXX'); // substitua pelo token
    if (defined('TDS_GSC_VERIFICATION') && TDS_GSC_VERIFICATION) {
        echo '<meta name="google-site-verification" content="' . esc_attr(TDS_GSC_VERIFICATION) . '">' . "\n";
    }
}, 5);

// Sitemap: oculta usuários, tags e páginas privadas/internas
add_filter('wp_sitemaps_add_provider', function ($provider, string $name) {
    return in_array($name, ['users', 'tags'], true) ? false : $provider;
}, 10, 2);

// Sitemap: exclui páginas marcadas como noindex (WooCommerce, LearnPress, áreas privadas)
add_filter('wp_sitemaps_posts_query_args', function (array $args, string $post_type): array {
    if ($post_type !== 'page') return $args;
    $args['meta_query'] = [
        'relation' => 'OR',
        [
            'key'     => 'rank_math_robots',
            'value'   => 'noindex',
            'compare' => 'NOT LIKE',
        ],
        [
            'key'     => 'rank_math_robots',
            'compare' => 'NOT EXISTS',
        ],
    ];
    return $args;
}, 10, 2);

// Robots.txt aprimorado
add_filter('robots_txt', function (string $output): string {
    $lines = [
        'User-agent: *',
        'Disallow: /wp-admin/',
        'Disallow: /wp-login.php',
        'Disallow: /wp-json/',
        'Disallow: /cart/',
        'Disallow: /checkout/',
        'Disallow: /meu-perfil/',
        'Disallow: /minha-area/',
        'Allow: /wp-admin/admin-ajax.php',
        '',
        '# Evitar indexação de conteúdo woocommerce/lms sensível',
        'Disallow: /wp-content/uploads/wc-logs/',
        'Disallow: /wp-content/uploads/woocommerce_transient_files/',
        '',
        'Sitemap: ' . home_url('/sitemap_index.xml'),
        '',
        '# Yandex',
        'User-agent: Yandex',
        'Clean-param: utm_source&utm_medium&utm_campaign&utm_term&utm_content',
    ];
    return implode("\n", $lines) . "\n";
}, 99);

// Remover generator tag (segurança)
remove_action('wp_head', 'wp_generator');

// Google Analytics 4
add_action('wp_head', function (): void {
    ?>
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-7B9JLYWLH4"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-7B9JLYWLH4');
</script>
    <?php
}, 2);
