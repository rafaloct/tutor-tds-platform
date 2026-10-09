# TDS Operator Portal

Interface Drupal fina para o fluxo operacional já autorizado pela FastAPI:
escopo, busca exata, inspeção, confirmação, comando e histórico.

- A sessão e as provas de identidade ficam somente no servidor.
- O Drupal não traduz papéis locais em permissões acadêmicas.
- Toda busca, inspeção e mutação é reautorizada pela FastAPI.
- POST não recebe retry de transporte. O único replay após `401` ocorre depois
  de refresh e comandos mantêm a mesma chave de idempotência.
- `/admin/*` não faz parte deste módulo.

Rota: `/operacoes`.
