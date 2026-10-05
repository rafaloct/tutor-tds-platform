# Chatwoot TDS — CW-3/CW-4, plano básico

Status: **TARGET / TESTED-LOCAL somente para o planejador**. Este diretório não
é um export da instalação e não configura Chatwoot. Ele prepara uma aplicação
manual, ou por adaptador futuro, depois do inventário autorizado de homologação.

## Limites de produto e autoridade

O desenho usa apenas elementos operacionais que podem ser executados manualmente
no plano básico: inbox, time, etiqueta, atributo de conversa/contato, resposta
rápida e macro. Se a edição instalada não tiver algum deles, a operação usa a
coluna `fallback_manual` do manifesto; não se compra ou habilita um tier para
este PR. Regras automáticas são intenções de roteamento, não pressuposições de
capacidade/licença, e possuem procedimento humano equivalente.

FastAPI/PostgreSQL continua sendo autoridade para pessoa, vínculo, matrícula,
frequência, reposição, certificado, mentoria, consentimento e notificação. O
Chatwoot mantém somente conversa, fila, responsável, etiquetas, notas internas
e referências opacas. Fechar uma conversa, aplicar etiqueta ou enviar uma macro
não altera estado acadêmico.

Não colocar CPF, NIS, senha, token, baseline socioeconômico, lista de presença,
texto integral de IA ou transcrição de conversa nos atributos. O manifesto usa
IDs opacos e `context_ref`; o servidor futuro resolve e autoriza qualquer detalhe
necessário no momento do atendimento.

## Como revisar localmente

O planejador não faz HTTP e não aceita credenciais. Ele compara o desejo do
manifesto com um inventário sanitizado (ou um inventário vazio) e produz ações
`create`, `update` ou `unchanged` de forma determinística:

```text
python api/ops/chatwoot_plan.py --manifest docs/production/chatwoot/cw3_basic_manifest.json
python api/ops/chatwoot_plan.py --manifest docs/production/chatwoot/cw3_basic_manifest.json --inventory exemplo.json
```

O arquivo `exemplo.json` jamais deve conter token, e-mail pessoal, telefone,
conversa, mensagem ou PII. O comando sempre é dry-run; não existe `--apply`.
Uma futura fatia CW-4 poderá usar este resultado para um adaptador servidor a
servidor, após confirmar versão, account, inbox, APIs permitidas, autenticação de
webhook e isolamento em staging.

## E-mail e caixas no plano básico

Há uma única inbox de e-mail institucional: `support@{{INSTITUTIONAL_DOMAIN}}`.
Os aliases `certificados@`, `frequencia@`, `mobilizacao@`, `privacidade@` e
`cursos@{{INSTITUTIONAL_DOMAIN}}` devem encaminhar para essa mesma caixa sem
criar caixas paralelas. O provedor de e-mail/infraestrutura configura os aliases;
Chatwoot recebe a mensagem em uma inbox e o time/etiquetas roteia o trabalho.
Nenhum endereço é criado por este repositório e o domínio permanece um placeholder
até aprovação institucional.

Chamadas só podem ser feitas por agente humano autorizado quando houver
consentimento específico registrado na autoridade acadêmica e uma referência
opaca de caso. O manifesto não armazena telefone, gravação, consentimento ou
discador. Não há promessa de telefonia no plano básico.

## Eventos futuros CW-4

`CW4_EVENT_CONTRACT.md` define envelopes mínimos para certificado emitido,
risco de frequência, mobilização, atividade/curso novo, feedback e suporte. É um
contrato de proposta: não cria webhook, endpoint, fila, worker ou evento no
runtime. O recebimento real deve validar origem/autenticação na versão instalada,
deduplicar por `event_id`, manter ordem/retry auditáveis e nunca fazer callback
que modifique decisão acadêmica.

## Gate antes de aplicar

1. Infraestrutura fornece inventário sanitizado de staging (versão/edição,
   account, inbox e capacidades), sem segredo no chat.
2. Coordenação aprova cobertura, substitutos, horários e respostas públicas.
3. Responsável por dados aprova minimização, retenção, aliases e consentimento de
   contato proativo/ligação.
4. Testar com contas e mensagens sintéticas: A/B, inbox alheia, troca de sessão,
   nota interna, macro, e-mail e resposta humana.
5. Só então um operador aplica manualmente o plano em staging, registrando IDs
   sanitizados e rollback. Produção é outro gate.
