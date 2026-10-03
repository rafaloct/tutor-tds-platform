<?php

defined( 'ABSPATH' ) || exit;

final class TDS_Courses_Service {
	private $adapter;

	public function __construct( TDS_Courses_Adapter_Interface $adapter ) {
		$this->adapter = $adapter;
	}

	public function public_catalog( $page = 1, $per_page = 12 ) {
		$page = max( 1, (int) $page );
		$per_page = min( 50, max( 1, (int) $per_page ) );
		$output = array( 'state' => 'error', 'courses' => array(), 'pagination' => array( 'page' => $page, 'per_page' => $per_page, 'total' => 0 ), 'error' => array( 'code' => 'catalog_error', 'message' => 'Não foi possível carregar o catálogo.' ) );
		try {
			$result = $this->adapter->fetch_courses( $page, $per_page );
			if ( ! is_array( $result ) || ! isset( $result['state'] ) || ! in_array( $result['state'], array( 'ready', 'disabled', 'unavailable', 'error' ), true ) ) {
				return $output;
			}
			if ( 'ready' !== $result['state'] ) {
				$output['state'] = $result['state'];
				$output['error'] = array( 'code' => 'catalog_' . $result['state'], 'message' => 'Catálogo indisponível temporariamente.' );
				return $output;
			}
			if ( ! isset( $result['courses'], $result['pagination'] ) || ! is_array( $result['pagination'] ) || ! isset( $result['pagination']['total'] ) || ! is_array( $result['courses'] ) || array_values( $result['courses'] ) !== $result['courses'] || count( $result['courses'] ) > $per_page || ! is_int( $result['pagination']['total'] ) || $result['pagination']['total'] < 0 ) {
				return $output;
			}
			if ( count( $result['courses'] ) > 0 && $result['pagination']['total'] < ( ( $page - 1 ) * $per_page + count( $result['courses'] ) ) ) {
				return $output;
			}
			$courses = array();
			foreach ( $result['courses'] as $course ) {
				if ( ! is_array( $course ) ) { return $output; }
				$public = array();
				foreach ( array( 'slug', 'title', 'status', 'published_version_label', 'updated_at' ) as $field ) {
					if ( ! isset( $course[ $field ] ) || ! is_string( $course[ $field ] ) || '' === trim( $course[ $field ] ) ) { return $output; }
					$public[ $field ] = sanitize_text_field( $course[ $field ] );
				}
				if ( 'published' !== $public['status'] || ! preg_match( '/^[a-z0-9]+(?:-[a-z0-9]+)*$/D', $public['slug'] ) ) { return $output; }
				foreach ( array( 'summary', 'public_workload_text', 'public_audience_text' ) as $field ) {
					if ( isset( $course[ $field ] ) ) {
						if ( ! is_string( $course[ $field ] ) ) { return $output; }
						$public[ $field ] = sanitize_text_field( $course[ $field ] );
					}
				}
				if ( isset( $course['cover_public_url'] ) ) {
					$url = TDS_Public_Config::validated_url( $course['cover_public_url'] );
					if ( '' === $url || false !== strpos( $url, '?' ) || false !== strpos( $url, '#' ) ) { return $output; }
					$public['cover_public_url'] = $url;
				}
				$courses[] = $public;
			}
			return array( 'state' => 'ready', 'courses' => $courses, 'pagination' => array( 'page' => $page, 'per_page' => $per_page, 'total' => $result['pagination']['total'] ), 'error' => null );
		} catch ( Throwable $failure ) {
			// Never publish adapter diagnostics or partially validated records.
			return $output;
		}
	}
}
