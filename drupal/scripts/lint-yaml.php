#!/usr/bin/env php
<?php

/**
 * @file
 * Lint de YAML: config sync, codigo customizado e infra declarativa.
 *
 * Executar dentro do container web (ou onde vendor/ exista).
 */

declare(strict_types=1);

use Symfony\Component\Yaml\Yaml;

$root = dirname(__DIR__);
require $root . '/vendor/autoload.php';

$files = [];

foreach (glob($root . '/*.yml') ?: [] as $f) {
  $files[] = $f;
}

foreach (['config', 'web/modules/custom', 'web/themes/custom', 'drush'] as $dir) {
  $path = $root . '/' . $dir;
  if (!is_dir($path)) {
    continue;
  }
  $iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($path, FilesystemIterator::SKIP_DOTS)
  );
  foreach ($iterator as $file) {
    if ($file->isFile() && in_array($file->getExtension(), ['yml', 'yaml'], TRUE)) {
      $files[] = $file->getPathname();
    }
  }
}

$errors = 0;
foreach (array_unique($files) as $file) {
  try {
    Yaml::parseFile($file);
  }
  catch (Throwable $e) {
    $errors++;
    fwrite(STDERR, sprintf("FAIL %s: %s\n", str_replace($root . '/', '', $file), $e->getMessage()));
  }
}

if ($errors > 0) {
  fwrite(STDERR, sprintf("lint-yaml: %d arquivo(s) invalidos\n", $errors));
  exit(1);
}

printf("lint-yaml: %d arquivo(s) OK\n", count(array_unique($files)));
