<?php

defined( 'ABSPATH' ) || exit;

interface TDS_Courses_Adapter_Interface {
	/** Return a sanitized public catalog result; never return enrollment or user data. */
	public function fetch_courses( $page = 1, $per_page = 12 );
}
