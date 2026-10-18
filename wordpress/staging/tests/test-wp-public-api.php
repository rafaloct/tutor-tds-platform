<?php
// Explicit HTTP doubles: proves adapter behavior, not WordPress DNS or live API.
require __DIR__ . '/test-wp2-foundation.php';
$calls = array();
$dns_safe = true;
$http_response = array();
function wp_http_validate_url( $url ) { return $GLOBALS['dns_safe'] ? $url : false; }
function wp_safe_remote_get( $url, $args ) {
    $GLOBALS['calls'][] = array( $url, $args );
    return $GLOBALS['http_response'];
}
function is_wp_error( $response ) { return $response instanceof Throwable; }
function wp_remote_retrieve_response_code( $response ) { return $response['code']; }
function wp_remote_retrieve_body( $response ) { return $response['body']; }
function http_catalog( $payload, $code = 200, $page = 1, $size = 12 ) {
    $GLOBALS['http_response'] = array( 'code' => $code, 'body' => is_string( $payload ) ? $payload : json_encode( $payload ) );
    return ( new TDS_Courses_Service( new TDS_HTTP_Courses_Adapter() ) )->public_catalog( $page, $size );
}
$checks = 0;
$extra_options[TDS_Public_Config::API_URL_OPTION] = 'https://api.example.org/tutor-api';
check( 'unavailable' === http_catalog( '{}' )['state'] && 0 === count( $calls ), 'default off despite URL' );
define( 'TDS_PUBLIC_CATALOG_ENABLED', true );
foreach ( array( '', 'http://api.example.org', 'https://127.0.0.1', 'https://10.1.1.1', 'https://[::1]', 'https://user:pass@api.example.org', 'https://api.example.org:8443', 'https://api.example.org?token=secret', 'https://api.example.org/#fragment' ) as $bad ) {
    $extra_options[TDS_Public_Config::API_URL_OPTION] = $bad;
    check( 'unavailable' === http_catalog( '{}' )['state'] && 0 === count( $calls ), 'invalid destinations never requested' );
}
$extra_options[TDS_Public_Config::API_URL_OPTION] = 'https://api.example.org/tutor-api';
$dns_safe = false;
check( 'unavailable' === http_catalog( '{}' )['state'] && 0 === count( $calls ), 'DNS validation blocks destination' );
$dns_safe = true;
$course = array( 'slug' => 'synthetic', 'title' => '<b>Synthetic</b>', 'status' => 'published', 'published_version_label' => 'v1', 'updated_at' => '2026-10-15', 'summary' => null, 'student_cpf' => 'SECRET', 'access_token' => 'SECRET' );
$payload = array( 'courses' => array( $course ), 'offset' => 12, 'limit' => 12, 'total' => 13, 'private' => 'SECRET' );
$result = http_catalog( $payload, 200, 2 );
check( 'ready' === $result['state'] && 'Synthetic' === $result['courses'][0]['title'], 'real API shape and text sanitization' );
check( false === strpos( json_encode( $result ), 'SECRET' ) && ! isset( $result['courses'][0]['summary'] ), 'nonpublic fields and null optionals excluded' );
check( 2 === $result['pagination']['page'] && 13 === $result['pagination']['total'], 'page maps offset total' );
$request = end( $calls );
check( 'https://api.example.org/tutor-api/public/courses?offset=12&limit=12' === $request[0], 'only fixed public path and numeric query' );
check( 0 === $request[1]['redirection'] && true === $request[1]['sslverify'] && 5 === $request[1]['timeout'] && 1048577 === $request[1]['limit_response_size'], 'bounded TLS transport without redirects' );
check( array( 'Accept' => 'application/json' ) === $request[1]['headers'] && array() === $request[1]['cookies'], 'anonymous outbound request' );
foreach ( array( 301, 302, 401, 403, 404, 500, 503 ) as $code ) {
    check( 'error' === http_catalog( $payload, $code, 2 )['state'], 'non-200 rejects payload' );
}
foreach ( array( '', 'null', '[]', '{broken', str_repeat( ' ', 1048577 ), '{"courses":[],"offset":0,"limit":12,"total":"0"}' ) as $body ) {
    check( 'error' === http_catalog( $body )['state'], 'malformed payload rejected' );
}
check( 'error' === http_catalog( $payload )['state'], 'pagination mismatch rejected' );
$payload['offset'] = 0;
$payload['total'] = 1;
$payload['courses'][0]['status'] = 'draft';
check( 'error' === http_catalog( $payload )['state'], 'draft fails closed' );
$http_response = new RuntimeException( 'SECRET transport detail' );
$result = ( new TDS_Courses_Service( new TDS_HTTP_Courses_Adapter() ) )->public_catalog();
check( 'error' === $result['state'] && false === strpos( json_encode( $result ), 'SECRET' ), 'transport failure hides diagnostics' );
$payload['courses'] = array();
$payload['total'] = 0;
check( 'ready' === http_catalog( $payload )['state'], 'empty real catalog is ready' );
check( 'unavailable' === TDS_Public_Config::get()['integration_state']['courses'], 'configuration alone never claims health' );
echo "PASS: {$checks} public HTTP adapter checks (doubles only)\n";
