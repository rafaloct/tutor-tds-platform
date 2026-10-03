<?php
/**
 * Plugin Name: TDS LMS Core
 * Description: Core LMS functionality for TDS platform — replaces all paid add-ons
 * Version: 1.0.0
 * Author: TDS
 * Text Domain: tds-lms-core
 */
if (!defined('ABSPATH')) exit;

spl_autoload_register(function (string $class): void {
    $prefix   = 'TDS\\';
    $base_dir = __DIR__ . '/modules/';
    if (strncmp($prefix, $class, strlen($prefix)) !== 0) return;
    $file = $base_dir . str_replace('\\', '/', substr($class, strlen($prefix))) . '.php';
    if (file_exists($file)) require $file;
});

add_action('plugins_loaded', function (): void {
    new \TDS\API\RestController();
    new \TDS\Webhooks\N8nDispatcher();
    new \TDS\Chatbot\WidgetInjector();
    new \TDS\Certificates\Generator();
    new \TDS\Certificates\Verifier();
    new \TDS\Drip\Scheduler();
    new \TDS\Quiz\AdvancedQuiz();
    new \TDS\Payments\EnrollmentGate();
    new \TDS\Subscriptions\PlanManager();
    new \TDS\Dashboard\StudentArea();
    new \TDS\Reports\AdminPanel();
    new \TDS\MultiInstructor\InstructorRoles();
}, 20); // priority 20 — after LearnPress (priority 10) loads

register_activation_hook(__FILE__, function (): void {
    \TDS\Certificates\Generator::create_table();
});
