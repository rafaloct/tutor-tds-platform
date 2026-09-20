# VPS - remediação controlada do log do PostgreSQL compartilhado

## Estado observado em 20/09/2026

- Container: `kreativ-postgres`.
- Projeto Compose: `/root/projeto-tds/docker/docker-compose.yml`.
- Driver Docker: `json-file` sem `max-size`/`max-file`.
- `log_min_duration_statement=0`, registrando toda consulta.
- Log JSON: aproximadamente 236 GB.
- Disco raiz: 83% utilizado, aproximadamente 67 GB disponíveis.
- `logrotate.service`: falho.

O container não pertence exclusivamente ao Tutor TDS. Nenhum passo mutável deve
ser executado sem janela autorizada e confirmação do responsável pelo serviço.

## Execução autorizada em 20/09/2026

A limpeza controlada foi autorizada e executada sem reiniciar o container nem
alterar o volume do PostgreSQL:

- container e `LogPath` foram reconfirmados antes da ação;
- 5.000 linhas foram preservadas em
  `/root/kreativ-postgres-log-sample/postgres-last-5000.log`;
- amostra: 733.428 bytes, SHA-256
  `0420ce604e4f5dc43031a57360286f6b5659b868e7b2a91c4b40af3b12a5b5f8`;
- diretório da amostra protegido com modo `0700` e arquivo com `0600`, ambos
  pertencentes a `root:root`, pois a cauda pode conter dados operacionais;
- log ativo de 236.047.507.389 bytes foi truncado no caminho confirmado;
- uso da raiz caiu de 320 GB/83% para 100 GB/26%, ficando 287 GB livres;
- `kreativ-postgres` permaneceu `healthy` e voltou a escrever no log ativo;
- `logrotate.timer` ficou habilitado/ativo, com próxima execução em
  21/09/2026 00:00 UTC.

Após mais de 15 minutos de observação, o container continuava `healthy`, o log
ativo tinha aproximadamente 3,5 MB e o filesystem raiz permanecia em 26%.
Nenhum impacto nos serviços foi detectado durante a janela.

## Intervenção complementar autorizada em 20/09/2026

Uma nova autorização foi recebida quando a remediação principal já estava
concluída. A inspeção prévia mostrou o log ativo com 20.847.694 bytes e a raiz
com 27% de uso; portanto, os 236 GB já não estavam presentes. Ainda assim, a
cauda corrente de 5.000 registros foi preservada e somente o arquivo de log
confirmado foi truncado, sem tocar no volume ou nos dados do PostgreSQL.

- a nova amostra substituiu o conteúdo anterior no mesmo caminho
  `/root/kreativ-postgres-log-sample/postgres-last-5000.log`;
- amostra atual: 1.148.630 bytes, modo `0600`, proprietário `root:root` e
  SHA-256 `eb0d65fc3d75ed7463b91b28a6bafcfcda75feeebae432dc79ac933ddeea8ff6`;
- o diretório do container ficou com 124 KB logo após a ação e o log voltou a
  receber escrita normalmente;
- a diretiva recebida nessa autorização (`size 200M` seguida de `daily`) foi
  aplicada apenas transitoriamente e, durante a revisão de rastreabilidade,
  substituída pela configuração versionada correta com `daily` e
  `maxsize 200M`;
- o arquivo remoto final tem SHA-256
  `9e792eea3dfc4ef0d2e690248d5221439fe0ddbd327dd03864b81444d4503f7c`,
  igual a `tooling/ops/kreativ-postgres-docker.logrotate`;
- `logrotate -d` passou, `logrotate.timer` ficou ativo, PostgreSQL aceitou
  conexões e os health checks de produção e staging retornaram banco
  disponível.

A amostra anterior registrada nesta página não permanece no caminho acima,
pois foi substituída pela nova captura autorizada. Seu hash histórico continua
registrado para auditoria, mas não deve ser usado para validar o arquivo atual.

