<?php
/**
 * Lint do tema: php -l em cada PHP, node --check no JS, balanço de chaves no CSS,
 * e varredura de padrões proibidos (GA/gtag, e-mail, telefone, tokens).
 * Uso: php -n tests/lint.php
 */

$root = dirname( __DIR__ );
$php = PHP_BINARY;
$failures = 0;
$checked = 0;

$iterator = new RecursiveIteratorIterator( new RecursiveDirectoryIterator( $root, FilesystemIterator::SKIP_DOTS ) );
foreach ( $iterator as $file ) {
	$path = $file->getPathname();
	$ext = strtolower( $file->getExtension() );
	$rel = str_replace( '\\', '/', substr( $path, strlen( $root ) + 1 ) );
	if ( 'php' === $ext ) {
		exec( escapeshellarg( $php ) . ' -n -l ' . escapeshellarg( $path ) . ' 2>&1', $out, $code );
		$checked++;
		if ( 0 !== $code ) {
			$failures++;
			echo "FAIL php -l $rel\n" . implode( "\n", $out ) . "\n";
		}
		$out = array();
	} elseif ( 'css' === $ext ) {
		$css = preg_replace( '#/\*.*?\*/#s', '', file_get_contents( $path ) );
		$checked++;
		if ( substr_count( $css, '{' ) !== substr_count( $css, '}' ) ) {
			$failures++;
			echo "FAIL css braces $rel\n";
		}
	} elseif ( 'js' === $ext ) {
		exec( 'node --check ' . escapeshellarg( $path ) . ' 2>&1', $out, $code );
		$checked++;
		if ( 0 !== $code ) {
			$failures++;
			echo "FAIL node --check $rel\n" . implode( "\n", $out ) . "\n";
		}
		$out = array();
	}
	// Testes contêm, deliberadamente, amostras de entradas inseguras e os
	// próprios padrões de detecção. A política de conteúdo vale para o tema
	// distribuível; os testes já são cobertos por sintaxe acima.
	if ( in_array( $ext, array( 'php', 'css', 'js', 'md' ), true ) && 0 !== strpos( $rel, 'tests/' ) ) {
		$text = file_get_contents( $path );
		$forbidden = array(
			'/gtag|googletagmanager/i' => 'analytics',
			'/\bG-[A-Z0-9]{6,20}\b/' => 'GA4 measurement id',
			'/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/' => 'e-mail literal',
			'/\(\d{2}\)\s?\d{4,5}-\d{4}/' => 'telefone',
			'/chatwoot|websiteToken|api_key|secret|password/i' => 'segredo/integração',
			'/\.apk\b/i' => 'APK',
		);
		foreach ( $forbidden as $pattern => $label ) {
			if ( preg_match( $pattern, $text ) ) {
				$failures++;
				echo "FAIL padrão proibido ($label) em $rel\n";
			}
		}
	}
}

echo "Lint: $checked arquivos verificados, $failures falhas.\n";
exit( $failures ? 1 : 0 );
