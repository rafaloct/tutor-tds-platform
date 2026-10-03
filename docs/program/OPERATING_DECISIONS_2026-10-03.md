# Decisões operacionais confirmadas — 03/10/2026

Status: **DECISION / HUMAN-CONFIRMED**.

Este documento registra respostas operacionais confirmadas pelo responsável do projeto para orientar desenvolvimento. Ele complementa `OPERATING_MODEL_SECRETARIAT.md` e reduz ambiguidades sem criar novas features por padrão.

## 1. Mobilização, comparecimento e matrícula

A mobilização funciona na prática como **pré-cadastro/interesse**. Muitas pessoas mobilizadas não comparecem no início do curso.

A participação real começa a ser reconhecida quando a pessoa **comparece ao primeiro dia**.

A confirmação formal da matrícula está associada ao comparecimento e ao preenchimento do baseline, porém o baseline pode ser realizado em momento diferente por necessidade logística.

```text
mobilizado/interessado
       ↓
compareceu ao primeiro encontro
       ↓
participante em regularização, se baseline pendente
       ↓
baseline preenchido/vinculado
       ↓
matrícula formalmente consolidada
```

Não remover ou bloquear automaticamente quem começou sem baseline.

Não existe uma única pessoa responsável pela confirmação. A rotina pode ser executada por mobilizadores, estagiários, instrutores e equipe/secretaria conforme contexto. O sistema deve trabalhar com **papel operacional**, não com nome de uma pessoa específica.

## 2. Baseline

O baseline pode ser preenchido no início, meio, fim ou depois da realização do curso, conforme logística e decisão da equipe.

```text
curso iniciado + baseline ausente
= pendência operacional
!= impedir estudo
!= excluir participante
!= criar baseline fictício
```

A equipe que normalmente resolve esse tipo de pendência inclui Evellyn, Paulo, estagiários e instrutores.

TARGET: detectar participantes ativos/interagindo com baseline não localizado e criar encaminhamento para a fila humana.

## 3. Frequência

A referência documental de **75% de frequência mínima** é efetivamente usada, porém sua aplicação é **flexível ao contexto operacional**.

O mesmo curso pode possuir quantidades diferentes de encontros em locais/turmas diferentes por razões logísticas. Consequência: **não calcular frequência por número fixo de encontros**.

A base preferida deve ser carga/tempo planejado e presença validada nas sessões realizadas.

A presença usa assinatura na frequência e evidência do aplicativo como componente pretendido. A evidência do aplicativo ainda não é confiável em produção devido às falhas de monitoramento/backend.

```text
telemetria do app não comprovada != presença comprovada
```

## 4. Reposição/complementação

Quando o participante não cumpre a presença esperada, a equipe pode utilizar **atividades de reposição/complementação**. Hoje isso é conduzido verbalmente e não existe mecanismo consolidado.

TARGET mínimo para registro:

```text
makeup_activity
participant/enrollment
reason
activity/description
assigned_by
completed_at
validated_by
evidence/reference opcional
effect_on_completion/frequency
notes
```

A atividade não se autoaprova. Instrutor/equipe valida. Não criar um LMS paralelo para reposição.

## 5. Componente presencial e digital

As nove cartilhas/cursos presentes no app em produção correspondem a cursos reais.

Existe uma etapa presencial de **40h já realizada** e uma etapa digital que também precisa ser formalizada/fechada em torno de **40h**, utilizando o app.

O problema atual não é a existência pedagógica da etapa digital, mas a falta de regra de fechamento, evidência confiável, fluxo de oficialização e monitoramento/backend consistente.

### HUMAN-GATE ainda aberto

1. confirmar se o certificado final representa 80h consolidadas, dois blocos de 40h ou outra forma;
2. definir quais eventos/evidências digitais são suficientes para reconhecer as 40h digitais;
3. definir como reposição digital interfere nesse fechamento.

Nenhum agente deve escolher isso sozinho.

## 6. Lançamento e conferência de frequência

A **secretaria do TDS/IPEX** é responsável pela digitalização/conferência/correção operacional da frequência após os registros de campo.

O sistema deve fornecer visão operacional para secretaria sem exigir SQL ou edição manual em planilha como fonte de verdade.

## 7. Papel do estagiário

Na operação real, o estagiário precisa possuir ampla capacidade operacional. Professores e responsáveis orientam o que deve ser feito, e a equipe muda ao longo do projeto.

Consequência de RBAC: não criar permissões excessivamente amarradas a uma pessoa ou a uma função pequena.

Criar um papel equivalente a `program_operator`, com capacidade ampla **dentro do escopo do programa**, incluindo rotinas de cadastro/vínculo, turma, presença, pendências, suporte, evidências, certificado operacional e mentoria/follow-up quando autorizado.

Continuam fora desse papel, por padrão: infraestrutura, secrets, billing, DNS, mudança de schema, deploy/release e acesso administrativo global.

Toda ação sensível deve ser auditada e a permissão deve ser revogável rapidamente quando o estagiário sair.

## 8. Atendimento e SLA operacional

Meta confirmada: **primeira resposta em até 5 minutos durante horário comercial, por agente automático ou humano**.

