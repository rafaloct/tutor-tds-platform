<?php
/** One-time empty-database install. Credentials arrive on stdin, never argv. */
declare(strict_types=1);
chdir('/var/www/html');
$input = json_decode(stream_get_contents(STDIN), TRUE, flags: JSON_THROW_ON_ERROR);
if (!preg_match('/^[a-z_][a-z0-9_]*$/', $input['username'] ?? '') || !preg_match('/^[a-f0-9]{96}$/', $input['password'] ?? '')) {
  throw new RuntimeException('Invalid bootstrap input');
}
$pdo = new PDO('mysql:host=' . getenv('DRUPAL_DB_HOST') . ';dbname=' . getenv('DRUPAL_DB_NAME'), getenv('DRUPAL_DB_USER'), getenv('DRUPAL_DB_PASSWORD'));
if ((int) $pdo->query('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()')->fetchColumn() !== 0) {
  throw new RuntimeException('Database is not empty; installation refused');
}
$settings = '/var/www/html/web/sites/default/settings.php';
$original = file_get_contents($settings);
register_shutdown_function(static function () use ($settings, $original): void {
  chmod($settings, 0600);
  file_put_contents($settings, $original);
  chmod($settings, 0444);
});
// Drush may append installation values; restore the env-only source on exit.
// Its entire output must be discarded by the caller (it prints a login URL).
$_SERVER['argv'] = ['drush', 'site:install', '--existing-config', '-y',
  '--account-name=' . $input['username'], '--account-pass=' . $input['password'],
  '--site-name=Tutor TDS', '--site-mail=tdsdados@gmail.com', '--account-mail=tdsdados@gmail.com'];
$_SERVER['argc'] = count($_SERVER['argv']);
require '/var/www/html/vendor/drush/drush/drush.php';
