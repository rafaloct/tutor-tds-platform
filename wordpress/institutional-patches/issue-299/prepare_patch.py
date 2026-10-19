"""Prepare a minimal patch against a sanitized TDS Child 2.0.0 copy, never deploy.

Exact source provenance is verified by the acquisition/QA runner. This script
requires every old fragment exactly once and stages both edits before writing.
It intentionally does not contain the institutional theme or its credentials.
"""
from pathlib import Path
import argparse
import difflib


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('Theme does not match the inspected institutional 2.0.0 fragment')
    return source.replace(old, new, 1)


def prepare(theme):
    originals = {name: (theme / name).read_text(encoding='utf-8')
                 for name in ('functions.php', 'pages/cadastro.php')}
    functions = originals['functions.php']
    functions = replace_once(functions, '// Cadastro simplificado',
        "require_once get_stylesheet_directory() . '/includes/tds-registration-course.php';\n\n// Cadastro simplificado")
    functions = replace_once(functions,
        "function tds_handle_cadastro_publico(): void {\n    $cadastro_url = home_url('/cadastro/');",
        """function tds_handle_cadastro_publico(): void {
    $context = tds_registration_course_context($_POST);
    $cadastro_url = home_url('/cadastro/');
    if ($context['id']) {
        $cadastro_url = add_query_arg('tds_curso', $context['id'], $cadastro_url);
    }""")
    # Restrict edits to this handler, not the separate contact handler.
    start = functions.index('function tds_handle_cadastro_publico(): void {')
    end = functions.index("\nadd_action('phpmailer_init'", start)
    handler = functions[start:end]
    handler = replace_once(handler, "wp_die('Requisição inválida.', 403);",
        "wp_die('Requisição inválida.', '', ['response' => 403]);")
    handler = replace_once(handler, "    $nome  = sanitize_text_field", """    if ($context['invalid'] || is_user_logged_in()) {
        wp_safe_redirect($context['url']);
        exit;
    }
    $nome  = sanitize_text_field""")
    handler = replace_once(handler, "wp_safe_redirect(home_url('/minha-area/?cadastro=ok'));",
        "wp_safe_redirect($context['id'] ? $context['url'] : home_url('/minha-area/?cadastro=ok'));")
    functions = functions[:start] + handler + functions[end:]
    page = originals['pages/cadastro.php']
    page = replace_once(page, "defined('ABSPATH') || exit;\nget_header();", """defined('ABSPATH') || exit;
$context = tds_registration_course_context($_GET);
if ($context['invalid'] || ($context['id'] && is_user_logged_in())) {
    wp_safe_redirect($context['url']);
    exit;
}
get_header();""")
    page = replace_once(page, '<input type="hidden" name="action" value="tds_cadastro">',
        '''<input type="hidden" name="action" value="tds_cadastro">
        <?php if ($context['id']): ?>
          <input type="hidden" name="tds_curso" value="<?= esc_attr((string) $context['id']) ?>">
        <?php endif; ?>''')
    page = replace_once(page, "wp_login_url(home_url('/minha-area/'))", "wp_login_url($context['url'])")
    edits = {'functions.php': functions, 'pages/cadastro.php': page}
    helper = theme / 'includes/tds-registration-course.php'
    if helper.exists():
        raise ValueError('Helper already exists; refusing to overwrite')
    diff = ''.join(''.join(difflib.unified_diff(originals[n].splitlines(True), v.splitlines(True),
                    fromfile='a/' + n, tofile='b/' + n)) for n, v in edits.items())
    for name, source in edits.items():
        (theme / name).write_text(source, encoding='utf-8', newline='\n')
    helper.write_bytes(Path(__file__).with_name('tds-registration-course.php').read_bytes())
    return diff


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('theme', type=Path)
    parser.add_argument('--diff', type=Path, required=True)
    args = parser.parse_args()
    args.diff.write_text(prepare(args.theme), encoding='utf-8', newline='\n')
