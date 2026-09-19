# Tutor TDS — Acesso SSH à VPS

> **Documento de Infraestrutura**
> Data: 2026-09-19

---

## Informações da VPS

| Campo | Valor |
|---|---|
| IP | 46.202.150.132 |
| Hospedagem | Hostinger |
| Painel | http://46.202.150.132 (Dokploy) |
| Usuário inicial | root |
| Usuário operacional futuro | tdsdeploy (a criar) |

---

## Chave SSH Dedicada do Projeto

Criar uma chave SSH exclusiva para o Tutor TDS (não reutilizar chaves pessoais):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/tutor_tds_vps -C "tutor-tds-vps"
```

Arquivos gerados:
- **Privada:** `~/.ssh/tutor_tds_vps` — NUNCA compartilhar ou versionar
- **Pública:** `~/.ssh/tutor_tds_vps.pub` — pode ser instalada no servidor

---

## Configuração SSH Local (`~/.ssh/config`)

Adicionar ao arquivo `~/.ssh/config` (criar se não existir):

```ssh-config
Host tutor-tds-vps
    HostName 46.202.150.132
    User root
    IdentityFile ~/.ssh/tutor_tds_vps
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Após configurado, a conexão é simplesmente:

```bash
ssh tutor-tds-vps
```

---

## Instalação da Chave Pública (Bootstrap Inicial)

Execute **uma única vez** para instalar a chave pública:

```bash
ssh-copy-id -i ~/.ssh/tutor_tds_vps.pub root@46.202.150.132
```

Ou manualmente:
```bash
cat ~/.ssh/tutor_tds_vps.pub | ssh root@46.202.150.132 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

---

## Usuário Operacional Dedicado (Após Bootstrap)

Após confirmar acesso root por chave, criar usuário dedicado:

```bash
# Na VPS
useradd -m -s /bin/bash tdsdeploy
usermod -aG sudo tdsdeploy
mkdir -p /home/tdsdeploy/.ssh
cp /root/.ssh/authorized_keys /home/tdsdeploy/.ssh/
chown -R tdsdeploy:tdsdeploy /home/tdsdeploy/.ssh
chmod 700 /home/tdsdeploy/.ssh
chmod 600 /home/tdsdeploy/.ssh/authorized_keys
```

Atualizar `~/.ssh/config` local:
```ssh-config
Host tutor-tds-vps
    HostName 46.202.150.132
    User tdsdeploy         # ← alterar aqui
    IdentityFile ~/.ssh/tutor_tds_vps
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**⚠️ Testar login com tdsdeploy em nova janela ANTES de bloquear root.**

---

## Hardening SSH (Somente após tdsdeploy funcional)

Editar `/etc/ssh/sshd_config`:
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Reiniciar:
```bash
systemctl restart sshd
```

**⚠️ NUNCA executar isso sem antes confirmar que `tdsdeploy` funciona corretamente.**

---

## Status Atual

| Etapa | Status |
|---|---|
| Gerar chave `tutor_tds_vps` | ✅ Concluído |
| Instalar chave pública na VPS | ✅ Concluído |
| Configurar acesso local | ✅ Chave dedicada validada |
| Validar acesso SSH | ✅ `BatchMode` como root funcional em 2026-09-19 |
| Criar usuário `tdsdeploy` | ⏳ Pendente |
| Bloquear login root | ⏳ Pendente |
| Desativar auth por senha | ⏳ Pendente |
| Auditoria somente leitura da VPS | ✅ Concluída |

---

_Atualizar conforme o acesso for configurado._
