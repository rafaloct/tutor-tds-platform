# Inventário para Segurança dos dados — Play Console

Escopo: Tutor TDS 1.4.0+13. Este documento é um inventário técnico; a resposta
final na Play Console deve ser validada pelo responsável jurídico/operacional e
pelos contratos dos provedores.

| Grupo | Dados e tratamento | Finalidade | Controle/retenção |
|---|---|---|---|
| Informações pessoais | Nome, telefone/WhatsApp e CPF informado no cadastro/certificado. Na API de contas o CPF vira HMAC e o número não é armazenado; no dispositivo pode ficar na área privada. | Conta, suporte, identificação pedagógica e certificado. | Conta online é opcional; certificado exige confirmação específica. Exclusão disponível no app e no site. |
| Identificadores | UUID interno da conta, matrícula, turma, sessão e evento. | Autenticação, hierarquia, idempotência e auditoria. | Excluídos com a conta de estudante. |
| Atividade no app | Conteúdo iniciado/concluído, respostas e estado de quizzes/simulados, check-in/evidências estruturadas, tempo ativo, páginas, recursos e funcionalidades com identificadores técnicos. | Retomada, progresso, carga horária, presença, funcionamento e analytics pedagógico. | Envio exige conta/vínculo nos recursos online e consentimento de acompanhamento quando aplicável; eventos vinculados são excluídos com a conta. |
| Conteúdo do usuário | Perguntas ao Tutor de IA e conteúdo enviado voluntariamente ao suporte. | Gerar resposta e prestar atendimento. | Não incluir CPF/telefone automaticamente no prompt. Retenção do suporte depende do canal contratado. |
| Áudio | Fala usada sob ação explícita para transcrição pelo serviço de reconhecimento disponível no dispositivo. | Preencher a pergunta por voz. | O app não grava nem mantém arquivo de áudio; confirmar no formulário o tratamento efêmero do provedor de reconhecimento. |
| Arquivos/documentos | PDFs de certificados na área privada e cópias exportadas pela pessoa. | Carteira, impressão e compartilhamento. | Área privada apagada na exclusão/desinstalação; cópia exportada fica sob controle do destino. |
| Fotos e vídeos | O app reproduz vídeos publicados pelo Programa; não solicita acesso à galeria nem envia fotos/vídeos do aparelho nesta versão. | Aprendizagem audiovisual. | URLs restritas usam autorização efêmera; não há upload de mídia pelo estudante. |
| Certificado público | Nome, cartilha, data, ID, hash e assinatura. CPF e telefone não são públicos. | Verificação de autenticidade. | Pode ser preservado para integridade/verificação; correção ou contestação pelo contato de privacidade. |

## Respostas técnicas de base

- O app coleta dados: **sim**.
- Dados são criptografados em trânsito: **sim**, endpoints produtivos HTTPS e
  tráfego HTTP bloqueado no Android.
- O usuário pode solicitar exclusão: **sim**, no app e pela URL externa.
- Analytics/crash SDK de terceiros: **não há SDK dedicado nesta versão**;
  analytics é first-party e autenticado.
- Localização, contatos, saúde e dados financeiros: **não coletados pelo app**.
- Microfone: permissão opcional e acionada pelo usuário.

## Ponto que exige decisão humana

Provedores de infraestrutura, IA, reconhecimento de fala e suporte normalmente
podem ser tratados como prestadores de serviço, e a publicação do certificado
é iniciada pela pessoa. Marcar “não compartilhado” só é correto se os contratos
e usos reais atenderem às exceções da política da Play. Caso contrário, declarar
os grupos aplicáveis como compartilhados. A declaração deve incluir também o
comportamento de SDKs e serviços do sistema, não apenas o código próprio.
