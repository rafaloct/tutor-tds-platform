<?php
// TDS override: renders lesson content + AnythingLLM chatbot widget
defined('ABSPATH') || exit;

$course = learn_press_get_course();
do_action('learn-press/before-lesson-content');
?>
<div class="lp-content-area">
  <?php the_content(); ?>
  <?php do_action('learn-press/after-lesson-content'); ?>
</div>
<?php
// AnythingLLM widget — injected by TDS\Chatbot\WidgetInjector via hook above
do_action('learn-press/lesson-buttons');
