<?php
/**
 * Testes sintéticos fail-closed do guard section-items (Issue #270).
 * Executar via:  wp eval-file tests/acl_unit_tests.php <COURSE_ID> <DRAFT_ITEM_ID> <OTHER_POST_ID>
 *   <COURSE_ID>      — id de um lp_course (ex.: 11)
 *   <DRAFT_ITEM_ID>  — id de um item draft da seção (ex.: 13)
 *   <OTHER_POST_ID>  — id de post publish que NÃO é lp_course (ex.: 12 lp_lesson)
 * Somente dados sintéticos; nenhum nome de draft é impresso.
 */
$GLOBALS['acl_pass'] = 0;
$GLOBALS['acl_fail'] = 0;
function t( $name, $cond ) {
	if ( $cond ) { $GLOBALS['acl_pass']++; echo "PASS $name\n"; }
	else         { $GLOBALS['acl_fail']++; echo "FAIL $name\n"; }
}

$course_id     = (int) $args[0];
$draft_item_id = (int) $args[1];
$other_post_id = (int) $args[2];

$route = '/learnpress/v1/section-items/items/1';
$req   = new WP_REST_Request( 'GET', $route );

// ---- curso inválido: nega para TODOS, inclusive admin (1) ----
wp_set_current_user( 1 );
t( 'course_id=0 nega admin',            ! tds_lp_can_moderate_course_items( 0 ) );
t( 'course_id negativo nega admin',     ! tds_lp_can_moderate_course_items( -5 ) );
t( 'post não-lp_course nega admin',     ! tds_lp_can_moderate_course_items( $other_post_id ) );
t( 'curso inexistente nega admin',      ! tds_lp_can_moderate_course_items( 999999 ) );
t( 'lp_course válido permite admin',    tds_lp_can_moderate_course_items( $course_id ) );

// ---- curso válido: escada de privilégio ----
wp_set_current_user( 0 );
t( 'guest negado em lp_course',         ! tds_lp_can_moderate_course_items( $course_id ) );
wp_set_current_user( 3 ); // student-B subscriber
t( 'subscriber negado em lp_course',    ! tds_lp_can_moderate_course_items( $course_id ) );
wp_set_current_user( 4 ); // instructor-QA editor + autor do curso
t( 'editor/autor permitido',            tds_lp_can_moderate_course_items( $course_id ) );

// ---- filtro: payload não-array nega para não-moderador ----
wp_set_current_user( 0 );
$resp = new WP_REST_Response( 'payload-inesperado-string' );
$out  = tds_lp_section_items_acl_filter( $resp, null, $req );
t( 'payload string -> array vazio (guest)', is_array( $out->get_data() ) && 0 === count( $out->get_data() ) );
t( 'payload string -> X-WP-Total=0',        '0' === (string) ( $out->get_headers()['X-WP-Total'] ?? 'null' ) );

$resp2 = new WP_REST_Response( (object) [ 'unexpected' => true ] );
$out2  = tds_lp_section_items_acl_filter( $resp2, null, $req );
t( 'payload objeto -> array vazio (guest)', is_array( $out2->get_data() ) && 0 === count( $out2->get_data() ) );

// ---- filtro: item sem id / status não-public é removido p/ guest ----
$resp3 = new WP_REST_Response( [
	[ 'id' => $draft_item_id, 'status' => 'draft', 'name' => 'x' ],
	[ 'id' => $other_post_id, 'status' => 'publish', 'name' => 'y' ],
	[ 'name' => 'sem-id' ],
] );
$out3  = tds_lp_section_items_acl_filter( $resp3, null, $req );
$d3    = $out3->get_data();
t( 'lista mista -> só publish p/ guest', 1 === count( $d3 ) && $d3[0]['id'] === $other_post_id );

// ---- filtro: moderador recebe resposta original intacta ----
wp_set_current_user( 1 );
$resp4 = new WP_REST_Response( [ [ 'id' => $draft_item_id, 'status' => 'draft' ] ] );
$out4  = tds_lp_section_items_acl_filter( $resp4, null, $req );
t( 'admin vê draft (passthrough)', 1 === count( $out4->get_data() ) );

// ---- rota não relacionada: passthrough sem tocar ----
wp_set_current_user( 0 );
$req2  = new WP_REST_Request( 'GET', '/learnpress/v1/courses/11' );
$resp5 = new WP_REST_Response( [ [ 'id' => 1, 'status' => 'draft' ] ] );
$out5  = tds_lp_section_items_acl_filter( $resp5, null, $req2 );
t( 'outra rota não é filtrada', is_array( $out5->get_data() ) && 1 === count( $out5->get_data() ) );

echo "== unit: PASS={$GLOBALS['acl_pass']} FAIL={$GLOBALS['acl_fail']} ==\n";
if ( $GLOBALS['acl_fail'] ) { exit( 1 ); }
