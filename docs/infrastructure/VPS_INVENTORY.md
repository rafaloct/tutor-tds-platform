# Tutor TDS — Inventário da VPS

> **Documento de Infraestrutura**
> Data: 2026-09-19
> **STATUS: PENDENTE — Auditoria SSH ainda não realizada**

---

## Dados Conhecidos (Pré-Auditoria)

| Campo | Valor |
|---|---|
| IP | 46.202.150.132 |
| Provedor | Hostinger |
| Orquestrador | Dokploy |
| Painel HTTP | http://46.202.150.132 |
| Acesso SSH | Requer configuração (ver SSH_ACCESS.md) |

---

## Itens a Inventariar (via SSH)

Execute estes comandos após a primeira conexão. **Somente leitura — não alterar serviços.**

### Sistema

```bash
uname -a
cat /etc/os-release
uptime
timedatectl
whoami
id
```

### Recursos

```bash
df -h
free -h
lsblk
nproc
cat /proc/cpuinfo | grep "model name" | head -1
```

### Usuários e Acesso

```bash
cat /etc/passwd | grep -v nologin
lastlog
who
```

### Rede e Portas

```bash
ss -tulpn
ip addr
cat /etc/hosts
```

### Firewall

```bash
ufw status verbose
iptables -L -n 2>/dev/null || nft list ruleset 2>/dev/null
```

### Docker

```bash
docker --version
docker compose version
docker ps -a
docker images
docker volume ls
docker network ls
docker stats --no-stream
```

### Dokploy

```bash
# Verificar instalação
ls /etc/dokploy/ 2>/dev/null
curl -s http://localhost:3000/api/health 2>/dev/null
# Ou verificar via painel web
```

### Serviços systemd

```bash
systemctl --failed
systemctl list-units --type=service --state=running
```

### Logs Recentes

```bash
journalctl -n 50 --no-pager
docker logs $(docker ps -q | head -1) --tail=20 2>/dev/null
```

### Cron Jobs

```bash
crontab -l
ls /etc/cron.d/
ls /etc/cron.daily/
ls /etc/cron.weekly/
```

### Backups

```bash
# Verificar se existe backup local
ls /backup/ 2>/dev/null
ls /var/backup/ 2>/dev/null
# Verificar agendamento de snapshot na Hostinger (via painel web)
```

---

## Resultado da Auditoria

_Preencher após executar os comandos acima._

### Sistema Operacional
- OS: _pendente_
- Kernel: _pendente_
- Uptime: _pendente_
- Timezone: _pendente_

### Recursos
- CPU: _pendente_
- RAM Total: _pendente_
- RAM Livre: _pendente_
- Disco Total: _pendente_
- Disco Usado: _pendente_
- Swap: _pendente_

### Serviços Docker em Execução
_pendente_

### Portas Abertas
_pendente_

### Dokploy
- Versão: _pendente_
- Projetos encontrados: _pendente_
- Composes encontrados: _pendente_

### Volumes Importantes
_pendente_

### Firewall
_pendente_

### Backups
_pendente_

---

## Mapa de Serviços (após auditoria)

_Substituir pelo diagrama real quando a auditoria for concluída._

```
Internet
   |
   ▼
[Nginx / Dokploy Reverse Proxy]
   |
   ├── PWA Flutter (porta 80/443)
   ├── AnythingLLM (porta interna)
   └── Outros serviços (a identificar)
```

---

_Este documento deve ser preenchido completamente após a primeira conexão SSH autorizada._