Isso é meta de atendimento inicial, não garantia de resolução em cinco minutos.

Um agente pode acusar recebimento, classificar, reunir contexto, orientar procedimento simples e encaminhar. Quando houver decisão/contexto humano, o caso deve chegar a estagiário real no Chatwoot.

A janela exata de 'horário comercial' ainda deve ser parametrizada/configurada.

## 9. Contato proativo

Hoje faltas e outras situações geralmente não geram contato proativo porque não existe monitoramento consolidado. A intenção do produto é mudar isso.

Casos proativos permitidos:

- baseline pendente;
- ausência recorrente/risco de frequência;
- documento obrigatório ausente;
- matrícula/identidade inconsistente;
- atividade de reposição pendente;
- requisito de certificado pendente;
- follow-up devido.

O agente pode classificar e priorizar, mas o estagiário é o braço humano de contato quando necessário.

## 10. Faltas, desistência e complementação

Na prática, quando há déficit de participação, a equipe pode passar complementação e ainda capacitar o participante.

```text
frequência abaixo do esperado != reprovação automática
```

O sistema deve sinalizar exceção e permitir regularização/revisão humana por atividade de complementação/reposição.

Não transformar a regra de 75% em bloqueio rígido sem considerar o mecanismo de regularização.

## 11. Mentoria

Há três caminhos válidos de entrada:

1. aluno solicita;
2. instrutor recomenda;
3. coordenação seleciona.

O domínio deve registrar a origem do encaminhamento. Nenhum desses caminhos significa mentoria iniciada até haver aceite/atribuição conforme fluxo.

## 12. Follow-up 30/60/90

A data-âncora confirmada é a **data do certificado**.

As janelas 30/60/90 contam a partir do certificado emitido/validado conforme autoridade definida no domínio.

## 13. Encerramento de turma e evidências

O pacote documental obrigatório deve espelhar o processo atualmente utilizado no Drive.

Componentes observados incluem ficha(s) de inscrição/matrícula, lista(s) de frequência/presença, evidências de campo/fotográficas quando aplicáveis, relatório de evento/encaminhamentos e demais documentos exigidos no pacote da turma.

Hoje cada equipe de campo pode organizar/coletar de forma diferente e depois envia o material para a secretaria organizar no Drive.

TARGET: o sistema deve padronizar **checklist e referências**, não obrigatoriamente substituir o Drive. A secretaria mantém função organizadora.

## 14. Notificações essenciais

Categorias confirmadas como essenciais:

- mudança/cancelamento de aula;
- resposta do suporte;
- pendência de matrícula/regularização;
- certificado disponível.

Outros avisos podem ser configuráveis.

```text
enviado != entregue != lido != resolvido
```

## 15. Chatwoot e casos proativos

Casos detectados pelo sistema **devem poder entrar proativamente no Chatwoot**, não apenas aguardar o aluno abrir conversa.

```text
FastAPI detecta regra objetiva
→ agente de triagem
→ cria/encaminha caso
→ Chatwoot
→ estagiário real
→ participante/instrutor/secretaria
→ estagiário registra resolução
→ FastAPI/PostgreSQL
```

Chatwoot permanece canal de trabalho humano, não fonte acadêmica.

## 16. Canais oficiais

Canal disponível hoje: Instagram do IPEX, instituto que abriga o programa.

Target de produção:

- site oficial do programa;
- WhatsApp contratado/oficial;
- Chatwoot como mesa operacional;
- app como entrada contextual.

Não depender permanentemente de contato informal ou Instagram para suporte individual.

## 17. Informação necessária ao atendimento

A orientação confirmada é disponibilizar ao estagiário **informações de acompanhamento** necessárias ao caso.

Visão candidata:

```text
identificação necessária
contato
turma/curso
status de matrícula
status do baseline
frequência/sessões
atividade/complementação
pendências abertas
certificado
mentoria/follow-up
histórico resumido de encaminhamentos
próxima ação
```

Dados socioeconômicos sensíveis do baseline não devem aparecer por padrão; apenas campos necessários à situação.

## 18. Princípio de implementação

A unidade operacional central não deve ser 'mais uma feature'. Deve ser:

> **Pendência / Encaminhamento / Caso operacional**

com regras objetivas que podem ser originadas por qualquer domínio e resolvidas por pessoas com contexto.

Isso permite tratar novas situações do projeto sem abrir novo workflow e nova tabela a cada caso.

## 19. Perguntas ainda abertas

Após as decisões acima, restam poucas questões que realmente precisam de confirmação:

1. Qual é a janela exata de 'horário comercial' usada pelo projeto?
2. A certificação final das etapas presencial + digital deve ser 80h consolidada, dois registros de 40h ou outra composição?
3. Quais eventos digitais comprovam oficialmente as 40h digitais?
4. Fotos e relatório são obrigatórios em toda turma ou podem existir exceções por tipo de ação?
5. Em caso de conflito entre lista física e dado digital de presença, qual fonte prevalece até revisão?

Essas cinco perguntas podem ser levadas aos instrutores/secretaria. Não há necessidade de ampliar o backlog até respondê-las.