<?php
namespace TDS\Tests\Webhooks;

use Brain\Monkey\Functions;
use TDS\Tests\BaseTestCase;
use TDS\Webhooks\N8nDispatcher;

class N8nDispatcherTest extends BaseTestCase {
    public function test_build_payload_enrolled(): void {
        Functions\when('get_user_by')->justReturn((object)[
            'display_name' => 'João Silva',
            'user_email'   => 'joao@test.com',
        ]);
        Functions\when('get_user_meta')->justReturn('63999999999');
        Functions\when('get_post_field')->justReturn('python-do-zero');

        $dispatcher = new N8nDispatcher();
        $payload    = $dispatcher->build_payload_public('enrolled', 5, 10);

        $this->assertEquals('enrolled',       $payload['event']);
        $this->assertEquals(5,                $payload['user_id']);
        $this->assertEquals('python-do-zero', $payload['course_slug']);
        $this->assertEquals('João Silva',     $payload['user_name']);
        $this->assertEquals('joao@test.com',  $payload['user_email']);
    }
}
