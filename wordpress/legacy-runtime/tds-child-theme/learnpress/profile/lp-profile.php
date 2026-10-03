<?php
// Redirect legacy LearnPress profile to TDS /minha-area
defined('ABSPATH') || exit;
wp_redirect(home_url('/minha-area'), 301);
exit;
