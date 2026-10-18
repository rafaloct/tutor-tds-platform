# QA independente do adaptador LearnPress PR #238

Data: 18/10/2026. Escopo: Issue #236, épico #224. Ambiente: VM
`dfd627`, WordPress com LearnPress 4.3.6 e MariaDB **sintéticos**.
**Não é o staging institucional, não há dados reais nem E2E Android.**

## Proveniência comprovada

- Código do plugin: `3856566e97a585c5d30dd8a1b72ca369f1704127`, PR #238.
- SHA256 da classe editorial no clone:
  `064c350c544f60c02526b774c96b56d4e3a77e28cf1e279346999d9d489b632c`.
- O plugin que já estava ativo no sandbox compartilhado possuía **outro hash**;
  **não foi modificado**. O script extrai o commit exato exclusivamente para
  uma cópia temporária da instalação WordPress.
- Base original da fixture: `127.0.0.1:18732`, `DB_NAME=tdsqam`,
  cinco contas sintéticas `@qa-synthetic.test`, nenhuma conta externa.
- Clone temporário: `127.0.0.1:18736`, esquema MariaDB aleatório,
  nunca exposto na rede e removido ao final.

## Como reproduzir com controle de isolamento

Na própria VM dfd627, mantendo o repositório com o commit exato PR #238
em `/workspace/tds-issue236-wp-editorial-bridge` e a fixture original
em `/workspace/tds-wp-sandbox-20261017`:

```bash
bash tooling/qa/ead_editorial_wp_runtime/run.sh
```

O runner valida a identidade dos cinco usuários, o hostname loopback,
o DB, a versão do código, ausência de servidor no porto 18736,
cria um clone SQL + filesystem, executa o probe e usa um `trap`
para encerrar apenas seu servidor PHP, revogar a permissão concedida ao
esquema efêmero, apagar banco e arquivos. Falhas saem com código não zero.

## Evidências OBSERVED

- **18/18 PASS** no probe `probe_rights.py`, executado por HTTP
  `urllib.request` no runtime WordPress+LearnPress, não por stubs PHP.
- Currículo público com `schema_version=1`, `authority=learnpress`,
  SHA256 revision, ETag e HTTP 304 quando não há alteração.
- Lição publicada só retorna HTTP 200 após opt-in sintético. Sem opt-in
  retorna 404. Revogação retira imediatamente o acesso.
- Metadados `YouTube` só aparecem com as duas flags sintéticas habilitadas,
  ID válido e vínculo à lição; mudança revoga o ETag anterior.
- Direitos retirados, ID inválido e poster externo não vazam mídia.
- Rascunho não aparece na grade; WP `users/me` não é público (401/403).
- Rollback: `ROLLBACK_DIR=PASS` e `ROLLBACK_DB=PASS`; fonte original
  permanece operacional. Não se publica o corpo HTML de aluno.

**Atenção sobre mídia:** o `video_id` `AAAAAAAAAAA` é somente fixture
sintética para testar validação do formato. Não significa existência,
licença, aprovação editorial ou reprodução real de um vídeo YouTube.

## Bloqueio distinto (não ocultar)

Um segundo probe parcial teve **12 verificações HTTP aprovadas** até tentar
mudar `post_content`/status pelo comando WP-CLI `post update`. A
operação falhou repetidamente em
`learnpress/inc/Models/PostModel.php:333`, no controle de capacidade para
editar `lp_lesson`. A tentativa de explicitar o usuário administrador
**sintético** da fixture não solucionou a permissão. Em todas as tentativas
houve rollback do clone.

Classificação: problema de **fixture/autorização de edição no ambiente QA**,
não evidência de bug de publicação do plugin nem de falha no EAD público.
Para concluir esse recorte, ajustar a fixture de capacidades do instrutor,
provar o fluxo de edição na UI WP em uma instalação staging realmente
segregada e refazer atualização de título, texto, ordem e status.
Não contornar autorização no EAD institucional.

## UNKNOWN / BLOCKED

- Não homologado no WordPress **staging institucional** nem em produção.
- Sem publicação/aprovação real de direitos de 48 vídeos, VTT ou poster.
- Sem E2E Flutter Android consumindo esta instalação efêmera (host HTTP
  loopback deliberadamente não é o domínio HTTPS fixo do cliente).
- Sem validação de SSO, matrícula, notas, provas, emissão de certificados
  nem RAG contextual dos dois cursos extras.
- A matriz de 29 quizzes/282 questões e 38 perguntas locais não é
  sincronizada automaticamente por este QA.

`MERGE_ALLOWED=NO`; sem alteração de dados reais, sem produção,
sem deploy, sem credenciais em arquivos versionados.
