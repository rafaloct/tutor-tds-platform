# Piloto de identidade e jornada — Rafael, 01/10/2026

Inteligência Artificial e Inclusão Digital em Palmas, Itaguatins e
Augustinópolis, com período comum de 11/10/2026 a 30/10/2026 confirmado por Rafael.
Carga horária oficial: 40 horas, confirmada por Rafael. O catálogo público da API
de produção contém o curso `ia-cartilha`, com esse título. Sua edição v1 foi
resolvida no ensaio de migração; oferta/equipe reais ainda dependem de cadastro.
Rafael conferirá os vínculos.
IPEX é a instituição responsável pelas três turmas, confirmado explicitamente
por Rafael em 01/10/2026. Programa: TDS. A confirmação foi registrada no plano;
o cadastro persistente deve reutilizar Institution equivalente, se existir,
antes de criar qualquer nova instituição. Nenhum ID de produção foi inventado.
Manutenção incremental do app;
sem novo cadastro paralelo e sem contratar um serviço de analytics para esta
fatia. Estado: candidato revisável, com flags desligadas por padrão. Publicação
na Play e promoção do BI ainda são gates próprios. Refresh e filtros de contas
sintéticas pendentes foram validados; dados legados ainda têm erros a conferir.

Rafael confirmou o uso da cartilha atual em 01/10 e informou que ainda não tem
conta online. Cadastro real não executado. O fluxo existente de Criar conta está
na WelcomeScreen, com nome/CPF/telefone/senha preenchidos pelo titular na tela;
não solicitar senha em chat nem usar persona QA para representar Rafael.
Cadastro pessoal não concede papel de equipe: vínculo teacher no programa/turmas
precisa de comando administrativo autorizado. A API de produção consultada
oferece /auth/register, mas ainda não expõe os comandos /admin/accounts e
/admin/programs; a cartilha pública também não retorna uma edição fixa.
Preparar backend e release antes de instruir o titular a cadastrar na variante
QA, cujas contas/segredos não são as contas de produção. Referência pública do
conteúdo e escolha confirmada em current-course-reference.json no pacote.

## O que mudou

Conta online é a identidade; matrícula é a participação no programa; baseline
é uma ficha que pode existir ou estar pendente. O perfil salvo no aparelho não
comprova conta online nem matrícula. A API de produção inspecionada tinha zero
users, class_enrollments e learning_events e schema 0005. Essa observação não
conta instalações da Play nem apaga usuários locais/inscrições das planilhas.

O app agora mede telas, tempo estimado de uso e pedidos de ajuda por conta
autenticada, com nova autorização. A fila conserva dono e ambiente, inclusive
offline. Troca de conta e respostas tardias de autenticação não transferem dados.
Contagem pausa em segundo plano/modal e limita inatividade a 60 segundos;
checkpoint periódico de 15 segundos. Isso não é frequência nem carga horária.

Rafael pode conferir uma inscrição real do BI na tela de acompanhamento, com
data da coleta, justificativa, confirmação e histórico. Se não existir código
de tablet, a inscrição do BI pode ser a referência da ficha. Uma inscrição não
pode ser ligada silenciosamente a outra pessoa; a referência anterior continua
reservada mesmo após correção. O ID de acompanhamento exibido na tela é o mesmo
pessoa_id usado nos relatórios, inclusive antes de existir baseline.

## Método de controle

1. Participante cria/entra na conta online pelo próprio app e decide se autoriza
   acompanhamento. A versão instalada da Play precisará receber a atualização.
2. Equipe registra matrícula válida no programa/curso e inclui a conta na turma
   correspondente. Cadastro, convite, telemetria e IA não concedem matrícula.
3. Propor uma turma por cidade, reutilizando o mesmo programa e curso/edição
   autorizado. Datas, oferta real, IDs existentes e equipe serão conferidos antes
   de provisionar; não criar entidades equivalentes em duplicata.
4. Rafael seleciona o participante na lista autorizada da turma. A conta já tem
   um ID estável e pode aparecer com "Conferência pendente".
