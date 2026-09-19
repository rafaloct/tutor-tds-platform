import 'package:flutter/material.dart';
import 'genui_assistant_screen.dart';

class GlossaryTerm {
  final String term;
  final String definition;
  final String cartilha;
  final Color color;
  const GlossaryTerm({
    required this.term,
    required this.definition,
    required this.cartilha,
    required this.color,
  });
}

// Cores por cartilha
const _cAgri = Color(0xFF2E7D32); // Agricultura Sustentável
const _cAten = Color(0xFF00838F); // Atendimento ao Cliente
const _cAudi = Color(0xFFAD1457); // Audiovisual
const _cCoop = Color(0xFFE65100); // Cooperativismo
const _cEcon = Color(0xFF6A1B9A); // Economia do Lar
const _cFin = Color(0xFF093AF4); // Educação Financeira
const _cIA = Color(0xFF283593); // IA
const _cSAF = Color(0xFF4E342E); // SAF
const _cSIM = Color(0xFF00695C); // SIM e SIMA

const _terms = [
  // ── AGRICULTURA SUSTENTÁVEL ──────────────────────────────────
  GlossaryTerm(
    term: 'Adubação Orgânica',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Uso de materiais naturais, como esterco e restos vegetais, para melhorar a fertilidade do solo.',
  ),
  GlossaryTerm(
    term: 'Adubação Verde',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Plantio de espécies utilizadas para proteger e enriquecer o solo de forma natural.',
  ),
  GlossaryTerm(
    term: 'Agroecologia',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Forma de produção agrícola que busca equilíbrio entre produção de alimentos, conservação ambiental e qualidade de vida.',
  ),
  GlossaryTerm(
    term: 'Agroecossistema',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Sistema formado pela interação entre plantas, solo, água, animais e pessoas em uma área produtiva.',
  ),
  GlossaryTerm(
    term: 'Agricultura Familiar',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Modelo de produção realizado principalmente pela própria família em pequenas propriedades rurais.',
  ),
  GlossaryTerm(
    term: 'Agrotóxicos',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Produtos químicos utilizados para controlar pragas, doenças e plantas invasoras nas lavouras.',
  ),
  GlossaryTerm(
    term: 'Capina Seletiva',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Retirada apenas das plantas invasoras que prejudicam a produção, preservando as demais.',
  ),
  GlossaryTerm(
    term: 'Cobertura do Solo',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Camada de plantas ou resíduos vegetais que protege o solo contra sol forte, chuva e erosão.',
  ),
  GlossaryTerm(
    term: 'Compostagem',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Processo de transformação de resíduos orgânicos em adubo natural.',
  ),
  GlossaryTerm(
    term: 'Consórcio de Culturas',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Cultivo de diferentes espécies agrícolas em uma mesma área ao mesmo tempo.',
  ),
  GlossaryTerm(
    term: 'Extrato Vegetal',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Preparado natural feito com plantas para auxiliar no controle de pragas e doenças.',
  ),
  GlossaryTerm(
    term: 'Fertilidade do Solo',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Capacidade do solo de fornecer nutrientes para o crescimento das plantas.',
  ),
  GlossaryTerm(
    term: 'Gotejamento',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Sistema de irrigação que libera água lentamente próximo às raízes das plantas.',
  ),
  GlossaryTerm(
    term: 'Irrigação de Baixo Custo',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Tecnologias simples e acessíveis para levar água às plantações com pouco gasto.',
  ),
  GlossaryTerm(
    term: 'Leguminosas',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Grupo de plantas que ajudam a enriquecer o solo com nutrientes, como feijão e crotalária.',
  ),
  GlossaryTerm(
    term: 'Microaspersão',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Sistema de irrigação que distribui água em pequenas gotas, semelhante a uma chuva leve.',
  ),
  GlossaryTerm(
    term: 'Monocultura',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Cultivo de apenas uma espécie agrícola em grandes áreas, o que pode degradar o solo.',
  ),
  GlossaryTerm(
    term: 'Reserva Legal',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Área da propriedade rural destinada à conservação ambiental conforme a legislação.',
  ),
  GlossaryTerm(
    term: 'Rotação de Culturas',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Alternância de diferentes cultivos em uma mesma área ao longo do tempo para recuperar o solo.',
  ),
  GlossaryTerm(
    term: 'SAFs (Sistemas Agroflorestais)',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Sistemas que integram árvores, cultivos agrícolas e, em alguns casos, animais em uma mesma área.',
  ),
  GlossaryTerm(
    term: 'Segurança Alimentar',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Garantia de acesso a alimentos suficientes e saudáveis para a população.',
  ),
  GlossaryTerm(
    term: 'Soberania Alimentar',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Direito das comunidades de produzir e consumir alimentos de acordo com sua cultura e realidade local.',
  ),
  GlossaryTerm(
    term: 'Sustentabilidade',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Uso equilibrado dos recursos naturais visando o bem-estar presente e das futuras gerações.',
  ),
  GlossaryTerm(
    term: 'Tecnologia Social',
    cartilha: 'Agricultura Sustentável',
    color: _cAgri,
    definition:
        'Solução simples e acessível criada para melhorar a vida das comunidades.',
  ),

  // ── ATENDIMENTO AO CLIENTE ───────────────────────────────────
  GlossaryTerm(
    term: 'Agilidade',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition:
        'Capacidade de atender com rapidez, sem perder a qualidade e a atenção ao cliente.',
  ),
  GlossaryTerm(
    term: 'Alteridade',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition:
        'Capacidade de reconhecer e respeitar o outro, entendendo que cada pessoa tem sua própria realidade e necessidade.',
  ),
  GlossaryTerm(
    term: 'Atendimento de Qualidade',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition:
        'Atendimento feito com respeito, atenção, clareza, responsabilidade e busca por solução.',
  ),
  GlossaryTerm(
    term: 'Cliente Fiel',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition:
        'Cliente que volta a procurar o mesmo negócio porque confia na qualidade do atendimento e do que é oferecido.',
  ),
  GlossaryTerm(
    term: 'Código de Defesa do Consumidor',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition:
        'Lei que protege os direitos de quem compra produtos ou contrata serviços.',
  ),
  GlossaryTerm(
    term: 'Comunicação Não Verbal',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition:
        'Mensagens transmitidas sem palavras, por meio do olhar, da postura, da expressão facial e do tom de voz.',
  ),
  GlossaryTerm(
    term: 'Cordialidade',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition: 'Forma educada, gentil e respeitosa de tratar o outro.',
  ),
  GlossaryTerm(
    term: 'Empatia',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition:
        'Capacidade de se colocar no lugar da outra pessoa, procurando compreender seus sentimentos e necessidades.',
  ),
  GlossaryTerm(
    term: 'Escuta Ativa',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition:
        'Forma de ouvir com atenção verdadeira, sem interromper, buscando compreender o que a outra pessoa quer dizer.',
  ),
  GlossaryTerm(
    term: 'Ética',
    cartilha: 'Atendimento ao Cliente',
    color: _cAten,
    definition:
        'Conjunto de atitudes baseadas no respeito, na honestidade e na responsabilidade no trabalho.',
  ),

  // ── AUDIOVISUAL ──────────────────────────────────────────────
  GlossaryTerm(
    term: 'Audiovisual',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition: 'Tudo que junta imagem e som para passar uma mensagem.',
  ),
  GlossaryTerm(
    term: 'Captação de Áudio',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Momento de gravar o som da melhor forma possível durante a produção do vídeo.',
  ),
  GlossaryTerm(
    term: 'Close',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Tipo de enquadramento que mostra o rosto ou um detalhe de perto.',
  ),
  GlossaryTerm(
    term: 'Direção de Arte',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition: 'Cuida da aparência do vídeo, como cenário, roupas e objetos.',
  ),
  GlossaryTerm(
    term: 'Edição',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Processo de organizar o vídeo, cortar partes e adicionar efeitos, música e texto.',
  ),
  GlossaryTerm(
    term: 'Enquadramento',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Como os elementos aparecem dentro da imagem — a forma de posicionar a câmera.',
  ),
  GlossaryTerm(
    term: 'Plano Aberto',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Enquadramento que mostra o ambiente completo, dando contexto à cena.',
  ),
  GlossaryTerm(
    term: 'Plano Médio',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition: 'Enquadramento que mostra a pessoa da cintura para cima.',
  ),
  GlossaryTerm(
    term: 'Pós-produção',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Etapa em que o vídeo é editado após a gravação, com cortes, efeitos e finalização.',
  ),
  GlossaryTerm(
    term: 'Pré-produção',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Planejamento do vídeo antes de gravar: roteiro, locações e equipe.',
  ),
  GlossaryTerm(
    term: 'Roteiro',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Planejamento escrito do que vai acontecer no vídeo — o que falar, onde filmar e em qual ordem.',
  ),
  GlossaryTerm(
    term: 'Storyboard',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Desenho ou esquema das cenas antes de gravar, para visualizar o vídeo antecipadamente.',
  ),
  GlossaryTerm(
    term: 'Travelling',
    cartilha: 'Audiovisual',
    color: _cAudi,
    definition:
        'Movimento de câmera que acompanha a pessoa ou objeto em deslocamento.',
  ),

  // ── COOPERATIVISMO ───────────────────────────────────────────
  GlossaryTerm(
    term: 'Associativismo',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Quando as pessoas se juntam para alcançar um objetivo em comum, como produzir, vender ou se ajudar.',
  ),
  GlossaryTerm(
    term: 'Autonomia',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Capacidade de decidir e organizar o próprio trabalho sem depender de terceiros.',
  ),
  GlossaryTerm(
    term: 'Cooperativa',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Grupo de pessoas que produzem, vendem ou prestam serviços juntos, compartilhando os ganhos.',
  ),
  GlossaryTerm(
    term: 'Cooperativismo',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Forma de organização onde as pessoas trabalham juntas em um negócio e dividem os resultados de forma justa.',
  ),
  GlossaryTerm(
    term: 'Divisão de Resultados',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Quando o dinheiro ganho é dividido entre todos os membros de forma justa e proporcional.',
  ),
  GlossaryTerm(
    term: 'Formalização',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Quando um grupo ou negócio passa a ser reconhecido oficialmente pelo governo.',
  ),
  GlossaryTerm(
    term: 'Geração de Renda',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Forma de ganhar dinheiro por meio de trabalho, produção ou venda de produtos e serviços.',
  ),
  GlossaryTerm(
    term: 'Inclusão Produtiva',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Quando uma pessoa começa a trabalhar e gerar renda dentro da economia formal ou comunitária.',
  ),
  GlossaryTerm(
    term: 'Organização Coletiva',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Trabalho em grupo com regras e divisão de tarefas para alcançar objetivos comuns.',
  ),
  GlossaryTerm(
    term: 'Planejamento',
    cartilha: 'Cooperativismo e Crédito',
    color: _cCoop,
    definition:
        'Organizar antes de agir, pensando no que precisa ser feito, quando e por quem.',
  ),

  // ── ECONOMIA DO LAR ─────────────────────────────────────────
  GlossaryTerm(
    term: 'Agricultura Urbana',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Cultivo de alimentos em espaços urbanos, como quintais, varandas e pequenos terrenos.',
  ),
  GlossaryTerm(
    term: 'Conforto Ambiental',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Conjunto de condições que tornam a casa mais agradável, saudável e adequada ao bem-estar dos moradores.',
  ),
  GlossaryTerm(
    term: 'Conforto Térmico',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Sensação de temperatura agradável dentro dos ambientes, evitando calor ou frio excessivo.',
  ),
  GlossaryTerm(
    term: 'Despesas Fixas',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Gastos que costumam ter valores semelhantes todos os meses, como aluguel e energia elétrica.',
  ),
  GlossaryTerm(
    term: 'Despesas Variáveis',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Gastos que mudam de acordo com o consumo, como alimentação, transporte e lazer.',
  ),
  GlossaryTerm(
    term: 'Economia Doméstica',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Conjunto de práticas para organizar melhor os recursos financeiros e materiais da casa.',
  ),
  GlossaryTerm(
    term: 'Horta Autoirrigável',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Sistema de cultivo que mantém a terra úmida por meio de reservatório de água, reutilizando garrafas PET.',
  ),
  GlossaryTerm(
    term: 'Iluminação Natural',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Entrada da luz do sol nos ambientes internos, reduzindo a necessidade de lâmpadas durante o dia.',
  ),
  GlossaryTerm(
    term: 'Móveis Multifuncionais',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Móveis que possuem mais de uma utilidade, ajudando a economizar espaço na casa.',
  ),
  GlossaryTerm(
    term: 'Orçamento Familiar',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Controle das entradas e saídas de dinheiro da família para evitar dívidas e planejar gastos.',
  ),
  GlossaryTerm(
    term: 'Orientação Solar',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Posição do sol em relação à casa ao longo do dia. Ajuda a identificar quais ambientes recebem mais calor.',
  ),
  GlossaryTerm(
    term: 'Parede Verde',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Estrutura com plantas cultivadas em paredes ou suportes verticais para reduzir calor e melhorar o ambiente.',
  ),
  GlossaryTerm(
    term: 'Reaproveitamento de Materiais',
    cartilha: 'Economia do Lar',
    color: _cEcon,
    definition:
        'Transformação de materiais descartados em novos objetos úteis para o cotidiano.',
  ),

  // ── EDUCAÇÃO FINANCEIRA ──────────────────────────────────────
  GlossaryTerm(
    term: 'Autonomia Financeira',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Capacidade de organizar e utilizar o próprio dinheiro de forma consciente, sem depender excessivamente de empréstimos.',
  ),
  GlossaryTerm(
    term: 'Consumo Consciente',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Forma de consumir considerando a real necessidade, evitando desperdícios e priorizando o uso responsável do dinheiro.',
  ),
  GlossaryTerm(
    term: 'Consumo Impulsivo',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Compra realizada sem planejamento, motivada por emoção ou desejo imediato, podendo prejudicar o orçamento.',
  ),
  GlossaryTerm(
    term: 'Crédito',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Valor disponibilizado por instituições ou pessoas para uso imediato, com pagamento futuro (ex: empréstimos, cartão de crédito).',
  ),
  GlossaryTerm(
    term: 'Endividamento',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Situação em que a pessoa possui dívidas que comprometem sua renda e dificultam o equilíbrio financeiro.',
  ),
  GlossaryTerm(
    term: 'Inclusão Financeira',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Acesso e uso de serviços financeiros (conta, crédito, poupança) de forma segura e consciente.',
  ),
  GlossaryTerm(
    term: 'Juros',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Valor cobrado pelo uso do dinheiro emprestado. Quanto mais tempo demorar para pagar, maiores os juros.',
  ),
  GlossaryTerm(
    term: 'Lucro',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Valor que sobra após pagar todos os custos de produção ou venda de um produto ou serviço.',
  ),
  GlossaryTerm(
    term: 'Renegociação de Dívidas',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Acordo para ajustar condições de pagamento, como prazos e valores, facilitando a quitação da dívida.',
  ),
  GlossaryTerm(
    term: 'Sustentabilidade Financeira',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Capacidade de manter as finanças organizadas ao longo do tempo, evitando prejuízos e garantindo estabilidade.',
  ),
  GlossaryTerm(
    term: 'Valor do Trabalho',
    cartilha: 'Educação Financeira',
    color: _cFin,
    definition:
        'Reconhecimento de que o tempo e esforço dedicados a uma atividade devem ser considerados no cálculo de preços e renda.',
  ),

  // ── INTELIGÊNCIA ARTIFICIAL ──────────────────────────────────
  GlossaryTerm(
    term: 'Algoritmo',
    cartilha: 'Inteligência Artificial',
    color: _cIA,
    definition:
        'Conjunto de instruções que um computador segue para resolver um problema. É como uma receita de bolo: passo a passo definido para chegar a um resultado.',
  ),
  GlossaryTerm(
    term: 'Aprendizado de Máquina',
    cartilha: 'Inteligência Artificial',
    color: _cIA,
    definition:
        'Ramo da IA em que sistemas aprendem a realizar tarefas a partir de exemplos e dados, sem serem programados explicitamente para cada situação.',
  ),
  GlossaryTerm(
    term: 'Ater Digital',
    cartilha: 'Inteligência Artificial',
    color: _cIA,
    definition:
        'Serviço de Assistência Técnica e Extensão Rural digital com IA que vai orientar produtores rurais via chatbot.',
  ),
  GlossaryTerm(
    term: 'Chatbot',
    cartilha: 'Inteligência Artificial',
    color: _cIA,
    definition:
        'Programa que simula uma conversa humana. É o que responde automaticamente quando você envia mensagem para empresas ou serviços públicos.',
  ),
  GlossaryTerm(
    term: 'Deep Learning',
    cartilha: 'Inteligência Artificial',
    color: _cIA,
    definition:
        'Tipo de IA que usa redes neurais com muitas camadas para aprender padrões complexos, como reconhecer rostos ou traduzir idiomas.',
  ),
  GlossaryTerm(
    term: 'IA Generativa',
    cartilha: 'Inteligência Artificial',
    color: _cIA,
    definition:
        'Tipo de IA capaz de criar conteúdos novos — textos, imagens, músicas — a partir de instruções em linguagem natural. Exemplos: ChatGPT, Gemini.',
  ),
  GlossaryTerm(
    term: 'LGPD',
    cartilha: 'Inteligência Artificial',
    color: _cIA,
    definition:
        'Lei Geral de Proteção de Dados Pessoais. Protege seus dados — nenhuma empresa pode usá-los sem sua autorização.',
  ),
  GlossaryTerm(
    term: 'PLN — Processamento de Linguagem Natural',
    cartilha: 'Inteligência Artificial',
    color: _cIA,
    definition:
        'Tecnologia que permite computadores entenderem e gerarem linguagem humana — escrita ou falada.',
  ),

  // ── SAF ──────────────────────────────────────────────────────
  GlossaryTerm(
    term: 'Agregar Valor',
    cartilha: 'SAF',
    color: _cSAF,
    definition:
        'Transformar a fruta em polpa ou a castanha em óleo — o lucro que ficava com o atravessador passa a ser seu.',
  ),
  GlossaryTerm(
    term: 'Agrofloresta (SAF)',
    cartilha: 'SAF',
    color: _cSAF,
    definition:
        'Sistema que imita a floresta, misturando árvores com roça de comida no mesmo lugar.',
  ),
  GlossaryTerm(
    term: 'Biomassa',
    cartilha: 'SAF',
    color: _cSAF,
    definition:
        'Folhas e galhos que, quando cortados e postos no chão, viram adubo natural para o solo.',
  ),
  GlossaryTerm(
    term: 'Entrelinhas',
    cartilha: 'SAF',
    color: _cSAF,
    definition:
        'O espaço entre as fileiras de árvores que deve ser sempre cultivado para gerar renda e proteger o solo.',
  ),
  GlossaryTerm(
    term: 'Estratos',
    cartilha: 'SAF',
    color: _cSAF,
    definition:
        'Os "andares" da plantação (rasteiro, baixo, médio e alto) para aproveitar o sol de forma inteligente.',
  ),
  GlossaryTerm(
    term: 'Placenta Financeira',
    cartilha: 'SAF',
    color: _cSAF,
    definition:
        'Técnica de plantar milho, feijão, abóbora e mandioca junto com as mudas de árvores para gerar renda enquanto as árvores crescem.',
  ),
  GlossaryTerm(
    term: 'Pluriatividade',
    cartilha: 'SAF',
    color: _cSAF,
    definition:
        'O produtor moderno não é só quem planta — é quem empreende. O SAF abre portas para não depender apenas da venda do produto bruto.',
  ),
  GlossaryTerm(
    term: 'Sucessão',
    cartilha: 'SAF',
    color: _cSAF,
    definition:
        'O crescimento natural da roça, que começa com plantas rápidas e termina com as árvores grandes ao longo do tempo.',
  ),

  // ── SIM e SIMA ───────────────────────────────────────────────
  GlossaryTerm(
    term: 'Agroindústria Familiar',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Produção de alimentos realizada por famílias, geralmente em pequena escala, com foco na geração de renda local.',
  ),
  GlossaryTerm(
    term: 'Boas Práticas de Fabricação (BPF)',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Conjunto de procedimentos que garantem a higiene e a qualidade na produção de alimentos.',
  ),
  GlossaryTerm(
    term: 'Certificação Sanitária',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Processo que comprova que o produto atende às normas de higiene e segurança exigidas pelos órgãos de fiscalização.',
  ),
  GlossaryTerm(
    term: 'Controle de Qualidade',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Conjunto de ações que garantem que os produtos estejam dentro dos padrões exigidos, seguros e adequados para consumo.',
  ),
  GlossaryTerm(
    term: 'DTAs (Doenças Transmitidas por Alimentos)',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Doenças causadas pela ingestão de alimentos contaminados — por isso a higiene na produção é fundamental.',
  ),
  GlossaryTerm(
    term: 'Higienização',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Limpeza adequada de instalações, equipamentos e utensílios para evitar contaminação dos alimentos.',
  ),
  GlossaryTerm(
    term: 'Regularização',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Processo de adequação às normas legais para que o produtor possa comercializar seus produtos.',
  ),
  GlossaryTerm(
    term: 'Rotulagem',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Informações presentes na embalagem do produto, como ingredientes, validade e identificação do produtor.',
  ),
  GlossaryTerm(
    term: 'SIM (Serviço de Inspeção Municipal)',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Serviço responsável pela inspeção de produtos de origem animal no âmbito municipal.',
  ),
  GlossaryTerm(
    term: 'SIMA',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Integração entre municípios para padronizar a inspeção e ampliar a comercialização dos produtos.',
  ),
  GlossaryTerm(
    term: 'SISBI-POA',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Sistema Brasileiro de Inspeção de Produtos de Origem Animal que permite a equivalência entre serviços de inspeção.',
  ),
  GlossaryTerm(
    term: 'Temperatura de Conservação',
    cartilha: 'SIM e SIMA',
    color: _cSIM,
    definition:
        'Controle térmico necessário para manter a qualidade e segurança dos alimentos, especialmente os perecíveis.',
  ),
];

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _search = '';
  String _filterCartilha = 'Todas';

  static final _cartilhas = [
    'Todas',
    ..._terms.map((t) => t.cartilha).toSet().toList()..sort(),
  ];

  List<GlossaryTerm> get _filtered {
    return _terms.where((t) {
      final matchSearch =
          _search.isEmpty ||
          t.term.toLowerCase().contains(_search.toLowerCase()) ||
          t.definition.toLowerCase().contains(_search.toLowerCase());
      final matchCartilha =
          _filterCartilha == 'Todas' || t.cartilha == _filterCartilha;
      return matchSearch && matchCartilha;
    }).toList()..sort((a, b) => a.term.compareTo(b.term));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Glossário TDS'),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                '${filtered.length} termos',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: Colors.black26,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar termo ou definição...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _cartilhas.length,
              itemBuilder: (context, i) {
                final selected = _filterCartilha == _cartilhas[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      _cartilhas[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.white : null,
                      ),
                    ),
                    selected: selected,
                    backgroundColor: Colors.grey[200],
                    selectedColor: const Color(0xFF093AF4),
                    onSelected: (_) =>
                        setState(() => _filterCartilha = _cartilhas[i]),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Nenhum termo encontrado.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _TermCard(term: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TermCard extends StatelessWidget {
  final GlossaryTerm term;
  const _TermCard({required this.term});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    term.term,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: term.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: term.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    term.cartilha,
                    style: TextStyle(
                      fontSize: 9,
                      color: term.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              term.definition,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF444444),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.psychology, size: 14),
                label: const Text(
                  'Perguntar à IA',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GenUIAssistantScreen(
                      initialContext:
                          'O aluno quer entender melhor o conceito de "${term.term}" da cartilha de ${term.cartilha}. '
                          'Explique de forma simples e com exemplos práticos do Tocantins.',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
