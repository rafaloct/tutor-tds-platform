<?php

declare(strict_types=1);

namespace Drupal\tds_public_portal\Controller;

use Drupal\Core\Controller\ControllerBase;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Link;
use Drupal\Core\Url;
use Drupal\tds_public_portal\Client\PublicCatalogClientInterface;
use Drupal\tds_public_portal\ValueObject\CatalogResult;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * Paginas publicas; conteudo editorial vem do Drupal e catalogo da FastAPI.
 */
final class PublicPortalController extends ControllerBase {

  private const EDITORIAL_BUNDLES = [
    'tds_news',
    'tds_event',
    'tds_public_material',
    'tds_faq',
  ];

  private const PAGE_KEYS = [
    'program',
    'privacy',
    'rights',
    'accessibility',
    'contact',
  ];

  /**
   * Construtor.
   */
  public function __construct(
    private readonly PublicCatalogClientInterface $catalogClient,
    private readonly EntityTypeManagerInterface $tdsEntityTypeManager,
    private readonly RequestStack $requestStack,
  ) {}

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container): static {
    return new static(
      $container->get('tds_public_portal.catalog_client'),
      $container->get('entity_type.manager'),
      $container->get('request_stack'),
    );
  }

  /**
   * Home publica sem inventar programa ou oferta.
   */
  public function home(): array {
    $catalog = $this->catalogClient->list(0, 6);
    $build = [
      '#type' => 'container',
      '#attributes' => ['class' => ['tds-public-home']],
      'intro' => [
        '#type' => 'html_tag',
        '#tag' => 'p',
        '#value' => $this->t('Conteudo institucional e catalogo publico do Tutor TDS.'),
        '#attributes' => ['class' => ['tds-public-lead']],
      ],
      'links' => [
        '#theme' => 'links',
        '#links' => [
          'program' => [
            'title' => $this->t('Conheca o programa'),
            'url' => Url::fromRoute('tds_public_portal.program'),
          ],
          'news' => [
            'title' => $this->t('Noticias'),
            'url' => Url::fromRoute('tds_public_portal.news'),
          ],
          'events' => [
            'title' => $this->t('Agenda'),
            'url' => Url::fromRoute('tds_public_portal.events'),
          ],
        ],
        '#attributes' => [
          'class' => ['tds-public-actions'],
          'aria-label' => $this->t('Atalhos do portal'),
        ],
      ],
      'catalog_title' => [
        '#type' => 'html_tag',
        '#tag' => 'h2',
        '#value' => $this->t('Cursos publicados'),
      ],
      'catalog' => $this->catalogBuild($catalog, TRUE),
      'all_courses' => Link::fromTextAndUrl(
        $this->t('Ver todos os cursos'),
        Url::fromRoute('tds_public_portal.catalog'),
      )->toRenderable(),
    ];
    return $this->withPageMetadata($build, (string) $this->t('Tutor TDS'));
  }

  /**
   * Lista conteudo publicado de um bundle editorial allowlisted.
   */
  public function editorialList(string $bundle): array {
    if (!in_array($bundle, self::EDITORIAL_BUNDLES, TRUE)) {
      throw new NotFoundHttpException();
    }
    $storage = $this->tdsEntityTypeManager->getStorage('node');
    $query = $storage->getQuery()
      ->accessCheck(TRUE)
      ->condition('type', $bundle)
      ->condition('status', 1)
      ->sort($bundle === 'tds_event' ? 'field_tds_event_start.value' : 'changed', 'DESC')
      ->range(0, 50);
    $nodes = $storage->loadMultiple($query->execute());
    $viewBuilder = $this->tdsEntityTypeManager->getViewBuilder('node');
    $items = [];
    foreach ($nodes as $node) {
      $items[] = $viewBuilder->view($node, 'teaser');
    }
    $build = $items === []
      ? $this->emptyState($this->t('Nenhum conteudo publicado nesta secao.'))
      : [
        '#theme' => 'item_list',
        '#items' => $items,
        '#attributes' => ['class' => ['tds-editorial-list']],
      ];
    $build['#cache']['tags'] = ['node_list:' . $bundle];
    $titles = [
      'tds_news' => $this->t('Noticias'),
      'tds_event' => $this->t('Agenda'),
      'tds_public_material' => $this->t('Materiais publicos'),
      'tds_faq' => $this->t('Perguntas frequentes'),
    ];
    return $this->withPageMetadata($build, (string) $titles[$bundle]);
  }

  /**
   * Renderiza a pagina institucional publicada para uma chave fixa.
   */
  public function institutional(string $page_key): array {
    if (!in_array($page_key, self::PAGE_KEYS, TRUE)) {
      throw new NotFoundHttpException();
    }
    $storage = $this->tdsEntityTypeManager->getStorage('node');
    $ids = $storage->getQuery()
      ->accessCheck(TRUE)
      ->condition('type', 'tds_institutional_page')
      ->condition('status', 1)
      ->condition('field_tds_page_key.value', $page_key)
      ->sort('changed', 'DESC')
      ->range(0, 1)
      ->execute();
    if ($ids === []) {
      $build = $this->emptyState($this->t('Conteudo institucional ainda nao publicado.'));
      $build['#cache']['tags'] = ['node_list:tds_institutional_page'];
      $titles = [
        'program' => $this->t('Programa'),
        'privacy' => $this->t('Privacidade'),
        'rights' => $this->t('Direitos e exclusao'),
        'accessibility' => $this->t('Acessibilidade'),
        'contact' => $this->t('Contato institucional'),
      ];
      return $this->withPageMetadata($build, (string) $titles[$page_key]);
    }
    $node = $storage->load(reset($ids));
    if ($node === NULL) {
      throw new NotFoundHttpException();
    }
    $build = $this->tdsEntityTypeManager->getViewBuilder('node')->view($node, 'full');
    return $this->withPageMetadata($build, $node->label());
  }

  /**
   * Catalogo paginado da projecao publica FastAPI.
   */
  public function catalog(): array {
    return $this->withPageMetadata(
      $this->catalogBuild($this->catalogClient->list()),
      (string) $this->t('Cursos'),
    );
  }

  /**
   * Detalhe do curso publico; draft/private e slug ausente viram 404.
   */
  public function course(string $slug): array {
    $result = $this->catalogClient->detail($slug);
    if ($result->state === CatalogResult::NOT_FOUND) {
      throw new NotFoundHttpException();
    }
    $build = [
      '#theme' => 'tds_public_course',
      '#course' => $result->payload,
      '#state' => $result->state,
      '#cache' => [
        'max-age' => 60,
        'contexts' => ['url.path', 'languages:language_interface'],
        'tags' => ['tds_public_catalog'],
      ],
    ];
    $title = is_string($result->payload['title'] ?? NULL)
      ? $result->payload['title']
      : (string) $this->t('Curso indisponivel');
    return $this->withPageMetadata($build, $title, 'article');
  }

  /**
   * Titulo seguro para a rota de detalhe.
   */
  public function courseTitle(string $slug): string {
    $result = $this->catalogClient->detail($slug);
    return is_string($result->payload['title'] ?? NULL)
      ? $result->payload['title']
      : (string) $this->t('Curso');
  }

  /**
   * Render do catalogo com estados empty/stale/unavailable explicitos.
   */
  private function catalogBuild(CatalogResult $result, bool $embedded = FALSE): array {
    $courses = is_array($result->payload['courses'] ?? NULL)
      ? $result->payload['courses']
      : [];
    foreach ($courses as &$course) {
      if (is_array($course) && is_string($course['slug'] ?? NULL)) {
        $course['portal_url'] = Url::fromRoute(
          'tds_public_portal.course',
          ['slug' => $course['slug']],
        )->toString();
      }
    }
    unset($course);
    $state = $result->state;
    if ($result->hasPayload() && $courses === []) {
      $state = 'empty';
    }
    return [
      '#theme' => 'tds_public_catalog',
      '#courses' => $courses,
      '#state' => $state,
      '#embedded' => $embedded,
      '#cache' => [
        'max-age' => 60,
        'contexts' => ['url.path', 'languages:language_interface'],
        'tags' => ['tds_public_catalog'],
      ],
    ];
  }

  /**
   * Estado vazio acessivel e deliberadamente sem placeholder inventado.
   */
  private function emptyState(mixed $message): array {
    return [
      '#type' => 'html_tag',
      '#tag' => 'p',
      '#value' => $message,
      '#attributes' => [
        'class' => ['tds-public-status'],
        'role' => 'status',
      ],
    ];
  }

  /**
   * Anexa canonical/OG, library e cache contexts sem incluir PII.
   */
  private function withPageMetadata(array $build, string $title, string $ogType = 'website'): array {
    $request = $this->requestStack->getCurrentRequest();
    $canonical = $request === NULL
      ? ''
      : $request->getSchemeAndHttpHost() . $request->getBaseUrl() . $request->getPathInfo();
    $build['#attached']['library'][] = 'tds_public_portal/public';
    if ($canonical !== '') {
      $build['#attached']['html_head_link'][] = [
        ['rel' => 'canonical', 'href' => $canonical],
        TRUE,
      ];
      $build['#attached']['html_head'][] = [
        [
          '#tag' => 'meta',
          '#attributes' => ['property' => 'og:url', 'content' => $canonical],
        ],
        'tds_public_og_url',
      ];
    }
    $build['#attached']['html_head'][] = [
      [
        '#tag' => 'meta',
        '#attributes' => ['property' => 'og:title', 'content' => $title],
      ],
      'tds_public_og_title',
    ];
    $build['#attached']['html_head'][] = [
      [
        '#tag' => 'meta',
        '#attributes' => ['property' => 'og:type', 'content' => $ogType],
      ],
      'tds_public_og_type',
    ];
    $build['#cache']['contexts'][] = 'url.path';
    $build['#cache']['contexts'][] = 'languages:language_interface';
    return $build;
  }

}
