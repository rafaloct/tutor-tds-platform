# Wave 1 — aceite funcional em staging

**APROVADO em 2026-09-23.** Autoriza avançar à Wave 2; não autoriza promoção
de produção ou publicação na Play. Registro verificável:
[wave1-acceptance.json](evidence/wave1-acceptance.json).

O app existente foi preservado e recebeu contexto resolvido, matrícula/edição
persistidas, progresso compartilhado e fila SQLite com feedback de entrega.
Não houve substituição da autenticação nem migração de produção para Supabase.

| Critério | Evidência aprovada |
| --- | --- |
| Aluno → Membership → Enrollment → CourseVersion → Home | login real pela UI Android; edição matriculada 1 preservada enquanto catálogo público oferece edição 2 |
| Conteúdo → atividade → persistência | interação real no leitor/quiz; progresso anterior de 5% aumenta para 7,5%; histórico preservado |
| Fechar → reabrir | processo Android encerrado; mesma posição e mesmos 7,5% confirmados |
| Offline → fila → fechar → reabrir | rede indisponível verificada; mesmos IDs/corpos sobrevivem; pendência visível na Home e no leitor |
| Reconexão → envio único | progresso chega a 10%; aviso de pendência desaparece; replay idêntico retorna 200 sem nova evidência/progresso |
| Instrutor da mesma turma | logout/login pela UI; dashboard exibe exatamente a projeção do aluno; acesso deriva do vínculo, embora User.role legado seja student |
| Negação/isolamento | HTTPS real: quatro respostas 403 para identidade sem acesso; segunda matrícula da mesma edição fica em 0%; original permanece em 10%; 74 eventos inalterados |
| Regressão local | 344 testes Flutter, análise global sem issues, 281 testes API com dependências fixadas; 15 testes adicionais do verificador de isolamento |
| Banco e implantação | migration 0019 em Supabase staging; migração populada/downgrade/forward testados em PostgreSQL descartável; deployment Cloud saudável |

As seis fases Android pertencem à **mesma execução**, em processos separados,
sem desinstalação entre fases. Ambiente: emulador Android 16, pacote
`com.tutortds_cartilhas.dev`, FastAPI Cloud + Supabase isolados. Deployment:
`b67f0921-d2c4-400d-a28e-c8832eb268fb`.

O consolidado confere hashes de 195 fontes Flutter/testes/configuração e 54
arquivos do backend implantado, além do lock de dependências. Evidências
anteriores permanecem históricas, inclusive falhas já corrigidas; não foram
reescritas como se tivessem passado.

## Evidências e reprodução

- [Android completo](evidence/context-android-gate.json) — runner
  `tooling/test_context_android.ps1`, seis fases, logs locais no diretório
  `tmp/context-android-20260923-173901/` da raiz.
- [Isolamento HTTPS](evidence/cloud-context-isolation.json) —
  `api/ops/verify_cloud_context_isolation.py`; executado depois do Android.
- [Gate Flutter](evidence/wave1-flutter-local-gate.json),
  [deployment fixado](evidence/cloud-locked-deployment.json) e
  [procedimento de staging](CLOUD_STAGING.md).

Usar somente dados sintéticos e os arquivos locais de configuração ignorados
pelo Git. O APK de integração contém definições de QA e não é distribuível.
Não resetar LearningEvents para repetir teste. O verificador de isolamento
acrescentou uma segunda turma; qualquer próxima jornada com cliente novo deve
escolher a turma explicitamente na UI. A execução aceita acima ocorreu antes
dessa adição. Repetição exige respeitar os guards de estado do runner.

## Limites e próximo gate

Flags continuam false por padrão; true apenas no candidato de staging.
Retenção dos recibos SQLite, paridade visual integral, QA físico, versão/AAB
assinado, privacidade/Data Safety e Play continuam pendentes antes de promover.
Não substituir o freeze existente nem marcar o produto PRODUCTION_READY.

Próxima fatia: auditar e fechar `course_publication_path` na Wave 2, aproveitando
Course/CourseVersion/editor existentes. Publicar conteúdo novo sem rebuild do
Flutter e preservar a versão imutável de turmas já matriculadas.
