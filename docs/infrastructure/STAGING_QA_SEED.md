# Seed sintético para QA físico

## Escopo e proteções

O comando abaixo cria somente dados identificados como `[STAGING]` para testar
Home, cursos, hierarquia institucional, turma, monitoria, Evidence Engine,
retomada de simulado e catálogo de mídia:

```bash
python -m app.staging_seed
```

A CLI recusa a execução antes de abrir o banco se qualquer guarda falhar:

- `TUTOR_ENVIRONMENT` precisa ser exatamente `staging`;
- `STAGING_SEED_CONFIRM` precisa ser exatamente
  `SEED_SYNTHETIC_STAGING_DATA`;
- o driver precisa ser PostgreSQL;
- tanto o host quanto o nome do banco em `DATABASE_URL` precisam conter
  `staging`.

Portanto, `localhost`, SQLite e o banco `tutor_tds` de produção são recusados.
A função é idempotente: os identificadores são fixos, a reexecução não cria
usuários, vínculos ou conteúdo duplicados e credenciais divergentes fazem o
processo falhar em vez de apropriar uma conta existente.

## Gerar e guardar credenciais no host

Entre no diretório dedicado de staging, aplique `umask 077` e gere o arquivo
fora do repositório. O trecho gera quatro CPFs válidos, senhas independentes e
um token de check-in sem imprimir os valores no terminal:

```bash
cd /CAMINHO/ABSOLUTO/DO/STAGING
umask 077
python3 - <<'PY' > .staging-seed.env
import secrets

def cpf():
    while True:
        digits = [secrets.randbelow(10) for _ in range(9)]
        if len(set(digits)) == 1:
            continue
        for index in (9, 10):
            total = sum(digits[position] * (index + 1 - position) for position in range(index))
            digits.append((total * 10 % 11) % 10)
        return ''.join(map(str, digits))

print('TUTOR_ENVIRONMENT=staging')
print('STAGING_SEED_CONFIRM=SEED_SYNTHETIC_STAGING_DATA')
for index, role in enumerate(('ADMIN', 'TEACHER', 'MONITOR', 'STUDENT'), start=1):
    print(f'STAGING_SEED_{role}_CPF={cpf()}')
    print(f'STAGING_SEED_{role}_PHONE=55000000000{index}')
    print(f'STAGING_SEED_{role}_PASSWORD={secrets.token_urlsafe(24)}')
print(f'STAGING_SEED_CHECKIN_TOKEN={secrets.token_urlsafe(24)}')
PY
chmod 600 .staging-seed.env
```

Preserve esse arquivo: ele é a fonte das credenciais das contas sintéticas.
Não o envie por chat, issue, log, commit ou artefato de CI. Compartilhe os
quatro pares CPF/senha com o QA por um cofre de senhas. Não regenere o arquivo
após a primeira execução; o seed recusa mudança silenciosa de credenciais.

## Executar após as migrations

Com o `.env` normal de staging no mesmo diretório do Compose e a nova imagem já
baixada, execute:

```bash
docker compose -f docker-compose.staging.yml run --rm --no-deps \
  --env-from-file .staging-seed.env \
  api-staging python -m app.staging_seed
```

O comando não precisa de credenciais Google e não habilita o profile do Sheets.
Ele imprime somente a quantidade de registros novos, nunca CPF, telefone, senha
ou token. Repetir exatamente o comando deve informar zero registros novos.

## Dados criados

- administrador global e contas locais de aluno, professor e monitor;
- instituição, programa, oferta, curso conversacional e carga horária;
- matrícula do aluno, professor titular, monitor atribuído e turma ativa;
- sessão aberta com token do arquivo, importação/evidência pendente sintética;
- simulado incompleto para testar retomada offline/online;
- eventos mínimos de estudo/conclusão para o painel da turma;
- mídia publicada para a instituição usando um stream HLS público de teste
  da Mux (`test-streams.mux.dev`), sem upload, OAuth ou credencial externa.

Os IDs começam por `staging-qa-`. A conta de professor e a de monitor mantêm
papel global `student`; a autoridade de equipe deriva dos vínculos locais de
programa/turma, conforme o modelo multi-programa.

## Arquivos necessários no staging

A imagem da API precisa conter `app/staging_seed.py`. Para operação manual,
copie/atualize também `docker-compose.staging.yml`; use
`staging.env.example` para o ambiente base e `staging-seed.env.example` apenas
como lista das credenciais a gerar. O arquivo preenchido `.staging-seed.env`
existe somente no host e deve permanecer com modo `600`.

## Evidência da execução em 20/09/2026

O seed foi aplicado no staging isolado em `/opt/tutor-tds-staging` após a
migration `20260920_0012`:

- primeira execução: 23 registros novos;
- segunda execução: zero registros novos, confirmando idempotência;
- arquivo de credenciais no host com modo `0600`, sem valores exibidos;
- `api/ops/staging_role_smoke.py` autenticou os quatro papéis;
- resultado do smoke: uma turma visível para cada papel, uma tentativa de
  avaliação e uma mídia; painel de professor/monitor e sessão aberta do aluno
  responderam sem expor o token de check-in.

O worker Sheets continuou desligado. Habilitá-lo permanece condicionado a uma
planilha real e credencial de serviço fornecidas pelo responsável.
