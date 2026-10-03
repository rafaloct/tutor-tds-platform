# Issue #2: automacao de backups gerida pelo Dokploy

## Escopo e estado

Politica aprovada por Rafael em 02/10/2026: TDS diario, 30 copias diarias validas;
Dokploy semanal, quatro copias semanais; alertas para tdsdados@gmail.com.
RPO alvos: 24h para TDS e 7 dias para configuracoes. RTO objetivo: 4h, nao SLA.
As evidencias manuais anteriores permanecem fora da limpeza desta rotina.

O codigo de `tooling/backup_automation/` roda no container Dokploy, nao no PC.
Runtime instalado em `/etc/dokploy/tds-backup-ops`, com diretorio privado 0700
e `runtime.json` 0600. Configuracao exporta somente credenciais de transporte
obtidas do destino nativo Dokploy e o destinatario age PUBLICO. A chave privada
age e o token administrativo do Dokploy NAO sao instalados no job diario.
O destino nativo continua fonte de configuracao: uma rotacao exige sincronizar
a exportacao de runtime e repetir teste de transporte. Nao ha reload automatico.

## Agendamentos nativos

| Fluxo | Identificador | Agenda UTC | Retencao |
| --- | --- | --- | --- |
| TDS | EIZHFzoDiUJmhH9Xpc_qM | 03:40 diariamente | 30 dias com copia valida |
| Dokploy | HipnWyHd6zQ54VS02kosa | domingo 04:20 | quatro copias |
| Monitor | xDa1AnQ9fHkG7hLi9YMbj | minuto 10 de cada hora | nao exclui dados |

Rotinas acima ativadas em 2026-10-03T00:03:40Z; readback nativo conferido.
O teste de falha `_BxLe890aGQZXg6FB4rVL` permanece DESABILITADO.
O registro manual `fgsppMQtOV9YUAyaPX4Qk` permanece desabilitado e preservado.
O cron anterior `/etc/cron.d/tutor-tds-api-backup`, 03:20 UTC, nao foi alterado.

## Fluxo diario e protecoes

`pg_dump` usa modo READ ONLY, timeout e identidade fixa de container/banco.
Dump custom permanece em memoria, com limite de 64 MiB. Ultrapassar o limite
interrompe a rotina, exigindo revisao de capacidade, nao um backup truncado.
`age` v1.3.2 foi obtido da release oficial, com SHA-256 de arquivo conferido:
`cbe24006683f8eb669266162894b9a522a1af52f2665fbc63a4bb032ed26ac10`.

Upload e download do criptografado devem ter tamanho e SHA-256 identicos.
Um recibo privado tambem e enviado e conferido antes de marcar sucesso.
`flock` impede sobreposicao normal das tarefas. Nao ha restauracao ou migration.

O prefixo exclusivo `postgres/scheduled/v1/` distingue este job das evidencias
em `postgres/encrypted/` e `qa/`. Retencao conserva a ultima copia por data UTC,
ate 30 datas com sucesso, e so exclui arquivos de recibos validos desse prefixo.
Recibos invalidos/arquivos ausentes interrompem a limpeza. Nenhum prefixo
manual entra nesse algoritmo. O semanal usa registro e prefixo nativos novos:
`backup-override-bluetooth-firewall-jsl27h/tds-control-plane-scheduled/`.

## Evidencia efetivamente obtida

- 28 testes de contrato passaram no Windows e no Node do container Dokploy.
- Primeiro acionamento pelo motor nativo do Dokploy: 2026-10-02T23:59:14Z.
- Objeto TDS: `postgres/scheduled/v1/20261002T235914Z-23f7a71b7bec42ad85d319caecdada2b/archive.dump.age`.
- 53.229 bytes; SHA-256 `76f39701ec7408be6b02939464aee10ff8398fce7e63adc51d77a62da1be21ef`.
- Primeiro acionamento nativo do novo registro semanal terminou `done`.
- Falha controlada retornou erro e gerou deployment `error` no Dokploy,
  sem consultar banco ou storage. O erro dessa tarefa de teste e intencional.
- Monitor identificou somente `email_delivery_not_configured` no ensaio.

## Pendencias e limites: nao fechar o gate ainda

