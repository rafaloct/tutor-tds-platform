# Xiaomi — leitura do pedido e decisão da equipe

Data: 2026-09-21. Código do app: `c7aeffd` (implementação Flutter de `04204c1`).
Somente `com.tutortds_cartilhas.dev`, versão `1.4.0-dev`, instalado com `adb install -r`
preservando dados. O app publicado não foi reinstalado nem alterado.

Build: `flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=config/staging.qa.json --no-pub`.
APK SHA256: `9d862afc66fafb8d7c487b0f66f16a74c84b5e610fec646c6ba71bd2cd303c9c`.
API: staging `04204c1`, migração PostgreSQL `0016`. Gateway IA vazio no QA.
Build passou, com aviso existente de futura incompatibilidade KGP em plugins;
não foram atualizadas dependências nesta validação.

## Evidência observada

1. Home → Meus certificados → Pedidos de certificado, reutilizando sessão
   sintética existente. A carteira ficou vazia: não surgiu certificado emitido.
2. Pedido real `1df9d709-29f4-4163-8a7f-42223ea78b76`, estado “Precisa de ajustes”,
   orientação do teste de staging e tempo validado `0.01 h de 40.00 h`.
3. Nome da turma QA e identificação expandida conferidos:
   matrícula `741f5e1b-380f-4889-9e72-774d6064f994`, edição
   `c276ae19-3f49-4271-99ae-2a367e04d517` e mesmo pedido do PostgreSQL.
4. “Solicitar nova análise” abriu diálogo “Pedir nova análise?”, com orientação
   para atender aos ajustes, botão Cancelar e Confirmar. Foi **cancelado**.
5. Smoke autenticado repetido no VPS confirmou `rejected`, revisão 2, mesmo ID;
   cancelamento não criou nova decisão nem reapresentou o pedido.

Capturas inspecionadas visualmente:

- `student-review-result.png`: resultado/justificativa vindos da API.
- `student-request-context.png`: identificadores de matrícula, edição e pedido.

Para interação ADB, usada temporariamente resolução nativa 1220×2712; override
anterior **1080×1920 restaurado**. Wi-Fi e dados móveis conferidos em estado 1;
nesta etapa a rede não foi desligada. Nenhum dado do aplicativo foi apagado.

## Limites — gate integral continua pendente

Não houve criação/reapresentação efetivada pelo aparelho, troca para conta de
professor, aprovação positiva, emissão assinada ou teste offline dessas telas.
A evidência comprova leitura Flutter → API → PostgreSQL do pedido e da decisão,
identificação acadêmica e confirmação/cancelamento. Não comprova toda a jornada
de emissão nem encerra o gate `certificate_human_approval_e2e`.

Nenhuma refatoração ou alteração visual foi feita durante este teste.
