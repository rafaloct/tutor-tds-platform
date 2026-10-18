# F3d — Homologação B0 das páginas Minha área (Issue #274)

Smoke de aceitação das três páginas de conta do tema candidato
**PR #251** (`wordpress/tds-child-theme`, HEAD `9905580`, versão `0.3.0`)
executado no **WordPress + MariaDB sintético isolado** do dfd627
(`http://127.0.0.1:18732`, DB `tdsqam`), com snapshot + rollback provado.

## Contexto / causa da lacuna

- Slugs `minha-area`, `meus-cursos`, `certificados` retornavam **404** na
  sandbox porque **não existiam páginas cadastradas** — lacuna de fixture,
  **não** prova de defeito em produção nem no tema.
- O tema instalado era `0.2.1`; para homologar o candidato real, os arquivos
  exatos de PR #251 foram carregados de forma **reversível**
  (`b0qa-snapshot/theme-backup` + hash manifest), com restauração total no fim.

## Ambiente / isolamento (OBSERVED)

| fato | valor |
|---|---|
| DB_NAME | `tdsqam` |
| siteurl/home | `http://127.0.0.1:18732` (loopback only) |
| usuários | 5 contas sintéticas `*@qa-synthetic.test` — nenhum dado real |
| tema antes/depois | `tds-child-theme@0.2.1` → candidato `0.3.0` → `0.2.1` |
| hash tema candidato (42 arquivos) | `7917f40c…9081` (idêntico ao git archive local) |
| hash tema restaurado | `c44f0db1…7746` (== snapshot inicial) |
| wp-cli | `php wp-cli.phar --allow-root --path=wordpress-mysql` |

## Fixture criada (marcada `tds_qa_b0=1`, revertida no trap)

| página | id | template |
|---|---|---|
| `minha-area` | 26 | `templates/minha-area.php` |
| `meus-cursos` | 27 | `templates/meus-cursos.php` |
| `certificados` | 28 | `templates/certificados.php` |

## Resultados OBSERVED (execução manual homologada — 18 sinais)

| # | verificação | resultado |
|---|---|---|
| 1 | guest `GET /minha-area/` | **200** + `data-tds-state="guest"` |
| 2 | guest `GET /meus-cursos/` | **200** + `guest` |
| 3 | guest `GET /certificados/` | **200** |
| 4 | CTA login guest | `wp-login.php?redirect_to=…127.0.0.1/minha-area/` — **same-origin** |
| 5 | opt-in de cadastro | `Criar conta EAD` presente |
| 6 | separação certificado | "Certificado oficial do Programa TDS" **e** "Conclusão de curso no EAD" — textos distintos, sem fusão |
| 7 | login WP web student-A/B | **302** (cookie session — não JWT LP/TDS) |
| 8 | A logado `minha-area`/`meus-cursos` | 200 + `data-tds-state="connected"` + link de logout |
| 9 | saudação correta | `Olá, student-A` só na sessão A; `Olá, student-B` só na B — **zero vazamento cross-account** |
| 10 | LP profile disponível | `learn_press_get_page_id('profile')=5` → botão "Abrir meu perfil EAD" |
| 11 | cookie forjado | 200 + `guest` — **fail closed** |
| 12 | logout | link same-origin com nonce → interstitial `403` (padrão WP) → confirm `302` → `/minha-area/` volta a `guest` |
| 13 | open redirect | `?redirect_to=https://evil.example` ignorado — página normal 200, sem redirect emitido |
| 14 | B0 | nenhum token TDS, SSO, broker, compartilhamento de sessão — logins LP e TDS permanecem separados |

**Rollbacks provados:** `qa_meta=0`, `tpl_meta=0`, `pages_total 8→8`,
`posts_total 15→15`, hash do tema idêntico ao snapshot, slugs voltam a **404**.

## UNKNOWN / BLOCKED

- Conteúdo interno da aba `courses` do perfil LP não foi assertado aqui —
  escopo do contrato de leitura F3c (PR #269).
- Estado `unavailable` visto nas páginas é do componente "Acesso ao app em
  configuração" (CTA global do app), **não** do learner-area.
- Comportamento com `lp profile` **não configurado** (fallback honesto)
  não exercitado — não foi desconfigurado por segurança da fixture.

## Como reproduzir

```bash
# dentro do sandbox (cwd = raiz onde há wp-cli.phar e wordpress-mysql/)
source f0_env.sh
THEME_DIR=<extração de wordpress/tds-child-theme @ PR251 HEAD> \
BASE_URL=http://127.0.0.1:18732 \
bash tooling/qa/ead_b0_portal_smoke/b0_run.sh
```

O runner faz snapshot → troca reversível → cria páginas `tds_qa_b0` →
probes guest/A/B/forjado/logout/redirect → **rollback em trap** (exit 3 se
o hash divergir). Saída = sinais booleanos + códigos HTTP; sem HTML
autenticado, JWT, cookie, senha ou títulos de rascunho em evidência.

## Riscos / limites

- QA é do **candidato exato PR #251** numa sandbox sintética — não valida
  produção nem outra versão do tema.
- Instalação do tema/páginas no EAD real continua **gate humano**.
- `MERGE_ALLOWED=NO`, `PRODUCTION_ALLOWED=NO`, `FORCE_PUSH_ALLOWED=NO`.
