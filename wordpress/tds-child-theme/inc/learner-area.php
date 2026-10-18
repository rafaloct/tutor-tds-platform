<?php
/** Minha área EAD: conta LearnPress projetada com identidade TDS. Sem autoridade acadêmica. */

defined( 'ABSPATH' ) || exit;

/** LearnPress disponível para a área do estudante? */
function tds_theme_learner_area_available() {
	return function_exists( 'learn_press_get_current_profile_tab' ) || shortcode_exists( 'learn_press_profile' );
}

function tds_theme_learner_login_url() {
	$redirect = is_page() ? get_permalink() : home_url( '/minha-area/' );
	return wp_login_url( $redirect );
}

function tds_theme_learner_register_url() {
	$cadastro = get_page_by_path( 'cadastro' );
	if ( $cadastro && 'publish' === $cadastro->post_status ) {
		return get_permalink( $cadastro );
	}
	return wp_registration_url();
}

function tds_theme_learner_area_url() {
	$profile = get_page_by_path( 'minha-area' );
	return $profile ? get_permalink( $profile ) : home_url( '/minha-area/' );
}

function tds_theme_learner_courses_url() {
	// Só gera rota de aba quando o LearnPress resolve um link real; caso contrário
	// aponta para páginas publicadas em vez de adivinhar /minha-area/<user>/courses/.
	if ( is_user_logged_in() && class_exists( 'LP_Profile' ) ) {
		try {
			$link = LP_Profile::instance()->get_tab_link( 'courses' );
			if ( is_string( $link ) && '' !== $link ) {
				return $link;
			}
		} catch ( Throwable $e ) { // phpcs:ignore Generic.CodeAnalysis.EmptyStatement.DetectedCatch -- fallback abaixo
		}
	}
	$meus_cursos = get_page_by_path( 'meus-cursos' );
	return $meus_cursos ? get_permalink( $meus_cursos ) : tds_theme_learner_area_url();
}

/** Estado desconectado: CTA de entrada sem simular sessão nem duplicar cadastro. */
function tds_theme_learner_area_guest() {
	$courses = get_page_by_path( 'cursos' );
	echo '<section class="tds-learner-area tds-learner-area--guest" data-tds-component="learner-area" data-tds-state="guest">';
	echo '<div class="tds-learner-area__intro">';
	echo '<img class="tds-learner-area__mark" src="' . esc_url( tds_theme_logo_url( true ) ) . '" width="96" height="80" alt="" loading="eager" decoding="async">';
	echo '<h2 class="tds-learner-area__title">' . esc_html__( 'Entre na sua conta EAD', 'tds-portal' ) . '</h2>';
	echo '<p class="tds-learner-area__text">' . esc_html__( 'A conta EAD é criada no site para acompanhar suas inscrições, lições, quizzes e progresso nos cursos on-line. Ela é diferente da conta institucional usada no aplicativo Tutor TDS.', 'tds-portal' ) . '</p>';
	echo '<div class="tds-cluster">';
	echo tds_theme_button( __( 'Entrar', 'tds-portal' ), tds_theme_learner_login_url(), 'primary' ); // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
	echo tds_theme_button( __( 'Criar conta EAD', 'tds-portal' ), tds_theme_learner_register_url(), 'outline' ); // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
	echo '</div>';
	if ( $courses ) {
		echo '<p class="tds-learner-area__hint"><a href="' . esc_url( get_permalink( $courses ) ) . '">' . esc_html__( 'Ver os cursos disponíveis sem entrar na conta', 'tds-portal' ) . '</a></p>';
	}
	echo '</div>';
	echo '</section>';
}

/** Saudação e atalhos da conta conectada, antes do perfil LearnPress. */
function tds_theme_learner_area_head( WP_User $user ) {
	echo '<header class="tds-learner-area__head">';
	echo '<p class="tds-eyebrow">' . esc_html__( 'Conta EAD', 'tds-portal' ) . '</p>';
	echo '<h2 class="tds-learner-area__title">' . esc_html( sprintf( /* translators: %s: display name */ __( 'Olá, %s', 'tds-portal' ), $user->display_name ? $user->display_name : $user->user_login ) ) . '</h2>';
	echo '<p class="tds-learner-area__text">' . esc_html__( 'Aqui ficam suas inscrições, lições, quizzes e o progresso dos cursos EAD. Certificados oficiais do Programa TDS seguem o fluxo institucional, com revisão da equipe.', 'tds-portal' ) . '</p>';
	echo '<nav class="tds-learner-area__nav" aria-label="' . esc_attr__( 'Atalhos da sua área', 'tds-portal' ) . '">';
	echo '<ul class="tds-learner-area__links">';
	echo '<li>' . tds_theme_button( __( 'Meus cursos', 'tds-portal' ), tds_theme_learner_courses_url(), 'outline' ) . '</li>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
	$cert = get_page_by_path( 'certificados' );
	if ( $cert ) {
		echo '<li>' . tds_theme_button( __( 'Certificados', 'tds-portal' ), get_permalink( $cert ), 'outline' ) . '</li>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
	}
	echo '<li>' . tds_theme_button( __( 'Sair', 'tds-portal' ), wp_logout_url( home_url( '/' ) ), 'outline' ) . '</li>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
	echo '</ul></nav>';
	echo '</header>';
}

