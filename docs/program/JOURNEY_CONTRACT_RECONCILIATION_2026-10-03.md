# Jornada — reconciliação corretiva META 04

Base: `1a577a6e9417772753beb1525e25757f4e97b7ea`, após #24/#49/#50.
Estado: DECISION documentada; implementação #39 e projeção #51 são candidatos.
Escritor deste contrato: Codex integrador. #39 permanece com seu implementador;
#51 permanece com Devin. Não alterar esses códigos nesta fatia documental.

## Precedência e evidência

A [decisão posterior de #5](https://github.com/rafaloct/tutor-tds-platform/issues/5#issuecomment-5965837795)
supera as regras anteriores incompatíveis de #6 e do PR #24. O checkpoint
5968944747 de #24 e a aceitação 5969009574 de #51 foram prematuros nesse ponto.
Não apagar a evidência histórica do piloto ou reinterpretar seus resultados.
O Plano de Trabalho citado na decisão humana não foi examinado nesta revisão.

O candidato [#39](https://github.com/rafaloct/tutor-tds-platform/pull/39), inspecionado
em `6ae0a664674b24f12e5a8c0a95e6bbb91408b135`, documenta a geração após o último
checkpoint antes de baseline/frequência/assinaturas, estados separados e transporte
sintético. Inspeção documental e de `certificate_policy.py` não é repetição dos
testes nem aceite integral do PR.

| Tema | Contrato vigente | Limite para implementação/projeção |
|---|---|---|
| Carga | 80h formais por curso TDS | Não exigir cronômetro 80h ou 40h digitais; não sobrescrever `planned_seconds` histórico nem compor 160h sem domínio correspondente |
| Frequência | >=70% dos encontros configurados por oferta, evidência institucional | Não usar 75%, duração ou telemetria como substitutos; exceções `pending_human_validation` com justificativa/responsável, sem presença automática |
| Trilha | Todos os checkpoints obrigatórios, configuração por edição e validação determinística backend | Não transformar Jotform, quiz, print ou page_view em requisito universal |
| Baseline | Evidência vinculada ao participante, tipo/origem/status | Forms, Jotform, app ou ficha digitalizada; não criar evidência nem presumir leitura/integração externa |
| CAPACITADO | Baseline registrado AND frequência >=70% AND trilha obrigatória concluída AND certificado de trilha gerado | Ausência de fontes integradas permanece null no BI; referência legada não prova a conjunção |
| CERTIFICADO_VALIDO | CAPACITADO AND fichas regularizadas assinadas pelo instrutor AND certificado assinado pela coordenação | Geração pode anteceder regularização e assinaturas; não equivale a validade institucional |
| Estados | GENERATED, PENDING_INSTRUCTOR_VALIDATION, PENDING_COORDINATOR_SIGNATURE, VALID | Não colapsar lifecycle, referência, aprovação de pedido e emissão oficial |
| Operação | Fluxo VPS e encaminhamento institucional auditável; Eliza indicada operacionalmente | Não inventar conta, vínculo, assinatura, envio ou recibo; provider e transporte permanecem simulados |
| Follow-up | Âncora no certificado conforme #8 | Evento entre geração/validade e reemissão ainda não definidos para automação; manter campos null |

## Responsabilidade e próxima evidência

- #24: integrado; esta correção documental segue em PR separado, sem reescrever histórico.
- #51: delta dirigido ao Devin no comentário 5969222081. Revalidar novo HEAD,
  diff e testes focais quando houver resposta; despacho não comprova execução.
- #39: preservar candidato, flags e gate de ativação. PostgreSQL/provider instalado,
  assinaturas e aceite físico/institucional continuam separados do teste local.
- #6/#33: consumir o mesmo contrato, sem recalcular retrospectivamente evidência.
- #42/#53: WordPress não decide presença, capacitação ou certificado.

Validação desta fatia: revisão de consistência dos documentos afetados e revisão
independente. Sem alteração de schema, dados, aplicativo, release, deploy ou AAB.
