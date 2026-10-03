<?php
/**
 * Smoke do tema em WordPress descartável (marcador .tds-disposable-qa obrigatório).
 *
 * Uso: TDS_WP_QA_ROOT=<dir wordpress> php -n -d extension_dir=... -d extension=pdo_sqlite ... tests/smoke-theme.php
 * Copia o tema para a instalação, ativa, cria conteúdo sintético, sobe php -S em
 * 127.0.0.1:18743, verifica templates/estados/acessibilidade estrutural e grava
 * tests/evidence/smoke-results.json. Nunca aponte para um site real.
 */

$qa = getenv( 'TDS_WP_QA_ROOT' );
if ( ! $qa || ! is_file( $qa . '/.tds-disposable-qa' ) || 'tds-wp2-local-synthetic-only' !== trim( (string) file_get_contents( $qa . '/.tds-disposable-qa' ) ) ) {
	fwrite( STDERR, "BLOCKED: TDS_WP_QA_ROOT ausente ou sem marcador de instalação descartável.\n" );
	exit( 2 );
}
$qa = rtrim( str_replace( '\\', '/', $qa ), '/' );
$theme_src = str_replace( '\\', '/', dirname( __DIR__ ) );
$theme_dst = $qa . '/wp-content/themes/tds-child-theme';
$results = array( 'assertions' => 0, 'failures' => array(), 'pages' => array() );

function tds_copy_dir( $src, $dst ) {
	if ( is_dir( $dst ) ) {
		$it = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $dst, FilesystemIterator::SKIP_DOTS ), RecursiveIteratorIterator::CHILD_FIRST );
		foreach ( $it as $f ) {
			$f->isDir() ? rmdir( $f->getPathname() ) : unlink( $f->getPathname() );
		}
		rmdir( $dst );
	}
	mkdir( $dst, 0777, true );
	$it = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $src, FilesystemIterator::SKIP_DOTS ), RecursiveIteratorIterator::SELF_FIRST );
	foreach ( $it as $f ) {
		$rel = substr( $f->getPathname(), strlen( $src ) + 1 );
		if ( 0 === strpos( str_replace( '\\', '/', $rel ), 'tests/evidence' ) ) {
			continue;
		}
		$f->isDir() ? mkdir( $dst . '/' . $rel, 0777, true ) : copy( $f->getPathname(), $dst . '/' . $rel );
	}
}

function tds_assert( $condition, $label ) {
	global $results;
	$results['assertions']++;
	if ( ! $condition ) {
		$results['failures'][] = $label;
		echo "FAIL $label\n";
	}
}

function tds_fetch( $url ) {
	$ctx = stream_context_create( array( 'http' => array( 'ignore_errors' => true, 'timeout' => 30 ) ) );
	$body = @file_get_contents( $url, false, $ctx );
	$status = 0;
	foreach ( isset( $http_response_header ) ? $http_response_header : array() as $h ) {
		if ( preg_match( '#^HTTP/\S+\s+(\d{3})#', $h, $m ) ) {
			$status = (int) $m[1];
		}
	}
	return array( $status, (string) $body );
}

tds_copy_dir( $theme_src, $theme_dst );
if ( ! is_dir( $qa . '/wp-content/themes/astra' ) ) {
	fwrite( STDERR, "BLOCKED: tema pai Astra ausente em wp-content/themes/astra.\n" );
	exit( 2 );
}

$_SERVER['HTTP_HOST'] = '127.0.0.1:18743';
require $qa . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

// A instalação descartável define a URL canônica. O listener do smoke deve
// usar essa mesma origem para não seguir redirects a outra porta local.
$base = untrailingslashit( home_url( '/' ) );
$base_parts = wp_parse_url( $base );
if ( ! is_array( $base_parts ) || 'http' !== ( $base_parts['scheme'] ?? '' ) || '127.0.0.1' !== ( $base_parts['host'] ?? '' ) || empty( $base_parts['port'] ) ) {
	fwrite( STDERR, "BLOCKED: a instalação descartável deve usar HTTP em 127.0.0.1 com porta explícita.\n" );
	exit( 2 );
}
$server_host = $base_parts['host'];
$server_port = (int) $base_parts['port'];

