<?php
/**
 * Plugin Name: TDS — LearnPress section-items ACL guard
 * Description: Esconde itens de seção não-publicados (draft/pending/private/etc) do
 *              endpoint público LearnPress `section-items/items/{id}` para visitantes
 *              e alunos. Instrutores do curso, editores e administradores continuam
 *              vendo os itens não-publicados. Camada de extensão — não modifica o
 *              vendor LearnPress. Reversível: desativar o plugin restaura o
 *              comportamento upstream (LP 4.3.6 expõe name/status/type de drafts).
 * Version:     0.1.0
 * Requires PHP: 7.4
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Quem pode ver itens de seção NÃO-publicados.
 *
 * Escada de privilégio (qualquer uma basta):
 *  - manage_options            — administrador WP
 *  - edit_others_posts         — editor/autor WP (papel editorial)
 *  - post_author do curso pai  — instrutor/dono do curso
 *  - edit_post no curso pai    — cobre mapeamentos de cap customizados
 *
 * Aluno inscrito (subscriber) e guest falham em todos → só veem `publish`.
 *
 * @param int $course_id ID do curso dono da seção.
 */
function tds_lp_can_moderate_course_items( int $course_id ): bool {
	// Fail-closed: o curso pai precisa resolver como lp_course real ANTES de
	// qualquer exceção de privilégio. get_post(0) cairia no post global do WP —
	// id inválido jamais concede acesso editorial.
	if ( $course_id <= 0 ) {
		return false;
	}
	$course = get_post( $course_id );
	if ( ! $course instanceof WP_Post || 'lp_course' !== $course->post_type ) {
		return false;
	}
	if ( ! is_user_logged_in() ) {
		return false;
	}
	if ( current_user_can( 'manage_options' ) || current_user_can( 'edit_others_posts' ) ) {
		return true;
	}
	if ( (int) $course->post_author === get_current_user_id() ) {
		return true;
	}
	return current_user_can( 'edit_post', $course_id );
}

/**
 * Filtro pós-callback na resposta REST: remove itens não-publicados da lista
 * `learnpress/v1/section-items/items/{section_id}` para não-moderadores e
 * recalcula X-WP-Total/X-WP-TotalPages após a filtragem.
 */
function tds_lp_section_items_acl_filter( $response, $handler, $request ) {
	if ( ! $request instanceof WP_REST_Request ) {
		return $response;
	}
	if ( ! preg_match( '#^/learnpress/v1/section-items/items/(\d+)$#', $request->get_route(), $m ) ) {
		return $response;
	}
	if ( is_wp_error( $response ) || ! $response instanceof WP_REST_Response ) {
		return $response;
	}

	$course_id = 0;
	if ( class_exists( 'LP_Section_DB' ) ) {
		$course_id = (int) LP_Section_DB::getInstance()->get_course_id_by_section( (int) $m[1] );
	}
	if ( tds_lp_can_moderate_course_items( $course_id ) ) {
		return $response;
	}

	$data = $response->get_data();
	if ( ! is_array( $data ) ) {
		// Fail-closed: shape inesperado não pode vazar a resposta original para
		// não-moderadores — nega com conjunto vazio explícito (sem corpo bruto).
		$response->set_data( array() );
		$response->header( 'X-WP-Total', 0 );
		$response->header( 'X-WP-TotalPages', 0 );
		return $response;
	}

	$filtered = array_values(
		array_filter(
			$data,
			function ( $item ) {
				if ( ! is_array( $item ) || empty( $item['id'] ) ) {
					return false;
				}
				$post = get_post( (int) $item['id'] );
				return $post && 'publish' === $post->post_status;
			}
		)
	);

	$response->set_data( $filtered );

	$total    = count( $filtered );
	$per_page = max( 1, (int) ( $request->get_param( 'per_page' ) ?: 10 ) );
	$response->header( 'X-WP-Total', $total );
	$response->header( 'X-WP-TotalPages', (int) ceil( $total / $per_page ) );

	return $response;
}
add_filter( 'rest_request_after_callbacks', 'tds_lp_section_items_acl_filter', 10, 3 );
