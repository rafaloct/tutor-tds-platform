# Issue #139 — QA visual no Pixel 8 Pro

Data: 2026-10-05

## Fonte de verdade

- PR: #144
- Branch: `feature/issue-139-class-lifecycle-wizard-20261005`
- HEAD funcional validado antes do QA: `7a3d80de7d005b43e3bded87cb4b8ea49fd94eda`
- AVD: `Pixel_8_Pro`
- Serial ADB: `emulator-5560`
- Android: 15 / API 35
- Resolução: 1344x2992
- Density: 480

## APK

- Package: `com.tutortds_cartilhas.dev.dynamicqa.r13900000000000000000000000000000`
- SHA-256: `AD9F5BED24214D802F9EC61F36E2D22E170A984D5ADFF08427729D794E036E6B`
- Build reutilizado, sem recompilação nesta execução.
- Instalação no `Pixel_8_Pro`: PASS.

## Evidências

1. `01-management.png`: Gestão mostra Preparar turma e Encerrar turma somente após capability do gateway.
2. `02-prepare-where.png`: etapa Onde será?, separando município/local da oferta de residência do participante.
3. `03-prepare-formation.png`: Programa TDS + Inteligência Artificial aplicada + "Edição publicada atual", sem ID/SHA técnico.
4. `04-prepare-when.png`: etapa de período.
5. `05-prepare-team.png`: professora responsável e dois monitores selecionados.
6. `06-prepare-participants.png`: 18/30 vagas e referência explícita ao fluxo já existente de participantes, sem segunda tela de cadastro.
7. `07-prepare-review.png`: resumo operacional completo e botão Preparar turma habilitado pela capability.
8. `08-close-readiness.png`: readiness, 0 encontros abertos, 4 pedidos de certificado como informação não bloqueante e aviso de independência do certificado.
9. `09-close-ready-to-submit.png`: motivo + confirmação explícita liberam o botão Encerrar turma no cenário autorizado.

`00-home.png` registra o app QA aberto no mesmo AVD antes de entrar em Gestão.

## Limites do fake gateway empacotado

O fake contém cenários `programOperator()`, `denied()` e `coordinator(readinessCanClose: false)`, mas o APK QA atual conecta a Home a `FakeClassLifecycleGateway.coordinator()` com `readinessCanClose=true` e não expõe seletor de cenário em runtime.

Por isso, não foi alterado código apenas para fabricar screenshots de:
- `open_sessions` como blocker;
- usuário sem capability.

Esses estados permanecem cobertos pelos testes focais da #139, incluindo o bloqueio de fechamento por readiness e a ausência de ação indevida sem capability.

## Resultado visual

VISUAL_QA=PASS para o fluxo empacotado e acessível no APK #139 no `Pixel_8_Pro`.

## Gate final após QA visual

- `flutter analyze --no-pub`: PASS, sem issues.
- suíte focal #139: 14/14 PASS.
- `git diff --check`: PASS antes do commit de evidências.
- Código funcional permaneceu no HEAD `7a3d80de7d005b43e3bded87cb4b8ea49fd94eda` durante todo o QA visual.
