<?php

declare(strict_types=1);

namespace Drupal\tds_tutor_gateway\Storage;

use Drupal\tds_tutor_gateway\ValueObject\TutorTokenSet;
use Symfony\Component\HttpFoundation\RequestStack;

/**
 * Tokens no backend da sessao Drupal, isolados por cookie de navegador.
 */
final class DrupalSessionTutorTokenStore implements TutorTokenStoreInterface {

  private const KEY = 'tds_tutor_gateway.tokens';

  /**
   * Construtor.
   */
  public function __construct(
    private readonly RequestStack $requestStack,
  ) {}

  /**
   * {@inheritdoc}
   */
  public function load(): ?TutorTokenSet {
    return TutorTokenSet::fromPrivateStore(
      $this->requestStack->getSession()->get(self::KEY),
    );
  }

  /**
   * {@inheritdoc}
   */
  public function save(TutorTokenSet $tokens): void {
    $this->requestStack->getSession()->set(self::KEY, $tokens->toPrivateStore());
  }

  /**
   * {@inheritdoc}
   */
  public function clear(): void {
    $this->requestStack->getSession()->remove(self::KEY);
  }

}