As agendas foram persistidas e ativadas. O primeiro disparo TDS POR RELOGIO
foi observado em 03/10; o primeiro semanal por relogio aguarda o domingo.
A rotina executa integralmente no servidor depois do acionamento.
O estado de notificacao abaixo foi atualizado em 03/10/2026. A rotina registra
falhas/atrasos, mas o runtime customizado ainda nao tem um canal de entrega.
Nao marcar `deliveryVerified` apenas porque o notificador nativo passou em teste.

O monitor considera atraso acima de 26h para TDS e 8 dias para Dokploy, com
verificacao horaria. Sao margens operacionais, nao garantias de RPO.
Ele roda na mesma VPS e NAO detecta/avisa a propria queda total enquanto offline.
Um watchdog externo continua necessario para independencia desse risco.

O ZIP nativo do Dokploy contem segredos sem camada age, em R2 privado com
criptografia gerenciada pelo provedor. Quem le o ZIP pode recuperar a chave.
Separacao de acesso entre chave/copia e escopo do token seguem pendentes.
O backup TDS abrange apenas aquele PostgreSQL, nao KV, planilhas, WordPress,
Chatwoot ou todo o ecossistema. O restore manual anterior nao foi repetido.

## Operacao

No Dokploy, Schedule Jobs controla TDS/monitor; Web Server > Backups controla
sua copia semanal. Para pausar, desabilitar somente os IDs desta rotina.
Nao apagar o registro manual nem alterar o cron local preexistente.
Nao divulgar runtime.json, backups ZIP, chaves ou dumps. Recibos sao sanitizados.
Apos upgrade do Dokploy, revalidar Node, rclone, age e notificacao.

## Atualizacao operacional: 03/10/2026

- O notificador Email nativo `7Oz5wKFr9S0vAy2XRE8Yw` foi cadastrado com
  destinatario `tdsdados@gmail.com`. Rafael confirmou recebimento do teste
  nativo na pasta de spam. Isso comprova aquele teste, nao um alerta da rotina
  customizada nem entrega futura na caixa de entrada.
- O monitor de 03/10 06:10 UTC ainda registrou
  `email_delivery_not_configured`; o teste nativo nao ativa automaticamente
  o canal da rotina customizada.
- O schedule TDS `EIZHFzoDiUJmhH9Xpc_qM` estava habilitado para `40 3 * * *`
  UTC. Deployment `sw5e1U47sCAvwVnqE2r0O` foi criado pelo relogio em
  03/10 03:40:00.713Z e terminou `done` em 03:40:09.708Z. O recibo
  `20261003T034000Z-1d97b88957c74e7790d78dfb1c0b9ba8` terminou
  `verified` em 03:40:04.295Z no prefixo exclusivo, 53.229 bytes e SHA-256
  `1ecdf7cb7c6098bbd167bfd3d9d6e82bcbee61425411ed12acc9e79a29e20953`.
  O semanal de domingo 04:20 UTC ainda nao venceu; nao foi disparado a mao.
- A API publica de notificacoes do Dokploy testa conexao SMTP recebendo a
  senha no pedido; o identificador do notificador salvo, isoladamente, nao
  comprova uma rota de alerta customizado. Falhas de Schedule Jobs geram logs,
  mas nao se deve pressupor que disparem o notificador. Priorizar mecanismo
  interno suportado que use a configuracao salva sem revelar senha. A funcao
  interna `sendDatabaseBackupNotifications` do Dokploy v0.29.1 seleciona os
  notificadores de backup da organizacao e carrega o SMTP dentro do proprio
  Dokploy. Em 03/10, so havia o notificador Email pretendido com o evento
  `databaseBackup` ativo. O codigo da rotina confere apenas IDs de metadados
  antes de chama-la, sem ler o campo de senha. A funcao interna captura erros
  de envio; por isso `native_dispatch_unverified` nao significa entrega.
  Revalidar essa integracao apos upgrade do Dokploy. O unico teste de falha
  controlada desta meta foi executado em 03/10; nao repeti-lo.
