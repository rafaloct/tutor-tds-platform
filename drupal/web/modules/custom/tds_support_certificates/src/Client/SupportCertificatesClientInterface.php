<?php

declare(strict_types=1);

namespace Drupal\tds_support_certificates\Client;

/**
 * Read-only support and certificate presentation boundary.
 */
interface SupportCertificatesClientInterface {

  /**
   * Returns certificate presentation fields, without hashes or owner IDs.
   */
  public function certificates(): array;

  /**
   * Returns the ephemeral signed Chatwoot identity for the current session.
   */
  public function identity(): array;

}
