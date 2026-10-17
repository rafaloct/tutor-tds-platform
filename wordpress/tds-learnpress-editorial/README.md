# Ponte Editorial Tutor TDS / LearnPress

Plugin WordPress independente com endpoints públicos somente leitura, conteúdo explicitamente autorizado e vídeo YouTube com direitos confirmados.

**Não instalar diretamente em produção.** Leia [contrato, testes, gates e rollback](../../docs/architecture/LEARNPRESS_EDITORIAL_ADAPTER_236.md).

Validação local: `php tests/test-contract.php` (stubs WordPress) e `php -l` em todos os arquivos PHP. Sem dados de aluno, notas, CPF ou gabaritos.