tds_assert( 'local' === wp_get_environment_type(), 'ambiente local' );
switch_theme( 'tds-child-theme' );
$theme = wp_get_theme();
tds_assert( 'tds-child-theme' === $theme->get_stylesheet() && 'astra' === $theme->get_template(), 'tema ativo é o child do Astra' );
$templates = $theme->get_page_templates();
foreach ( array( 'templates/acessar.php', 'templates/programa.php', 'templates/privacidade.php', 'templates/direitos.php', 'templates/acessibilidade.php', 'templates/contato.php' ) as $tpl ) {
	tds_assert( isset( $templates[ $tpl ] ), "template registrado $tpl" );
}
$pattern_registry = WP_Block_Patterns_Registry::get_instance();
foreach ( array( 'hero-institucional', 'cta-acesso-app', 'catalogo-publico', 'cards-destaques', 'estados', 'faq' ) as $slug ) {
	tds_assert( $pattern_registry->is_registered( 'tds-portal/' . $slug ), "pattern tds-portal/$slug" );
}

// WP-3: contrato fail-closed para métricas, eventos e cards futuros.
tds_assert( '' === tds_theme_event_attributes( 'contact_submitted' ), 'analytics: evento fora da allowlist rejeitado' );
$event_attrs = tds_theme_event_attributes( 'tool_card_click', 'Área Sintética QA' );
tds_assert( false !== strpos( $event_attrs, 'tool_card_click' ) && false !== strpos( $event_attrs, 'area-sintetica-qa' ), 'analytics: somente evento e slug público' );

$stats_filter = static function () {
	return array(
		array( 'label' => 'Indicador sintético', 'value' => '12', 'source_label' => 'Fonte QA', 'source_url' => 'https://example.org/public-report' ),
		array( 'label' => 'Sem fonte', 'value' => '99' ),
		array( 'label' => 'Fonte insegura', 'value' => '3', 'source_label' => 'HTTP QA', 'source_url' => 'http://example.org/report' ),
	);
};
add_filter( 'tds_portal_public_stats', $stats_filter );
$stats = TDS_Theme_Portal_Stats_Provider::get();
tds_assert( 1 === count( $stats ) && '12' === $stats[0]['value'], 'stats: somente métrica com proveniência válida' );
remove_filter( 'tds_portal_public_stats', $stats_filter );

$tools_filter = static function () {
	return array(
		array( 'title' => str_repeat( 'Ferramenta extensa ', 10 ), 'text' => 'Texto sintético.', 'url' => 'https://example.org/tool', 'slug' => 'ferramenta-qa', 'state' => 'available' ),
		array( 'title' => 'Em preparação QA', 'state' => 'coming_soon' ),
		array( 'title' => 'Restrita QA', 'state' => 'restricted' ),
		array( 'title' => 'Oculta QA', 'state' => 'hidden' ),
	);
};
add_filter( 'tds_portal_home_tools', $tools_filter );
ob_start();
tds_theme_home_collection( 'tds_portal_home_tools', 'tool_card_click', true );
$tools_html = ob_get_clean();
remove_filter( 'tds_portal_home_tools', $tools_filter );
tds_assert( false !== strpos( $tools_html, 'data-tds-tool-state="available"' ), 'ferramentas: available' );
tds_assert( false !== strpos( $tools_html, 'data-tds-tool-state="coming_soon"' ), 'ferramentas: coming_soon' );
tds_assert( false !== strpos( $tools_html, 'data-tds-tool-state="restricted"' ), 'ferramentas: restricted' );
tds_assert( false === strpos( $tools_html, 'Oculta QA' ), 'ferramentas: hidden não renderiza' );
tds_assert( false !== strpos( $tools_html, 'data-tds-event="tool_card_click"' ), 'ferramentas: evento declarativo sem transporte' );