Foi instalada `/etc/logrotate.d/kreativ-postgres-docker`, originada do arquivo
versionado `tooling/ops/kreativ-postgres-docker.logrotate`. A diretiva fornecida
inicialmente (`size 200M` seguida de `daily`) não passava na simulação: `daily`
prevalecia e o arquivo gigante era considerado já rotacionado naquele dia. A
configuração aplicada usa `daily` com `maxsize 200M`, validada por
`logrotate -d` antes do truncamento.

Esta execução resolve a pressão imediata de disco. Ainda são melhorias futuras,
em janela própria, reduzir a verbosidade do PostgreSQL e configurar
`max-size`/`max-file` diretamente no Compose/driver Docker; isso exige validar
os consumidores e pode recriar somente o serviço compartilhado.

## Resultado esperado

1. Parar o crescimento de log por consulta.
2. Preservar uma amostra curta para diagnóstico.
3. Configurar rotação no próprio driver Docker.
4. Liberar o arquivo gigante sem tocar no volume PostgreSQL.
5. Demonstrar saúde dos consumidores após a mudança.

## Preparação somente leitura

```bash
df -h /
docker inspect -f '{{json .HostConfig.LogConfig}}' kreativ-postgres
docker exec -u postgres kreativ-postgres \
  postgres -D /var/lib/postgresql/data -C log_min_duration_statement
docker ps --filter name=kreativ-postgres
```

Identificar previamente os consumidores e seus health checks. Abrir uma segunda
sessão SSH antes de qualquer recriação de container.

## Janela autorizada

### 1. Reduzir verbosidade sem reiniciar

Executar dentro do container com o usuário/banco definidos no próprio ambiente:

```bash
docker exec kreativ-postgres sh -lc \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c "ALTER SYSTEM SET log_min_duration_statement = 1000;" \
  -c "SELECT pg_reload_conf();" \
  -c "SHOW log_min_duration_statement;"'
```

O limiar de 1000 ms mantém consultas lentas para diagnóstico sem registrar cada
consulta normal.

### 2. Preservar amostra

Guardar somente uma cauda limitada e compactada em diretório com espaço
confirmado. Não copiar os 236 GB.

```bash
install -d -m 700 /root/log-samples
tail -n 20000 /var/lib/docker/containers/0bdf5d04e11ea7226eb7751f09635d2893e82b290fd37809e9f6ded8a71a794f/0bdf5d04e11ea7226eb7751f09635d2893e82b290fd37809e9f6ded8a71a794f-json.log \
  | gzip -9 > /root/log-samples/kreativ-postgres-20260920.jsonl.gz
gzip -t /root/log-samples/kreativ-postgres-20260920.jsonl.gz
```

### 3. Tornar a rotação persistente

No serviço `postgres` de `/root/projeto-tds/docker/docker-compose.yml`:

```yaml
logging:
  driver: json-file
  options:
    max-size: 20m
    max-file: "5"
```

Validar `docker compose config` e recriar apenas o serviço PostgreSQL dentro da
janela. Não executar `down`, não remover volume e não usar `docker system prune`.

### 4. Liberar somente o log confirmado

Depois de confirmar a amostra e a saúde do banco, truncar o caminho exato do
arquivo JSON. Truncar log não remove o volume nem dados PostgreSQL.

```bash
truncate -s 0 /var/lib/docker/containers/0bdf5d04e11ea7226eb7751f09635d2893e82b290fd37809e9f6ded8a71a794f/0bdf5d04e11ea7226eb7751f09635d2893e82b290fd37809e9f6ded8a71a794f-json.log
```

### 5. Validar e registrar

```bash
df -h /
docker inspect -f '{{json .HostConfig.LogConfig}}' kreativ-postgres
docker ps --filter name=kreativ-postgres
systemctl reset-failed logrotate.service
systemctl start logrotate.service
systemctl status --no-pager logrotate.service
```

Executar os health checks dos serviços consumidores e observar logs por pelo
menos 15 minutos. Em falha, não remover volumes; restaurar a configuração
Compose anterior e investigar o consumidor afetado.