- Codigo `3683ef5` instalado no runtime privado com SHA-256
  `73c1fad9f1101f165e1ee3d49926ac845126a4df0b6135c5bf984abec0fb71bb`.
  `runtime.json` passou a conter somente os IDs do notificador/organizacao
  na secao `mail`, sem inserir senha SMTP. Uma unica execucao direta de
  `probe-failure` em 03/10/2026 06:55:13Z nao consultou banco TDS ou R2,
  nem alterou agendas, backup ou restore. Recibo:
  `BACKUP_ACTION_REQUIRED`, etapa
  `controlled_failure_no_database_or_storage_access`, alerta
  `native_dispatch_unverified`, `delivered=false`. O helper do Dokploy nao
  propaga o resultado de SMTP; recebimento deste alerta precisa ser conferido
  pelo destinatario, inclusive na pasta de spam. Nao repetir o probe.
- Rafael confirmou em 03/10/2026 que o alerta da falha controlada chegou por
  email. Essa e a evidencia de HUMAN ACCEPTANCE daquela mensagem, associada
  ao recibo de 06:55:13Z. Nao transforma `delivered=false` do recibo em PASS
  automatico nem prova entrega futura.
- Uma consulta manual do monitor em 03/10 06:59:55Z retornou `MONITOR_OK`,
  `problems=[]` depois da integracao. Isso valida o estado atual dos recibos
  e a referencia nativa, nao a entrega de email em uma falha futura.
- Para queda total da VPS, `.github/workflows/tds-vps-watchdog.yml` e um
  candidato minimo: consulta a API publica e o banco a cada 30 minutos a
  partir dos runners GitHub, com timeout e falha explicita. Em caso de falha,
  tenta email direto para `tdsdados@gmail.com` via SMTP externo com TLS. A
  URL retornou
  `{"status":"ok","database":"available"}` em 03/10. O workflow agendado
  so roda na branch default apos integracao do PR; execucoes podem atrasar ou
  ser descartadas. O SMTP externo ainda precisa ser configurado e testado;
  nao declarar alerta externo entregue sem execucao e recebimento verificados.
  O PR draft nao ativa esse watchdog.
- Revisar o escopo efetivo da credencial R2 e a possibilidade de uma pessoa
  acessar simultaneamente ZIP do Dokploy, configuracao e identidade age.
  O armazenamento privado nao prova separacao de acesso. Rafael declarou
  "aceito o risco" em 03/10/2026, em resposta a essa pendencia agrupada.
  Trata-se de aceite formal do risco residual de acesso conjunto e escopo
  R2 nao verificado; nao e prova de privilegios minimos.

## Canal do watchdog externo

Rafael escolheu aviso por email. O workflow GitHub proposto ainda esta em
PR draft. As notificacoes padrao dos workflows agendados vao para o usuario
que criou o workflow, nao necessariamente para `tdsdados@gmail.com`. A API
de emails da conta GitHub conectada nao esta disponivel com o escopo atual;
nao alterar autorizacao OAuth para deduzir o destino. O workflow usa email
SMTP direto, com destinatario fixo e credencial propria no GitHub Actions:

| Tipo | Nome | Conteudo esperado |
| --- | --- | --- |
| Repository variable | `TDS_WATCHDOG_SMTP_HOST` | Host SMTP externo a VPS |
| Repository variable | `TDS_WATCHDOG_SMTP_PORT` | `465` ou `587` |
| Repository variable | `TDS_WATCHDOG_SMTP_USER` | Usuario SMTP |
| Repository variable | `TDS_WATCHDOG_SMTP_FROM` | Remetente autorizado |
| Repository secret | `TDS_WATCHDOG_SMTP_PASSWORD` | Credencial inserida manualmente pelo titular |

Nao copiar a senha SMTP do banco Dokploy. Nao colocar valores em commit,
issue, comentario ou log. Depois de configurar a credencial, integrar o
workflow na branch default com aprovacao, disparar uma unica execucao
`workflow_dispatch` com `test_email=true` e conferir o recebimento da
mensagem rotulada como teste. A opcao nao simula indisponibilidade. O envio
SMTP bem-sucedido significa aceite do servidor, nao recebimento na caixa.
Em outage real, o workflow falha e tenta enviar email com URL da execucao;
quando GitHub atrasar ou omitir a agenda, nao ha garantia de alerta.

O adaptador de alerta altera apenas o caminho de notificacao da rotina TDS.
Nao muda agenda, banco, destino, segredo nem configuracao do notificador nativo.
O gate operacional permanece aberto ate o primeiro semanal por relogio e
o aviso externo por email serem comprovados.
