<?php

defined( 'ABSPATH' ) || exit;

final class TDS_Courses_Service {
	private $adapter;

	public function __construct( TDS_Courses_Adapter_Interface $adapter ) {
		$this->adapter = $adapter;
	}

	public function public_catalog( $page = 1, $per_page = 12 ) {
		$result = $this->adapter->fetch_courses( $page, $per_page );
		if ( ! is_array( $result ) || ! isset( $result['state'] ) ) {
			return array(
				'state' => 'error',
				'courses' => array(),
				'error' => array( 'code' => 'invalid_adapter_response', 'message' => 'Não foi possível carregar o catálogo.' ),
			);
		}

		return $result;
	}
}
