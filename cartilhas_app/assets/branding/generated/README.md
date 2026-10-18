# Assets gerados — pacote "anti-inércia" do app

**Status:** DRAFT — arte pronta para inserção; nenhuma linha de código do app alterada.
**Gerado em:** 2026-10-18, GPU local (dfd627, NVIDIA L4) via ComfyUI + SDXL-Turbo.
**Complementa:** PR #255 (splash/loading/error/padrão cerrado — primeira leva).

## Objetivo

Ativos estáticos para **não deixar o usuário inerte em telas frias** — momentos de
loading, espera de sincronização, estados vazios e transições. Tudo é dado
estático (JSON + JPEG): o app consome sem dependência de backend e sem
interferir no trabalho em andamento do outro agente.

## Conteúdo

### `curiosities.json` — cartões de curiosidade (20 itens)

Schema `tds.curiosities/v1`, pt-BR, formato pergunta → resposta curta + fonte.
Conteúdo no estilo de comunicação pública Embrapa/ATER+/MDS/MDA — agroecologia,
cerrado, capim dourado, CAF/PAA/PNAE, práticas de campo — mais dois itens de
contexto do próprio programa (modo offline, diferença certificado EAD × TDS).

Uso sugerido (a implementar pelo app quando convier): sortear 1 item durante
loading >2s, telas de espera de sync, empty states e tela offline. Cada item é
autocontido — nenhum depende de estado, conta ou rede.

### Ilustrações 1024×1024 JPEG q88 — flat illustration, paleta oficial

Paleta restrita às cores do manual: `#093AF4`, `#FF341B`, `#F6D846`, `#18D010`,
`#262626`, fundo branco. Elementos do público: buriti, capim dourado, veredas,
agricultura familiar, casas simples do interior do Tocantins.

| arquivo | uso previsto |
|---|---|
| `onboarding_welcome.jpg` | primeira abertura / boas-vindas |
| `success_complete.jpg` | conclusão de curso/lição, conquistas |
| `sync_offline.jpg` | sincronização após período offline |
| `study_tip.jpg` | dica de estudo / tela de pausa |
| `curiosity_card.jpg` | verso/companion visual dos cartões de curiosidade |

### Leva "assentamento" — público majoritário (5 ilustrações adicionais)

Gerada após feedback de que a primeira leva estava "cerrado genérico".
Linguagem visual dos assentamentos da reforma agrária no Tocantins.

| arquivo | uso previsto |
|---|---|
| `assent_mutirao.jpg` | trabalho coletivo na roça de mandioca — comunidade/ajuda |
| `assent_casa_farinha.jpg` | casa de farinha — contexto produtivo regional |
| `assent_feira.jpg` | feira do agricultor familiar — renda/associativismo |
| `assent_parcela.jpg` | parcela de assentamento vista aérea — território |
| `assent_mulher.jpg` | mulher agricultora na roça — protagonismo feminino |

`curiosities.json` ganhou 4 itens (c021–c024): assentamento/INCRA, mutirão,
casa de farinha, feira do agricultor — total 24 cartões.

## Conformidade de marca

- Ilustrações NÃO contêm a marca TDS — uso da marca segue as regras do manual
  (arquivo oficial `marca_isolada_tds.png`, sem distorção/recolorir/IA).
- Nenhum texto embutido nas imagens (evita artefatos de IA e permite i18n).
- Prompts e workflow ComfyUI em `/workspace/tds-assets-20261018/` no dfd627.
- Nemotron (LLM local) estava indisponível na janela de geração; contexto local
  foi aplicado manualmente nos prompts — registrado por transparência.

## Limites

- Revisão visual humana recomendada antes do merge (semiótica da ilustração).
- Curiosidades citam programas públicos reais — validar redação final com a
  coordenação pedagógica antes de publicar.
- `AGUARDAR_COORDENADOR`, `MERGE_ALLOWED=NO`, `PRODUCTION_ALLOWED=NO`.
