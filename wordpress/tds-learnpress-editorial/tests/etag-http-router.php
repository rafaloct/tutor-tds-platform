<?php
/** Loopback-only test router. Never part of the deployable plugin package. */
if ( 'cli-server' !== PHP_SAPI || '127.0.0.1' !== ( $_SERVER['REMOTE_ADDR'] ?? '' ) ) {
	http_response_code( 403 );
	exit;
}
ob_start();
require __DIR__ . '/test-contract.php';
ob_end_clean();
$posts[1425]->post_content = '<p>Synthetic public lesson.</p>';
$posts[1425]->post_title = 'Synthetic lesson';
update_post_meta( 1425, '_tds_mobile_public', '1' );
if ( isset( $_GET['changed'] ) ) {
	$posts[1425]->post_title .= ' revised';
}
if ( isset( $_GET['revoked'] ) ) {
	update_post_meta( 1425, '_tds_mobile_public', '0' );
}
$tag = $_SERVER['HTTP_IF_NONE_MATCH'] ?? '';
$response = isset( $_GET['lesson'] ) ? request_lesson( 1425, $tag ) : request_course( 1356, $tag );
header( 'Content-Type: application/json' );
if ( is_wp_error( $response ) ) {
	http_response_code( $response->data['status'] ?? 404 );
	echo json_encode( array( 'code' => $response->code ) );
	exit;
}
http_response_code( $response->get_status() );
$gzip = 'gzip' === ( $_SERVER['HTTP_ACCEPT_ENCODING'] ?? '' );
foreach ( $response->headers as $name => $value ) {
	// Model the observed intermediary transformation; do not alter production headers.
	header( $name . ': ' . ( $gzip && 'ETag' === $name ? 'W/' . $value : $value ) );
}
if ( 304 === $response->get_status() ) {
	exit;
}
$body = json_encode( $response->get_data() );
if ( $gzip ) {
	header( 'Content-Encoding: gzip' );
	$body = gzencode( $body );
}
echo $body;
