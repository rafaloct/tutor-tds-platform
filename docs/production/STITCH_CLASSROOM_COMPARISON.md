# Classroom: design e implementação — Wave 1

Referência: projeto `3740249934950673416`, tela
`389e412e620c4c49841a5e9508cf6bfb`. Screenshot obtido pela API; HTML original
obtido em sessão autenticada pelo comando Mostrar código → Copiar código.
Título, regiões e ações conferidos; hashes em metadata. Nenhuma edição remota.

| Região do design | Código existente | Resultado |
| --- | --- | --- |
| Cabeçalho e card do encontro | ClassroomDashboardScreen mostra turma, curso, período e status | PARTIAL: turma não é encontro/sessão; composição visual diferente |
| Sessão ativa / presentes | fluxo SessionPresenceScreen; dashboard tem presenças confirmadas | PARTIAL: não confundir presença confirmada com contador ao vivo |
| Abrir QR | ação Presença, QR e evidências navega ao fluxo existente | PARTIAL: jornada disponível, atalho visual diferente |
| Enviar atividade | requer auditoria da atribuição de atividade | MISSING para este comando específico |
| Turma agora | dashboard usa inatividade, pendências e abaixo do esperado | PARTIAL: critérios não equivalem aos números estáticos do mockup |
| Pergunta ao vivo / aviso | domínio/realtime da Wave 4 ainda ausente | MISSING; não simular atualização |
| Evidência / observação | EvidenceStaffScreen e StudentFollowupScreen existentes | PARTIAL: rotas existentes, agrupamento visual diferente |
| Encerrar encontro | fluxo de presença separado; não é encerrar turma | PARTIAL: verificar comando de sessão antes de conectar o card |
| Início / Conteúdos / TDS IA / Perfil | navegação do MVP preservada | PARTIAL: adaptação visual ainda sem aceite |

Para a Wave 1, reutilizar a projeção real de progresso e os vínculos existentes.
Não exibir contadores, diagnóstico ou estado ao vivo estáticos como funcionais.
O HTML é referência visual, não implementação de autorização ou persistência.
Cache completo não muda status da tela para TESTED/PRODUCTION_READY.
