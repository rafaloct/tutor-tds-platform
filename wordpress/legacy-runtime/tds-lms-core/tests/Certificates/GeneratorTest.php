<?php
namespace TDS\Tests\Certificates;

use Brain\Monkey\Functions;
use TDS\Certificates\Generator;
use TDS\Tests\BaseTestCase;

class GeneratorTest extends BaseTestCase {
    public function test_build_hash_is_sha256_hex(): void {
        $hash = Generator::build_hash(1, 'python-do-zero', '2026-04-20');
        $this->assertMatchesRegularExpression('/^[a-f0-9]{64}$/', $hash);
    }

    public function test_build_hash_is_deterministic(): void {
        $h1 = Generator::build_hash(1, 'python-do-zero', '2026-04-20');
        $h2 = Generator::build_hash(1, 'python-do-zero', '2026-04-20');
        $this->assertEquals($h1, $h2);
    }

    public function test_build_hash_differs_by_user(): void {
        $h1 = Generator::build_hash(1, 'python-do-zero', '2026-04-20');
        $h2 = Generator::build_hash(2, 'python-do-zero', '2026-04-20');
        $this->assertNotEquals($h1, $h2);
    }

    public function test_mask_cpf_masks_middle_digits(): void {
        $masked = Generator::mask_cpf('123.456.789-01');
        $this->assertEquals('123.***.***-01', $masked);
    }

    public function test_mask_cpf_handles_empty(): void {
        $this->assertEquals('', Generator::mask_cpf(''));
    }
}
