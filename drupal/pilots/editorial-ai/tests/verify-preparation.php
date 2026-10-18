<?php

/**
 * @file
 * Run with drush php:script after applying the recipe in a disposable site.
 */

use Drupal\Core\Session\AnonymousUserSession;
use Drupal\filter\Entity\FilterFormat;
use Drupal\user\Entity\Role;

$checks = 0;
$check = static function (bool $condition, string $code) use (&$checks): void {
  if (!$condition) {
    throw new RuntimeException($code);
  }
  $checks++;
};

$format = FilterFormat::load('tds_editorial_pilot');
$check($format !== NULL, 'pilot_format_missing');
$check(!$format->access('use', new AnonymousUserSession()), 'anonymous_format_access');
$role = Role::load('tds_editorial_pilot');
$check($role !== NULL && !$role->isAdmin(), 'pilot_role_missing_or_admin');
$check($role->getPermissions() === ['use text format tds_editorial_pilot'], 'pilot_role_excess_permissions');
foreach (['anonymous', 'authenticated', 'tds_editor', 'tds_reviewer', 'tds_publisher'] as $name) {
  $existing = Role::load($name);
  $check($existing !== NULL && !$existing->hasPermission('use text format tds_editorial_pilot'), 'existing_role_changed');
}
foreach (['ai', 'ai_ckeditor', 'ai_provider_openrouter', 'ai_agents', 'ai_search'] as $module) {
  $check(!\Drupal::moduleHandler()->moduleExists($module), 'ai_unexpectedly_enabled');
}
$workflow = \Drupal::config('workflows.workflow.tds_editorial')->get('type_settings');
$check($workflow['default_moderation_state'] === 'draft', 'default_not_draft');
$check($workflow['states']['draft']['published'] === FALSE && $workflow['states']['review']['published'] === FALSE, 'draft_or_review_published');
$check($workflow['transitions']['publish']['from'] === ['review', 'published'], 'publish_bypasses_review');
$check(!Role::load('tds_editor')->hasPermission('use tds_editorial transition publish'), 'editor_can_publish');
$check(!Role::load('tds_reviewer')->hasPermission('use tds_editorial transition publish'), 'reviewer_can_publish');
$check(Role::load('tds_publisher')->hasPermission('use tds_editorial transition publish'), 'human_publisher_removed');

$filter = $format->filters('filter_html');
$output = (string) $filter->process('<p onclick="bad()">Texto <strong>editorial</strong><script>bad()</script><iframe src="https://example.test"></iframe><a href="javascript:bad()">link</a></p>', 'pt-br')->getProcessedText();
$check(!str_contains($output, '<script') && !str_contains($output, '<iframe') && !str_contains($output, 'onclick') && !str_contains($output, 'javascript:'), 'unsafe_html_survived');
$check(str_contains($output, '<strong>editorial</strong>'), 'safe_formatting_removed');

foreach (['filter.format.tds_editorial_pilot', 'editor.editor.tds_editorial_pilot', 'user.role.tds_editorial_pilot'] as $name) {
  $data = \Drupal::config($name)->getRawData();
  $typed = \Drupal::service('config.typed')->createFromNameAndData($name, $data);
  $violations = $typed->validate();
  foreach ($violations as $violation) {
    fwrite(STDERR, $name . ':' . $violation->getPropertyPath() . ':' . $violation->getMessage() . "\n");
  }
  $check(count($violations) === 0, 'config_schema_invalid');
}
fwrite(STDOUT, sprintf("PASS: %d Drupal preparation checks; AI not enabled or invoked by this check.\n", $checks));
