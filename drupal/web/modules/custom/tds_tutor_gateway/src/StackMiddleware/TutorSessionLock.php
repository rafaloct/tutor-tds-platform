<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\StackMiddleware;

use Drupal\Core\Session\ResponseKeepSessionOpenInterface;
use Drupal\Core\Session\SessionConfigurationInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\HttpKernelInterface;

/**
 * Wraps Drupal's session middleware: acquire before read, release after save.
 */
final class TutorSessionLock implements HttpKernelInterface {

  /**
   * Constructs the outer session boundary without initializing a session.
   */
  public function __construct(
    private readonly HttpKernelInterface $httpKernel,
    private readonly SessionConfigurationInterface $configuration,
    private readonly \Closure $mutexProvider,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function handle(Request $request, $type = self::MAIN_REQUEST, $catch = TRUE): Response {
    if ($type !== self::MAIN_REQUEST || !$this->configuration->hasSession($request)) {
      return $this->httpKernel->handle($request, $type, $catch);
    }
    $name = $this->configuration->getOptions($request)['name'];
    $cookie = $request->cookies->get($name);
    if (!is_string($cookie) || !preg_match('/^[A-Za-z0-9,-]{1,256}$/D', $cookie)) {
      return $this->unavailable();
    }
    // Drupal cookie names scope the site, including configured cookie domains.
    // Do not add host: aliases sharing a session must acquire the same mutex.
    // Never retain the cookie itself in the database lock name or diagnostics.
    $key = hash('sha256', 'tds-session:' . $name . ':' . $cookie);
    try {
      // Resolve database services only here, inside the sanitized boundary.
      $mutex = ($this->mutexProvider)();
      if (!$mutex->acquire($key)) {
        return $this->unavailable();
      }
    }
    catch (\Throwable) {
      return $this->unavailable();
    }
    try {
      try {
        $response = $this->httpKernel->handle($request, $type, $catch);
        // Deferred writes cannot escape this ownership boundary.
        if ($response instanceof ResponseKeepSessionOpenInterface) {
          $response = $this->unavailable();
        }
      }
      finally {
        // Core normally saves on success. Also save after exceptions and for
        // keep-open responses before releasing: preserve rotated tokens.
        if ($request->hasSession() && $request->getSession()->isStarted()) {
          $request->getSession()->save();
        }
      }
    }
    catch (\Throwable) {
      // No exception chain: errors may retain credentials or cookies.
      $response = $this->unavailable();
    }
    finally {
      try {
        $mutex->release($key);
      }
      catch (\Throwable) {
        $response = $this->unavailable();
      }
    }
    return $response;
  }

  /**
   * Contention and backend errors fail before reading a stale session snapshot.
   */
  private function unavailable(): JsonResponse {
    return new JsonResponse(['error' => 'session_busy_or_unavailable'], 503, [
      'Cache-Control' => 'no-store, private',
      'Pragma' => 'no-cache',
      'Retry-After' => '1',
    ]);
  }

}
