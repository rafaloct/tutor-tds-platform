<?php

declare(strict_types=1);

namespace Drupal\tds_editorial_ai\Policy;

use Drupal\Core\Config\ConfigFactoryInterface;
use Drupal\Core\Session\AccountInterface;
use Drupal\node\NodeInterface;
use Drupal\tds_editorial_ai\Exception\EditorialAiException;

/**
 * Enforces the editorial boundary before credentials or transport are used.
 */
final class EditorialAiPolicy {

  /**
   * Allowed transformations are server-owned, never a caller-supplied prompt.
   */
  public const ACTIONS = ['summarize', 'spell_fix', 'tone'];

  /**
   * Constructs the policy.
   */
  public function __construct(private readonly ConfigFactoryInterface $configFactory) {}

  /**
   * Authorizes saved editorial content and checks field access independently.
   */
  public function authorize(NodeInterface $node, AccountInterface $account): void {
    if ($this->configFactory->get('tds_editorial_ai.settings')->get('enabled') !== TRUE) {
      throw new EditorialAiException('pilot_disabled', 503);
    }
    if (!$account->isAuthenticated()
      || !$account->hasPermission('request tds editorial suggestions')
      || $node->isNew()
      || !in_array($node->bundle(), ['tds_news', 'tds_faq'], TRUE)
      || !$node->access('update', $account)
      || !$node->hasField('body')
      || !$node->get('body')->access('edit', $account)) {
      throw new EditorialAiException('access_denied', 403);
    }
  }

  /**
   * Validates only explicit selected text, not arbitrary model configuration.
   */
  public static function validate(string $action, string $selection): void {
    if (!in_array($action, self::ACTIONS, TRUE) || !mb_check_encoding($selection, 'UTF-8') || trim($selection) === '' || mb_strlen($selection, 'UTF-8') > 4000) {
      throw new EditorialAiException('invalid_request', 422);
    }
  }

}
