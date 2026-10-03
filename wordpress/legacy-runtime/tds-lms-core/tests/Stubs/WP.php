<?php
/**
 * WordPress stub classes for unit testing.
 * These allow PHPUnit to mock WP types without a real WordPress installation.
 */

if (!class_exists('WP_REST_Request')) {
    class WP_REST_Request {
        public function get_header(string $key): ?string { return null; }
        public function get_param(string $key): mixed { return null; }
    }
}

if (!class_exists('WP_REST_Response')) {
    class WP_REST_Response {
        public function __construct(
            public mixed $data = null,
            public int $status = 200
        ) {}
    }
}

if (!class_exists('WP_Error')) {
    class WP_Error {
        public function __construct(
            public string $code = '',
            public string $message = '',
            public mixed $data = null
        ) {}
        public function get_error_message(): string { return $this->message; }
    }
}
