# Gate de certificado no staging — 20/09/2026

## Resultado

O recorte que independe do emissor externo está pronto e foi comprovado somente
com dados sintéticos. O certificado E2E completo permanece bloqueado de forma
honesta porque staging não possui emissor/verificador próprio configurado.

Imagem observada:

```text
tutor-tds-api:staging-0014-certificate-seed-20260920
sha256:65a5506836f9df0a0c8cd658bede0ad3973164e645436b31aa2dbe077c521d08
Alembic 20260920_0014 (head)
```

## Evidência reproduzida

- o seed foi reexecutado com zero registros novos;
- o aluno `staging-qa-student` possui matrícula ativa no programa, curso e
  turma sintéticos;
- soma validada `28804` segundos para carga planejada de `28800` segundos;
- evento `lesson_completed` presente;
- `GET /certificates` sem token retornou HTTP 401;
- as carteiras do aluno e do professor autenticados retornaram HTTP 200;
- a carteira do professor permaneceu vazia, sem cruzamento de titulares;
- os JSONs das carteiras não contêm campos `cpf`, `cpf_digest` ou `phone`;
- nenhum certificado foi gravado para o aluno sintético;
- `/health` público permaneceu com API e banco disponíveis.

O smoke reproduzível é `api/ops/staging_certificate_gate_smoke.py`. As
credenciais sintéticas são lidas somente de `.staging-seed.env` no host; o
script não imprime credenciais, tokens nem identificadores civis.

## Fronteira do contrato

A API Tutor não emite o certificado. `POST /certificates/references` registra
uma referência somente depois de:

1. validar matrícula, turma, carga horária e conclusão no PostgreSQL;
2. consultar por HTTPS o certificado já emitido na origem allowlisted;
3. comparar ID, curso, titular e hash com a resposta pública.

`GET /certificates` lista somente as referências do titular autenticado. Não há
endpoint backend de PDF: o PDF A4, a abertura, impressão e compartilhamento são
funções locais do Flutter após uma emissão válida.

## Bloqueios externos exatos

No staging observado:

- `STAGING_CERTIFICATE_VERIFICATION_URL_PREFIX` está vazio;
- o build DEV mantém `TUTOR_GATEWAY_URL` vazio, conforme o gate que impede usar
  o gateway produtivo em debug;
- não há Worker/KV, namespace, URL HTTPS ou segredo de assinatura exclusivos de
  staging no workspace/host.

Por isso, `POST /certificates/references` falha fechado com HTTP 503 antes de
aceitar qualquer referência, e emissão/verificação pública não podem ser
simuladas como sucesso. Para fechar o E2E é necessário provisionar um gateway
de certificado **exclusivo de staging**, com KV isolado, segredo próprio e URL
HTTPS; configurar seu prefixo na API e a URL no build DEV; então emitir no
Xiaomi, validar o hash local, abrir/compartilhar o PDF e verificar a URL/QR sem
login. O gateway de produção não deve ser reutilizado.
