# Issue #2: transporte R2 criptografado, candidato nao implantado

Base: `b701b7869a7736100348db406406f1f69a8a18b4`.
Estado: **UNIT_TESTED_ONLY; ISSUE_2_OPEN; PRODUCTION_RELEASE_READY=false**.

## Recorte entregue

`api/ops/backup_r2_transport.py` prepara uma etapa de transporte, separada do
`backup.sh` existente. Nao executa pg_dump, migrations, restore, cron ou deploy.
Nao altera dependencias da API e nao acessa o arquivo de credenciais DPAPI.

Por padrao, gera somente um plano: sem subprocessos, rede ou gravacao de arquivos.
A execucao exige `--execute` e `--key-custody-confirmed`; este ultimo representa
uma declaracao do operador, nunca uma prova automatica de custodia independente.
No host operacional Linux, requer age, AWS CLI v2 e diretorio privado fora do Git.
Autenticacao pertence ao provedor normal da AWS CLI, configurado por um mecanismo
autorizado. Este modulo nao instala, extrai, exporta ou contorna credenciais.

Sequencia proposta: arquivo `.dump`/`.sql.gz` estavel -> age com destinatario
PUBLICO -> SHA-256 -> PUT condicional -> GET -> comparacao de tamanho e SHA-256.
Destino fixo: conta `8b1d9dad829dd6927091666a1f186717`, bucket `tds-backups`,
prefixo `postgres/encrypted/`. Chave de objeto nova por execucao; solicita
`If-None-Match: *`. Sem exclusao de objetos e sem alteracao de regras do bucket.
Nao equivale a armazenamento imutavel/WORM nem verifica o escopo completo do token.

A chave PRIVADA de recuperacao nao pertence ao job que envia backups.
Um recibo local registra sucesso/falha do transporte, nunca aceite de restore.
Falha externa, arquivo de retorno divergente ou mudanca do arquivo de origem
interrompe a sequencia. stderr e credenciais nao sao publicados pelo programa.
Artefatos locais e eventuais objetos de uploads parciais ficam preservados para
investigacao; a rotina nao remove nem substitui os backups atuais.
Limite deliberado: PUT simples de ate 1 GiB criptografado; multipart nao implementado.
A assinatura do formato nao comprova que o dump seja restauravel.

## Evidencia desta rodada

Em container Linux isolado do ChatGPT, Python 3.13.5:
`python -m pytest tests/test_backup_r2_transport.py -q --tb=short`
Resultado: **27 testes passaram**, sem rede, dados reais ou credenciais.
Os comandos age e AWS foram substituidos por doubles nos testes de transporte.
Logo, isto NAO comprova criptografia real, autenticacao S3, upload R2 ou PostgreSQL.
Os testes cobrem plano sem efeitos, confirmacao de custodia, ordem de operacoes,
falhas de ferramentas/upload/download, retorno adulterado, origem alterada,
rejeicao de formato/caminhos inadequados, limites de tamanho, permissoes locais,
nao sobrescrita solicitada, erro sanitizado e retorno nao-zero para monitoramento.

A tentativa de continuar a operacao remota foi bloqueada antes de executar.
Nenhuma leitura/descriptografia do DPAPI foi repetida nem houve tentativa de
obter as mesmas credenciais por outro caminho. O Docker local estava indisponivel
na verificacao somente leitura; seu inicio nao foi confirmado.
O transporte OAuth anterior continua uma evidencia separada, nao valida as chaves S3.

## Proxima execucao autorizada

1. Revisar este candidato e disponibilizar age/AWS CLI no host operacional aprovado.
2. Configurar a credencial R2 restrita ao bucket por autenticacao autorizada,
   sem reutilizar/contornar o arquivo cuja leitura foi bloqueada.
3. Demonstrar recuperacao da chave privada fora da VPS e independente do notebook.
4. Ensaiar primeiro com dump PostgreSQL sintetico e criptografia REAL; executar
   download, descriptografia e pg_restore em instancia descartavel sem rede de
   producao. Comparar schema, contagens, valores/digests e referencias da fixture.
5. Somente apos autorizacao operacional, repetir com backup real, restaurando
   em instancia isolada. Nao usar o banco, volume ou nome do container produtivo.
6. Integrar a rotina ao backup/monitoramento somente apos aceite da recuperacao.

RPO, RTO e retencao nao foram definidos ou medidos nesta rodada. A coordenacao
precisa aprovar metas; medir restauracao real incluindo provisionamento e chaves.
O codigo retorna falha detectavel, mas nenhum canal de alerta foi configurado.
Nao criar `production-restore-acceptance.json` nem fechar Issue #2 com estes testes.

## Referencias tecnicas primarias

- https://github.com/FiloSottile/age : interface age e separacao recipient/identity.
- https://developers.cloudflare.com/r2/api/s3/api/ : endpoint, regiao auto e operacoes.
- https://docs.aws.amazon.com/cli/latest/reference/s3api/put-object.html : PUT condicional.
- https://www.postgresql.org/docs/16/app-pgdump.html : formatos e limites do dump.
