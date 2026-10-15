<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Lock;

use Drupal\Core\Database\Connection;
use Drupal\Core\Session\SessionHandler;

/**
 * MySQL/MariaDB connection-owned mutex; no lease can expire mid-refresh.
 */
final class DatabaseSessionMutex implements SessionMutexInterface {

  /**
   * Pins the same connection used by the default Drupal session handler.
   */
  public function __construct(private readonly Connection $database) {}

  /**
   * Validates supported storage without opening another connection.
   */
  public static function create(Connection $database, \SessionHandlerInterface $handler): self {
    if (get_class($handler) !== SessionHandler::class) {
      throw new \RuntimeException('session_mutex_storage_unsupported');
    }
    return new self($database);
  }

  /**
   * {@inheritdoc}
   */
  public function acquire(string $key): bool {
    if ($this->database->driver() !== 'mysql') {
      throw new \RuntimeException('session_mutex_backend_unsupported');
    }
    $pdo = $this->database->getClientConnection();
    if (!$pdo instanceof \PDO || $pdo->getAttribute(\PDO::ATTR_PERSISTENT)) {
      throw new \RuntimeException('session_mutex_persistent_connection_unsupported');
    }
    $result = $this->database->query('SELECT GET_LOCK(:key, 0)', [':key' => $key])->fetchField();
    if ($result === NULL || $result === FALSE) {
      throw new \RuntimeException('session_mutex_unavailable');
    }
    return (int) $result === 1;
  }

  /**
   * {@inheritdoc}
   */
  public function release(string $key): void {
    $result = $this->database->query('SELECT RELEASE_LOCK(:key)', [':key' => $key])->fetchField();
    if ((int) $result !== 1) {
      throw new \RuntimeException('session_mutex_release_failed');
    }
  }

}
