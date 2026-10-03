<?php
// WP-4 editorial contract tests with explicit WordPress doubles.
define( 'ABSPATH', __DIR__ );
$post_types = $taxonomies = $meta = array();

function register_post_type( $name, $args ) { $GLOBALS['post_types'][ $name ] = $args; }
function register_taxonomy( $name, $objects, $args ) { $GLOBALS['taxonomies'][ $name ] = array( $objects, $args ); }
function register_post_meta( $type, $key, $args ) { $GLOBALS['meta'][ $type ][ $key ] = $args; }
function sanitize_text_field( $value ) { return is_string( $value ) ? trim( strip_tags( $value ) ) : ''; }
function wp_parse_url( $url ) { return parse_url( $url ); }
function esc_url_raw( $url ) { return $url; }
function current_user_can( $cap, $post_id = null ) { return 'edit_post' === $cap && 42 === $post_id; }

require __DIR__ . '/../../tds-portal-core/includes/class-tds-public-config.php';
require __DIR__ . '/../../tds-portal-core/includes/class-tds-editorial-content.php';

$checks = 0;
function wp4_check( $condition, $name ) {
	if ( ! $condition ) { throw new RuntimeException( 'FAIL: ' . $name ); }
	$GLOBALS['checks']++;
}

TDS_Editorial_Content::register();

wp4_check( array( 'tds_event', 'tds_material' ) === array_keys( $post_types ), 'only event and material CPTs' );
foreach ( array( 'tds_event', 'tds_material' ) as $type ) {
	wp4_check( true === $post_types[ $type ]['public'], $type . ' public' );
	wp4_check( true === $post_types[ $type ]['show_in_rest'], $type . ' REST visible' );
	wp4_check( true === $post_types[ $type ]['has_archive'], $type . ' archive' );
	wp4_check( in_array( 'revisions', $post_types[ $type ]['supports'], true ), $type . ' revisions' );
}
wp4_check( 'agenda' === $post_types['tds_event']['rewrite']['slug'], 'event archive slug' );
wp4_check( 'biblioteca' === $post_types['tds_material']['rewrite']['slug'], 'material archive slug' );

wp4_check( array( 'tds_material' ) === $taxonomies['tds_material_type'][0], 'material type scoped to materials' );
wp4_check( array( 'post', 'tds_event', 'tds_material' ) === $taxonomies['tds_topic'][0], 'topic shared with public editorial content' );
wp4_check( true === $taxonomies['tds_topic'][1]['hierarchical'], 'topic hierarchical' );
wp4_check( false === $taxonomies['tds_material_type'][1]['hierarchical'], 'material type flat' );

wp4_check(
	array( 'tds_event_start_at', 'tds_event_end_at', 'tds_event_location', 'tds_event_registration_url' ) === array_keys( $meta['tds_event'] ),
	'event meta allowlist'
);
wp4_check( array( 'tds_material_public_url' ) === array_keys( $meta['tds_material'] ), 'material meta allowlist' );

foreach ( $meta as $fields ) {
	foreach ( $fields as $args ) {
		wp4_check( true === $args['show_in_rest'] && true === $args['single'] && 'string' === $args['type'], 'public scalar meta schema' );
		wp4_check( true === $args['auth_callback']( false, 'synthetic', 42 ), 'edit_post authorization' );
		wp4_check( false === $args['auth_callback']( false, 'synthetic', 43 ), 'other post denied by double' );
	}
}

wp4_check( '2026-10-03T12:30:00+00:00' === TDS_Editorial_Content::sanitize_datetime( '2026-10-03T12:30:00Z' ), 'RFC3339 normalized' );
foreach ( array( '', '2026-10-03', '2026-99-99T99:99:99Z', array() ) as $bad ) {
	wp4_check( '' === TDS_Editorial_Content::sanitize_datetime( $bad ), 'invalid datetime rejected' );
}

wp4_check( 'https://example.org/evento' === TDS_Editorial_Content::sanitize_public_url( 'https://example.org/evento' ), 'public https URL accepted' );
foreach ( array( 'http://example.org', 'https://localhost/x', 'https://127.0.0.1/x', 'https://user:pass@example.org/x' ) as $bad ) {
	wp4_check( '' === TDS_Editorial_Content::sanitize_public_url( $bad ), 'unsafe public URL rejected' );
}

wp4_check( ! isset( $post_types['tds_story'] ), 'stories remain native category, no CPT' );
echo 'PASS: ' . $checks . " WP-4 editorial assertions (WordPress doubles).\n";
