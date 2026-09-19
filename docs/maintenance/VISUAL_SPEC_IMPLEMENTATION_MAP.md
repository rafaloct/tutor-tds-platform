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
5. Cobrir os componentes com widget tests e feature flags.

O componente de espera usa mensagens e dicas locais, sem nova chamada de IA e sem porcentagem artificial. O comportamento foi coberto por widget test.

O Tutor não envia mais o contexto automaticamente ao abrir a tela. O contexto prepara a conversa localmente; a chamada de IA só ocorre após uma ação explícita do estudante.

O progresso da cartilha é persistido no aparelho por curso. A Home mostra a próxima ação e a experiência restaura seção, mensagem, perguntas respondidas e conclusão sem depender de rede.

## Incremento 2 - aprendizagem contextual

1. ~~Mover dificuldade para configuração da atividade.~~ Concluído em painel explícito antes da geração.
2. ~~Adicionar quantidade/fonte antes de gerar flashcards, quiz, resumo e simulado.~~ Concluído; resumo usa tamanho em lugar de contagem de itens.
3. ~~Exibir progresso, autoavaliação e origem dos cartões.~~ Concluído com contador, barra de progresso, origem e totais “lembrei”/“para revisar”.
4. Estruturar feedback de quiz com fonte e próxima ação.
5. Persistir resumo/tentativa e suportar retomada offline.

## Incremento 3 - Home e dados remotos

1. Home deve mostrar próxima ação, pendências e progresso.
2. `CourseRepository` consulta API e mantém assets como fallback offline.
3. Cada retomada/conclusão emite LearningEvent idempotente.
4. Interface varia por papel somente depois de RBAC no backend.

## Incremento 4 - novas superfícies

- Classroom do professor.
- Monitor por exceção.
- Evidence Engine.
- Creator/vídeo com finalidade pedagógica.

Essas telas dependem do backend, eventos, RBAC e contratos da Onda 1; não devem ser protótipos desconectados da fonte de dados.

## Ordem de implementação

```text
componentes compartilhados
  -> contratos/API e eventos
  -> Home e aprendizagem
  -> Classroom/evidência
  -> Creator/comercial
  -> freeze e QA
```
