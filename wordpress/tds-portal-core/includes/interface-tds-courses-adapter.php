<?php

defined( 'ABSPATH' ) || exit;

interface TDS_Courses_Adapter_Interface {
	/** Return a public catalog transport result; never return enrollment or user data. */
	public function fetch_courses( $page = 1, $per_page = 12 );

	/** Return one public course transport result by canonical slug. */
	public function fetch_course( $slug );
}
