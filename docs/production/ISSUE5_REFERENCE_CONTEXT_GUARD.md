# Issue #5 — guarda de contexto da referência de certificado

## Escopo

Com `CERTIFICATE_APPROVAL_REQUIRED=true`, a criação de uma referência exige
exatamente uma aprovação humana para a mesma pessoa, matrícula ativa, programa,
curso e turma (inclusive `class_id=null`). A guarda não emite certificado nem
aciona Worker.

## Comportamento

- Mais de uma matrícula ativa correspondente, nenhuma aprovação correspondente
  ou mais de uma aprovação do contexto exato bloqueiam a criação.
- Aprovações de outra turma/edição não autorizam `class_id` ausente ou diferente.
- O pedido aprovado tem o contexto atual revalidado e a elegibilidade é calculada
  pela regra canônica, com eventos da edição e turma exatas.
- Revogação de matrícula, vínculo de programa ou turma bloqueia a criação.
- Com a flag desligada, o caminho legado permanece inalterado; replay idempotente,
  verificação pública e snapshots também permanecem inalterados.

## Evidência local

Os testes HTTP com `TestClient` usam verificação pública simulada. Antes da
correção, eventos da edição 2 autorizaram uma referência da turma/edição 1,
`class_id` omitido com duas aprovações retornou sucesso e vínculo revogado também
retornou sucesso. Após a correção, esses cenários são rejeitados e o caminho
exato mais replay passa.

Isto é apenas um guard de aprovação de referência; não é emissão, aceite da
Issue #5 nem gate de release.

## Revisao e regressao do coordenador

Foram acrescentados seis cenarios: turma explicitamente divergente, duas
aprovacoes publicas ambiguas, contexto publico valido com replay, edicao fixada
alterada, vinculo de turma revogado e eventos da mesma edicao em outra turma.
Os tres arquivos abaixo passaram em conjunto: **13/13**, exit code 0.

```text
python -m pytest tests/test_certificates.py tests/test_certificate_approval_gate.py tests/test_certificate_reference_context.py --basetemp ../tmp/issue5-coordinator-regression -p no:cacheprovider -q --tb=short
```

Python reutilizado do ambiente travado existente. Nenhum acesso real ao Worker,
nenhuma migration, alteracao de regras de frequencia ou suite completa local.
O guard nao prova linhagem emitida pelo Worker, nem adiciona course_version_id
persistido a CertificateReference. A emissao autenticada e a prova fisica da
Issue #5 permanecem pendentes. CI remoto sera registrado no PR, nao presumido.
