# Ponte Editorial Tutor TDS / LearnPress

Plugin WordPress independente com endpoints públicos somente leitura, conteúdo explicitamente autorizado e mídia YouTube ou MP4 institucional com direitos confirmados.

Para MP4 sem ID YouTube, o editor salva a fonte da aula e confirma os direitos em um segundo salvamento. A aprovação fica vinculada ao MP4 e à VTT validados (inclusive VTT editorial opcional); troca de fonte ou ausência do fingerprint faz a projeção REST retornar `media: null`. O opt-in de texto `_tds_mobile_public` continua separado. Aprovações MP4 anteriores sem fingerprint exigem nova revisão; nenhum vídeo recebe aprovação em massa.

**Não instalar diretamente em produção.** Leia [contrato, testes, gates e rollback](../../docs/architecture/LEARNPRESS_EDITORIAL_ADAPTER_236.md).

Validação local: `php tests/test-contract.php` (stubs WordPress) e `php -l` em todos os arquivos PHP. Sem dados de aluno, notas, CPF ou gabaritos.
