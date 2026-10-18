# Guia de inserção — como usar sem ficar "chato" no app

Princípio: **a ilustração nunca é a tela**. Ela acompanha conteúdo como faixa
ou card — máximo ~35% da altura útil no celular, ~25% em desktop/tablet.
Texto sempre fora da imagem (nunca sobreposta — legibilidade + i18n).

## Formatos disponíveis

| sufixo | dimensões | aspecto | onde usar |
|---|---|---|---|
| `_banner16x9` | 1280×720 | 16:9 | topo de tela/card largo, header de seção |
| `_card4x3` | 1200×900 | 4:3 | card médio em grid/carrossel |
| `_spot` | 600×600 | 1:1 | diálogo, empty state compacto, avatar de contexto |
| `_strip_wide`* | 1344×768 | ~16:9 nativa | faixa de loading/splash inferior |
| (raiz, `.jpg`) | 1024×1024 | 1:1 | máster/original — não usar direto em tela |

`*` gerada nativa em wide (não é crop).

## Mapa tela → asset sugerido

| momento | asset | formato | comportamento |
|---|---|---|---|
| Splash/boot | `splash_screen_white.png` (PR #255) | full | marca centrada — já entregue |
| Loading >2s (fetch de curso, login) | `loading_strip_wide` + 1 cartão de `curiosities.json` | faixa ~160dp + card | card de curiosidade rotativo; some quando dados chegam |
| Sync offline → online | `sync_offline` | `_banner16x9` ~140dp | banner no topo da snackbar/tela de sync |
| Lista de cursos vazia | `empty_state_wide` | `_banner16x9` | header do empty state + CTA "ver catálogo" |
| Erro sem internet | `error_offline_hero` (PR #255) | `_card4x3` | card + botão retry — nunca full-screen |
| Erro genérico | `error_generic_hero` (PR #255) | `_card4x3` | idem |
| Conclusão de curso/lição | `success_complete` | `_card4x3` ou `_spot` | card no dialog de conquista |
| Onboarding 1ª abertura | `onboarding_welcome` | `_banner16x9` | header do carrossel de boas-vindas |
| Dica de estudo contextual | `study_tip` + item de `curiosities.json` | `_card4x3` | card em home/dashboard, troca a cada abertura |
| Diálogo de curiosidade ("Você sabia?") | `curiosity_card` + item do JSON | `_spot` 120–160dp | imagem pequena à esquerda do texto |
| Comunidade/associação | `assent_mutirao`, `assent_feira` | `_banner16x9`/`_card4x3` | headers de seções comunitárias |
| Contexto produtivo do curso | `assent_casa_farinha`, `assent_parcela`, `assent_mulher` | `_card4x3` | capas/headers de trilhas de agroecologia |

## Curiosidades — regra de exibição

- Máximo 1 cartão por tela; rotação por sorteio local, sem repetição na mesma
  sessão quando possível.
- Loading curto (<2s): não mostrar — evita "flash" de conteúdo.
- O cartão morre junto com o estado que o criou (dismiss automático).
- Offline completo: JSON é asset local — funciona sem rede, ideal para telas
  de espera/offline.

## Implementação

`integration/curiosity_card.dart` é um widget pronto de exemplo (model do JSON
+ card imagem+pergunta, ~120 linhas, sem dependência nova). O agente do app
pode copiar, adaptar ao design system ou ignorar — é referência, não
obrigação.

Declaração no `pubspec.yaml` (quando o app for consumir):

```yaml
flutter:
  assets:
    - cartilhas_app/assets/branding/generated/variants/
    - cartilhas_app/assets/branding/generated/curiosities.json
```