5. Se encontrar uma ficha original no BI, confere a pessoa e copia o registro_id
   real, por exemplo DIG-/ESC-. A data informada é a data real da coleta. Não
   presumir que ID do BI e ID local de tablet são iguais.
6. Se não houver ficha, manter pendência e aplicar o instrumento de coleta já
   adotado. Nenhuma resposta ou ID fictício será preenchido para fechar o painel.
7. Inscrição ambígua permanece pendente. Corrigir vínculo exige revisão atual e
   motivo, com histórico. Não vincular por semelhança de nome ou posição de linha.
8. Acompanhar separadamente contas no programa, inscrições vinculadas,
   pendências, atividade, pedidos de ajuda e resultados oficiais.

## Integração com o BI existente

Relatório inspecionado: TDS | Baseline e Jornada, 17 páginas. Baseline/Jornada
preservadas na fonte original. As 17 páginas continuam byte a byte no candidato;
Baseline/ComplementoBaseline receberam somente tipagem numérica explícita na
saída das consultas, após o Desktop inferir texto e quebrar medidas SUM. Jornada
permanece byte a byte idêntica. O relatório atual importa
planilhas e não recebe eventos do Tutor. As 510 inscrições observadas não
significam 510 pessoas únicas. pessoa_id era descartado pela consulta Baseline.

Candidato final:
`outputs/TDS_Journey_Pilot_2026-10-11/TDS_Rastreio.pbip`.
Acrescenta quatro tabelas e uma página, sem substituir as originais:

| Saída | Finalidade | Quem entra |
| --- | --- | --- |
| TDS_PARTICIPANTES_APP | Pessoa/turma e estado da conferência | Matrícula ativa e consistente, inclusive sem baseline |
| TDS_JORNADA_APP | Inscrição do baseline e progresso oficial do app | Somente ponte conferida e com linhagem válida |
| TDS_ATIVIDADE_APP | Resumo diário por pessoa/evento/tela | Atividade consentida das contas matriculadas |

PessoaApp fornece a chave distinta de pessoas. Atividade é da conta; não é
atribuída automaticamente a uma cidade/turma. Se uma conta pertence a duas
turmas, o exportador desduplica event_id antes de somar. O resumo usa dias UTC
e janela explícita, de até 31 dias. Importar o snapshot integral, sem anexar
períodos sobrepostos. Conferir permissões da planilha e do workspace: pseudônimo
não torna o cruzamento com o baseline público ou irreidentificável.

A nova página contém contas, vínculos e pendências, tempo por tela, pedidos de
ajuda e referências de certificado da API; tabelas detalham telas e conferência.
Power Query exige IDs válidos e únicos e interrompe refresh com referência
inexistente, participante fora do snapshot ou duplicata. JSON foi verificado;
TMDL/M abriu no Power BI Desktop. Login Google concluído pelo titular, atualização
e seleção de participantes validadas: global 2 contas/2 pendências/3 minutos/1
pedido; QA-Palmas 1 conta/2 minutos/1 pedido; QA-Itaguatins 1 conta/1 minuto/nenhum
pedido registrado (cartão DAX em branco). JornadaApp está vazia: vínculo confirmado
e certificado ainda não foram validados no Desktop. O refresh das consultas antigas
carregou 510 linhas, com 68 linhas de erro em Baseline e 65 em Jornada; uma data
inválida foi inspecionada. Não somar esses erros como inscrições/pessoas distintas.
Selecionar turma/pessoa na tabela de conferência filtra as medidas do recorte.
Os filtros geográficos antigos do baseline não classificam contas ainda sem
ficha; sua cidade depende da turma autorizada, sem inferência pelos eventos.

O exportador `api/ops/export_tds_journey.py` usa Bearer protegido em
TDS_BI_EXPORT_TOKEN. Exemplo de execução, sem token em argumento/histórico:

```text
python -m ops.export_tds_journey --api-url https://ENDPOINT_AUTORIZADO --class-id ID_TURMA --since 2026-10-01T00:00:00Z --until 2026-10-02T00:00:00Z --output-dir DIRETORIO_NOVO
```

