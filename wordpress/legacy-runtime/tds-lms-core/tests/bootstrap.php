<?php
require_once dirname(__DIR__) . '/vendor/autoload.php';
require_once __DIR__ . '/Stubs/WP.php';

if (!defined('ABSPATH'))             define('ABSPATH', '/var/www/html/');
if (!defined('TDS_API_KEY'))         define('TDS_API_KEY', 'synthetic-test-key');
if (!defined('TDS_N8N_URL'))         define('TDS_N8N_URL', 'https://n8n.test/webhook');
if (!defined('TDS_ANYTHINGLLM_URL')) define('TDS_ANYTHINGLLM_URL', 'https://rag.test');
if (!defined('TDS_ANYTHINGLLM_KEY')) define('TDS_ANYTHINGLLM_KEY', 'synthetic-test-key');
if (!defined('WP_CONTENT_DIR'))      define('WP_CONTENT_DIR', '/tmp/wp-content');
