<?php
// WP-5 server-side public API adapter tests with explicit WordPress doubles.
define( 'ABSPATH', __DIR__ );

$http_queue = array();
$http_calls = array();
$transients = array();
$transient_ttls = array();

function absint( $value ) { return abs( (int) $value ); }
function sanitize_title( $value ) {
	$value = strtolower( trim( (string) $value ) );
	$value = preg_replace( '/[^a-z0-9]+/', '-', $value );
	return trim( $value, '-' );
}
function sanitize_text_field( $value ) { return is_string( $value ) ? trim( strip_tags( $value ) ) : ''; }
function wp_parse_url( $url ) { return parse_url( $url ); }
function esc_url_raw( $url ) { return $url; }
function wp_safe_remote_get( $url, $args ) {
	$GLOBALS['http_calls'][] = array( 'url' => $url, 'args' => $args );
	return array_shift( $GLOBALS['http_queue'] );
}
function is_wp_error( $value ) { return $value instanceof WP_Error; }
function wp_remote_retrieve_response_code( $response ) { return $response['response']['code'] ?? 0; }
function wp_remote_retrieve_body( $response ) { return $response['body'] ?? ''; }
function get_transient( $key ) { return array_key_exists( $key, $GLOBALS['transients'] ) ? $GLOBALS['transients'][ $key ] : false; }
function set_transient( $key, $value, $ttl ) {
	$GLOBALS['transients'][ $key ] = $value;
	$GLOBALS['transient_ttls'][ $key ] = $ttl;
	return true;
}
function delete_transient( $key ) {
	unset( $GLOBALS['transients'][ $key ], $GLOBALS['transient_ttls'][ $key ] );
	return true;
}
class WP_Error {}

require __DIR__ . '/../../tds-portal-core/includes/class-tds-public-config.php';
require __DIR__ . '/../../tds-portal-core/includes/interface-tds-courses-adapter.php';
require __DIR__ . '/../../tds-portal-core/includes/class-tds-http-courses-adapter.php';
require __DIR__ . '/../../tds-portal-core/includes/class-tds-courses-service.php';

$checks = 0;
function wp5_check( $condition, $name ) {
	if ( ! $condition ) { throw new RuntimeException( 'FAIL: ' . $name ); }
	$GLOBALS['checks']++;
}
function response( $status, $body = null ) {
	return array(
		'response' => array( 'code' => $status ),
		'body' => null === $body ? '' : json_encode( $body ),
	);
}
function course( $slug = 'safe' ) {
	return array(
		'slug' => $slug,
		'title' => 'Curso público',
		'status' => 'published',
		'published_version_label' => 'v3',
		'updated_at' => '2026-10-03T12:00:00+00:00',
		'summary' => 'Resumo público',
		'cover_public_url' => 'https://cdn.example.org/cover.webp',
		'public_workload_text' => '80h',
		'public_audience_text' => 'Público informado',
		'enrollment_id' => 'must-not-leak',
		'sections' => array( array( 'private' => true ) ),
	);
}

$adapter = new TDS_HTTP_Courses_Adapter( 'https://api.example.org', 4 );
$service = new TDS_Courses_Service( $adapter );

$http_queue[] = response(
	200,
	array(
		'courses' => array( course() ),
		'offset' => 2,
		'limit' => 2,
		'total' => 3,
	)
);
$catalog = $service->public_catalog( 2, 2 );
wp5_check( 'ready' === $catalog['state'], 'catalog live ready' );
wp5_check( 3 === $catalog['pagination']['total'], 'catalog total preserved' );
wp5_check( 1 === count( $catalog['courses'] ), 'catalog one item' );
wp5_check( ! isset( $catalog['courses'][0]['enrollment_id'], $catalog['courses'][0]['sections'] ), 'catalog allowlist strips private fields' );
wp5_check( 'https://api.example.org/public/courses?offset=2&limit=2' === $http_calls[0]['url'], 'uses only public catalog endpoint' );
wp5_check( 4 === $http_calls[0]['args']['timeout'] && 0 === $http_calls[0]['args']['redirection'], 'timeout and no redirect' );
wp5_check( ! isset( $http_calls[0]['args']['headers']['Authorization'] ), 'no credential header' );

$before = count( $http_calls );
$cached = $service->public_catalog( 2, 2 );
wp5_check( $cached === $catalog && $before === count( $http_calls ), 'fresh cache avoids network' );

foreach ( $transient_ttls as $key => $ttl ) {
	if ( TDS_HTTP_Courses_Adapter::FRESH_TTL === $ttl ) {
		unset( $transients[ $key ], $transient_ttls[ $key ] );
	}
}
$http_queue[] = new WP_Error();
$stale = $service->public_catalog( 2, 2 );
wp5_check( 'ready' === $stale['state'] && $stale['courses'] === $catalog['courses'], 'network failure falls back to short stale cache' );

$http_queue[] = response( 200, array( 'courses' => array(), 'offset' => 0, 'limit' => 1 ) );
$malformed = $service->public_catalog( 1, 1 );
wp5_check( 'error' === $malformed['state'] && array() === $malformed['courses'], 'malformed upstream fails closed' );

$http_queue[] = response( 200, course( 'detail' ) );
$detail = $service->public_course( 'detail' );
wp5_check( 'ready' === $detail['state'] && 'detail' === $detail['course']['slug'], 'detail live ready' );
wp5_check( ! isset( $detail['course']['enrollment_id'], $detail['course']['sections'] ), 'detail allowlist strips private fields' );
$detail_call = end( $http_calls );
wp5_check( 'https://api.example.org/public/courses/detail' === $detail_call['url'], 'uses only public detail endpoint' );

$before = count( $http_calls );
$detail_cached = $service->public_course( 'detail' );
wp5_check( $detail_cached === $detail && $before === count( $http_calls ), 'detail fresh cache avoids network' );

foreach ( $transient_ttls as $key => $ttl ) {
	if ( TDS_HTTP_Courses_Adapter::FRESH_TTL === $ttl ) {
		unset( $transients[ $key ], $transient_ttls[ $key ] );
	}
}
$http_queue[] = response( 404 );
$missing = $service->public_course( 'detail' );
wp5_check( 'not_found' === $missing['state'] && null === $missing['course'], 'authoritative 404 does not serve stale detail' );

$before = count( $http_calls );
$invalid = $service->public_course( '../private' );
wp5_check( 'not_found' === $invalid['state'] && $before === count( $http_calls ), 'invalid slug never reaches network' );

$offline = new TDS_Courses_Service( new TDS_HTTP_Courses_Adapter( '', 2 ) );
wp5_check( 'error' === $offline->public_catalog( 1, 12 )['state'], 'missing API base fails closed without network' );

foreach ( $http_calls as $call ) {
	wp5_check( false === strpos( $call['url'], '/courses?' ) || false !== strpos( $call['url'], '/public/courses?' ), 'never calls private Flutter catalog route' );
}

echo 'PASS: ' . $checks . " WP-5 adapter assertions (server-side doubles).\n";
