<?php
namespace TDS\Tests\API;

use Brain\Monkey\Functions;
use TDS\API\RestController;
use TDS\Tests\BaseTestCase;

class RestControllerTest extends BaseTestCase {
    public function test_authenticate_returns_true_with_correct_key(): void {
        $request = $this->createMock(\WP_REST_Request::class);
        $request->method('get_header')->with('X-API-Key')->willReturn('test_api_key_abc123');

        $controller = new RestController();
        $this->assertTrue($controller->authenticate_public($request));
    }

    public function test_authenticate_returns_false_with_wrong_key(): void {
        $request = $this->createMock(\WP_REST_Request::class);
        $request->method('get_header')->with('X-API-Key')->willReturn('wrong_key');

        $controller = new RestController();
        $this->assertFalse($controller->authenticate_public($request));
    }

    public function test_authenticate_returns_false_with_null_key(): void {
        $request = $this->createMock(\WP_REST_Request::class);
        $request->method('get_header')->with('X-API-Key')->willReturn(null);

        $controller = new RestController();
        $this->assertFalse($controller->authenticate_public($request));
    }
}
