# Observabilidade operacional — Issue #32

Estado: IMPLEMENTED candidato local, não monitor externo instalado. Base
`1a577a6e9417772753beb1525e25757f4e97b7ea`, 03/10/2026. Limiares abaixo são
TARGET de operação, não SLA. [Continuidade](../program/OPERATIONS_CONTINUITY.md)
define tiers; [interoperabilidade](../program/INTEROPERABILITY.md) define os dados
proibidos. Nenhum payload, CPF, nome, conversa, prompt, resposta ou segredo entra
nos snapshots. Não acrescentar endpoint público de métricas de infraestrutura.

## Evidência disponível

- OBSERVED no código: middleware [API](../../api/app/observability.py) registra
  rota-template, status e duração, sem body. Não comprova agregação/alerta instalado.
- OBSERVED: watchdog de backup da #2 executou externamente no GitHub Actions,
  [run 37123913929](https://github.com/rafaloct/tutor-tds-platform/actions/runs/37123913929),
  com health aprovado e e-mail SKIPPED. Não prova recebimento nem cobertura de todos
  os Tier 1. Reutilizar [automação existente](../../tooling/backup_automation/backup.mjs);
  este candidato não altera sua agenda, política ou transporte.
- Histórico: API produção `/health=200`, `/version=404`, documentado em
  [estado atual](../CURRENT_STATE.md). Não é observação runtime desta implementação.
- UNKNOWN: monitor externo de API/autenticação/Play, coletores host/DB, dashboard,
  métricas agregadas e instalação das demais regras. Não comprar SaaS nem configurar
  credenciais para preencher essa lacuna sem o gate de acesso.

## Matriz serviço → SLI/check

Cada amostra contém número e `observed_at` UTC; proporções de erros exigem também `sample_count` inteiro (mínimo 100, ou UNKNOWN). Ausência, timestamp futuro
ou observação com mais de 10 minutos é UNKNOWN, nunca sucesso. Idade de backup/sync
é calculada pelo coletor a partir do último sucesso, com observação fresca;
não confundir idade do evento com frescor da coleta. Timeouts devem virar
indisponibilidade no coletor, sem serializar exceção/URL/body.

| Serviço / tier | Check / condição candidata | Janela/coleta alvo | Severidade | Runbook / recuperação |
|---|---|---|---|---|
| API / 1 | api_http: HTTP diferente de 200; api_latency: >2000ms | sintético externo 1min; avaliar falha por amostra | SEV1 / SEV2 | [configuração](../program/CONFIGURATION_RUNBOOK.md): verificar rota/versão/dependências, restauração só com gate |
| API / 1 | api_5xx: proporção >5% | agregado 5min, mínimo100 requests; sem amostra suficiente UNKNOWN | SEV2 | configuração: correlacionar versão e logs sanitizados |
| PostgreSQL / 1 | postgres: available=0 | readiness interno 1min, sem SQL público | SEV1 | [backup/restore](../infrastructure/BACKUP_RESTORE.md): validar DB e recuperação isolada |
| Backup / 0 | backup: idade >26h | recibo diário consultado 5min | SEV1 | backup/restore e #2; semanal >8dias permanece no watchdog existente |
| VPS / 1 | disk: uso >85%; memory: uso >90% | agregado 5min via coletor autorizado | SEV2 | continuidade: investigar crescimento, sem apagar volumes/dados |
| TLS/DNS / 0 | tls: validade restante <14dias | monitor externo diário; snapshot da consulta precisa ser fresco | SEV2 | configuração: conferir domínio e renovação; sem mudar DNS automaticamente |
| WordPress / 2 | wordpress: HTTP diferente de 200 | público sintético externo 5min | SEV3 | #42/#47: rollback de artefato isolado; #48 preserva conteúdo para triagem |
| Chatwoot / 2 | chatwoot: HTTP diferente de 200 | health técnico 5min, sem abrir conversa | SEV3 | configuração: verificar serviço/inbox, não reenviar mensagens |
| Gateway / 2 | gateway: erros upstream >5% | agregado 5min, mínimo100 requests | SEV3 | configuração: flags/fallback, não produzir prompt de usuário |
| AnythingLLM / 2 | anythingllm: available=0 | health sem geração, 5min | SEV3 | configuração: upstream degradado não altera autorização |
| Sheets / 3 | sheets_sync: último sucesso >2h; queue: item mais antigo >1h | coletor interno 5min | SEV3 | interoperabilidade: revisar retry/idempotência; nunca corrigir cadastro na planilha |
| Media / 2 | media: available=0 | fake local agora; provider futuro 5min | SEV3 | #52/#31: provider indisponível, sem registrar URL assinada |
| Autenticação / 1 | fluxo sintético com conta dedicada | TARGET externo 5min; não implementado pelo avaliador | SEV1 | configuração: login indisponível sem nova conta real automática |
| App publicado / 1 | disponibilidade Play + versão/proveniência | TARGET externo diário + gates físicos | SEV2 | #3: app instalado não é provado por HTTP200 da loja |
| GitHub / 0 | CI e acesso ao repositório/custódia | TARGET externo; provedor independente | SEV2 | continuidade: segundo administrador e break-glass #36 |

O avaliador não calcula séries/percentis nem instala coletores. Cabe ao coletor
autorizado entregar agregados da janela declarada. Falta de coletor, ausência de
conta QA ou provider não implantado ficam UNKNOWN, sem inventar zeros.

## Roteamento, deduplicação e silêncio

Destinatário funcional de cada regra: plantão técnico para SEV1/SEV2; responsável
do serviço para SEV3, escalando ao plantão se afetar o núcleo. Nomes, canal e segundo
responsável são UNKNOWN até indicação institucional no inventário #26. Nenhum
envio é implementado aqui. O e-mail existente da #2 mantém autorização própria.

Chave de deduplicação: ambiente + check. O estado local gera `opened` uma vez,
`unchanged` nas repetições e `resolved` após uma observação saudável. Perda de
telemetria conserva incidente aberto; nunca gera recovery falso. O adaptador de
entrega futuro deve persistir estado atomicamente e confirmar recibo antes de
promover notificação para enviada. O JSON emitido não é comprovante de entrega.

Silêncio TARGET para todas as regras: manutenção aprovada com responsável,
motivo, ambiente, checks e expiração (máximo2h), preservando coleta e histórico;
sem silêncio automático de SEV1 ou de monitor desconhecido. O avaliador não
suprime alertas. Configuração de silêncio/roteamento pertence ao monitor externo
após gate; recuperação deve fechar a mesma chave, mantendo registro do incidente.

## Uso local e contrato sanitizado

Requer Python3 com biblioteca padrão. Não acessa rede nem variáveis de ambiente.

```powershell
python -m unittest discover -s tools/observability -p 'test_*.py' -v
python tools/observability/evaluate.py snapshot.json
python tools/observability/evaluate.py snapshot.json --previous previous.json
```

Exemplo parcial: demais checks retornam UNKNOWN por ausência deliberada.

```json
{"environment":"local","checks":{"api_http":{"value":500,"observed_at":"2026-10-03T16:00:00Z"}}}
```

IDs permitidos são fixos em [evaluate.py](../../tools/observability/evaluate.py).
Estado anterior é o objeto `next_state` da execução anterior, não o output inteiro.
Ambientes não podem compartilhar estado. Saída possui enums fixos, sem valores,
URLs ou campos livres da entrada. Campos extras são rejeitados. Exit0 significa
todos os checks saudáveis; exit1 indica firing/unknown; exit2 entrada inválida.
Mesmo exit0 não atesta integridade da fonte: o coletor deve ter custódia/autorização
própria. Executar com snapshots confiáveis, sem PII, e guardar estado por ambiente.

## Aceite e gates restantes

- Matriz e avaliador local cobrem falha500, atraso backup/sync, dedup e recuperação.
- Testes controlados locais são sintéticos; não equivalem a TESTED-STAGING.
- WAITING-HUMAN/Access: escolher monitor realmente fora da VPS, responsável,
  destinos autorizados e ambiente isolado. Sem esse acesso, Tier1 não é DONE.
- Próxima prova staging: instalar coletor no ambiente isolado autorizado, induzir
  500 somente em endpoint sintético, atrasar recibo fake de backup/sync, comprovar
  abertura/duplicata/recuperação e sanitização; não repetir restores da #2.
- Provar detector externo durante indisponibilidade sintética do alvo; não
  derrubar produção para o teste. Registrar SHA/config, timestamps e recibos
  sanitizados. Dashboard somente após confirmar suporte da infraestrutura.
- Rollback local: remover uso do avaliador; nenhum serviço ou regra remota mudou.
  #32 permanece aberta até monitor externo Tier1 e prova controlada de staging.
