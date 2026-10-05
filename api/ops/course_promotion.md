# Promoção explícita de cursos

Execute em `api/`, com as migrações aplicadas. `python -m app.course_promotion`
usa a URL na variável `DATABASE_URL`; `--database-url-env OUTRA_VARIAVEL` permite
selecionar outra variável sem colocar credenciais nos argumentos/manifesto.

Exporte uma versão **publicada** do ambiente de origem:

```text
python -m app.course_promotion export --course-id CURSO --version-id VERSAO --output curso-v2.json
```

O arquivo contém somente `schema_version: 1`, `course_id`, `version_id`,
`version_number`, `content` e `sha256`. Preserva os IDs e versões dos módulos e
mensagens. Mensagens bot podem conter `experience` com ID estável, tipo conhecido,
objetivo e campos opcionais estritamente validados (`required`, `actionLabel` e
`ai.starterPrompt`). Campos fora do contrato de conteúdo são rejeitados; não exporta usuários,
matrículas, turmas, certificados, credenciais, IDs de programa ou IDs do autor no
banco. `author` continua sendo o crédito editorial do curso. O caminho de saída
deve ser novo. Revise também o texto e os links do conteúdo antes de transferir.

SHA256 cobre todos os campos exceto `sha256`, serializados em UTF-8 com chaves
ordenadas, `ensure_ascii=False` e separadores `,`/`:`. Ele detecta alterações;
não é uma assinatura de origem. Transfira/confirme o digest por um canal confiável.

Com `DATABASE_URL` apontando para o destino, ensaie primeiro:

```text
python -m app.course_promotion import curso-v2.json --expected-digest SHA256_CONFERIDO --expected-database-name BANCO_DESTINO --actor-user-id REVISOR_LOCAL --program-id PROGRAMA_LOCAL
```

Esse comando é **dry-run por padrão** e não cria curso, vínculos, versões ou
auditoria. A saída identifica o banco real, curso/versão, eventual versão a
arquivar e vínculo a criar. `--dry-run` é um sinônimo explícito. PostgreSQL compara
`BANCO_DESTINO` com `current_database()`; SQLite exige o caminho absoluto completo
do arquivo (não aceita `:memory:`). O digest, banco, revisor e programa são
obrigatórios também no ensaio. Nenhuma conexão se faz com o banco de origem na
importação; somente o manifesto é transferido.

Após revisar o plano, repita os mesmos argumentos acrescentando **`--apply`**.
O ator deve existir no destino e ser admin global ou coordenador/admin ativo no
programa escolhido e em todos os programas que já oferecem o curso. O programa
local deve existir. Publicabilidade é validada novamente, inclusive quiz com
alternativa correta; o arquivo nunca altera os snapshots existentes.

Uma promoção nova publica a versão e registra o ator/data locais, arquiva a
publicação anterior e atualiza a projeção pública na mesma transação. Não move
turmas para a nova versão nem modifica certificados. `course_id`, `version_id`,
número e IDs dos componentes são preservados. Não copia a identidade de pessoas
ou programas de staging, nem inventa histórico de revisão no destino.

Repetir o mesmo manifesto é idempotente. Se sua versão já estiver arquivada no
destino, permanece arquivada e a publicação mais nova permanece ativa. Pode apenas
criar o vínculo explicitamente solicitado com um programa local ainda não ligado.
Mesmo ID com conteúdo/número/curso diferente, número ocupado ou anterior ao maior
número local, versão local em edição e curso não versionado são conflitos: nada
é sobrescrito. Resolva a divergência editorial antes de exportar uma versão nova.

O comando não sincroniza bases, não executa migrações/deploy e não ativa workers.
