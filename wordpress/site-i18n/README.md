# Tutor TDS | Tradução pt-BR reprodutível (site WordPress)

Este diretório controla somente **arquivos de interface** do LearnPress, complemento Course Review e Astra. **Não é STT de vídeo e não modifica aulas, currículos, usuários ou dados acadêmicos.**

## Fonte de verdade e resultado atual

- Locale WordPress observado em 17/10/2026: `pt_BR`.
- Problema observado: o LearnPress 4.3.6 usava arquivos `learnpress-pt_BR` idênticos em bytes aos `pt_PT`, incompletos.
- Correção anterior aplicada na instalação: 578 entradas traduzidas LearnPress, 49 Course Review, 54 Astra. Este repositório preserva os dicionários versionados e um gerador auditável, mas **não declara que foi regenerado ou implantado automaticamente**.
- Backup anterior no host WordPress `/root/tds-ptbr-rollback-20261017`; **não alterar/remover esse backup**.

## Manutenção em qualquer rodada

1. Coletar os POT **da versão exata instalada**, sem inferir tradução de um pacote antigo: LearnPress `languages/learnpress.pot`, Course Review `languages/learnpress-course-review.pot`, Astra `languages/astra.pot`.
2. Usar ambiente local isolado: `python -m venv .venv`, ativar e `python -m pip install -r requirements.txt`.
3. Exemplo com LearnPress: `python build.py --pot /caminho/learnpress.pot --domain learnpress --glossary glossaries/learnpress-core.pt_BR.json --glossary glossaries/learnpress-extra.pt_BR.json --out out/learnpress --fail-on-critical`.
4. Exemplo Astra: `python build.py --pot /caminho/astra.pot --domain astra --glossary glossaries/astra.pt_BR.json --out out/astra --fail-on-critical`.
5. Exemplo Course Review: `python build.py --pot /caminho/learnpress-course-review.pot --domain learnpress-course-review --glossary glossaries/learnpress-core.pt_BR.json --glossary glossaries/learnpress-extra.pt_BR.json --out out/review --fail-on-critical`.
6. Analisar JSON `*-report.json` (novas entradas, placeholders rejeitados, mensagens críticas, glossário sem correspondência). **Não implantar quando BLOCKED**.
7. Usar `wp i18n make-php` e `wp i18n make-json --no-purge` para artefatos PHP/JavaScript, respeitando nome/domínio/diretórios oficiais de idiomas. A geração não substitui backup.
8. Num QA WordPress isolado, comparar arquivos gerados e conferir navegação do curso, busca, matrícula, questionário, perfil e avaliações em pt-BR. Aplicar em produção **somente com backup, compare-and-swap por hash e gate humano**.

O `--existing` reaproveita traduções anteriores **somente se o PO declarar `Language: pt_BR`**. Cópias portuguesas de Portugal não são aceitas como fallback.

## Segurança e continuidade

Não existe dependência operacional de Devin, de GPU, de LLM ou de credenciais cloud para gerar os arquivos. Os glossários JSON podem receber novas frases na próxima rodada. O relatório nunca preenche mensagens desconhecidas com tradução inventada; os textos faltantes ficam sinalizados. Este diretório não inclui credenciais, dump da base WordPress nem qualquer transcrição dos vídeos.

Tests: `python -m unittest discover -s tests -v`.

Referência: https://developer.wordpress.org/cli/commands/i18n/
