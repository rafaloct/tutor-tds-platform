# LearnPress × Tutor TDS | Matriz de paridade e critérios de aceite

**Status:** TARGET, critérios aprovados como direção de produto, **não executados**. Alimentar o checklist apenas com provas reais, marcando `PASS`, `FAIL`, `BLOCKED` ou `NOT_RUN`. Decisão e fronteiras na [ADR](ADR_2026-10-18_LEARNPRESS_FASTAPI_AUTHORITY.md).

## 1. Paridade funcional por persona

| Jornada testável | LearnPress Web | Flutter desejado | Autoridade | Gate e evidência obrigatória | Estado 18/10 |
|---|---|---|---|---|---|
| Público vê catálogo/curso e matrícula opcional | 11 cursos públicos | Catálogo público e caminho para ingresso | LP editorial | IDs/links iguais em 11 ofertas, sem login | PARCIAL: catálogo PASS, matrícula não |
| Pessoa vincula conta EAD a TDS | WP login / sessão | Minha área vinculada sem re-digitar senha | TDS vínculo, WP prova de login | 2 identidades verificadas e auditadas, logout e revogação | BLOCKED |
| Estudante consulta meus cursos | Conta LP privada | Cursos inscritos e estado com origem | LearnPress | IDs, estado e contagem iguais na web/app para A e B | NOT_RUN |
| Inscrever-se e cancelar se permitido | Endpoint/regra LP autenticados | Mesma ação sem duplicata e confirmação | LearnPress | recibo, reentrada, restrições e 409/403 | NOT_RUN |
| Retomar aula no ponto autorizado | Última lição/progresso LP | “Continuar curso” na Minha área | LearnPress | curso + lesson + estado idênticos sem assumir watch time | NOT_RUN |
| Marcar aula concluída | LearnPress | Somente comando de conclusão autorizado | LearnPress | dupla tentativa não cria evento institucional | NOT_RUN |
| Iniciar/retomar quiz do LP | Quiz publicado e autorizado | Motor LP ou ponte segura | LearnPress | respostas/gabaritos não vazam; tentativa e nota iguais | BLOCKED: grade pública sem vínculo comprovado |
| Atualização editorial | Editor LP e revisão | Atualizar grade/texto/vídeo aprovado | LearnPress | 200/304/403/404, ETag, opt-in, direitos | PARCIAL: PR #238 draft/404 público |
| Cartilhas e atividades locais | Não é a autoridade | Continuar offline identificado | Flutter local/TDS | estado não influi no percentual LP nem frequência | PARCIAL: recurso existe, isolamento transversal pendente |
| Tutor contextual | Fonte cartilha/módulo válida | Contexto por edição/lesson | TDS + curadoria RAG | sem corpus: nenhum conselho/nota inventados | PARCIAL |
| Turma, check-in, frequência | Fora do LP | Minha participação institucional | FastAPI | fonte idêntica para aluno/instrutor autorizado | NÃO INTEGRADO na Minha Área EAD |
| Certificado oficial | Portal verificador, não LP | Carteira/pedido/status TDS | TDS + Worker/KV, revisão humana | certificado validado e origem rotulada | PARCIAL, sem visão federada |
| Certificado/conclusão LP, se existir | A comprovar em staging | Se comprovado, registro separado | LearnPress legado | não importar como certificado TDS | UNKNOWN |
| Perfil e privacidade | Conta WP / exclusão LP | vínculo, escopo e pedido por controlador | Cada controlador | logout A→B, consentimento, revogação, expurgo | NOT_RUN |
| Suporte | Formulário/web/Chatwoot | Ajuda contextual sem PII indevida | Chatwoot e APIs de contexto | sem criar matrícula por ticket | PARCIAL |
| Acessibilidade e baixa rede | Site e webview | navegação sem lacuna funcional | UX/transportes | TalkBack, 200% fonte, 401/offline/retry, teclado | NOT_RUN |

**Nunca converter** `PARCIAL` em `PASS` apenas porque um widget renderiza ou porque HTTP 200 foi observado anonimamente.

## 2. Crosswalk mínimo por oferta

| Nome publicado | `wp_course_id` OBSERVED | `course_id` TDS por título (candidato, validar) | Direito institucional |
|---|---:|---|---|
| Agricultura Sustentável | 1298 | `agricultura-sustentavel` | Não inferido do título |
| Atendimento ao Cliente | 1307 | `atendimento-cliente` | Não inferido |
| Audiovisual para o Dia a Dia | 1314 | `audiovisual` | Não inferido |
| Cooperativismo e Crédito | 1321 | `cooperativismo` | Não inferido |
| Economia do Lar | 1328 | `economia-lar` | Não inferido |
| Educação Financeira | 1335 | `educacao-financeira` | Não inferido |
| Inspeção e Certificação (SIM/SIMA) | 1343 | `sim-sima` | Não inferido |
| Inteligência Artificial e Inclusão Digital | 614 | `ia-cartilha` | Não inferido |
| Sistemas Agroflorestais (SAF) | 1356 | `saf` | Não inferido |
| Automações com o Celular para o Pequeno Negócio | 1474 | **NÃO MAPEADO** | Somente oferta LP, sem CourseVersion TDS |
| IA aplicada a Processos Internos | 1709 | **NÃO MAPEADO** | Somente oferta LP; revisar público-alvo |

