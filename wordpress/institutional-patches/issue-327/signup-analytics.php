<?php
declare(strict_types=1);

/**
 * Pure contract for a future WordPress public-registration integration.
 * The caller must assemble this trusted snapshot after wp_insert_user succeeds;
 * request parameters, GET redirects and browser consent claims are not facts.
 * No WordPress, tag, network, storage or rendering operation belongs here.
 */
const TDS_SIGNUP_WP_DEDUP_MARKER = '_tds_ga4_signup_reported';

function tds_signup_exact_keys(array $value, array $keys): bool
{
    $actual = array_keys($value);
    sort($actual);
    sort($keys);
    return $actual === $keys;
}

/** Return only GA4 event data, or null on any ambiguity. */
function tds_signup_analytics_event(array $facts): ?array
{
    if (!tds_signup_exact_keys($facts, [
        'trigger', 'handler', 'insert_status', 'insert_succeeded_at',
        'event_time', 'nonce_valid', 'user_existed_before',
        'account_matches_insert', 'reported_before', 'consent', 'utm',
        'course_id', 'course_public',
    ])) {
        return null;
    }

    if ($facts['trigger'] !== 'insert_success'
        || $facts['handler'] !== 'tds_cadastro_publico'
        || $facts['insert_status'] !== 'created'
        || $facts['nonce_valid'] !== true
        || $facts['user_existed_before'] !== false
        || $facts['account_matches_insert'] !== true
        || $facts['reported_before'] !== false
        || !is_int($facts['insert_succeeded_at'])
        || !is_int($facts['event_time'])
        || $facts['insert_succeeded_at'] <= 0
        || $facts['event_time'] < $facts['insert_succeeded_at']
        || $facts['event_time'] - $facts['insert_succeeded_at'] > 30
    ) {
        return null;
    }

    $consent = $facts['consent'];
    if (!is_array($consent) || !tds_signup_exact_keys($consent, [
        'analytics', 'explicit', 'revoked', 'checked_at',
    ]) || $consent['analytics'] !== 'granted'
        || $consent['explicit'] !== true
        || $consent['revoked'] !== false
        || !is_int($consent['checked_at'])
        || $consent['checked_at'] < $facts['insert_succeeded_at']
        || $consent['checked_at'] > $facts['event_time']
        || $facts['event_time'] - $consent['checked_at'] > 30
    ) {
        return null;
    }

    $utm = $facts['utm'];
    if (!is_array($utm) || !tds_signup_exact_keys($utm, [
        'utm_source', 'utm_medium', 'utm_campaign', 'utm_content',
    ]) || $utm['utm_source'] !== 'tutor_tds_app'
        || $utm['utm_medium'] !== 'app'
        || $utm['utm_campaign'] !== 'ead_signup'
    ) {
        return null;
    }

    $courseId = $facts['course_id'];
    if ($courseId === null) {
        if ($facts['course_public'] !== false || $utm['utm_content'] !== 'welcome_signup') {
            return null;
        }
        $content = 'welcome_signup';
    } else {
        if (!is_int($courseId) || $courseId <= 0 || $facts['course_public'] !== true
            || $utm['utm_content'] !== 'course_' . $courseId) {
            return null;
        }
        $content = 'course_' . $courseId;
    }

    return [
        'event_name' => 'sign_up',
        'method' => 'wordpress',
        'utm_source' => 'tutor_tds_app',
        'utm_medium' => 'app',
        'utm_campaign' => 'ead_signup',
        'utm_content' => $content,
    ];
}
