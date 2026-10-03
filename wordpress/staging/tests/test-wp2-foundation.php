<?php
// Behavioral PHP tests. These explicit WordPress doubles do not prove WP integration.
define( 'ABSPATH', __DIR__ );
set_error_handler( static function ( $severity, $message, $file, $line ) { throw new ErrorException( $message, 0, $severity, $file, $line ); } );
$actions = $routes = $settings = $fields = array();
$option = '';
$can_manage = true;
function add_action( $hook, $callback ) { $GLOBALS['actions'][ $hook ] = $callback; }
function register_rest_route( $namespace, $route, $args ) { $GLOBALS['routes'][ $namespace . $route ] = $args; }
function register_setting( $group, $name, $args ) { $GLOBALS['settings'][ $name ] = array( $group, $args ); }
function add_settings_field( $id, $title, $callback, $page, $section, $args ) { $GLOBALS['fields'][ $id ] = array( $callback, $page, $args ); }
function get_option( $name, $default ) { return $GLOBALS['option']; }
function current_user_can( $cap ) { return $GLOBALS['can_manage'] && 'manage_options' === $cap; }
function wp_parse_url( $url ) { return parse_url( $url ); }
function esc_url_raw( $url ) { return $url; }
function sanitize_text_field( $text ) { return trim( strip_tags( $text ) ); }
function esc_attr( $text ) { return htmlspecialchars( $text, ENT_QUOTES, 'UTF-8' ); }
function absint( $value ) { return abs( (int) $value ); }
class WP_REST_Server { const READABLE = 'GET'; }
class WP_REST_Request {
    private $params;
    public function __construct( $params ) { $this->params = $params; }
    public function get_param( $key ) { return $this->params[ $key ] ?? null; }
}
class WP_REST_Response {
    public $data;
    public $status;
    public function __construct( $data, $status ) { $this->data = $data; $this->status = $status; }
}
require __DIR__ . '/../../tds-portal-core/tds-portal-core.php';
$checks = 0;
function check( $condition, $name ) {
    if ( ! $condition ) { throw new RuntimeException( 'FAIL: ' . $name ); }
    ++$GLOBALS['checks'];
}
function catalog( $result ) {
    return ( new TDS_Courses_Service( new class( $result ) implements TDS_Courses_Adapter_Interface {
        private $result;
        public function __construct( $result ) { $this->result = $result; }
        public function fetch_courses( $page = 1, $per_page = 12 ) {
            if ( $this->result instanceof Throwable ) { throw $this->result; }
            return $this->result;
        }
    } ) )->public_catalog();
}
$course = array( 'slug' => 'synthetic-course', 'title' => 'Synthetic course', 'status' => 'published', 'published_version_label' => 'v1', 'updated_at' => '2026-10-03T00:00:00Z' );
$ready = array( 'state' => 'ready', 'courses' => array( $course ), 'pagination' => array( 'total' => 1 ) );
check( 'unavailable' === TDS_Public_Config::get()['integration_state']['app'], 'missing app config' );
foreach ( array( '', null, array(), 'http://example.org', 'javascript:alert(1)', 'https://user:pass@example.org', 'https://localhost', 'https://127.0.0.1', 'https://10.0.0.1', 'https://portal.internal', 'https://example.org:444', "https://example.org/\nx", 'https://example.org\\x' ) as $url ) {
    check( '' === TDS_Public_Config::validated_url( $url ), 'invalid app URL rejected' );
}
$option = 'https://play.google.com/store/apps/details?id=org.example.synthetic';
check( $option === TDS_Public_Config::get()['app_access_url'], 'store query retained' );
check( 'ready' === TDS_Public_Config::get()['integration_state']['app'], 'configured app ready' );
check( 'disabled' === TDS_Public_Config::get()['integration_state']['analytics'] && 'disabled' === TDS_Public_Config::get()['integration_state']['support'], 'integrations off' );
$actions['admin_init']();
check( 'general' === $settings['tds_app_access_url'][0] && false === $settings['tds_app_access_url'][1]['show_in_rest'], 'native Settings API group and REST off' );
ob_start(); $fields['tds_app_access_url'][0](); $html = ob_get_clean();
check( false !== strpos( $html, 'name="tds_app_access_url"' ), 'single field renders' );
$can_manage = false;
ob_start(); $fields['tds_app_access_url'][0](); $html = ob_get_clean();
check( '' === $html, 'non-admin field hidden' );
$actions['rest_api_init']();
$route = $routes['tds-portal/v1/public/courses'];
check( 'GET' === $route['methods'] && '__return_true' === $route['permission_callback'], 'public read only route' );
check( 50 === $route['args']['per_page']['maximum'], 'REST page limit declared' );
$response = $route['callback']( new WP_REST_Request( array( 'page' => 1, 'per_page' => 12 ) ) );
check( 503 === $response->status && array() === $response->data['courses'], 'bootstrap stays offline without fixture' );
foreach ( array( 'disabled' => 503, 'unavailable' => 503, 'error' => 502, 'ready' => 200 ) as $state => $status ) {
    $fake = new TDS_Fake_Courses_Adapter( $state, array( $course ) );
    $response = ( new TDS_Public_Courses_Controller( new TDS_Courses_Service( $fake ) ) )->get_courses( new WP_REST_Request( array( 'page' => 1, 'per_page' => 12 ) ) );
    check( $status === $response->status && $state === $response->data['state'], 'HTTP for ' . $state );
    check( ! isset( $response->data['source'] ), 'internal fake metadata omitted' );
}
foreach ( array( null, array(), array( 'state' => 'invented' ), new RuntimeException( 'private diagnostic' ), new TypeError( 'private diagnostic' ), array( 'state' => 'ready', 'courses' => array(), 'pagination' => 'invalid' ) ) as $bad ) {
    $out = catalog( $bad );
    check( 'error' === $out['state'] && array() === $out['courses'] && false === strpos( json_encode( $out ), 'private' ), 'fail closed invalid/exception' );
}
$injected = $ready;
$injected['internal'] = 'private'; $injected['courses'][0]['enrollment'] = 'private';
check( catalog( $injected )['courses'] === array( $course ) && ! isset( catalog( $injected )['internal'] ), 'explicit course and envelope whitelist' );
$bad = $ready; $bad['courses'][] = array( 'title' => 'invalid' ); $bad['pagination']['total'] = 2;
check( array() === catalog( $bad )['courses'], 'partial catalog never leaks' );
foreach ( array( 'slug', 'title', 'status', 'published_version_label', 'updated_at' ) as $field ) {
    $bad = $ready; $bad['courses'][0][ $field ] = '<b></b>';
    check( 'error' === catalog( $bad )['state'] && array() === catalog( $bad )['courses'], 'required field empty after sanitization: ' . $field );
}
foreach ( array( 'status' => 'draft', 'title' => array(), 'cover_public_url' => 'https://example.org/a?token=x' ) as $key => $value ) {
    $bad = $ready; $bad['courses'][0][ $key ] = $value;
    check( 'error' === catalog( $bad )['state'], 'reject unsafe course field ' . $key );
}
$empty = array( 'state' => 'ready', 'courses' => array(), 'pagination' => array( 'total' => 0 ) );
check( 'ready' === catalog( $empty )['state'], 'valid empty is ready' );
$fake = new TDS_Fake_Courses_Adapter( 'ready', array( $course, array_merge( $course, array( 'slug' => 'second-course' ) ) ) );
$service = new TDS_Courses_Service( $fake );
check( 'second-course' === $service->public_catalog( 2, 1 )['courses'][0]['slug'], 'fixture pagination' );
check( $service->public_catalog( 2, 1 ) === $service->public_catalog( 2, 1 ), 'deterministic repeated reads' );
check( 1 === $service->public_catalog( -5, 100 )['pagination']['page'] && 50 === $service->public_catalog( -5, 100 )['pagination']['per_page'], 'service clamps direct callers' );
echo 'PASS: ' . $checks . " behavioral assertions (WordPress doubles; no WordPress runtime/staging).\n";
