<?php
/** Course context only: account creation stays in the theme; enrollment stays in LearnPress. */
defined('ABSPATH') || exit;

function tds_registration_course_context(array $input): array {
    $context = ['id' => 0, 'invalid' => false, 'url' => home_url('/minha-area/')];
    if (!array_key_exists('tds_curso', $input)) {
        return $context;
    }
    $context['invalid'] = true;
    $context['url'] = add_query_arg('inscricao', 'curso-indisponivel', home_url('/cursos/'));
    $raw = $input['tds_curso'];
    if (!is_string($raw) || !preg_match('/^[1-9][0-9]*$/D', $raw)) {
        return $context;
    }
    $id = filter_var($raw, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    $course = $id ? get_post($id) : null;
    if (!$course || $course->post_type !== 'lp_course' || $course->post_status !== 'publish' || $course->post_password !== '') {
        return $context;
    }
    $url = get_permalink($course);
    $target = $url ? wp_parse_url($url) : false;
    $origin = wp_parse_url(home_url('/'));
    if (!$target || !$origin || isset($target['user']) || isset($target['pass'])) {
        return $context;
    }
    foreach (['scheme', 'host', 'port'] as $part) {
        if (($target[$part] ?? null) !== ($origin[$part] ?? null)) {
            return $context;
        }
    }
    if (wp_validate_redirect($url, '') !== $url) {
        return $context;
    }
    return ['id' => $id, 'invalid' => false, 'url' => $url];
}
