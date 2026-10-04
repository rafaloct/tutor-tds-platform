<?php
define( 'ABSPATH', __DIR__ );

$registered_filters = array();
$story_posts = array();
$current_post_id = 0;
$last_query_args = array();

function add_filter( $hook, $callback, $priority = 10, $accepted_args = 1 ) {
	$GLOBALS['registered_filters'][ $hook ] = array( $callback, $priority, $accepted_args );
}
function get_the_ID() { return $GLOBALS['current_post_id']; }
function get_the_title( $post_id ) { return $GLOBALS['story_posts'][ $post_id ]['title']; }
function get_permalink( $post_id ) { return 'https://portal.example.org/' . $GLOBALS['story_posts'][ $post_id ]['slug'] . '/'; }
function get_post_field( $field, $post_id ) { return $GLOBALS['story_posts'][ $post_id ][ $field ]; }
function has_excerpt( $post_id ) { return '' !== $GLOBALS['story_posts'][ $post_id ]['excerpt']; }
function get_the_excerpt( $post_id ) { return $GLOBALS['story_posts'][ $post_id ]['excerpt']; }
function wp_strip_all_tags( $value ) { return strip_tags( $value ); }
function wp_trim_words( $value, $count ) {
	$words = preg_split( '/\s+/', trim( $value ) );
	return implode( ' ', array_slice( $words, 0, $count ) );
}
function wp_reset_postdata() {}

class WP_Query {
	private $post_ids = array();
	private $position = 0;

	public function __construct( $args ) {
		$GLOBALS['last_query_args'] = $args;
		$this->post_ids = array_keys( $GLOBALS['story_posts'] );
		$this->post_ids = array_slice( $this->post_ids, 0, (int) $args['posts_per_page'] );
	}

	public function have_posts() {
		return $this->position < count( $this->post_ids );
	}

	public function the_post() {
		$GLOBALS['current_post_id'] = $this->post_ids[ $this->position ];
		$this->position++;
	}
}

require __DIR__ . '/../inc/story-provider.php';

$checks = 0;
function story_check( $condition, $label ) {
	if ( ! $condition ) {
		throw new RuntimeException( 'FAIL: ' . $label );
	}
	$GLOBALS['checks']++;
}

story_check( isset( $registered_filters['tds_portal_home_stories'] ), 'provider registered on existing WP-3 filter' );

$story_posts = array(
	10 => array(
		'title'        => 'Escuta dos territórios',
		'slug'         => 'escuta-territorios',
		'post_name'    => 'escuta-territorios',
		'post_content' => 'Conteúdo da história de escuta.',
		'excerpt'      => '62 lideranças participaram daquele encontro específico.',
	),
	20 => array(
		'title'        => 'Associativismo em Palmas',
		'slug'         => 'associativismo-palmas',
		'post_name'    => 'associativismo-palmas',
		'post_content' => 'Conteúdo da formação.',
		'excerpt'      => '61 inscritos naquela formação específica.',
	),
);

$result = tds_theme_home_stories_provider(
	array(
		'state' => 'unavailable',
		'items' => array(),
	)
);

story_check( 'success' === $result['state'], 'published stories resolve unavailable slot' );
story_check( 2 === count( $result['items'] ), 'two stories mapped' );
story_check( 'available' === $result['items'][0]['state'], 'story item available' );
story_check( ! isset( $result['items'][0]['image'] ) && ! isset( $result['items'][0]['thumbnail'] ), 'provider exposes no image' );
story_check( 'post' === $last_query_args['post_type'], 'native posts only' );
story_check( 'publish' === $last_query_args['post_status'], 'published posts only' );
story_check( 'historias' === $last_query_args['category_name'], 'stories category contract' );
story_check( 3 === $last_query_args['posts_per_page'], 'home cap remains small' );

$resolved = array(
	'state' => 'success',
	'items' => array( array( 'title' => 'Outro provider' ) ),
);
story_check( $resolved === tds_theme_home_stories_provider( $resolved ), 'resolved provider is preserved' );

$story_posts = array();
$empty = tds_theme_home_stories_provider(
	array(
		'state' => 'unavailable',
		'items' => array(),
	)
);
story_check( 'empty' === $empty['state'] && array() === $empty['items'], 'no published story returns empty' );

$pattern_one = file_get_contents( __DIR__ . '/../patterns/historia-escuta-territorios-palmas.php' );
$pattern_two = file_get_contents( __DIR__ . '/../patterns/historia-associativismo-palmas.php' );
foreach ( array( $pattern_one, $pattern_two ) as $index => $pattern ) {
	story_check( false === stripos( $pattern, '<img' ), 'pattern ' . ( $index + 1 ) . ' has no image' );
	story_check( false !== strpos( $pattern, 'REALIZADO' ), 'pattern ' . ( $index + 1 ) . ' preserves status' );
	story_check( false !== strpos( $pattern, 'Fonte' ), 'pattern ' . ( $index + 1 ) . ' preserves source' );
}
story_check( false !== strpos( $pattern_one, '62 lideranças comunitárias' ), '62 stays in story one context' );
story_check( false !== strpos( $pattern_two, '61 inscritos' ), '61 stays in story two context' );

echo 'PASS: ' . $checks . " WP-4 story assertions.\n";
