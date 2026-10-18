# Auditoria de preservação de conteúdo público — ead.ipexdesenvolvimento.cloud

Data: 2026-10-18 · Refs: Issue #215 (preservar conteúdo/rotas na promoção do tema
candidato do PR #214). Método: leitura pública HTTP (visitante anônimo, sem
credenciais, sem escrita). Nada em produção foi alterado.

## 1. Inventário de rotas públicas (OBSERVED)

| Rota | HTTP | Observação |
|---|---|---|
| `/` | 200 | Home — hero "Formação gratuita nos territórios do Tocantins", cards, CTA app |
| `/sobre/` | 200 | Missão/visão/valores/princípios completos (texto capturado) |
| `/metodologia/` | 200 | Princípios + 5 trilhas formativas |
| `/contato/` | 200 | Formulário **renderizado** (nome, e-mail, telefone/WhatsApp, assunto) — envio **não exercitado** (UNKNOWN; ver §6) |
| `/cursos/` | 200 | **Catálogo já conectado à API acadêmica** — "9 cursos publicados na fonte acadêmica oficial", cards com "Abrir curso e aulas →" |
| `/noticias/` | 200 | Lista de notícias/comunicados (Tudo/Notícias/Visitas/Comunicados/Eventos/Instagram) |
| `/tutor-tds/` | 200 | Página do app (Google Play, guias) |
| `/tutorial/` | 200 | "Como usar o aplicativo Tutor TDS" |
| `/links-uteis/` | 200 | Hub de serviços/orientações (~41k chars renderizados) |
| `/galeria/` | 200 | Galeria de encontros |
| `/interesse/` | 200 | Manifestar interesse |
| `/sob-demanda/` | 200 | Capacitação sob demanda |
| `/cadastro/` | 200 | Cadastro |
| `/minha-area/` | 200 | Página existe (shell EAD — profundidade autenticada = F0/PR #251) |
| `/certificados/` | 200 | Página existe |
| `/courses/automacoes-celular/` | 200 | Rota LearnPress de curso funciona |
| `/termos/` | 200 | **Renderiza conteúdo de Notícias** — slug/título inconsistente (ver §4) |
| `/profile/` | **404** | Rota LearnPress profile padrão não existe |
| `/meus-cursos/` | **404** | Sem rota LP de meus cursos |
| `/privacidade/` | **404** | **Página de privacidade ausente** (lacuna para app que coleta dados) |

## 2. Menu público vigente (OBSERVED)

Itens (header + mobile, deduplicados):
Início · Cursos · Notícias · Sobre · Contato · Minha Área · Metodologia ·
Como usar o aplicativo Tutor TDS → `/tutorial/` · Certificados · Tutor TDS →
`/tutor-tds/` · Links Úteis · Automações → `/courses/automacoes-celular/` ·
Entrar → `/wp-login.php` · Cadastrar → `/cadastro/`.

Extra: `/galeria/`, `/interesse/`, `/sob-demanda/` existem mas **não** estão no
menu principal — confirmar se devem entrar nas posições `tds-primary`/`tds-footer`
do tema candidato ou ficar só linkadas internamente.

## 3. Conteúdo vigente extraído (evidência)

Textos completos renderizados em `evidence/2026-10-18-public-routes/*.txt`
(sobre, metodologia, contato, home, links-uteis, tutor-tds, tutorial). Estes
são os conteúdos que a Issue #215 registra como vivendo no PHP legado com
`post_content` vazio — este dump é a referência canônica para migrar para
editor/templates novos **sem perda**, mantendo IDs/URLs.

Pontos de conteúdo que NÃO podem se perder na promoção:
- Home: "36 municípios", "Bico do Papagaio e Jalapão", "100% Gratuito CadÚnico/PBF", parceria UFT/IPEX/MDS.
- Sobre: Missão/Visão/Valores/Princípios completos.
- Metodologia: 5 trilhas formativas + princípios (>60% carga aplicada).
- Contato: formulário + assuntos (Inscrição/Certificado/Acesso/Parceria/Imprensa).
- Catálogo: vitrine FastAPI (anônima) já funcional — preservar opção `tds_public_api_base_url` configurada.
- LP course routes (`/courses/<slug>/`) devem continuar resolvendo.
- Links Úteis: 97 âncoras com URLs externas (gov.br, Ruraltins, Embrapa, BCB,
  R2/VTT) preservadas em `evidence/2026-10-18-public-routes/links-uteis-anchors.txt`
  — são os destinos a restaurar na migração.

## 4. Anomalias encontradas

1. `/termos/` renderiza a página de Notícias — slug provavelmente aponta para a
   página errada ou o título/conteúdo de "Termos" nunca foi escrito. Decidir:
   criar Termos de Uso reais ou redirecionar.
2. `/privacidade/` 404 — recomendado criar Política de Privacidade antes de
   promover o tema (app coleta dados; LGPD).
3. `/profile/` e `/meus-cursos/` 404 — lacuna já coberta pelo PR #251
   (learner-area no child theme + página Meus Cursos).
4. Menus `primary`/`mobile_menu` têm entradas repetidas (já registrado na #215)
   — o inventário acima é o alvo deduplicado.

## 5. Plano de preservação proposto (TARGET — pendente de gate humano)

1. **Antes de trocar o tema**: backup privado de `wp_posts`/`wp_options`/menus +
   export do conteúdo legado (humano com acesso admin/SSH — fora do meu alcance).
2. Migrar os textos desta evidência para `post_content`/templates novos,
   mantendo IDs de página e URLs (checklist por rota na §1).
3. Mapear menus: `tds-primary` = itens do inventário §2 sem duplicatas;
   `tds-footer` = institucional (Sobre/Contato/Privacidade/Links).
4. Configurar opções fora do código: `tds_app_access_url` (Google Play),
   `tds_public_api_base_url` (FastAPI staging/prod), `tds_support_base_url`
   (só após destino validado).
5. LearnPress: manter páginas referenciadas (cursos 668, perfil 667,
   checkout 671, candidatura 672) até transição explícita — PR #251 já propõe
   apontar Profile → `/minha-area/`.
6. Diff de dados antes/depois + restauração ensaiada em sandbox (dfd627 WP/LP
   disponível) antes de qualquer promoção.
7. Smoke pós-promoção: re-rodar o inventário de rotas da §1 como checklist.

## 6. Limites

- `/contato/`: o GET anônimo só comprova o formulário renderizado. O envio NÃO
  foi exercitado (UNKNOWN) — atenção: o handler legado
  (`wordpress/legacy-runtime/tds-child-theme/functions.php`) reporta sucesso
  mesmo quando `wp_mail` falha; o checklist pós-promoção precisa de um envio de
  teste com confirmação real de entrega, não apenas do retorno 200 da página.
- Conteúdo capturado do render público; `post_content` e opções internas não
  foram lidos (sem acesso admin) — a Issue já os descreve.
- Backup/restore e escrita em produção: fora de escopo (gate humano).
- Elementos dinâmicos (JS-only) podem não constar nos dumps de texto.