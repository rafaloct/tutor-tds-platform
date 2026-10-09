<?php

declare(strict_types=1);

namespace Drupal\tds_public_portal\Controller;

use Drupal\Core\Controller\ControllerBase;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Url;
use Drupal\tds_public_portal\Client\PublicCatalogClientInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\Response;

/**
 * Sitemap somente com rotas publicas e entidades publicadas.
 */
final class SitemapController extends ControllerBase {

  /**
   * Construtor.
   */
  public function __construct(
    private readonly PublicCatalogClientInterface $catalogClient,
    private readonly EntityTypeManagerInterface $tdsEntityTypeManager,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static(
      $container->get('tds_public_portal.catalog_client'),
      $container->get('entity_type.manager'),
    );
  }

  /**
   * Resposta XML; curso indisponivel nunca derruba URLs editoriais.
   */
  public function sitemap(): Response {
    $routeNames = [
      'tds_public_portal.home',
      'tds_public_portal.program',
      'tds_public_portal.news',
      'tds_public_portal.events',
      'tds_public_portal.materials',
      'tds_public_portal.faq',
      'tds_public_portal.privacy',
      'tds_public_portal.rights',
      'tds_public_portal.accessibility',
      'tds_public_portal.contact',
      'tds_public_portal.catalog',
    ];
    $urls = [];
    foreach ($routeNames as $routeName) {
      $urls[] = Url::fromRoute($routeName, [], ['absolute' => TRUE])->toString();
    }

    $storage = $this->tdsEntityTypeManager->getStorage('node');
    $ids = $storage->getQuery()
      ->accessCheck(TRUE)
      ->condition('type', [
        'tds_news',
        'tds_event',
        'tds_public_material',
        'tds_faq',
        'tds_institutional_page',
      ], 'IN')
      ->condition('status', 1)
      ->range(0, 1000)
      ->execute();
    foreach ($storage->loadMultiple($ids) as $node) {
      $urls[] = $node->toUrl('canonical', ['absolute' => TRUE])->toString();
    }

    $catalog = $this->catalogClient->list(0, 100);
    foreach ($catalog->payload['courses'] ?? [] as $course) {
      if (is_string($course['slug'] ?? NULL)) {
        $urls[] = Url::fromRoute(
          'tds_public_portal.course',
          ['slug' => $course['slug']],
          ['absolute' => TRUE],
        )->toString();
      }
    }

    $items = '';
    foreach (array_values(array_unique($urls)) as $url) {
      $escaped = htmlspecialchars((string) $url, ENT_XML1 | ENT_QUOTES, 'UTF-8');
      $items .= "  <url><loc>{$escaped}</loc></url>\n";
    }
    $xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      . "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"
      . $items
      . "</urlset>\n";
    $response = new Response($xml, 200, [
      'Content-Type' => 'application/xml; charset=UTF-8',
      'Cache-Control' => 'public, max-age=60, stale-while-revalidate=300',
    ]);
    return $response;
  }

}
