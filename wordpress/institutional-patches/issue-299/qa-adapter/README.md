# Adaptador/Android — STOP de integridade antes do clone

Preparação derivada do bootstrap validado de #299, mas **não homologada**.
`test_editorial.py` passou somente parse Python; nenhum de seus POSTs foi executado.
`run.sh` passou Bash syntax e executou apenas o preflight de integridade: FAIL.
Não executar novamente sem resolver o gate de integridade documentado no recibo.

O runner teria usado outro DB descartável, admin sintético, HTTP nativo para
0→1→0, e uma única aula13 para Android. Mantém siteurl privado e configura home
canônico IPEX apenas na cópia para validar a política de URLs do adaptador.
Essa etapa não foi alcançada. Nenhum plugin produtivo foi instalado.

Recibo: `docs/qa/ead-registration-resume-20261019/ADAPTER_STOP.md`.
