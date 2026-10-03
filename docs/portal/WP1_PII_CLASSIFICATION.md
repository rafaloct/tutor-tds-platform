# WP-1 — Classificação de candidatos a PII no snapshot legado

A revisão independente encontrou strings que correspondem a padrões genéricos de e-mail e CPF. Foi feita classificação por contexto sem publicar os valores.

## composer.lock

- E-mails encontrados são campos authors[].email de dependências Composer, isto é, metadados upstream públicos do ecossistema de pacotes.
- Os candidatos numéricos a CPF encontrados por regex de texto não aparecem como valores JSON escalares no composer.lock; são falsos positivos por substrings numéricas em metadata de dependências.
- Não são dados de participantes TDS.

## Testes do tds-lms-core

- Candidatos em tests/Certificates/GeneratorTest.php e tests/Webhooks/N8nDispatcherTest.php são fixtures hardcoded de testes legados.
- São tratados como dados sintéticos e não devem ser usados como identidade real.
- O snapshot é somente referência histórica; WP-2 não reutiliza essas fixtures como dados operacionais.

## Tema/child theme

- Endereços de e-mail literais no tema são contatos institucionais/operacionais publicados no próprio código legado.
- Campos como nome, e-mail e telefone aparecem como nomes de campos/formulário, não como registros de participantes.
- O novo portal deve manter os dados de contato no sistema operacional de suporte e nunca projetá-los para analytics.

## Conclusão

Nenhum candidato classificado nesta revisão representa evidência de PII de participante incorporada no snapshot. A classificação não transforma o legado em fonte confiável nem autoriza seu deploy.
