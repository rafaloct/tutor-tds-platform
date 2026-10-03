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

Limite confirmado no [complemento final da Issue #6](https://github.com/rafaloct/tutor-tds-platform/issues/6#issuecomment-5965300113):
o baseline precisa estar **regularizado antes do certificado**. Isso não bloqueia
o estudo nem permite criar ficha fictícia. É requisito institucional; a referência
de certificado hoje exportada pela API não comprova que esse gate foi executado.

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

Em caso de conflito entre dado digital e frequência física, **a lista física assinada prevalece como evidência operacional oficial**, até que uma correção humana posterior seja formalmente validada.

```text
lista física assinada > evidência digital conflitante
telemetria do app não comprovada != presença comprovada
divergência -> pendência para revisão humana
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

### Decisão confirmada de carga total e fechamento digital

A formação deve representar **80h totais**.

O arranjo de referência é **40h presencial + 40h digital**, mas essa proporção não é rígida. A distribuição pode variar por razões humanas e logísticas, desde que a composição total e a exceção sejam registradas e validadas.

Portanto:

```text
target padrão: 40h presencial + 40h digital = 80h
exceção: percentuais/cargas diferentes permitidos
condição: justificativa logística/humana + validação
resultado: total formativo = 80h
```

Esse alvo de formação não reescreve a carga configurada de ofertas históricas:
as 40h do piloto registradas em `../DECISIONS.md`, itens 19/21, permanecem com
seu escopo e evidência. Não substituir `ProgramCourse.planned_seconds` por 80h
na exportação, nem creditar tempo de tela como carga digital validada.

A evidência digital deve ser uma **combinação de critérios**, incluindo:

- uso de pelo menos uma funcionalidade relevante de cada eixo/funcionalidade obrigatória definida no app;
- evidência de conclusão na carteira de certificados do aplicativo;
- print/registro do certificado disponível nessa carteira;
- avaliação complementar via Jotform, ainda a ser desenvolvida;
- demais eventos digitais confiáveis que forem formalizados no backend.

O Jotform será instrumento de avaliação/coleta, não fonte mestre de matrícula ou autorização.

O agente pode implementar o contrato técnico e os pontos de integração, mas não deve inventar novos critérios pedagógicos fora dessa combinação sem nova decisão humana.

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

Janelas confirmadas de suporte humano:

- **08:00–12:00**;
- **14:00–18:00**;
- **19:00–21:00**.

Fora dessas janelas, o atendimento inicial pode ser realizado por IA/agente configurado no Chatwoot, com triagem, orientação e registro. Casos que exigirem decisão humana permanecem pendentes para a próxima janela de suporte humano.

O sistema deve distinguir:
- resposta automática;
- primeira resposta humana;
- resolução.

A meta de até 5 minutos vale para a primeira resposta, humana ou automatizada, durante o funcionamento do canal.

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

A decisão final sobre se a complementação é suficiente para capacitar o participante é do **instrutor**, considerando o contexto.

Portanto:
- o sistema calcula e sinaliza;
- o instrutor decide a suficiência da reposição/complementação;
- a decisão deve ser registrada com ator, data e justificativa curta;
- não transformar a regra de 75% em bloqueio rígido sem considerar o mecanismo de regularização.

## 11. Mentoria

Há três caminhos válidos de entrada:

1. aluno solicita;
2. instrutor recomenda;
3. coordenação seleciona.

O domínio deve registrar a origem do encaminhamento. Nenhum desses caminhos significa mentoria iniciada até haver aceite/atribuição conforme fluxo.

## 12. Follow-up 30/60/90

A data-âncora confirmada é a **data do certificado**.

As janelas 30/60/90 contam a partir do certificado emitido/validado conforme autoridade definida no domínio.

Esta decisão, também registrada na [Issue #8](https://github.com/rafaloct/tutor-tds-platform/issues/8#issuecomment-5965176322),
supera a redação anterior que ancorava a janela na aplicação validada. O tratamento
da âncora em caso de reemissão continua uma exceção a definir antes de automatizá-la;
não reiniciar prazos por inferência. Os campos de follow-up atuais permanecem null
até integração de fatos, contato/resposta e revisão autorizada.

## 13. Encerramento de turma e evidências

O pacote documental obrigatório deve espelhar o processo atualmente utilizado no Drive.

Componentes observados incluem ficha(s) de inscrição/matrícula, lista(s) de frequência/presença, evidências de campo/fotográficas quando aplicáveis, relatório de evento/encaminhamentos e demais documentos exigidos no pacote da turma.

Hoje cada equipe de campo pode organizar/coletar de forma diferente e depois envia o material para a secretaria organizar no Drive.

TARGET: o sistema deve padronizar **checklist e referências**, não obrigatoriamente substituir o Drive. A secretaria mantém função organizadora.

Fotos e relatório de evento são tratados como **padrão de boas práticas esperado** para as turmas.

Quando o pacote chegar sem essas evidências, o sistema não deve inventá-las nem necessariamente bloquear todo o fechamento. Deve gerar uma pendência/flag para a equipe de mobilização ou campo **revisitar/coletar imagens e complementar o relatório**, quando isso ainda for possível.

Exemplo de reason codes:

```text
COURSE_PHOTOS_MISSING
EVENT_REPORT_MISSING
EVIDENCE_PACKAGE_INCOMPLETE
```

A ausência deve ficar rastreável para a secretaria.

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

## 19. Estado das decisões humanas

As cinco lacunas operacionais anteriormente abertas foram respondidas em 03/10/2026:

1. suporte humano: 08–12, 14–18 e 19–21;
2. carga total: 80h, preferencialmente 40h presencial + 40h digital, com adaptação logística/humana permitida;
3. fechamento digital: combinação de uso funcional do app + carteira/certificado + avaliação Jotform + eventos confiáveis;
4. fotos/relatório: padrão de boa prática; ausência gera flag para complementação/revisita, não evidência fictícia;
5. conflito de presença: lista física assinada prevalece até correção humana formal.

Assim, o desenvolvimento das frentes #5, #6, #7, #8, #30, #33 e #34 não deve ficar bloqueado por falta de regra operacional geral.

Novas dúvidas devem ser tratadas como configuração ou exceção específica, não como motivo para criar novo módulo por padrão.
