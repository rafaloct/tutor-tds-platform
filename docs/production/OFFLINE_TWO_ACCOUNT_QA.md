# Roteiro físico: duas contas no mesmo aparelho

Ambiente: staging Tutor TDS. Usar duas contas sintéticas identificáveis, A e B,
com matrículas e versões de curso distintas. Não usar CPF, senha, token ou
conteúdo de aluno real em capturas.

## Pré-condições

- O aplicativo contém o commit do fluxo de limpeza de sessão.
- A e B possuem acesso de staging e a conta A pode ser revogada pelo operador.
- A rede pode ser desligada e religada durante o roteiro.

## Roteiro

1. Entrar como A, abrir a turma e o conteúdo com rede. Iniciar um quiz/simulado,
   gerar ao menos um rascunho/evidência offline e abrir a carteira de
   certificados.
2. Desligar a rede e confirmar que A ainda vê somente o conteúdo que já foi
   autorizado para sua turma. Não concluir que isso concede horas ou certificado.
3. Sair da conta. Confirmar o aviso de remoção e verificar que a tela volta ao
   início sem perfil, tentativa, fila, certificado ou rota de A.
4. Entrar como B, ainda offline. Confirmar que B não vê tentativa, certificado,
   conteúdo de turma, analytics ou fila de A; B tampouco deve sincronizar um
   evento criado por A ao religar a rede.
5. Com rede, abrir a turma de B e confirmar que somente a matrícula/edição de B
   é baixada. Religá-la e inspecionar o resultado de sincronização: nenhuma
   evidência de A pode ser enviada sob a sessão de B.
6. Entrar novamente como A, pedir ao operador a revogação enquanto a rota da
   turma está aberta. Forçar uma chamada protegida ou atualizar a tela.
7. Confirmar `401`/acesso negado, retorno ao login e remoção de tokens, cache,
   fila, analytics e rotas acadêmicas. Tentar abrir rota previamente empilhada:
   ela deve exigir nova autenticação/autorização.

## Resultado a registrar

| Cenário | Esperado | Obtido | Evidência sanitizada |
| --- | --- | --- | --- |
| A offline → logout → B offline | B não lê nem entrega dados de A | pendente | vídeo/captura sem PII + log de status |
| reconexão de B | nenhum evento de A é enviado | pendente | IDs sintéticos e status API |
| revogação de A | token/cache/rotas deixam de funcionar | pendente | status HTTP e captura sem PII |

## Política P0 desta revisão

Enquanto todos os formatos legados não carregam matrícula/versão, o aplicativo
adota limpeza destrutiva no fim da sessão: não reutiliza dados acadêmicos entre
identidades. A fila durável existente já filtra por usuário, ambiente, turma e
versão; as demais cópias são removidas no logout/revogação em vez de serem
atribuídas retroativamente a outra conta.
