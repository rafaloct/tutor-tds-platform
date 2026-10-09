#!/usr/bin/env php
<?php

/**
 * @file
 * Lint de Twig: templates customizados do portal.
 *
 * Executar dentro do container web (ou onde vendor/ exista).
 */

declare(strict_types=1);

$root = dirname(__DIR__);
require $root . '/vendor/autoload.php';

$twig = new Twig\Environment(new Twig\Loader\ArrayLoader());

$files = [];
foreach (['web/modules/custom', 'web/themes/custom'] as $dir) {
  $path = $root . '/' . $dir;
  if (!is_dir($path)) {
    continue;
  }
  $iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($path, FilesystemIterator::SKIP_DOTS)
  );
  foreach ($iterator as $file) {
    if ($file->isFile() && $file->getExtension() === 'twig') {
      $files[] = $file->getPathname();
    }
  }
}

$errors = 0;
foreach ($files as $file) {
  $relative = str_replace($root . '/', '', $file);
  try {
    $source = new Twig\Source(file_get_contents($file), basename($file), $file);
    $twig->parse($twig->tokenize($source));
  }
  catch (Throwable $e) {
    $errors++;
    fwrite(STDERR, sprintf("FAIL %s: %s\n", $relative, $e->getMessage()));
  }
}

if ($errors > 0) {
  fwrite(STDERR, sprintf("lint-twig: %d template(s) invalidos\n", $errors));
  exit(1);
}

printf("lint-twig: %d template(s) OK\n", count($files));
