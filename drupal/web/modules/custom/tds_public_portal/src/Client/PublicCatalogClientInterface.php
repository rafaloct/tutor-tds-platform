<?php

declare(strict_types=1);

namespace Drupal\tds_public_portal\Client;

use Drupal\tds_public_portal\ValueObject\CatalogResult;

/**
 * Cliente read-only da projecao publica FastAPI.
 */
interface PublicCatalogClientInterface {

  /**
   * Lista somente cursos publicados.
   */
  public function list(int $offset = 0, int $limit = 50): CatalogResult;

  /**
   * Busca um curso publicado por slug.
   */
  public function detail(string $slug): CatalogResult;

}
