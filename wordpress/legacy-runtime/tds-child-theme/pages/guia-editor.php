<?php
/**
 * Template Name: TDS — Guia do Editor
 */
defined('ABSPATH') || exit;

// Apenas usuários com permissão de editar posts podem ver esta página
if (!current_user_can('edit_posts')) {
    wp_redirect(wp_login_url(get_permalink()));
    exit;
}

get_header();
?>

<style>
.guia-hero{background:linear-gradient(135deg,#1e293b 0%,#0f172a 100%);color:#fff;padding:3rem 1.5rem;text-align:center}
.guia-hero h1{font-size:clamp(1.5rem,4vw,2.2rem);font-weight:800;margin-bottom:.5rem}
.guia-hero p{opacity:.8;font-size:1.05rem;max-width:600px;margin:0 auto}
.guia-badge{display:inline-flex;align-items:center;gap:.4rem;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.2);border-radius:99px;padding:.3rem .9rem;font-size:.75rem;font-weight:600;letter-spacing:.05em;text-transform:uppercase;margin-bottom:1rem}
.guia-wrap{max-width:860px;margin:0 auto;padding:2.5rem 1.5rem 4rem}
.guia-section{margin-bottom:3.5rem}
.guia-section-title{font-size:1.4rem;font-weight:800;color:var(--tds-texto);border-left:4px solid var(--tds-destaque,#f59e0b);padding-left:.75rem;margin-bottom:1.5rem}
.guia-step{display:flex;gap:1rem;margin-bottom:1.25rem;align-items:flex-start}
.guia-step__num{flex-shrink:0;width:2rem;height:2rem;border-radius:50%;background:var(--tds-destaque,#f59e0b);color:#000;font-weight:800;font-size:.85rem;display:flex;align-items:center;justify-content:center}
.guia-step__body{flex:1}
.guia-step__title{font-weight:700;color:var(--tds-texto);margin-bottom:.25rem;font-size:.95rem}
.guia-step__desc{color:var(--tds-texto-fraco,#64748b);font-size:.9rem;line-height:1.6}
.guia-tip{background:#fefce8;border:1px solid #fde047;border-radius:.5rem;padding:.9rem 1rem;display:flex;gap:.6rem;align-items:flex-start;margin-top:1rem;margin-bottom:1rem;font-size:.88rem;color:#713f12}
.guia-tip strong{color:#92400e}
.guia-warn{background:#fff1f2;border:1px solid #fda4af;border-radius:.5rem;padding:.9rem 1rem;display:flex;gap:.6rem;align-items:flex-start;margin-top:.75rem;font-size:.88rem;color:#881337}
.guia-info{background:#eff6ff;border:1px solid #bfdbfe;border-radius:.5rem;padding:.9rem 1rem;display:flex;gap:.6rem;align-items:flex-start;margin-top:.75rem;font-size:.88rem;color:#1e40af}
.guia-card{background:#fff;border:1px solid var(--tds-borda,#e2e8f0);border-radius:.75rem;padding:1.25rem 1.5rem;margin-bottom:1rem}
.guia-card h4{font-size:1rem;font-weight:700;color:var(--tds-texto);margin-bottom:.35rem}
.guia-card p{color:var(--tds-texto-fraco,#64748b);font-size:.88rem;line-height:1.6;margin:0}
.guia-cats{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:.75rem;margin-top:1rem}
.guia-cat{border-radius:.5rem;padding:.6rem .9rem;font-size:.85rem;font-weight:600;text-align:center}
.guia-cat--azul{background:#dbeafe;color:#1e40af}
.guia-cat--verde{background:#dcfce7;color:#166534}
.guia-cat--laranja{background:#ffedd5;color:#9a3412}
.guia-cat--roxo{background:#ede9fe;color:#5b21b6}
.guia-cat--rosa{background:#fce7f3;color:#9d174d}
.guia-kbd{display:inline-block;background:#f1f5f9;border:1px solid #cbd5e1;border-radius:.25rem;padding:.1rem .4rem;font-family:monospace;font-size:.82rem;color:#334155}
.guia-nav{display:flex;gap:.5rem;flex-wrap:wrap;margin-bottom:2rem}
.guia-nav a{display:inline-block;padding:.4rem .9rem;background:#f1f5f9;border-radius:.4rem;font-size:.82rem;font-weight:600;color:#334155;text-decoration:none;border:1px solid #e2e8f0}
.guia-nav a:hover{background:#e2e8f0}
.guia-divider{border:none;border-top:2px dashed var(--tds-borda,#e2e8f0);margin:3rem 0}
.guia-path{display:inline-flex;align-items:center;gap:.3rem;background:#f8fafc;border:1px solid #e2e8f0;border-radius:.4rem;padding:.3rem .75rem;font-size:.83rem;font-family:monospace;color:#475569;margin:.3rem 0}
.guia-path span{color:#94a3b8}
@media(prefers-color-scheme:dark){
  .guia-card{background:#1e293b;border-color:#334155}
  .guia-nav a{background:#1e293b;border-color:#334155;color:#cbd5e1}
}
</style>

<div class="guia-hero">
  <div class="guia-badge">🔒 Área restrita — apenas editores</div>
  <h1>Guia do Editor TDS</h1>
  <p>Passo a passo para publicar notícias, criar cursos e manter o site sempre atualizado.</p>
</div>

<div class="guia-wrap">

  <!-- ÍNDICE -->
  <nav class="guia-nav" aria-label="Ir para seção">
    <a href="#acesso">🔑 Acesso ao painel</a>
    <a href="#alunos">👤 Cadastrar aluno</a>
    <a href="#noticias">📰 Publicar notícia</a>
    <a href="#categorias">🏷️ Categorias</a>
    <a href="#cursos">🎓 Criar curso</a>
    <a href="#licoes">📖 Aulas e seções</a>
    <a href="#dicas">💡 Boas práticas</a>
  </nav>

  <!-- ============ ACESSO ============ -->
  <section class="guia-section" id="acesso">
    <h2 class="guia-section-title">🔑 Acessar o painel de administração</h2>

    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Abra o endereço do painel</div>
        <div class="guia-step__desc">
          No navegador, acesse:
          <div class="guia-path">ead.ipexdesenvolvimento.cloud<span>/</span>wp-admin</div>
        </div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Faça login com seu usuário e senha</div>
        <div class="guia-step__desc">Use as credenciais fornecidas pela equipe técnica. Caso tenha esquecido a senha, clique em "Esqueceu sua senha?" e informe seu e-mail cadastrado.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Você verá o painel (Dashboard)</div>
        <div class="guia-step__desc">O menu lateral à esquerda tem todas as opções. As mais usadas são: <strong>Posts</strong> (para notícias) e <strong>LearnPress</strong> (para cursos).</div>
      </div>
    </div>

    <div class="guia-tip">💡 <div><strong>Dica:</strong> Marque o endereço <code>ead.ipexdesenvolvimento.cloud/wp-admin</code> nos favoritos do seu navegador para acessar mais rápido.</div></div>
  </section>

  <hr class="guia-divider">

  <!-- ============ CADASTRO DE ALUNOS ============ -->
  <section class="guia-section" id="alunos">
    <h2 class="guia-section-title">👤 Cadastrar aluno e matricular em curso</h2>

    <p style="color:var(--tds-texto-fraco);margin-bottom:1.5rem;font-size:.9rem">
      As contas dos alunos são criadas <strong>manualmente pelos estagiários</strong> via painel. O sistema gera automaticamente as credenciais e envia tudo por e-mail para o aluno.
    </p>

    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Acesse "Cadastrar Aluno" no menu lateral</div>
        <div class="guia-step__desc">
          No painel, clique em <strong>Cadastrar Aluno</strong> no menu da esquerda (ícone de grupo de pessoas).
          <div class="guia-path">Painel <span>›</span> Cadastrar Aluno</div>
        </div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Preencha o nome completo e e-mail do aluno</div>
        <div class="guia-step__desc">Esses dados devem ser confirmados com o aluno antes do cadastro. O e-mail precisa ser válido pois as credenciais são enviadas para ele.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Informe o telefone/WhatsApp (opcional)</div>
        <div class="guia-step__desc">Útil para contato futuro em caso de dúvidas ou avisos de oficinas.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">4</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Selecione o(s) curso(s) do aluno</div>
        <div class="guia-step__desc">Marque os cursos da trilha que o aluno vai cursar. Um aluno pode ser matriculado em mais de um curso ao mesmo tempo.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">5</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Clique em "Criar conta e matricular aluno"</div>
        <div class="guia-step__desc">O sistema automaticamente: cria a conta, gera uma senha temporária, matricula no(s) curso(s) e <strong>envia o e-mail com tudo</strong> para o aluno.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">6</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Confirme com o aluno que o e-mail chegou</div>
        <div class="guia-step__desc">Peça ao aluno que verifique também a pasta de spam. Caso o e-mail não chegue em 10 minutos, refaça o processo — o sistema reenviará as credenciais.</div>
      </div>
    </div>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:.75rem;margin-top:1.25rem">
      <div class="guia-tip" style="margin:0">✅ <div><strong>Se o aluno já tem conta:</strong> o sistema apenas matricula nos novos cursos e envia um e-mail de confirmação. Nenhuma informação é sobrescrita.</div></div>
      <div class="guia-warn" style="margin:0">⚠️ <div><strong>E-mail inválido:</strong> verifique bem antes de cadastrar. Se o e-mail errar, o aluno não receberá as credenciais e precisará de recuperação manual de senha.</div></div>
    </div>

    <div class="guia-info" style="margin-top:1rem">ℹ️ <div><strong>O e-mail enviado ao aluno inclui:</strong> usuário de acesso · senha temporária · link direto para o curso · link da plataforma · contato de suporte via WhatsApp.</div></div>
  </section>

  <hr class="guia-divider">

  <!-- ============ NOTÍCIAS ============ -->
  <section class="guia-section" id="noticias">
    <h2 class="guia-section-title">📰 Publicar uma notícia</h2>

    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Vá em Posts → Adicionar novo</div>
        <div class="guia-step__desc">
          No menu lateral esquerdo, clique em <strong>Posts</strong> e depois em <strong>Adicionar novo post</strong>.
          <div class="guia-path">Painel <span>›</span> Posts <span>›</span> Adicionar novo post</div>
        </div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Escreva o título</div>
        <div class="guia-step__desc">Clique no campo <strong>"Adicionar título"</strong> no topo da página. Use um título claro e direto, por exemplo:<br><em>"Oficina de Culinária Saudável ocorre em Araguaína no dia 10/06"</em></div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Escreva o conteúdo</div>
        <div class="guia-step__desc">Clique abaixo do título e comece a digitar. Pressione <span class="guia-kbd">Enter</span> para criar um novo parágrafo. Para formatar o texto (negrito, itálico), selecione o texto e use a barra de ferramentas que aparece.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">4</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Adicione uma imagem de destaque</div>
        <div class="guia-step__desc">
          No painel lateral direito, role até encontrar <strong>"Imagem destacada"</strong> e clique em <strong>"Definir imagem destacada"</strong>. Carregue uma foto (formato JPG ou PNG, mínimo 800×500 pixels). Esta foto aparecerá no cartão da notícia na listagem.
        </div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">5</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Escolha a categoria</div>
        <div class="guia-step__desc">No painel lateral direito, procure <strong>"Categorias"</strong> e marque a que melhor se encaixa (veja a lista abaixo). Cada categoria muda a cor do badge na listagem de notícias.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">6</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Escreva um resumo (opcional, mas recomendado)</div>
        <div class="guia-step__desc">Role para baixo até encontrar <strong>"Extrato"</strong> (pode estar oculto — clique em "Opções de tela" no canto superior direito e ative "Extrato"). Escreva 1 a 2 frases resumindo a notícia. Este texto aparece nos cartões da listagem.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">7</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Publique!</div>
        <div class="guia-step__desc">Clique no botão azul <strong>"Publicar"</strong> no canto superior direito. Confirme clicando em "Publicar" novamente. A notícia já aparece na página de Notícias do site.</div>
      </div>
    </div>

    <div class="guia-warn">⚠️ <div>Antes de publicar, releia o texto. Erros de ortografia passam uma imagem negativa. Use o corretor ortográfico do navegador (sublinhado vermelho).</div></div>
  </section>

  <hr class="guia-divider">

  <!-- ============ CATEGORIAS ============ -->
  <section class="guia-section" id="categorias">
    <h2 class="guia-section-title">🏷️ Categorias de notícias</h2>
    <p style="color:var(--tds-texto-fraco);margin-bottom:1rem;font-size:.9rem">Cada categoria tem uma cor diferente no site. Use a categoria que melhor descreve o conteúdo da notícia:</p>

    <div class="guia-cats">
      <div class="guia-cat guia-cat--azul">🔵 Notícias<br><small style="font-weight:400">Informações gerais do projeto</small></div>
      <div class="guia-cat guia-cat--verde">🟢 Visitas a Comunidades<br><small style="font-weight:400">Atividades de campo nos territórios</small></div>
      <div class="guia-cat guia-cat--laranja">🟠 Comunicados<br><small style="font-weight:400">Avisos oficiais, prazos, inscrições</small></div>
      <div class="guia-cat guia-cat--roxo">🟣 Eventos<br><small style="font-weight:400">Oficinas, encontros, datas presenciais</small></div>
      <div class="guia-cat guia-cat--rosa">🩷 Instagram<br><small style="font-weight:400">Reposts de conteúdo das redes sociais</small></div>
    </div>

    <div class="guia-tip" style="margin-top:1.25rem">💡 <div><strong>Dica:</strong> Se a notícia se encaixa em mais de uma categoria, escolha a <strong>principal</strong>. Evite marcar várias categorias ao mesmo tempo.</div></div>
  </section>

  <hr class="guia-divider">

  <!-- ============ CURSOS ============ -->
  <section class="guia-section" id="cursos">
    <h2 class="guia-section-title">🎓 Criar um novo curso</h2>

    <p style="color:var(--tds-texto-fraco);margin-bottom:1.5rem;font-size:.9rem">Os cursos usam o plugin <strong>LearnPress</strong>. Siga os passos abaixo para criar do zero:</p>

    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Vá em LearnPress → Cursos → Adicionar novo</div>
        <div class="guia-step__desc">
          <div class="guia-path">Painel <span>›</span> LearnPress <span>›</span> Cursos <span>›</span> Adicionar novo</div>
        </div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Preencha o título do curso</div>
        <div class="guia-step__desc">Exemplo: <em>"Empreendedorismo Popular — Gestão de Negócios"</em>. Seja claro e inclua o nome da trilha.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Escreva a descrição do curso</div>
        <div class="guia-step__desc">No editor principal, descreva o que o aluno vai aprender, para quem é o curso, e o que é necessário para participar. Use parágrafos curtos para facilitar a leitura.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">4</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Configure o preço como "Grátis"</div>
        <div class="guia-step__desc">Role a página até encontrar o bloco <strong>"Configurações do Curso"</strong>. No campo <strong>Preço</strong>, deixe em branco ou coloque <strong>0</strong>. Marque como <strong>Gratuito</strong> se houver essa opção.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">5</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Configure as opções de inscrição</div>
        <div class="guia-step__desc">Em <strong>"Inscrição"</strong>, selecione <strong>"Inscrição aberta"</strong> para que qualquer aluno com conta no site possa se inscrever automaticamente. Não ative aprovação manual (atrasa o acesso dos alunos).</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">6</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Defina a duração (opcional)</div>
        <div class="guia-step__desc">Informe a carga horária total, por exemplo: <strong>"40 horas"</strong>. Esse dado aparece na página do curso.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">7</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Adicione a imagem de capa do curso</div>
        <div class="guia-step__desc">No painel lateral direito, clique em <strong>"Imagem destacada"</strong> e carregue uma imagem representativa do curso (mínimo 800×500 px).</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">8</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Salve como Rascunho por enquanto</div>
        <div class="guia-step__desc">Clique em <strong>"Salvar rascunho"</strong> para não perder o trabalho enquanto adiciona as aulas. Você publica depois de adicionar todo o conteúdo.</div>
      </div>
    </div>

    <div class="guia-info">ℹ️ <div>Um curso sem nenhuma aula não deve ser publicado. Adicione pelo menos uma seção e uma aula antes de tornar o curso público.</div></div>
  </section>

  <hr class="guia-divider">

  <!-- ============ AULAS ============ -->
  <section class="guia-section" id="licoes">
    <h2 class="guia-section-title">📖 Adicionar seções e aulas ao curso</h2>

    <p style="color:var(--tds-texto-fraco);margin-bottom:1.5rem;font-size:.9rem">O conteúdo de um curso é organizado em <strong>Seções</strong> (como capítulos) e dentro de cada seção há <strong>Aulas</strong> e/ou <strong>Quizzes</strong>.</p>

    <div class="guia-step">
      <div class="guia-step__num">1</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Localize o bloco "Currículo do curso"</div>
        <div class="guia-step__desc">Role a página do curso para baixo até encontrar o bloco <strong>"Currículo do Curso"</strong>. É aqui que você adiciona toda a estrutura do curso.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">2</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Adicione uma seção</div>
        <div class="guia-step__desc">Clique em <strong>"+ Nova seção"</strong> e digite o nome da seção, por exemplo: <em>"Módulo 1 — Introdução ao Empreendedorismo"</em>. Pressione <span class="guia-kbd">Enter</span> para confirmar.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">3</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Adicione aulas dentro da seção</div>
        <div class="guia-step__desc">Clique em <strong>"+ Nova aula"</strong> dentro da seção. Digite o título da aula, por exemplo: <em>"O que é ser empreendedor?"</em>. Clique no ícone de lápis ✏️ para abrir o editor da aula.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">4</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Escreva o conteúdo da aula</div>
        <div class="guia-step__desc">Uma nova janela ou página abre para editar a aula. Escreva o conteúdo, adicione vídeos (cole o link do YouTube no bloco de vídeo), imagens, textos, documentos PDF, etc. Salve quando terminar.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">5</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Adicione um quiz (avaliação) — opcional</div>
        <div class="guia-step__desc">Clique em <strong>"+ Novo quiz"</strong> para adicionar uma avaliação ao final da seção. Configure as perguntas, o tipo de resposta (múltipla escolha, verdadeiro/falso) e a nota mínima para aprovação.</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">6</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Repita para cada módulo/seção</div>
        <div class="guia-step__desc">Continue adicionando seções e aulas até o curso estar completo. A ordem das seções e aulas pode ser alterada arrastando e soltando (<strong>drag &amp; drop</strong>).</div>
      </div>
    </div>

    <div class="guia-step">
      <div class="guia-step__num">7</div>
      <div class="guia-step__body">
        <div class="guia-step__title">Publique o curso</div>
        <div class="guia-step__desc">Quando todo o conteúdo estiver pronto, volte à página principal do curso e clique no botão <strong>"Publicar"</strong> (canto superior direito). O curso estará disponível imediatamente para os alunos se inscreverem.</div>
      </div>
    </div>

    <div class="guia-tip">💡 <div><strong>Aulas com vídeo do YouTube:</strong> Copie o link do vídeo, adicione um bloco "Vídeo" na aula e cole o link. O vídeo aparece embutido na plataforma.</div></div>
    <div class="guia-tip">💡 <div><strong>Aulas com PDF:</strong> Adicione um bloco "Arquivo" e carregue o PDF. Os alunos poderão baixar diretamente pela plataforma.</div></div>
  </section>

  <hr class="guia-divider">

  <!-- ============ DICAS ============ -->
  <section class="guia-section" id="dicas">
    <h2 class="guia-section-title">💡 Boas práticas de conteúdo</h2>

    <div class="guia-card">
      <h4>📸 Imagens de qualidade</h4>
      <p>Use sempre fotos nítidas, bem iluminadas e no formato paisagem (horizontal). Evite imagens com texto sobreposto ou logos de terceiros. O tamanho mínimo recomendado é <strong>800×500 pixels</strong>. Fotos de atividades reais do projeto têm mais impacto do que imagens genéricas da internet.</p>
    </div>

    <div class="guia-card">
      <h4>✍️ Texto claro e direto</h4>
      <p>Escreva para o público do projeto: pessoas de comunidades rurais, agricultores familiares e empreendedores informais. Use <strong>frases curtas</strong>, evite palavras técnicas sem explicação e prefira a voz ativa ("A equipe realizou" em vez de "Foi realizado pela equipe").</p>
    </div>

    <div class="guia-card">
      <h4>🔗 Não publique informações pessoais</h4>
      <p>Nunca publique CPF, endereço residencial, telefone pessoal de beneficiários ou qualquer dado sensível. Para eventos, use apenas cidade e data — nunca endereços completos de residências.</p>
    </div>

    <div class="guia-card">
      <h4>📅 Frequência ideal de publicação</h4>
      <p>O ideal é publicar pelo menos <strong>2 notícias por semana</strong>. Visitas a campo, oficinas realizadas, comunicados importantes e reposts do Instagram são sempre bons conteúdos. Um site atualizado passa credibilidade e aparece melhor no Google.</p>
    </div>

    <div class="guia-card">
      <h4>🗂️ Organização dos cursos</h4>
      <p>Mantenha a estrutura de módulos consistente entre os cursos. Use sempre o padrão: <strong>"Módulo X — Nome do Módulo"</strong> para as seções e títulos descritivos para as aulas. Isso facilita a navegação dos alunos.</p>
    </div>

    <div class="guia-card">
      <h4>🔔 Comunicar lançamentos</h4>
      <p>Ao publicar um novo curso ou um comunicado importante, envie uma mensagem nos grupos do WhatsApp da comunidade TDS avisando sobre o novo conteúdo. Inclua o link direto da página.</p>
    </div>
  </section>

  <hr class="guia-divider">

  <!-- SUPORTE -->
  <div style="text-align:center;padding:2rem;background:#f8fafc;border-radius:.75rem">
    <div style="font-size:2rem;margin-bottom:.5rem">🛠️</div>
    <h3 style="font-size:1.1rem;font-weight:700;margin-bottom:.5rem">Precisa de ajuda técnica?</h3>
    <p style="color:var(--tds-texto-fraco);font-size:.9rem;margin-bottom:1rem">Para problemas com o site, cursos ou conteúdo, entre em contato com a equipe de desenvolvimento:</p>
    <a href="https://chat.ipexdesenvolvimento.cloud" target="_blank" rel="noopener" class="tds-btn tds-btn--amarelo" style="margin-right:.5rem">💬 Abrir chamado no Chatwoot</a>
    <a href="mailto:ipexdesenvolvimento@uft.edu.br" class="tds-btn tds-btn--ghost" style="color:var(--tds-texto)!important">✉️ Enviar e-mail</a>
  </div>

</div>

<?php get_footer(); ?>
