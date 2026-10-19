<?php

defined( 'ABSPATH' ) || exit;

/**
 * Small editorial control on the existing LearnPress lesson editor.
 * Approval is explicit, never inferred from published/preview status.
 */
final class TDS_LearnPress_Editorial_Admin {
	public static function register_box() {
		add_meta_box(
			'tds-learnpress-mobile',
			'Tutor TDS: conteúdo no aplicativo',
			array( __CLASS__, 'render' ),
			'lp_lesson',
			'side',
			'default'
		);
	}

	public static function render( $post ) {
		if ( ! current_user_can( 'edit_post', $post->ID ) ) {
			return;
		}
		wp_nonce_field( 'tds_mobile_lesson_' . $post->ID, 'tds_mobile_lesson_nonce' );
		$public = get_post_meta( $post->ID, '_tds_mobile_public', true ) === '1';
		$approved = get_post_meta( $post->ID, '_tds_mobile_rights_approved', true ) === '1';
		$youtube = (string) get_post_meta( $post->ID, '_tds_mobile_youtube_id', true );
		if ( '' === $youtube ) {
			$fingerprint = TDS_LearnPress_Editorial::mp4_source_fingerprint( $post->ID );
			$approved = $approved && null !== $fingerprint &&
				hash_equals( $fingerprint, (string) get_post_meta( $post->ID, '_tds_mobile_rights_source_fingerprint', true ) );
		}
		$poster = (string) get_post_meta( $post->ID, '_tds_mobile_poster_url', true );
		$captions = (string) get_post_meta( $post->ID, '_tds_mobile_captions_url', true );
		echo '<p><label><input type="checkbox" name="tds_mobile_public" value="1" ' . checked( $public, true, false ) . '> Publicar o texto desta aula no app para visitantes, mesmo sem matrícula</label></p>';
		echo '<p class="description">Desmarcado por padrão. Somente texto revisado e publicado. Não coloque dados pessoais ou materiais exclusivos para matriculados.</p>';
		echo '<p><label for="tds_mobile_youtube_id">ID de vídeo YouTube aprovado (11 caracteres)</label><input class="widefat" id="tds_mobile_youtube_id" name="tds_mobile_youtube_id" value="' . esc_attr( $youtube ) . '" maxlength="11"></p>';
		echo '<p><label><input type="checkbox" name="tds_mobile_rights_approved" value="1" ' . checked( $approved, true, false ) . '> Confirmo direitos e liberação editorial deste vídeo</label></p>';
		echo '<p class="description">Se mudar o ID YouTube, o MP4 ou sua legenda VTT, salve a aula e confirme os direitos em um segundo salvamento.</p>';
		echo '<p><label for="tds_mobile_poster_url">Poster WordPress HTTPS</label><input class="widefat" id="tds_mobile_poster_url" name="tds_mobile_poster_url" value="' . esc_attr( $poster ) . '"></p>';
		echo '<p><label for="tds_mobile_captions_url">Legenda VTT WordPress HTTPS</label><input class="widefat" id="tds_mobile_captions_url" name="tds_mobile_captions_url" value="' . esc_attr( $captions ) . '"></p>';
	}

	public static function save( $post_id, $post ) {
		if ( ! isset( $_POST['tds_mobile_lesson_nonce'] ) ||
			! is_string( $_POST['tds_mobile_lesson_nonce'] ) ||
			! wp_verify_nonce(
				sanitize_text_field( wp_unslash( $_POST['tds_mobile_lesson_nonce'] ) ),
				'tds_mobile_lesson_' . $post_id
			) || ! current_user_can( 'edit_post', $post_id ) ||
			( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) ||
			! $post || $post->post_type !== 'lp_lesson' ||
			wp_is_post_revision( $post_id ) ) {
			return;
		}
		$public = isset( $_POST['tds_mobile_public'] ) && '1' === $_POST['tds_mobile_public'];
		$approved = isset( $_POST['tds_mobile_rights_approved'] ) && '1' === $_POST['tds_mobile_rights_approved'];
		$old_video = (string) get_post_meta( $post_id, '_tds_mobile_youtube_id', true );
		$pending_source = (string) get_post_meta( $post_id, '_tds_mobile_rights_pending_source_fingerprint', true );
		$approved_source = (string) get_post_meta( $post_id, '_tds_mobile_rights_source_fingerprint', true );
		$video = isset( $_POST['tds_mobile_youtube_id'] ) && is_string( $_POST['tds_mobile_youtube_id'] )
			? sanitize_text_field( wp_unslash( $_POST['tds_mobile_youtube_id'] ) )
			: '';
		if ( '' !== $video && ! preg_match( '/^[a-zA-Z0-9_-]{11}$/D', $video ) ) {
			$video = '';
			$approved = false;
		}
		if ( $old_video !== $video ) {
			// Rights cannot silently transfer when the asset changes.
			$approved = false;
		}
		update_post_meta( $post_id, '_tds_mobile_public', $public ? '1' : '0' );
		update_post_meta( $post_id, '_tds_mobile_youtube_id', $video );
		foreach ( array(
			'tds_mobile_poster_url' => '_tds_mobile_poster_url',
			'tds_mobile_captions_url' => '_tds_mobile_captions_url',
		) as $field => $meta ) {
			$url = isset( $_POST[ $field ] ) && is_string( $_POST[ $field ] )
				? esc_url_raw( wp_unslash( $_POST[ $field ] ), array( 'https' ) ) : '';
			update_post_meta( $post_id, $meta, $url );
		}
		if ( '' === $video ) {
			$fingerprint = TDS_LearnPress_Editorial::mp4_source_fingerprint( $post_id );
			$approved = $approved && null !== $fingerprint &&
				( hash_equals( $pending_source, $fingerprint ) ||
					( '' !== $approved_source && hash_equals( $approved_source, $fingerprint ) ) );
			update_post_meta( $post_id, '_tds_mobile_rights_pending_source_fingerprint', $fingerprint ?? '' );
			update_post_meta( $post_id, '_tds_mobile_rights_source_fingerprint', $approved ? $fingerprint : '' );
		} else {
			update_post_meta( $post_id, '_tds_mobile_rights_pending_source_fingerprint', '' );
			update_post_meta( $post_id, '_tds_mobile_rights_source_fingerprint', '' );
		}
		update_post_meta( $post_id, '_tds_mobile_rights_approved', $approved ? '1' : '0' );
	}
}
