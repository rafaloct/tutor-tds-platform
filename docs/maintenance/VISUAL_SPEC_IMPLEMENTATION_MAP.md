# Mapa de Implementação da Especificação Visual

Fonte: `Tutor_TDS_Especificacao_Visual_Manutencao_v1.pdf`, 34 páginas.

## Já existente ou parcialmente atendido

| Requisito | Estado no código |
|---|---|
| Microfone sob demanda | implementado em `genui_assistant_screen.dart`; permissão ocorre após toque |
| Turnos em bolhas | implementado no Tutor IA |
| Resumo em seções | implementado em visão geral, pontos-chave, exemplos e perguntas |
| Quiz com feedback imediato | implementado |
| Simulado com cronômetro | implementado |
| Certificados verificáveis | implementado via Cloudflare KV/HMAC |
| Layout responsivo básico | implementado em Home e Central de Estudos |

## Incremento 1 - fundação visual segura

1. ~~Criar tokens/componentes compartilhados do design system.~~ Concluído com `AppTheme`, assinatura cromática, espera, retomada e controles de geração compartilhados.
2. ~~Implementar `TDSWaitExperience` e substituir spinners vazios.~~ Concluído em 2026-09-19 nas telas Home, Tutor IA e materiais de estudo.
3. ~~Tornar cabeçalho/composer do Tutor contextuais.~~ Concluído em 2026-09-19 com rótulo do conteúdo e orientação de entrada por modo.
4. ~~Adicionar ações iniciais úteis e continuidade de estudo.~~ Concluído em 2026-09-19 com explicação simples, exemplo prático, prática com feedback e retomada local da cartilha.
5. ~~Cobrir os componentes com widget tests e feature flags.~~ Suíte final com
   163/163 testes; cobertura crítica acima de 80%, enquanto os goldens ainda são
   gate da Onda 5.

O componente de espera usa mensagens e dicas locais, sem nova chamada de IA e sem porcentagem artificial. O comportamento foi coberto por widget test.

O Tutor não envia mais o contexto automaticamente ao abrir a tela. O contexto prepara a conversa localmente; a chamada de IA só ocorre após uma ação explícita do estudante.

O progresso da cartilha é persistido no aparelho por curso. A Home mostra a próxima ação e a experiência restaura seção, mensagem, perguntas respondidas e conclusão sem depender de rede.

## Incremento 2 - aprendizagem contextual

1. ~~Mover dificuldade para configuração da atividade.~~ Concluído em painel explícito antes da geração.
2. ~~Adicionar quantidade/fonte antes de gerar flashcards, quiz, resumo e simulado.~~ Concluído; resumo usa tamanho em lugar de contagem de itens.
3. ~~Exibir progresso, autoavaliação e origem dos cartões.~~ Concluído com contador, barra de progresso, origem e totais “lembrei”/“para revisar”.
4. ~~Estruturar feedback de quiz com fonte e próxima ação.~~ Concluído com correção, explicação, cartilha de origem e orientação contextual.
5. ~~Persistir resumo/tentativa e suportar retomada offline.~~ Concluído para resumos, quizzes e simulados; a Home prioriza a atividade local mais recente.


## Incremento 3 - Home e dados remotos

1. Home mostra próxima ação/progresso, curso de staging e retomada local; professor
   e monitor têm capabilities distintas provadas fisicamente.
2. `CourseRepository`, API, cache e fallback estão operacionais; curso sintético
   remoto e cache em modo avião foram vistos no Xiaomi.
3. Eventos e sincronização autenticada estão implementados/testados; o E2E
   offline -> morte/reabertura -> reconexão -> banco foi provado para a
   tentativa sintética. Sheets real continua gate externo da Onda 5.
4. RBAC deriva do vínculo backend; re-login, professor, monitor e dashboards
   foram provados no dispositivo. Aluno/admin e negações cruzadas ainda faltam.

## Incremento 4 - novas superfícies

- Classroom do professor: implementado; login/capability/dashboard de staging
  provados fisicamente.
- Monitor por exceção: implementado; Home/capability/painel acionável provados
  fisicamente.
- Evidence Engine: sessão, QR/check-in, recuperação, revisão e relatório
  implementados; check-in físico ainda inconclusivo.
- Creator/vídeo: catálogo/player e playback público provados; smoke real em
  staging aprovou grant prefixado, tamper, telemetria/idempotência, rating,
  bloqueio/revogação, histórico e arquivo. Provider institucional, Score v2
  operacional e operação comercial continuam pendentes.

Essas superfícies usam backend, RBAC e contratos reais. O aceite visual ainda
depende de TalkBack, fonte/tema/landscape, confirmação da assinatura conjunta e
dos E2E restantes.

## Ordem de implementação

```text
componentes compartilhados
  -> contratos/API e eventos
  -> Home e aprendizagem
  -> Classroom/evidência
  -> Creator/comercial
  -> freeze e QA
```
