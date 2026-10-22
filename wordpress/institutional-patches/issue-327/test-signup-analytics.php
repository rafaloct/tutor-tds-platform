<?php
declare(strict_types=1);

require __DIR__ . '/signup-analytics.php';

$passed = 0;
$failed = 0;
function check(string $name, bool $condition): void
{
    global $passed, $failed;
    if ($condition) {
        ++$passed;
        echo "PASS $name\n";
    } else {
        ++$failed;
        fwrite(STDERR, "FAIL $name\n");
    }
}

$base = [
    'trigger' => 'insert_success',
    'handler' => 'tds_cadastro_publico',
    'insert_status' => 'created',
    'insert_succeeded_at' => 1000,
    'event_time' => 1002,
    'nonce_valid' => true,
    'user_existed_before' => false,
    'account_matches_insert' => true,
    'reported_before' => false,
    'consent' => [
        'analytics' => 'granted', 'explicit' => true,
        'revoked' => false, 'checked_at' => 1001,
    ],
    'utm' => [
        'utm_source' => 'tutor_tds_app', 'utm_medium' => 'app',
        'utm_campaign' => 'ead_signup', 'utm_content' => 'welcome_signup',
    ],
    'course_id' => null,
    'course_public' => false,
];
$expected = [
    'event_name' => 'sign_up', 'method' => 'wordpress',
    'utm_source' => 'tutor_tds_app', 'utm_medium' => 'app',
    'utm_campaign' => 'ead_signup', 'utm_content' => 'welcome_signup',
];
check('public welcome signup exact payload', tds_signup_analytics_event($base) === $expected);
$course = $base;
$course['course_id'] = 1298;
$course['course_public'] = true;
$course['utm']['utm_content'] = 'course_1298';
check('public course signup exact payload', tds_signup_analytics_event($course) === array_replace($expected, ['utm_content' => 'course_1298']));
check('WP-side dedup marker named', TDS_SIGNUP_WP_DEDUP_MARKER === '_tds_ga4_signup_reported');

$cases = [];
$cases['GET alone'] = ['trigger' => 'get'];
$cases['UTM without creation'] = ['insert_status' => 'not_attempted'];
$cases['nonce failed'] = ['nonce_valid' => false];
$cases['existing account'] = ['user_existed_before' => true];
$cases['duplicate report'] = ['reported_before' => true];
$cases['consent denied'] = ['consent' => array_replace($base['consent'], ['analytics' => 'denied'])];
$cases['consent unknown'] = ['consent' => array_replace($base['consent'], ['analytics' => 'unknown'])];
$cases['consent revoked'] = ['consent' => array_replace($base['consent'], ['revoked' => true])];
$cases['consent implicit'] = ['consent' => array_replace($base['consent'], ['explicit' => false])];
$cases['consent checked before insert'] = ['consent' => array_replace($base['consent'], ['checked_at' => 999])];
$cases['consent stale after insert'] = ['event_time' => 1032, 'consent' => array_replace($base['consent'], ['checked_at' => 1001])];
$cases['consent checked in future'] = ['consent' => array_replace($base['consent'], ['checked_at' => 1003])];
$cases['refresh replay'] = ['trigger' => 'refresh'];
$cases['relaunch replay'] = ['trigger' => 'relaunch'];
$cases['late insert replay'] = ['event_time' => 1031, 'consent' => array_replace($base['consent'], ['checked_at' => 1030])];
$cases['insert error'] = ['insert_status' => 'wp_error'];
$cases['insert crash'] = ['insert_status' => 'crashed'];
$cases['insert missing timestamp'] = ['insert_succeeded_at' => null];
$cases['account switched'] = ['account_matches_insert' => false];
$cases['wrong handler'] = ['handler' => 'tds_cadastro_aluno'];
$cases['course zero'] = ['course_id' => 0, 'course_public' => true, 'utm' => array_replace($base['utm'], ['utm_content' => 'course_0'])];
$cases['course text'] = ['course_id' => '1298', 'course_public' => true, 'utm' => array_replace($base['utm'], ['utm_content' => 'course_1298'])];
$cases['course private'] = ['course_id' => 1298, 'course_public' => false, 'utm' => array_replace($base['utm'], ['utm_content' => 'course_1298'])];
$cases['course mismatched'] = ['course_id' => 1298, 'course_public' => true, 'utm' => array_replace($base['utm'], ['utm_content' => 'course_614'])];
$cases['external campaign'] = ['utm' => array_replace($base['utm'], ['utm_campaign' => 'other'])];
$cases['foreign source'] = ['utm' => array_replace($base['utm'], ['utm_source' => 'newsletter'])];
$cases['hostile source'] = ['utm' => array_replace($base['utm'], ['utm_source' => '<script>alert(1)</script>'])];
$cases['PII in medium'] = ['utm' => array_replace($base['utm'], ['utm_medium' => 'person@example.test'])];
$cases['URL in content'] = ['utm' => array_replace($base['utm'], ['utm_content' => 'https://evil.test/?email=a@b.test'])];
$cases['hostile content'] = ['utm' => array_replace($base['utm'], ['utm_content' => 'welcome_signup<script>'])];
$cases['extra top-level email'] = ['email' => 'person@example.test'];
$cases['extra top-level URL'] = ['url' => 'https://evil.test/?cpf=123'];
$cases['extra UTM user ID'] = ['utm' => array_replace($base['utm'], ['user_id' => 123])];
$cases['extra consent token'] = ['consent' => array_replace($base['consent'], ['token' => 'synthetic'])];
$cases['missing nonce evidence'] = ['nonce_valid' => null];
$cases['unknown reported state'] = ['reported_before' => null];
$cases['unknown public status'] = ['course_public' => null];
$cases['array UTM injection'] = ['utm' => array_replace($base['utm'], ['utm_source' => ['tutor_tds_app']])];
foreach ($cases as $name => $changes) {
    check($name . ' denied', tds_signup_analytics_event(array_replace($base, $changes)) === null);
}

$_GET = ['cadastro' => 'ok', 'email' => 'leak@example.test'];
check('GET superglobal cannot affect event', tds_signup_analytics_event($base) === $expected);
echo "TOTAL=" . ($passed + $failed) . " PASS=$passed FAIL=$failed\n";
exit($failed === 0 ? 0 : 1);
