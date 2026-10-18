<?php
// Fixture helper (Issue #252): detecta o dialeto da coluna de ordenação em
// {prefix}learnpress_question_answers. SQLite-integration usa 'ordering';
// MySQL nativo usa 'order'. Uso:
//   COL=$(php wp-cli.phar --allow-root --path=<wp> eval-file lp_question_answers_col.php)
global $wpdb;
$table = $wpdb->prefix . 'learnpress_question_answers';
$cols  = wp_list_pluck( $wpdb->get_results( "SHOW COLUMNS FROM $table" ), 'Field' );
if ( in_array( 'order', $cols, true ) ) {
    echo 'order';
} elseif ( in_array( 'ordering', $cols, true ) ) {
    echo 'ordering';
} else {
    fwrite( STDERR, 'ERRO: nem order nem ordering encontrado em ' . $table . PHP_EOL );
    exit(1);
}
