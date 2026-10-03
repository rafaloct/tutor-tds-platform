<?php

defined( 'ABSPATH' ) || exit;

final class TDS_Public_Courses_Controller {
	private $service;

	public function __construct( TDS_Courses_Service $service ) {
		$this->service = $service;
	}

	public function register_routes() {
		register_rest_route(
			'tds-portal/v1',
			'/public/courses',
			array(
				'methods' => WP_REST_Server::READABLE,
				'callback' => array( $this, 'get_courses' ),
				'permission_callback' => '__return_true',
				'args' => array(
					'page' => array( 'default' => 1, 'type' => 'integer', 'minimum' => 1 ),
					'per_page' => array( 'default' => 12, 'type' => 'integer', 'minimum' => 1, 'maximum' => 50 ),
				),
			)
		);
		register_rest_route(
			'tds-portal/v1',
			'/public/courses/(?P<slug>[a-z0-9]+(?:-[a-z0-9]+)*)',
			array(
				'methods' => WP_REST_Server::READABLE,
				'callback' => array( $this, 'get_course' ),
				'permission_callback' => '__return_true',
				'args' => array(
					'slug' => array( 'required' => true, 'type' => 'string' ),
				),
			)
		);
	}

	public function get_courses( WP_REST_Request $request ) {
		$result = $this->service->public_catalog( $request->get_param( 'page' ), $request->get_param( 'per_page' ) );
		$status = 'ready' === $result['state'] ? 200 : ( 'error' === $result['state'] ? 502 : 503 );
		return new WP_REST_Response( $result, $status );
	}

	public function get_course( WP_REST_Request $request ) {
		$result = $this->service->public_course( $request->get_param( 'slug' ) );
		if ( 'ready' === $result['state'] ) {
			$status = 200;
		} elseif ( 'not_found' === $result['state'] ) {
			$status = 404;
		} elseif ( 'error' === $result['state'] ) {
			$status = 502;
		} else {
			$status = 503;
		}
		return new WP_REST_Response( $result, $status );
	}
}
