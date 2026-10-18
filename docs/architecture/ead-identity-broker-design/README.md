# EAD Identity Broker — design de vínculo TDS ↔ LearnPress (Issue #272)

**Status: TARGET / NOT IMPLEMENTED — documento de decisão, zero implementação.**

Avaliação da arquitetura concreta para vincular voluntariamente a conta
institucional TDS (FastAPI) à conta EAD (WordPress/LearnPress), de modo que o
app Flutter possa oferecer Minha Área/reader autenticado **sem SSO caseiro** e
sem mutação em produção.

## Documentos

| Arquivo | Conteúdo |
|---|---|
| `01_OBSERVED_CAPABILITIES.md` | Fatos verificados (código + sandbox sintético) sobre autenticação em cada lado |
| `02_ALTERNATIVES_MATRIX.md` | Matriz de decisão das abordagens A/B/C + recomendação |
| `03_TARGET_PROTOCOL.md` | Protocolo de vínculo proposto: fluxos, artefatos, revogação |
| `04_THREAT_MODEL.md` | Matriz de ameaças + casos negativos obrigatórios |
| `tooling/qa/ead_identity_broker_design/` | Vetores de teste offline (sem rede, sem segredo) |

## Resumo executivo

- **Não existe federação disponível hoje.** O sandbox WP 7.1.3 + LP 4.3.6 não
  tem provider OIDC/OAuth2 instalado; `wp_is_application_passwords_available()`
  retorna `no` (HTTP loopback); o único token usuário-scoped é o **JWT do
  LearnPress** (`POST /learnpress/v1/token`), válido **7 dias**, **não aceito
  pelo WP core** e **não revogado por logout**.
- **Recomendação:** Alternativa **B** — *dois logins explícitos* + **vínculo
  verificado por introspecção**: o Flutter obtém o JWT LP diretamente do EAD
  (senha nunca passa pelo FastAPI), e um futuro broker FastAPI verifica esse
  JWT **uma única vez** via `POST /learnpress/v1/token/validate` +
  `GET /learnpress/v1/users/{id}` (IDOR real) antes de gravar
  `tds_user_id ↔ wp_user_id ↔ environment`. O JWT LP é **descartado** — jamais
  armazenado nem repassado como sessão.
- **Por que JWT LP não é `EadSessionProof`:** TTL 7d ≫ 15min exigido pelo
  contrato Flutter; `aud` implícito é LP-REST, não o broker; logout WP não
  revoga; não há refresh nem escopo. O proof correto é um artefato curto
  emitido pelo broker após verificação fresca.
- **Alternativa A** (provider OAuth2/OIDC dedicado no WP) é o alvo ideal de
  longo prazo, mas hoje é **UNKNOWN/BLOCKED**: exige plugin de terceiro,
  homologação e instalação por humano. Fallback honesto é B, nunca SSO
  improvisado.

## Decisão humana mínima solicitada

1. Aprovar **B** como caminho de vínculo (ou exigir A com provider aprovado).
2. Confirmar que o JWT LP pode transitar Flutter→EAD diretamente (TLS, secure
   storage, nunca para FastAPI).
3. Autorizar abertura de Issue de implementação do broker (schema + rotas
   TARGET) — separada desta.