// Conteúdo sintético (idempotente por título).
function tds_page( $title, $template = '', $content = '', $excerpt = '' ) {
	$existing = get_page_by_path( sanitize_title( $title ), OBJECT, 'page' );
	if ( $existing ) {
		return $existing->ID;
	}
	$id = wp_insert_post( array( 'post_type' => 'page', 'post_status' => 'publish', 'post_title' => $title, 'post_content' => $content, 'post_excerpt' => $excerpt, 'page_template' => $template ) );
	return $id;
}
$home_id = tds_page( 'Início QA', '', '<!-- wp:paragraph --><p>Conteúdo editorial sintético da home.</p><!-- /wp:paragraph -->', 'Resumo sintético do programa para QA.' );
$debug_log = $qa . '/wp-content/debug.log';
$debug_offset = is_file( $debug_log ) ? filesize( $debug_log ) : 0;
$pages = array(
	'templates/programa.php'       => tds_page( 'O Programa QA', 'templates/programa.php', '<!-- wp:paragraph --><p>Texto sintético do programa.</p><!-- /wp:paragraph -->' ),
	'templates/acessar.php'        => tds_page( 'Acessar o app QA', 'templates/acessar.php', '<!-- wp:paragraph --><p>Como entrar.</p><!-- /wp:paragraph -->' ),
	'templates/privacidade.php'    => tds_page( 'Privacidade QA', 'templates/privacidade.php', '<!-- wp:paragraph --><p>Política sintética.</p><!-- /wp:paragraph -->' ),
	'templates/direitos.php'       => tds_page( 'Direitos QA', 'templates/direitos.php', '<!-- wp:paragraph --><p>Direitos sintéticos.</p><!-- /wp:paragraph -->' ),
	'templates/acessibilidade.php' => tds_page( 'Acessibilidade QA', 'templates/acessibilidade.php', '<!-- wp:paragraph --><p>Declaração sintética.</p><!-- /wp:paragraph -->' ),
	'templates/contato.php'        => tds_page( 'Contato QA', 'templates/contato.php', '<!-- wp:paragraph --><p>Contato institucional sintético.</p><!-- /wp:paragraph -->' ),
);
$states_id = tds_page( 'Estados QA', '', '[tds_estado estado="loading"][tds_estado estado="success"][tds_estado estado="empty"][tds_estado estado="stale"][tds_estado estado="unavailable"][tds_estado estado="error"][tds_catalogo quantidade="3"][tds_acesso_app]' );
if ( ! get_posts( array( 'post_type' => 'post', 'post_status' => 'publish', 'numberposts' => 1, 'title' => 'Notícia sintética QA' ) ) ) {
	wp_insert_post( array( 'post_type' => 'post', 'post_status' => 'publish', 'post_title' => 'Notícia sintética QA', 'post_content' => '<!-- wp:paragraph --><p>Corpo da notícia sintética.</p><!-- /wp:paragraph -->' ) );
}
$post = get_posts( array( 'post_type' => 'post', 'numberposts' => 1 ) );
update_option( 'show_on_front', 'page' );
update_option( 'page_on_front', $home_id );
update_option( 'blogdescription', 'Portal público sintético para QA do tema' );
update_option( TDS_Public_Config::APP_URL_OPTION, '' );

