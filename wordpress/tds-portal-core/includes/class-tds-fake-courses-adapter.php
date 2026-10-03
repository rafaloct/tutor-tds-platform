<?php

defined( 'ABSPATH' ) || exit;

/** Deterministic offline adapter used until an approved upstream is configured. */
final class TDS_Fake_Courses_Adapter implements TDS_Courses_Adapter_Interface {
	private $cache = array();

	public function fetch_courses( $page = 1, $per_page = 12 ) {
		$page     = max( 1, absint( $page ) );
		$per_page = min( 50, max( 1, absint( $per_page ) ) );
		$key      = $page . ':' . $per_page;

		if ( isset( $this->cache[ $key ] ) ) {
			return $this->cache[ $key ];
		}

		$result = array(
			'state' => 'unavailable',
			'courses' => array(),
			'pagination' => array( 'page' => $page, 'per_page' => $per_page, 'total' => 0 ),
			'error' => array( 'code' => 'catalog_unavailable', 'message' => 'Catálogo indisponível temporariamente.' ),
			'source' => 'offline-fake',
		);
		$this->cache[ $key ] = $result;
		return $result;
	}
}