/** Corpo da Minha área: perfil LearnPress quando ativo; estado honesto quando ausente. */
function tds_theme_learner_area( $args = array() ) {
	if ( post_password_required() ) {
		return;
	}
	if ( ! is_user_logged_in() ) {
		tds_theme_learner_area_guest();
		return;
	}
	$user = wp_get_current_user();
	echo '<section class="tds-learner-area" data-tds-component="learner-area" data-tds-state="connected">';
	tds_theme_learner_area_head( $user );
	if ( tds_theme_learner_area_available() ) {
		echo '<div class="tds-learner-area__profile">';
		echo do_shortcode( '[learn_press_profile]' ); // phpcs:ignore WordPress.Security.EscapeOutput -- saída própria do LMS
		echo '</div>';
	} else {
		tds_theme_state_notice(
			'unavailable',
			array(
				'title' => __( 'Área de estudo temporariamente indisponível', 'tds-portal' ),
				'text'  => __( 'O ambiente de cursos está em manutenção. Tente novamente mais tarde; sua conta e inscrições estão preservadas.', 'tds-portal' ),
			)
		);
	}
	echo '</section>';
}

/** Lista somente os cursos inscritos: mesma autoridade LP, atalho para a aba cursos. */
function tds_theme_learner_courses( $args = array() ) {
	if ( post_password_required() ) {
		return;
	}
	if ( ! is_user_logged_in() ) {
		tds_theme_learner_area_guest();
		return;
	}
	// O perfil LP só renderiza na página configurada; aqui apontamos para a aba cursos da Minha área.
	echo '<section class="tds-learner-area" data-tds-component="learner-courses" data-tds-state="connected">';
	tds_theme_learner_area_head( wp_get_current_user() );
	if ( tds_theme_learner_area_available() ) {
		echo '<div class="tds-learner-area__intro">';
		echo '<h2 class="tds-learner-area__title">' . esc_html__( 'Seus cursos estão na Minha área', 'tds-portal' ) . '</h2>';
		echo '<p class="tds-learner-area__text">' . esc_html__( 'Inscrições, lições concluídas e progresso ficam na aba Cursos da sua área de estudo.', 'tds-portal' ) . '</p>';
		echo '<div class="tds-cluster">' . tds_theme_button( __( 'Abrir meus cursos', 'tds-portal' ), tds_theme_learner_courses_url(), 'primary' ) . '</div>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
		echo '</div>';
	} else {
		tds_theme_state_notice( 'unavailable', array( 'title' => __( 'Cursos indisponíveis temporariamente', 'tds-portal' ) ) );
	}
	echo '</section>';
}

/** Certificados: origem rotulada, nunca fundir conclusão EAD com certificado oficial TDS. */
function tds_theme_learner_certificates( $args = array() ) {
	if ( post_password_required() ) {
		return;
	}
	echo '<section class="tds-certificates" data-tds-component="certificates">';
	echo '<div class="tds-prose">';
	echo '<h2>' . esc_html__( 'Certificado oficial do Programa TDS', 'tds-portal' ) . '</h2>';
	echo '<p>' . esc_html__( 'O certificado oficial do Programa TDS é emitido pela equipe institucional após revisão de presença e requisitos do curso. Concluir lições ou quizzes no EAD não emite certificado automaticamente.', 'tds-portal' ) . '</p>';
	echo '<h2>' . esc_html__( 'Conclusão de curso no EAD', 'tds-portal' ) . '</h2>';
	echo '<p>' . esc_html__( 'O progresso e a conclusão dos cursos on-line aparecem na sua Minha área. Esses registros pertencem à plataforma de cursos (LearnPress) e não substituem o certificado institucional.', 'tds-portal' ) . '</p>';
	if ( is_user_logged_in() ) {
		echo '<p>' . tds_theme_button( __( 'Ir para Minha área', 'tds-portal' ), tds_theme_learner_area_url(), 'primary' ) . '</p>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
	} else {
		echo '<p>' . tds_theme_button( __( 'Entrar na conta EAD', 'tds-portal' ), tds_theme_learner_login_url(), 'primary' ) . '</p>'; // phpcs:ignore WordPress.Security.EscapeOutput -- escaped in tds_theme_button
	}
	echo '</div></section>';
}

function tds_theme_shortcode_minha_area( $atts ) {
	$atts = shortcode_atts( array(), $atts, 'tds_minha_area' );
	ob_start();
	tds_theme_learner_area( $atts );
	return ob_get_clean();
}

function tds_theme_shortcode_meus_cursos( $atts ) {
	$atts = shortcode_atts( array(), $atts, 'tds_meus_cursos' );
	ob_start();
	tds_theme_learner_courses( $atts );
	return ob_get_clean();
}

function tds_theme_shortcode_certificados( $atts ) {
	$atts = shortcode_atts( array(), $atts, 'tds_certificados' );
	ob_start();
	tds_theme_learner_certificates( $atts );
	return ob_get_clean();
}
