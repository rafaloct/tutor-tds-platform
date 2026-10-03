<?php
/**
 * Editorial public content model for WP-4 / Issue #44.
 *
 * WordPress remains editorial only. No enrollment, attendance, progress,
 * certificate decision, support transcript or academic identifier belongs here.
 */
defined( 'ABSPATH' ) || exit;

final class TDS_Editorial_Content {
	const EVENT_POST_TYPE = 'tds_event';
	const MATERIAL_POST_TYPE = 'tds_material';
	const MATERIAL_TYPE_TAXONOMY = 'tds_material_type';
	const TOPIC_TAXONOMY = 'tds_topic';

	public static function register() {
		register_post_type( self::EVENT_POST_TYPE, self::event_post_type_args() );
		register_post_type( self::MATERIAL_POST_TYPE, self::material_post_type_args() );
		register_taxonomy( self::MATERIAL_TYPE_TAXONOMY, array( self::MATERIAL_POST_TYPE ), self::material_type_args() );
		register_taxonomy( self::TOPIC_TAXONOMY, array( 'post', self::EVENT_POST_TYPE, self::MATERIAL_POST_TYPE ), self::topic_args() );

		self::register_public_meta(
			self::EVENT_POST_TYPE,
			array(
				'tds_event_start_at'         => array( 'sanitize_callback' => array( __CLASS__, 'sanitize_datetime' ) ),
				'tds_event_end_at'           => array( 'sanitize_callback' => array( __CLASS__, 'sanitize_datetime' ) ),
				'tds_event_location'         => array( 'sanitize_callback' => 'sanitize_text_field' ),
				'tds_event_registration_url' => array( 'sanitize_callback' => array( __CLASS__, 'sanitize_public_url' ) ),
			)
		);
		self::register_public_meta(
			self::MATERIAL_POST_TYPE,
			array(
				'tds_material_public_url' => array( 'sanitize_callback' => array( __CLASS__, 'sanitize_public_url' ) ),
			)
		);
	}

	private static function post_type_args( $singular, $plural, $slug, $menu_icon ) {
		return array(
			'labels' => array(
				'name'          => $plural,
				'singular_name' => $singular,
				'add_new_item'  => sprintf( 'Adicionar %s', strtolower( $singular ) ),
				'edit_item'     => sprintf( 'Editar %s', strtolower( $singular ) ),
			),
			'public'       => true,
			'show_in_rest' => true,
			'has_archive'  => true,
			'rewrite'      => array( 'slug' => $slug ),
			'menu_icon'    => $menu_icon,
			'supports'     => array( 'title', 'editor', 'excerpt', 'thumbnail', 'revisions' ),
		);
	}

	public static function event_post_type_args() {
		return self::post_type_args( 'Evento', 'Agenda', 'agenda', 'dashicons-calendar-alt' );
	}

	public static function material_post_type_args() {
		return self::post_type_args( 'Material', 'Biblioteca', 'biblioteca', 'dashicons-media-document' );
	}

	public static function material_type_args() {
		return array(
			'labels'            => array( 'name' => 'Tipos de material', 'singular_name' => 'Tipo de material' ),
			'public'            => true,
			'show_in_rest'      => true,
			'hierarchical'      => false,
			'show_admin_column' => true,
			'rewrite'           => array( 'slug' => 'tipo-de-material' ),
		);
	}

	public static function topic_args() {
		return array(
			'labels'            => array( 'name' => 'Temas', 'singular_name' => 'Tema' ),
			'public'            => true,
			'show_in_rest'      => true,
			'hierarchical'      => true,
			'show_admin_column' => true,
			'rewrite'           => array( 'slug' => 'tema' ),
		);
	}

	private static function register_public_meta( $post_type, array $fields ) {
		foreach ( $fields as $key => $overrides ) {
			$args = array_merge(
				array(
					'type'         => 'string',
					'single'       => true,
					'show_in_rest' => true,
					'default'      => '',
					'auth_callback' => static function ( $allowed, $meta_key, $post_id ) {
						return current_user_can( 'edit_post', $post_id );
					},
				),
				$overrides
			);
			register_post_meta( $post_type, $key, $args );
		}
	}

	public static function sanitize_public_url( $value ) {
		if ( ! class_exists( 'TDS_Public_Config' ) ) {
			return '';
		}
		return TDS_Public_Config::validated_url( $value );
	}

	public static function sanitize_datetime( $value ) {
		if ( ! is_string( $value ) ) {
			return '';
		}
		$value = trim( $value );
		if ( ! preg_match( '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})$/D', $value ) ) {
			return '';
		}
		try {
			$date = new DateTimeImmutable( $value );
		} catch ( Exception $exception ) {
			return '';
		}
		return $date->format( DATE_ATOM );
	}
}