**Política:** mapeamento só passa a válido com revisão editorial e contratual assinada, IDs reais e versão aprovados. Não unir cursos por título nem atribuir `course_version_id` fictício. Cada linha validada deve receber o vínculo WP course, lesson, quiz, vídeo autorizado, cartilha e edição TDS, ou `unmapped` expresso.

## 3. Protocolo de E2E obrigatório em staging

Preparar um clone WP/LearnPress, dois usuários alunos `A` e `B`, uma conta editorial/instrutor e identidade TDS sintética para cada um; **nenhum CPF de pessoa real ou dados de produção**. Backup/restauração, rede e segregação de credenciais confirmados antes de iniciar.

| Caso | Operação no site | Operação no app | Asserção / prova | Estado |
|---|---|---|---|---|
| P01 Público | consultar catálogo sem login | consultar catálogo | 11 IDs e links, diferenças de 9 TDS explicitadas | NOT_RUN |
| P02 Vinculação A | login recente conta LP-A | vínculo com TDS-A | nonce/PKCE ou código verificável, somente A autorizado | NOT_RUN |
| P03 Tentativa indevida | tentar LP-B com TDS-A | negar associação silenciosa | sem IDOR, sem associação por email/CPF | NOT_RUN |
| P04 Matrícula | inscrever LP-A no curso 1298 | consultar meus cursos | mesmo ID/status/timestamp e única inscrição | NOT_RUN |
| P05 Replay | repetir requisição idêntica | reenviar com atraso | não duplicar matrícula ou lição concluída | NOT_RUN |
| P06 Lição | concluir uma lição autorizada | atualizar progresso | mesmas lições/percentual na origem LP e app | NOT_RUN |
| P07 Quiz | iniciar/finalizar quiz publicado | visualizar tentativa autorizada | mesma nota/estado; nenhum gabarito exposto | BLOCKED: quiz real vinculado pendente |
| P08 Offline | desconectar Android após fetch | consultar cache e tentar concluir | cache com carimbo, sem confirmação de mutação LP | NOT_RUN |
| P09 Conta compartilhada | sair de TDS-A e WP-A | entrar TDS-B/WP-B | nenhum progresso/certificado A em B | NOT_RUN |
| P10 Revogação | invalidar vínculo ou acesso a curso | atualizar/relogar | 401/403, cache privado inacessível e CTA correto | NOT_RUN |
| P11 Conteúdo privado | lição não liberada por editor | tentar ID direto | 403/404 e nunca texto/YouTube protegido | NOT_RUN |
| P12 Certificado | concluir EAD, solicitar TDS | ver carteira | EAD ≠ certificado oficial; aprovação humana preservada | NOT_RUN |
| P13 Instrutor | revisar turma/curso escopado | vista autorizada | mesmo contexto, sem outro aluno | NOT_RUN |
| P14 Erro servidor | induzir 5xx e timeout | retry do app | indisponibilidade explícita sem criar fato | NOT_RUN |
| P15 UX | tela pequena, fonte 200%, TalkBack | percorrer Minha área e curso | sem controles inacessíveis/contraste indevido | NOT_RUN |
| P16 Regressão | atualizar uma aula no editor LP | refresh no Flutter | revisão versionada, ETag/opt-in e mesma grade | NOT_RUN |
| P17 Certificado legado | caso somente se LP fornecer resultado | lista segregada | emissor/origem visíveis, não “TDS oficial” | UNKNOWN |

## 4. Condições de aceite por etapa

- **F0 Evidência:** mapa de rotas autenticadas, prova de permissão por persona, formatos de resposta anon/autenticada, backup/rollback comprovados. Sem inferir UI autenticada de GET 200 público.
- **F1 Crosswalk:** 11 entradas com título/ID/revisão, 9 TDS verificadas por CourseVersion e 2 marcadas `unmapped`; plano de divergência 9↔11 revisado por editor.
- **F2 Segurança:** autenticação de ambas as contas, escopo, vínculo revogável, consentimento, expiração e proteção A/B com provas negativas. Sem segredo no APK ou URL.
- **F3 UX:** Minha área funcional no app com a mesma informação do site, estados loading/empty/error/offline, acessibilidade, logout e restrições claras.
- **F4 LMS:** matrícula/lição/quiz autênticos atualizam uma única autoridade sem duplicar, com respostas de erro e replay comprovados.
- **F5 Institucional:** certificados oficiais e registros EAD separados; review humano e critérios de frequência intactos.
- **F6 Release:** CI verde, staging E2E, Android emulador e smoke físico do build final congelado, fingerprint e versionCode Play conferidos, artefato assinado/manifesto e autorização de produção/Play distinta.

## 5. Formato do recibo por execução

```text
TEST_CASE=P06
ENVIRONMENT=staging
GIT_SHA=<sha>
WP_FIXTURE=<id_opaco>
TDS_FIXTURE=<id_opaco>
DEVICE=<emulador_ou_QA>
ACTION=<comando_exercitado>
EXPECTED=<contrato_exato>
OBSERVED=<resultado_verificado>
STATUS=PASS|FAIL|BLOCKED|NOT_RUN
EVIDENCE=<caminho_relatório_sanitizado_ou_link>
REDACTION=PASS|FAIL
OWNER=<papel_responsável>
```

Proibido imprimir senha, token, CPF/NIS, gabarito, nome real ou tela privada em evidências. Não alegar `PRODUCTION_READY` a partir de `PASS` parcial. Se dois testes repetidos falharem pelo mesmo motivo, registrar causa de fronteira, arquivos afetados, mitigação e ação humana mínima antes de novas alterações.
