<?php

defined( 'ABSPATH' ) || exit;

interface TDS_Courses_Adapter_Interface {
	/** Return a public catalog candidate; service allowlists fields before publication. */
	public function fetch_courses( $page = 1, $per_page = 12 );
}