// Servidor loopback.
$php_cmd = escapeshellarg( PHP_BINARY ) . ' -n -d extension_dir=' . escapeshellarg( dirname( PHP_BINARY ) . '/ext' ) . ' -d extension=pdo_sqlite -d extension=sqlite3 -d extension=openssl -d extension=mbstring -S ' . escapeshellarg( $server_host . ':' . $server_port ) . ' -t ' . escapeshellarg( $qa );
$server = proc_open( $php_cmd, array( 0 => array( 'pipe', 'r' ), 1 => array( 'file', dirname( $qa ) . '/theme-http-out.log', 'a' ), 2 => array( 'file', dirname( $qa ) . '/theme-http-error.log', 'a' ) ), $pipes );
try {
	$ready = false;
	for ( $i = 0; $i < 40 && ! $ready; $i++ ) {
		usleep( 250000 );
		list( $status ) = tds_fetch( $base . '/' );
		$ready = $status > 0;
	}
	tds_assert( $ready, 'servidor loopback respondeu' );

	$common = static function ( $label, $html ) {
		tds_assert( false !== strpos( $html, 'class="tds-skip-link" href="#tds-main"' ), "$label: skip link" );
		tds_assert( false !== strpos( $html, '<main id="tds-main" class="tds-main" tabindex="-1"' ), "$label: main focável" );
		tds_assert( false !== strpos( $html, '<header class="tds-header"' ) && false !== strpos( $html, '<nav id="tds-primary-nav" class="tds-nav" aria-label=' ), "$label: header/nav" );
		tds_assert( false !== strpos( $html, '<footer class="tds-footer">' ), "$label: footer" );
		tds_assert( false !== strpos( $html, 'aria-expanded="false" aria-controls="tds-primary-nav"' ), "$label: toggle acessível" );
		tds_assert( preg_match( '/<body[^>]*class="[^"]*\btds-portal\b/', $html ) === 1, "$label: body.tds-portal" );
		tds_assert( substr_count( $html, '<h1' ) === 1, "$label: exatamente um h1" );
		tds_assert( false !== strpos( $html, 'name="viewport" content="width=device-width, initial-scale=1' ), "$label: viewport" );
		tds_assert( ! preg_match( '/gtag|googletagmanager|\bG-[A-Z0-9]{6,20}\b/', $html ), "$label: sem analytics" );
		tds_assert( ! preg_match( '/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/', $html ), "$label: sem e-mail no HTML" );
		tds_assert( false === stripos( $html, 'example.invalid' ) && false === stripos( $html, 'qa_admin' ), "$label: sem identidade de QA" );
		tds_assert( ! preg_match( '/<script[^>]+src="https?:\/\/(?!127\.0\.0\.1)/', $html ), "$label: sem script externo" );
		tds_assert( false !== strpos( $html, 'tds-child-theme/assets/js/navigation.js' ), "$label: navigation.js" );
	};

	list( $status, $html ) = tds_fetch( $base . '/' );
	$results['pages']['home'] = $status;
	tds_assert( 200 === $status, 'home 200' );
	$common( 'home', $html );
	tds_assert( false !== strpos( $html, 'data-tds-component="catalog" data-tds-state="unavailable"' ), 'home: catálogo unavailable' );
	tds_assert( false !== strpos( $html, 'data-tds-component="app-access" data-tds-state="unavailable"' ), 'home: acesso ao app unavailable' );
	tds_assert( false === strpos( $html, 'data-tds-action="app-access"' ), 'home: botão de acesso oculto sem URL' );
	tds_assert( false !== strpos( $html, '<meta property="og:title"' ) && false !== strpos( $html, '<link rel="canonical" href="' . $base . '/">' ), 'home: og/canonical' );
	tds_assert( false !== strpos( $html, 'Portal público sintético para QA do tema' ), 'home: descrição do site' );
	tds_assert( false !== strpos( $html, 'Notícia sintética QA' ), 'home: notícias recentes' );
	tds_assert( false !== strpos( $html, 'data-tds-event="news_click"' ), 'home: notícia com evento declarativo' );
	tds_assert( false !== strpos( $html, 'tds-child-theme/assets/img/logo-tds.png' ), 'home: logo oficial' );
	tds_assert( false !== strpos( $html, 'data-tds-event="portal_home_view"' ), 'home: evento de visualização declarativo' );
	$home_blocks = array( 'hero', 'journey', 'areas', 'courses', 'tools', 'stories', 'news', 'agenda', 'library', 'partners', 'app-access', 'certificate', 'support' );
	foreach ( $home_blocks as $block ) {
		tds_assert( false !== strpos( $html, 'data-tds-home-block="' . $block . '"' ), "home: bloco $block" );
	}
	tds_assert( 13 === substr_count( $html, 'data-tds-home-block=' ), 'home: 13 blocos visíveis sem stats não comprovados' );
	tds_assert( false === strpos( $html, 'data-tds-home-block="stats"' ), 'home: stats ocultos sem fonte' );
	tds_assert( false !== strpos( $html, 'data-tds-component="certificate-verify"' ) && false !== strpos( $html, 'Verificação oficial ainda não conectada' ), 'home: certificado fail-closed' );
	tds_assert( false !== strpos( $html, 'data-tds-component="support" data-tds-state="disabled"' ), 'home: suporte fail-closed' );

	foreach ( $pages as $tpl => $id ) {
		list( $status, $html ) = tds_fetch( get_permalink( $id ) );
		$results['pages'][ $tpl ] = $status;
		tds_assert( 200 === $status, "$tpl 200" );
		$common( $tpl, $html );
		tds_assert( false !== strpos( $html, '<header class="tds-page-header">' ), "$tpl: cabeçalho de página" );
	}
	list( , $html ) = tds_fetch( get_permalink( $pages['templates/contato.php'] ) );
	tds_assert( false !== strpos( $html, 'data-tds-state="disabled"' ) && false === strpos( $html, '<form' ), 'contato: suporte disabled e sem formulário' );
	list( , $html ) = tds_fetch( get_permalink( $pages['templates/direitos.php'] ) );
	tds_assert( false !== strpos( $html, 'Última atualização' ) && false !== strpos( $html, 'data-tds-state="disabled"' ), 'direitos: data e canal disabled' );

	list( $status, $html ) = tds_fetch( get_permalink( $states_id ) );
	$results['pages']['estados'] = $status;
	foreach ( array( 'loading', 'success', 'empty', 'stale', 'unavailable', 'error' ) as $state ) {
		tds_assert( false !== strpos( $html, 'data-tds-state="' . $state . '"' ), "estados: $state" );
	}
	tds_assert( false !== strpos( $html, 'role="alert"' ) && false !== strpos( $html, 'aria-busy="true"' ), 'estados: roles' );

	list( $status, $html ) = tds_fetch( get_permalink( $post[0] ) );
	$results['pages']['single'] = $status;
	tds_assert( 200 === $status, 'single 200' );
	$common( 'single', $html );

	list( $status, $html ) = tds_fetch( $base . '/?s=sint%C3%A9tica' );
	$results['pages']['search'] = $status;
	tds_assert( 200 === $status && false !== strpos( $html, 'tds-search-form' ), 'busca 200 com formulário' );
	$common( 'search', $html );

	list( $status, $html ) = tds_fetch( $base . '/?p=999999' );
	$results['pages']['404'] = $status;
	tds_assert( 404 === $status && false !== strpos( $html, 'tds-404' ), '404 com template próprio' );
	$common( '404', $html );

	// URL de acesso configurada pelo plugin → botão aparece; inválida → oculto.
	update_option( TDS_Public_Config::APP_URL_OPTION, 'https://app.qa-tds.example.org/entrar' );
	list( , $html ) = tds_fetch( $base . '/' );
	tds_assert( false !== strpos( $html, 'data-tds-component="app-access" data-tds-state="ready"' ) && false !== strpos( $html, 'href="https://app.qa-tds.example.org/entrar"' ) && false !== strpos( $html, 'data-tds-event="app_access_click"' ), 'app ready: botão exibido com evento declarativo' );
	update_option( TDS_Public_Config::APP_URL_OPTION, 'http://insecure.example.org/' );
	list( , $html ) = tds_fetch( $base . '/' );
	tds_assert( false !== strpos( $html, 'data-tds-state="unavailable"' ) && false === strpos( $html, 'insecure.example.org' ), 'app inválido: botão oculto' );
	update_option( TDS_Public_Config::APP_URL_OPTION, '' );

	// Plugin inativo → tema degrada para unavailable sem erro.
	deactivate_plugins( 'tds-portal-core/tds-portal-core.php' );
	list( $status, $html ) = tds_fetch( $base . '/' );
	tds_assert( 200 === $status && false !== strpos( $html, 'data-tds-component="catalog" data-tds-state="unavailable"' ), 'plugin inativo: catálogo unavailable' );
	activate_plugin( 'tds-portal-core/tds-portal-core.php' );
	tds_assert( is_plugin_active( 'tds-portal-core/tds-portal-core.php' ), 'plugin reativado' );

	$log = is_file( $debug_log ) ? (string) file_get_contents( $debug_log, false, null, $debug_offset ) : '';
	tds_assert( ! preg_match( '#themes[/\\]tds-child-theme#', $log ), 'debug.log sem avisos novos do tema' );
	if ( preg_match_all( '#^.*themes[/\\]tds-child-theme.*$#m', $log, $m ) ) {
		$results['debug_log'] = array_slice( $m[0], 0, 10 );
	}
} finally {
	if ( is_resource( $server ) ) {
		// Em PHP para Windows um processo recém-encerrado pode continuar sendo
		// um resource, mas não aceitar proc_get_status(). A limpeza permanece
		// melhor esforço e não deve transformar uma execução aprovada em fatal.
		try {
			$pid_status = proc_get_status( $server );
		} catch ( Throwable $exception ) {
			$pid_status = array();
		}
		if ( ! empty( $pid_status['pid'] ) && 'WIN' === strtoupper( substr( PHP_OS, 0, 3 ) ) ) {
			exec( 'taskkill /PID ' . (int) $pid_status['pid'] . ' /T /F >nul 2>&1' );
		}
		@proc_terminate( $server );
		if ( is_resource( $pipes[0] ) ) {
			fclose( $pipes[0] );
		}
		@proc_close( $server );
	}
}

$results['php'] = PHP_VERSION;
$results['wordpress'] = get_bloginfo( 'version' );
$results['astra'] = wp_get_theme( 'astra' )->get( 'Version' );
@mkdir( $theme_src . '/tests/evidence', 0777, true );
file_put_contents( $theme_src . '/tests/evidence/smoke-results.json', json_encode( $results, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ) . "\n" );
printf( "Smoke: %d assertivas, %d falhas. WP %s / Astra %s / PHP %s\n", $results['assertions'], count( $results['failures'] ), $results['wordpress'], $results['astra'], PHP_VERSION );
exit( $results['failures'] ? 1 : 0 );