Repetir --class-id para as três turmas. A primeira entrega é CSV+review.json
revisável. Foi criada uma cópia nativa privada da planilha, com as três abas:
[TDS — Homologação do rastreio](https://docs.google.com/spreadsheets/d/1a7KS1twBIlSO5kTXCmUVvmEIxkbt7IwttHKW4Xqzrzs/edit).
Apenas o proprietário tem acesso. Ela contém dois participantes QA-SINTETICO,
três linhas de atividade e nenhuma inscrição para exercitar pendência/filtros.
As três consultas novas do candidato apontam para essa cópia; Baseline/Jornada
mantêm as mesmas fontes. Jornada permanece idêntica; Baseline recebeu apenas a
correção de tipo descrita acima. Não promover dados sintéticos. Conferir qualidade
das consultas antigas, vínculo confirmado, destino e acesso antes da promoção.
O job recorrente pode reutilizar n8n já instalado: precisa de credencial de
equipe autorizada com renovação de acesso e permissões mínimas; não copiar um
token de sessão com expiração para um fluxo permanente. Automação não foi
ativada em produção nesta fatia.

## Limites dos indicadores

Pedido de ajuda prova o uso do botão/envio ao Tutor; não prova atendimento
resolvido ou mentoria. Abertura do WhatsApp/Chatwoot continua sob ação do usuário.
O texto da pergunta não entra no export analítico.

Progresso vem da projeção canônica de estudo. Frequência presencial, elegibilidade,
mentoria e 30/60/90 continuam nos registros humanos existentes. Não preencher
esses campos com zeros a partir de eventos. Certificado da API exige referência
emitida no escopo. A carteira/Cloudflare KV do app publicado usa outra identidade;
certificados históricos ainda sem ligação canônica são desconhecidos. O candidato
não substitui o indicador de certificados da ficha humana nem emite certificados.

## Custos e serviços

| Item | Papel | Decisão para o piloto |
| --- | --- | --- |
| VPS + PostgreSQL | API, contas, matrícula, fila recebida e dados primários | Reutilizar infraestrutura existente; custo atual do contrato não consultado |
| Backup externo e domínio | Recuperação e URLs estáveis | Incluir/confirmar na folha de custos; não substituir por desktop ligado |
| Gateway Cloudflare + KV | Tutor/certificados publicados | Preservar; plano gratuito tem limites. Paid parte de US$ 5/mês, mais consumo |
| Provedor de IA | Respostas ao Tutor | Crédito por consumo; modelo exato faturado deve ser confirmado na conta |
| Power BI/Fabric | Compartilhar e atualizar o painel | Reutilizar licenças/capacidade existentes; acesso às faturas não realizado |
| n8n e Chatwoot no VPS | Integração e atendimento | Componentes existentes; sem nova contratação ou fluxo externo automático |
| SaaS adicional de analytics | Eventos e jornada | Não necessário para a fatia implementada; custo adicional de assinatura proposto: zero |

Referências de orçamento consultadas em 01/10/2026:
[Workers](https://developers.cloudflare.com/workers/platform/pricing/),
[limites KV](https://developers.cloudflare.com/kv/platform/limits/).
Gemini 2.5 Flash Lite, usado na linhagem histórica, tem preço de referência
US$ 0,10/milhão de tokens de entrada e US$ 0,40/milhão de saída no
[OpenRouter](https://openrouter.ai/google/gemini-2.5-flash-lite/pricing).
Isso não confirma modelo atual, saldo, impostos ou fatura. Refresh depende da
[licença e configuração Power BI](https://learn.microsoft.com/en-us/power-bi/connect-data/refresh-scheduled-refresh).
Nenhum plano foi comprado ou renovado pelo agente.

## Ativação e intervenções humanas

- Reason: matrícula real depende da conta de equipe real; IPEX já confirmado.
  Exact human action: Rafael cria sua conta
  pelo fluxo normal quando o ambiente de ativação estiver disponível. Cartilha,
  edição legada v1, período e 40 horas já foram resolvidos; não perguntar de novo.
  Não enviar senha/token.
  What remains unblocked: código, artefatos e QA sintético estão preparados.
- Resolvida em 01/10: login Google concluído pelo titular após o pedido de apoio.
  Refresh e filtros sintéticos verificados e relatório salvo; não pedir novo login.
- Reason: consultas antigas contêm datas inválidas; não há evidência para inventar
  as datas corretas. Esta pendência não impede o QA sintético de rastreio.
  Exact human action: na revisão da base, conferir os registros com erro contra
  o formulário/ficha original e fornecer a correção ou registrar dado desconhecido.
  What remains unblocked: tipos numéricos corrigidos, cartões antigos calculando,
  filtros do rastreio validados e demais preparações técnicas disponíveis.
- Reason: release está bloqueada pelos gates existentes em release_status.json.
  Exact human action: decidir a promoção após o agente concluir os testes técnicos
  restantes e apresentar pacote concreto, privacidade/Data Safety e evidências.
  Não é obrigação humana executar testes que as ferramentas conseguem realizar.
  What remains unblocked: APK DEV sem credenciais operacionais, migration 0020
  aditiva e evidências disponíveis; flags permanecem false fora de QA.

Recorte alvo cabe em 3–4 dias com infraestrutura e instrumentos existentes:
identidade/conferência; telemetria/fila; overlay BI; piloto/revisão e release gates.
Tempo de revisão da Play, levantamento de fichas ausentes, licenças e trabalhos
pendentes de outras waves não é garantido por esse prazo.

## Verificação concluída em 01/10

POCO: login/consentimento, tempo de tela, pedidos de ajuda, troca de conta,
offline e reconexão; dez eventos offline entregues uma vez. Outro gate físico
conferiu uma inscrição pela UI real e HTTPS, sem código de tablet: mesmo ID
antes/depois e uma revisão auditada. Produção 1.2.0+11, rede, sessão e binário DEV
anteriores preservados/restaurados. Dados exclusivamente sintéticos.

Migration 0020 passou em SQLite e PostgreSQL 16 isolado, com dados anteriores e
guards preservados. Exportação HTTPS final gerou os três CSVs: uma conta e uma
inscrição sintéticas, sem atividade nessa execução de conferência. A execução
física de atividade e seus dez eventos está documentada separadamente.

O ambiente temporário foi removido; staging original e produção responderam
GET /health com 200. APK DEV normal, sem credenciais de QA, disponível em
`outputs/Tutor-TDS-Journey-2026-10-01-staging-dev.apk`. Não é AAB de distribuição
e a API candidata temporária já está encerrada. Evidências e limites em
`TDS_JOURNEY_QA_2026-10-01.md`.

Continuação Astra: 367 testes Flutter completos passaram, analyze global limpo.
API: 346 passaram na suíte completa; uma fixture temporal foi corrigida e passou
isoladamente (nenhuma regra comercial mudou; não houve rerun completo).

O ensaio `cec516308697` restaurou backup real em PostgreSQL 16 isolado e migrou
0005→0020 preservando todos os valores das colunas originais. Nove cursos; zero
contas/matrículas na fonte observada. Catálogo antigo preservado com quatro campos
aditivos de edição. Imagem anterior iniciou na base atualizada, com health e
catálogo válidos. Isso não substitui QA de todos os fluxos com dados reais.

Edição resolvida de ia-cartilha: `d496856d-6bf3-5f8a-92a3-f292cca92ed5` (v1).
Backup protegido permanece no VPS; cópia criptografada fora dele teve recuperação
verificada com DPAPI CurrentUser, dependente deste perfil/chaves Windows.
Compose de produção/staging validado com flags false e worker Sheets opt-in;
nenhum compose foi implantado nem worker existente interrompido. A imagem usada
no ensaio ainda é QA; proveniência de release e os gates restantes são necessários
antes da promoção. Ver evidence/journey-production-rehearsal-2026-10-01.json,
journey-off-vps-backup-2026-10-01.json e journey-compose-config-2026-10-01.json.
