# Tutor TDS - Creator, ledger e integrações comerciais

## Princípio

O Tutor TDS pode medir valor pedagógico antes de operar dinheiro. A Onda 4
implementa contratos, permissões, auditoria e simulação; cobrança e repasse
ficam desligados até aprovação jurídica, financeira e humana.

## Fluxo editorial

```text
creator vinculado à instituição
  -> cria rascunho de mídia
  -> informa curso, módulo, competência, direitos e próxima atividade
  -> envia master ao acervo institucional
  -> processamento/validação do provedor
  -> revisão por admin/coordenador
  -> publicação
  -> analytics pedagógico
  -> score versionado
  -> lançamento simulado no ledger
```

Papéis mínimos:

- `creator`: cria e edita somente conteúdo próprio em programas autorizados;
- `teacher`: associa conteúdo publicado a uma turma/atividade;
- `coordinator`: revisa e publica para seus programas;
- `admin`: administra instituição, regras e auditoria;
- `finance`: consulta/fecha ledger, sem permissão editorial implícita.

Um papel global não substitui o vínculo por instituição e programa.

## Creator Score

Cada cálculo deve registrar `rule_version` e a janela avaliada. Uma proposta
inicial, ainda sem efeito financeiro, combina:

```text
conclusão qualificada        35%
atividade pós-conteúdo       35%
avaliação explícita          15%
salvamento/retorno           10%
qualidade operacional         5%
```

Fraude e ruído são reduzidos por matrícula ativa, eventos idempotentes,
posição/duração plausíveis, deduplicação de sessões e teto por participante.
View, autoplay e preload não geram remuneração isoladamente.

O contrato implementado usa `creator-score-v2`. Avaliação explícita é uma
nota estruturada de 1 a 5, sem texto livre, aceita somente depois de conclusão
qualificada e com matrícula ativa. O snapshot guarda apenas contagem, soma das
notas e pontos calculados, nunca identidade do aluno. Uma simples abertura do
player não gera pontos, nem mesmo o bônus de qualidade operacional.

Scores já calculados permanecem imutáveis e identificados por versão. A janela
deve ser calculada após seu fechamento para incluir avaliações registradas no
período; recalcular a mesma versão/janela devolve o snapshot existente.

## Ledger auditável

`RevenueLedger` deve ser append-only. Correção cria lançamento inverso; nunca
edita o histórico.

Campos mínimos:

```text
id
institution_id
program_id
creator_user_id
media_id
source_event_id
rule_version
entry_type       accrual | reversal | adjustment | payout
amount_minor
currency
status           simulated | approved | payable | paid | void
idempotency_key
calculation_snapshot
created_at
approved_by
approved_at
external_reference
```

Restrições:

- unicidade de `idempotency_key`;
- valor em unidade monetária inteira, nunca ponto flutuante;
- snapshot sem CPF, telefone ou nome desnecessário;
- transição de status registrada em trilha de auditoria;
- fechamento com total de débitos e créditos conciliável;
- payout não pode exceder saldo aprovado.

## Adapter de pagamento

O domínio depende de uma interface, não de Mercado Pago, Stripe ou banco:

```text
create_recipient
create_payment
get_payment_status
request_payout
get_payout_status
verify_webhook
```

O adapter padrão é `disabled`. Webhooks exigem assinatura, timestamp,
idempotência, replay protection e armazenamento do identificador externo.
Segredo de pagamento nunca entra no Flutter.

## Gates humanos obrigatórios

Ativação financeira exige, fora do código:

1. modelo de negócio, base jurídica e regras de remuneração aprovados;
2. entidade recebedora, tributação, termos de creators e política de estorno;
3. conta comercial verificada no provedor;
4. credenciais de sandbox e produção separadas;
5. limites, conciliação e responsáveis por aprovação definidos;
6. teste de webhook e payout em sandbox;
7. autorização explícita para qualquer cobrança real.

Até lá, endpoints financeiros só retornam dados simulados para usuários
autorizados e nunca chamam serviços externos.
