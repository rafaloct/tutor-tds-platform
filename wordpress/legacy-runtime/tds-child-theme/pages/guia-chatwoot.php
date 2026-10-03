<?php
/**
 * Template Name: TDS — Guia do Chatwoot
 */
defined('ABSPATH') || exit;

if (!current_user_can('edit_posts')) {
    wp_redirect(wp_login_url(get_permalink()));
    exit;
}

get_header();
?>
<style>
.guia-hero{background:linear-gradient(135deg,#0f172a 0%,#1a1035 50%,#0f172a 100%);color:#fff;padding:3rem 2rem;text-align:center}
.guia-hero h1{font-size:clamp(1.6rem,4vw,2.2rem);font-weight:900;margin:0 0 .5rem;color:#fff!important}
.guia-hero p{opacity:.75;font-size:1rem;margin:0}
.guia-hero__badge{display:inline-block;background:rgba(245,158,11,.2);border:1px solid rgba(245,158,11,.4);color:#fbbf24;border-radius:99px;padding:.3rem .9rem;font-size:.75rem;font-weight:700;letter-spacing:.08em;text-transform:uppercase;margin-bottom:1rem}

.guia-body{max-width:860px;margin:0 auto;padding:2.5rem 1.5rem 4rem}
.guia-toc{background:#f8fafc;border:1px solid #e2e8f0;border-radius:.75rem;padding:1.25rem 1.5rem;margin-bottom:2.5rem}
.guia-toc h3{font-size:.85rem;font-weight:800;color:#64748b;text-transform:uppercase;letter-spacing:.08em;margin:0 0 .75rem}
.guia-toc ol{margin:0;padding-left:1.25rem}
.guia-toc li{font-size:.9rem;margin-bottom:.3rem}
.guia-toc a{color:#2563eb;text-decoration:none}
.guia-toc a:hover{text-decoration:underline}

.guia-section{margin-bottom:3rem}
.guia-section h2{font-size:1.25rem;font-weight:900;color:#0f172a;border-bottom:2px solid #e2e8f0;padding-bottom:.6rem;margin-bottom:1.25rem;display:flex;align-items:center;gap:.6rem}
.guia-section h3{font-size:1rem;font-weight:800;color:#1e293b;margin:1.5rem 0 .5rem}
.guia-section p,.guia-section li{font-size:.92rem;color:#374151;line-height:1.7}
.guia-section ul,.guia-section ol{padding-left:1.4rem;margin:.5rem 0 1rem}
.guia-section li{margin-bottom:.4rem}

.guia-step{display:flex;gap:1rem;margin-bottom:1.25rem;align-items:flex-start}
.guia-step__num{flex-shrink:0;width:2rem;height:2rem;background:#2563eb;color:#fff!important;font-weight:900;font-size:.85rem;border-radius:50%;display:flex;align-items:center;justify-content:center}
.guia-step__body{font-size:.9rem;color:#374151;line-height:1.65}
.guia-step__title{font-weight:800;color:#0f172a;display:block;margin-bottom:.2rem}

.guia-tip{background:#f0fdf4;border:1px solid #86efac;border-radius:.75rem;padding:1rem 1.1rem;display:flex;gap:.6rem;align-items:flex-start;margin:1rem 0;font-size:.88rem;color:#166534!important}
.guia-tip strong{color:#14532d!important}
.guia-warn{background:#fff7ed;border:1px solid #fed7aa;border-radius:.75rem;padding:1rem 1.1rem;display:flex;gap:.6rem;align-items:flex-start;margin:1rem 0;font-size:.88rem;color:#9a3412!important}
.guia-info{background:#eff6ff;border:1px solid #bfdbfe;border-radius:.75rem;padding:1rem 1.1rem;display:flex;gap:.6rem;align-items:flex-start;margin:1rem 0;font-size:.88rem;color:#1e40af!important}
.guia-info strong,.guia-warn strong{color:inherit!important}

.guia-card{background:#fff;border:1px solid #e2e8f0;border-radius:.875rem;padding:1.25rem;margin-bottom:.75rem;box-shadow:0 1px 4px rgba(0,0,0,.05)}
.guia-card__title{font-weight:800;color:#0f172a;font-size:.95rem;margin-bottom:.3rem}
.guia-card__desc{font-size:.88rem;color:#475569}

.guia-kbd{display:inline-block;background:#f1f5f9;border:1px solid #cbd5e1;border-radius:.3rem;padding:.1rem .45rem;font-family:monospace;font-size:.82rem;color:#334155}

.guia-inbox-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:.75rem;margin:.75rem 0}
.guia-inbox{background:#f8fafc;border:1px solid #e2e8f0;border-radius:.75rem;padding:1rem;font-size:.85rem}
.guia-inbox__name{font-weight:800;color:#0f172a;margin-bottom:.25rem}
.guia-inbox__email{color:#475569;font-size:.8rem;word-break:break-all}
.guia-inbox__tag{display:inline-block;margin-top:.4rem;background:#e0f2fe;color:#0369a1;border-radius:99px;padding:.15rem .6rem;font-size:.72rem;font-weight:700}
.guia-inbox__tag--verde{background:#dcfce7;color:#166534}
.guia-inbox__tag--roxo{background:#f3e8ff;color:#7e22ce}
.guia-inbox__tag--amarelo{background:#fef9c3;color:#713f12}

.guia-status-grid{display:grid;grid-template-columns:1fr 1fr;gap:.75rem;margin:.75rem 0}
@media(max-width:600px){.guia-status-grid{grid-template-columns:1fr}.guia-inbox-grid{grid-template-columns:1fr}}
.guia-status{border-radius:.75rem;padding:.9rem 1rem;font-size:.88rem}
.guia-status__label{font-weight:800;font-size:.8rem;text-transform:uppercase;letter-spacing:.06em;margin-bottom:.2rem}
.guia-status--aberta{background:#fef9c3;border:1px solid #fde047;color:#713f12}
.guia-status--pendente{background:#fff7ed;border:1px solid #fed7aa;color:#9a3412}
.guia-status--resolvida{background:#dcfce7;border:1px solid #86efac;color:#166534}
.guia-status--adiada{background:#f3e8ff;border:1px solid #d8b4fe;color:#7e22ce}
</style>

<div class="guia-hero">
  <div class="guia-hero__badge">🔒 Acesso restrito — Instrutores e Estagiários</div>
  <h1>Guia do Chatwoot — TDS Capacitação</h1>
  <p>Como usar a central de atendimento para responder alunos por e-mail e WhatsApp</p>
</div>

<div class="guia-body">

  <!-- Índice -->
  <div class="guia-toc">
    <h3>Neste guia</h3>
    <ol>
      <li><a href="#o-que-e">O que é o Chatwoot e como ele funciona no TDS</a></li>
      <li><a href="#acesso">Como acessar e fazer login</a></li>
      <li><a href="#inboxes">Os canais de entrada (inboxes)</a></li>
      <li><a href="#conversas">Entendendo as conversas</a></li>
      <li><a href="#responder">Como responder um aluno</a></li>
      <li><a href="#whatsapp">Atendimento pelo WhatsApp</a></li>
      <li><a href="#email">Atendimento por e-mail</a></li>
      <li><a href="#status">Gerenciar status das conversas</a></li>
      <li><a href="#atribuir">Atribuir conversa a outro agente</a></li>
      <li><a href="#etiquetas">Usar etiquetas (labels)</a></li>
      <li><a href="#respostas">Respostas prontas (canned responses)</a></li>
      <li><a href="#notificacoes">Notificações e plantão</a></li>
      <li><a href="#boas-praticas">Boas práticas de atendimento</a></li>
    </ol>
  </div>

  <!-- 1. O que é -->
  <div class="guia-section" id="o-que-e">
    <h2>1 — O que é o Chatwoot e como ele funciona no TDS</h2>
    <p>O <strong>Chatwoot</strong> é a central de atendimento do Projeto TDS. Todos os e-mails enviados para os endereços oficiais e as mensagens de WhatsApp que saem do bot chegam aqui para serem respondidos por um instrutor ou estagiário.</p>
    <p>Você não precisa acessar webmail nem o celular com o número do projeto — tudo aparece em uma tela só, em <a href="https://chat.ipexdesenvolvimento.cloud" target="_blank" rel="noopener"><strong>chat.ipexdesenvolvimento.cloud</strong></a>.</p>

    <div class="guia-info">
      💡 <div><strong>Fluxo de atendimento:</strong> Aluno envia e-mail ou mensagem → sistema recebe e cria uma "conversa" no Chatwoot → você responde diretamente da plataforma → aluno recebe a resposta no canal original (e-mail ou WhatsApp).</div>
    </div>
  </div>

  <!-- 2. Acesso -->
  <div class="guia-section" id="acesso">
    <h2>2 — Como acessar e fazer login</h2>

    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Abra o navegador</span>
        Acesse <strong>chat.ipexdesenvolvimento.cloud</strong>. Use Chrome, Firefox ou Edge atualizado.
      </div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Faça login com sua conta de agente</span>
        Use o e-mail e senha que a coordenação forneceu. Se ainda não tiver conta, peça ao administrador para criar via <em>Settings → Agents → Invite Agent</em>.
      </div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Defina sua disponibilidade</span>
        No canto inferior esquerdo, clique no seu avatar e escolha <strong>Online</strong> quando estiver disponível para atender. Mude para <strong>Ocupado</strong> ou <strong>Ausente</strong> quando não puder responder.
      </div>
    </div>

    <div class="guia-tip">
      ✅ <div><strong>Dica:</strong> Ative notificações do navegador na primeira vez que acessar — o Chatwoot vai pedir permissão. Assim você recebe aviso de novas mensagens mesmo com a aba em segundo plano.</div>
    </div>
  </div>

  <!-- 3. Inboxes -->
  <div class="guia-section" id="inboxes">
    <h2>3 — Os canais de entrada (inboxes)</h2>
    <p>Cada inbox representa um canal por onde os alunos chegam. Na barra lateral esquerda, em <strong>Conversations</strong>, você vê as mensagens separadas por inbox.</p>

    <div class="guia-inbox-grid">
      <div class="guia-inbox">
        <div class="guia-inbox__name">💬 WhatsApp TDS</div>
        <div class="guia-inbox__email">Via Evolution API + bot n8n</div>
        <span class="guia-inbox__tag guia-inbox__tag--verde">WhatsApp</span>
      </div>
      <div class="guia-inbox">
        <div class="guia-inbox__name">📧 Atendimento Geral</div>
        <div class="guia-inbox__email">atendimento@ipexdesenvolvimento.cloud</div>
        <span class="guia-inbox__tag">E-mail</span>
      </div>
      <div class="guia-inbox">
        <div class="guia-inbox__name">📧 Coordenação TDS</div>
        <div class="guia-inbox__email">coordenacao@ipexdesenvolvimento.cloud</div>
        <span class="guia-inbox__tag">E-mail</span>
      </div>
      <div class="guia-inbox">
        <div class="guia-inbox__name">📧 Financeiro</div>
        <div class="guia-inbox__email">financeiro@ipexdesenvolvimento.cloud</div>
        <span class="guia-inbox__tag">E-mail</span>
      </div>
      <div class="guia-inbox">
        <div class="guia-inbox__name">🌐 Tutor TDS — Site</div>
        <div class="guia-inbox__email">Widget do site ead.ipexdesenvolvimento.cloud</div>
        <span class="guia-inbox__tag guia-inbox__tag--roxo">Widget</span>
      </div>
    </div>

    <div class="guia-warn">
      ⚠️ <div><strong>Atenção:</strong> Os e-mails dos inboxes são sincronizados automaticamente a cada poucos minutos. Se um e-mail demorar a aparecer, aguarde até 5 minutos ou clique em <em>Refresh</em> na conversa.</div>
    </div>
  </div>

  <!-- 4. Conversas -->
  <div class="guia-section" id="conversas">
    <h2>4 — Entendendo as conversas</h2>
    <p>Cada mensagem de um aluno vira uma <strong>conversa</strong>. Uma conversa contém todo o histórico de troca com aquele aluno naquele assunto.</p>

    <div class="guia-status-grid">
      <div class="guia-status guia-status--aberta">
        <div class="guia-status__label">🟡 Aberta (Open)</div>
        Conversa ativa, aguardando resposta sua ou do aluno.
      </div>
      <div class="guia-status guia-status--pendente">
        <div class="guia-status__label">🟠 Pendente (Pending)</div>
        Conversa nova que ainda não foi atribuída a nenhum agente.
      </div>
      <div class="guia-status guia-status--resolvida">
        <div class="guia-status__label">✅ Resolvida (Resolved)</div>
        Problema solucionado. A conversa fica arquivada.
      </div>
      <div class="guia-status guia-status--adiada">
        <div class="guia-status__label">😴 Adiada (Snoozed)</div>
        Pausada temporariamente. Volta para Aberta automaticamente.
      </div>
    </div>

    <h3>Painel de detalhes da conversa</h3>
    <p>Na coluna direita de cada conversa você vê:</p>
    <ul>
      <li><strong>Conversation Actions</strong> — status, agente responsável, etiquetas</li>
      <li><strong>Conversation Information</strong> — canal de origem, data/hora</li>
      <li><strong>Contact Information</strong> — nome, e-mail, histórico do contato</li>
      <li><strong>Previous Conversations</strong> — outras conversas do mesmo aluno</li>
    </ul>
  </div>

  <!-- 5. Responder -->
  <div class="guia-section" id="responder">
    <h2>5 — Como responder um aluno</h2>

    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Abra a conversa</span>
        Clique em qualquer conversa na lista. O histórico aparece no centro da tela.
      </div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Certifique-se de estar na aba "Reply"</span>
        Na caixa de texto, verifique se está em <strong>Reply</strong> (resposta ao aluno) e não em <strong>Note</strong> (nota interna visível só para a equipe).
      </div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Digite sua resposta</span>
        Escreva naturalmente. Para e-mail, pode usar formatação (negrito, listas). Para WhatsApp, texto simples funciona melhor.
      </div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">4</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Envie</span>
        Clique em <strong>Send</strong> ou pressione <span class="guia-kbd">Ctrl</span> + <span class="guia-kbd">Enter</span>. O aluno recebe a resposta no mesmo canal que usou para entrar em contato.
      </div>
    </div>

    <div class="guia-tip">
      💬 <div><strong>Nota interna:</strong> Use a aba <strong>Note</strong> para deixar observações para seus colegas (ex: "aguardando retorno da coordenação") — o aluno <em>não</em> vê essas notas.</div>
    </div>
  </div>

  <!-- 6. WhatsApp -->
  <div class="guia-section" id="whatsapp">
    <h2>6 — Atendimento pelo WhatsApp</h2>
    <p>O WhatsApp do TDS usa um bot automático (n8n + AnythingLLM) para responder perguntas sobre os cursos. Quando o bot não sabe responder ou o aluno pede um humano, a conversa é transferida para o Chatwoot.</p>

    <h3>Quando uma conversa cai no Chatwoot</h3>
    <p>Você receberá uma notificação. A conversa aparece na inbox <strong>WhatsApp TDS</strong> com o histórico completo da conversa com o bot.</p>

    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Leia o histórico</span>
        Role para cima para ver o que o aluno perguntou e o que o bot respondeu.
      </div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Apresente-se</span>
        Comece com uma mensagem como: <em>"Olá [Nome]! Sou [Seu Nome], da equipe TDS. Vi sua dúvida sobre [assunto]. Vou te ajudar 😊"</em>
      </div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Resolva e encerre</span>
        Após resolver, marque como <strong>Resolved</strong>. O bot volta a atender automaticamente.
      </div>
    </div>

    <div class="guia-warn">
      ⚠️ <div><strong>Importante:</strong> No WhatsApp, respostas longas com formatação (asteriscos, listas) funcionam bem. Evite respostas com mais de 3 parágrafos — prefira dividir em mensagens menores.</div>
    </div>
  </div>

  <!-- 7. E-mail -->
  <div class="guia-section" id="email">
    <h2>7 — Atendimento por e-mail</h2>
    <p>Quando um aluno envia e-mail para <strong>atendimento@ipexdesenvolvimento.cloud</strong> (ou coordenação/financeiro), o Chatwoot importa automaticamente e cria uma conversa na inbox correspondente.</p>

    <h3>Respondendo por e-mail</h3>
    <p>Funciona igual a qualquer e-mail: a sua resposta no Chatwoot é enviada como resposta ao e-mail original. O aluno vê apenas um e-mail normal — não percebe que você usou o Chatwoot.</p>

    <div class="guia-tip">
      📎 <div><strong>Anexos:</strong> Você pode incluir arquivos na resposta clicando no ícone de clipe (📎) na caixa de resposta. Bom para enviar certificados, regulamentos ou guias em PDF.</div>
    </div>

    <h3>Formulário de contato do site</h3>
    <p>Quando alguém preenche o formulário em <strong>ead.ipexdesenvolvimento.cloud/contato</strong>, o e-mail chega em <strong>tdsdados@gmail.com</strong> com cópia para <strong>atendimento@ipexdesenvolvimento.cloud</strong>. Responda diretamente pelo Chatwoot ou pelo Gmail.</p>
  </div>

  <!-- 8. Status -->
  <div class="guia-section" id="status">
    <h2>8 — Gerenciar status das conversas</h2>

    <div class="guia-card">
      <div class="guia-card__title">✅ Resolver conversa</div>
      <div class="guia-card__desc">Clique em <strong>Resolve</strong> (botão verde no topo da conversa) quando o problema foi solucionado. A conversa vai para a aba "Resolved". Atalho: <span class="guia-kbd">Ctrl</span>+<span class="guia-kbd">Alt</span>+<span class="guia-kbd">E</span></div>
    </div>
    <div class="guia-card">
      <div class="guia-card__title">😴 Adiar conversa (Snooze)</div>
      <div class="guia-card__desc">Use quando precisa aguardar algo (ex: confirmação da coordenação). Clique na seta ao lado de Resolve → <strong>Snooze until...</strong>. Escolha quando quer que ela volte para Open.</div>
    </div>
    <div class="guia-card">
      <div class="guia-card__title">🔄 Reabrir conversa</div>
      <div class="guia-card__desc">Se o aluno responder uma conversa já resolvida, ela reabre automaticamente. Você também pode reabrir manualmente pelo botão <strong>Reopen</strong>.</div>
    </div>

    <div class="guia-tip">
      🎯 <div><strong>Meta de atendimento:</strong> Tente resolver ou dar um retorno em até 24h durante dias úteis. Conversas abertas por mais de 48h sem resposta ficam destacadas no painel da coordenação.</div>
    </div>
  </div>

  <!-- 9. Atribuir -->
  <div class="guia-section" id="atribuir">
    <h2>9 — Atribuir conversa a outro agente</h2>
    <p>Se a dúvida é de outro agente ou você está saindo, transfira a conversa:</p>

    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Abra o painel de ações</span>
        Na coluna direita, procure <strong>Conversation Actions</strong> → <strong>Assigned Agent</strong>.
      </div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Escolha o agente</span>
        Clique no campo e selecione o nome do colega que vai assumir.
      </div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">
        <span class="guia-step__title">Deixe uma nota interna</span>
        Na aba <strong>Note</strong>, explique brevemente o contexto para o colega (ex: "Aluno aguarda confirmação de matrícula no Curso de Empreendedorismo").
      </div>
    </div>
  </div>

  <!-- 10. Etiquetas -->
  <div class="guia-section" id="etiquetas">
    <h2>10 — Usar etiquetas (labels)</h2>
    <p>As etiquetas classificam as conversas e facilitam o filtro. Encontre as etiquetas em <strong>Conversation Actions → Conversation Labels</strong>.</p>

    <div class="guia-inbox-grid">
      <div class="guia-inbox">
        <div class="guia-inbox__name">🎓 matricula</div>
        <div class="guia-inbox__email">Pedido de inscrição ou acesso ao curso</div>
      </div>
      <div class="guia-inbox">
        <div class="guia-inbox__name">📜 certificado</div>
        <div class="guia-inbox__email">Dúvidas sobre certificado ou histórico</div>
      </div>
      <div class="guia-inbox">
        <div class="guia-inbox__name">🔑 acesso</div>
        <div class="guia-inbox__email">Problemas de login ou senha</div>
      </div>
      <div class="guia-inbox">
        <div class="guia-inbox__name">🤖 ia-bolso</div>
        <div class="guia-inbox__email">Questões sobre a IA de Bolso / AnythingLLM</div>
      </div>
      <div class="guia-inbox">
        <div class="guia-inbox__name">⚠️ urgente</div>
        <div class="guia-inbox__email">Requer resposta imediata</div>
      </div>
    </div>

    <p>Para filtrar por etiqueta, clique em <strong>Labels</strong> no menu lateral esquerdo.</p>
  </div>

  <!-- 11. Respostas prontas -->
  <div class="guia-section" id="respostas">
    <h2>11 — Respostas prontas (canned responses)</h2>
    <p>Para perguntas frequentes, use as respostas prontas. Na caixa de resposta, digite <span class="guia-kbd">/</span> seguido de uma palavra-chave e o Chatwoot sugere a resposta pronta.</p>

    <div class="guia-card">
      <div class="guia-card__title">/senha → Redefinição de senha</div>
      <div class="guia-card__desc"><em>"Olá! Para redefinir sua senha, acesse ead.ipexdesenvolvimento.cloud, clique em 'Entrar' → 'Esqueci minha senha' e informe o e-mail cadastrado. O link chega em até 5 minutos (verifique o spam)."</em></div>
    </div>
    <div class="guia-card">
      <div class="guia-card__title">/certificado → Prazo de certificado</div>
      <div class="guia-card__desc"><em>"Olá! O certificado é emitido automaticamente ao concluir todas as aulas da trilha. Aparece na área 'Minha Área' → 'Certificados'. Se já concluiu e não apareceu, aguarde 24h ou entre em contato."</em></div>
    </div>
    <div class="guia-card">
      <div class="guia-card__title">/matricula → Como se matricular</div>
      <div class="guia-card__desc"><em>"Olá! As matrículas são realizadas pelos estagiários do TDS. Por favor, confirme seu nome completo e e-mail e o curso de interesse que faremos o cadastro para você."</em></div>
    </div>

    <h3>Criar uma nova resposta pronta</h3>
    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">Vá em <strong>Settings → Canned Responses → New Canned Response</strong></div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">Defina um <strong>Short Name</strong> (palavra-chave sem espaços, ex: <code>acesso-bloqueado</code>)</div>
    </div>
    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">Escreva o <strong>Content</strong> (texto completo da resposta) e salve</div>
    </div>
  </div>

  <!-- 12. Notificações -->
  <div class="guia-section" id="notificacoes">
    <h2>12 — Notificações e plantão</h2>

    <h3>Configurar notificações</h3>
    <p>Acesse <strong>Profile Settings → Notifications</strong> (ícone de sino → <em>Notification Settings</em>). Recomendado ativar:</p>
    <ul>
      <li>✅ New conversation assigned to me</li>
      <li>✅ Conversation assigned to me is reopened</li>
      <li>✅ New mention (quando alguém te marca com @)</li>
    </ul>

    <h3>Horário de atendimento sugerido</h3>
    <p>O TDS não tem plantão 24h. A recomendação é:</p>
    <ul>
      <li>Verificar o Chatwoot <strong>2× por dia</strong> nos dias úteis (manhã e tarde)</li>
      <li>Priorizar conversas com etiqueta <strong>urgente</strong></li>
      <li>Conversas do WhatsApp transferidas pelo bot têm <strong>prioridade</strong> — o aluno está esperando ativamente</li>
    </ul>

    <div class="guia-info">
      📱 <div><strong>App móvel:</strong> O Chatwoot tem app para Android e iOS (busque "Chatwoot" nas lojas). Com ele você recebe notificações push mesmo sem estar no computador.</div>
    </div>
  </div>

  <!-- 13. Boas práticas -->
  <div class="guia-section" id="boas-praticas">
    <h2>13 — Boas práticas de atendimento</h2>

    <div class="guia-card">
      <div class="guia-card__title">🫂 Trate o aluno pelo nome</div>
      <div class="guia-card__desc">Comece sempre com "Olá [Nome]!". O nome está visível em <em>Contact Information</em> no painel direito.</div>
    </div>
    <div class="guia-card">
      <div class="guia-card__title">🗂️ Nunca deixe conversa "pendurada"</div>
      <div class="guia-card__desc">Se não sabe a resposta, mande um "Olá [Nome], recebi sua mensagem! Vou verificar e retorno em breve." — isso já ajuda o aluno a saber que foi atendido.</div>
    </div>
    <div class="guia-card">
      <div class="guia-card__title">📝 Use notas internas para coordenação</div>
      <div class="guia-card__desc">Se precisar de ajuda da coordenação, use a aba <strong>Note</strong> e mencione o colega com <span class="guia-kbd">@nome</span>. Ele recebe notificação.</div>
    </div>
    <div class="guia-card">
      <div class="guia-card__title">✅ Resolva ao terminar</div>
      <div class="guia-card__desc">Sempre marque como <strong>Resolved</strong> ao finalizar. A lista de conversas abertas é o "to-do" da equipe — não deixe crescer.</div>
    </div>
    <div class="guia-card">
      <div class="guia-card__title">🔒 Não compartilhe dados sensíveis no chat</div>
      <div class="guia-card__desc">Senhas, CPF e dados pessoais de alunos não devem ser enviados via WhatsApp ou e-mail aberto. Para cadastros, use o sistema interno <em>Cadastrar Aluno</em> no painel do WordPress.</div>
    </div>
    <div class="guia-card">
      <div class="guia-card__title">📊 Relatórios mensais</div>
      <div class="guia-card__desc">A coordenação acessa <strong>Reports → Overview</strong> para ver o volume de atendimentos. Manter as conversas bem classificadas (etiquetas + resolvidas corretamente) ajuda nesse controle.</div>
    </div>
  </div>

  <div style="background:linear-gradient(135deg,#1e1b4b,#0f172a);border-radius:1rem;padding:2rem;text-align:center;color:#fff;margin-top:1rem">
    <p style="font-size:1rem;font-weight:800;margin:0 0 .5rem;color:#fff!important">Dúvidas sobre o Chatwoot?</p>
    <p style="font-size:.88rem;opacity:.75;margin:0 0 1.25rem;color:rgba(255,255,255,.75)!important">Fale com a coordenação do projeto ou acesse a documentação oficial</p>
    <a href="https://www.chatwoot.com/docs/user-guide/" target="_blank" rel="noopener"
       style="display:inline-block;background:#f59e0b;color:#000!important;font-weight:800;font-size:.9rem;padding:.7rem 2rem;border-radius:.5rem;text-decoration:none">
      Documentação oficial →
    </a>
    <a href="<?= esc_url(admin_url('admin.php?page=cadastrar-aluno')) ?>"
       style="display:inline-block;background:rgba(255,255,255,.1);color:#fff!important;font-weight:700;font-size:.9rem;padding:.7rem 2rem;border-radius:.5rem;text-decoration:none;margin-left:.75rem;border:1px solid rgba(255,255,255,.2)">
      Cadastrar Aluno →
    </a>
  </div>

</div>

<?php get_footer(); ?>
