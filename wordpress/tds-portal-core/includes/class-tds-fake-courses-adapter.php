<?php

defined( 'ABSPATH' ) || exit;

/** Deterministic offline adapter used until an approved upstream is configured. */
final class TDS_Fake_Courses_Adapter implements TDS_Courses_Adapter_Interface {
	private $cache = array();
	private $state;
	private $courses;

	/** Fixtures must be synthetic. Bootstrap deliberately supplies none. */
	public function __construct( $state = 'unavailable', array $courses = array() ) {
		$this->state = $state;
		$this->courses = $courses;
	}

	public function fetch_courses( $page = 1, $per_page = 12 ) {
		$page     = max( 1, absint( $page ) );
		$per_page = min( 50, max( 1, absint( $per_page ) ) );
		$key      = $page . ':' . $per_page;

		if ( isset( $this->cache[ $key ] ) ) {
			return $this->cache[ $key ];
		}

		$result = array(
			'state' => $this->state,
			'courses' => 'ready' === $this->state ? array_slice( $this->courses, ( $page - 1 ) * $per_page, $per_page ) : array(),
			'pagination' => array( 'page' => $page, 'per_page' => $per_page, 'total' => 'ready' === $this->state ? count( $this->courses ) : 0 ),
			'error' => array( 'code' => 'catalog_unavailable', 'message' => 'Catálogo indisponível temporariamente.' ),
			'source' => 'offline-fake',
		);
		$this->cache[ $key ] = $result;
		return $result;
	}
}
