#!/usr/bin/env python3
"""Gera guias de uso por perfil (DOCX + PDF) para a plataforma Tutor TDS.

Modelo de conteudo: lista de blocos
  ('h1', texto) | ('h2', texto) | ('p', texto) | ('note', texto)
  ('bullets', [itens]) | ('table', {'headers': [...], 'rows': [[...]]})
  ('pagebreak', None)
"""
from __future__ import annotations

import os
import sys

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Pt

from fpdf import FPDF
from fpdf.enums import XPos, YPos

MC = {"new_x": XPos.LMARGIN, "new_y": YPos.NEXT}

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "guias")
OUT_DIR = os.path.normpath(OUT_DIR)

FONT_DIR = r"C:\Windows\Fonts"

CREDENTIAL_HELP = (
    "Para alterar CPF, senha, nome ou papel de qualquer conta, o operador executa "
    "no VPS: /root/tutor-tds-platform-1/tooling/ops/manage_credentials.sh "
    "set-password --cpf <CPF_ATUAL> --new-password '<NOVA_SENHA>' "
    "[--new-cpf <NOVO_CPF>] [--name '<NOVO_NOME>'] [--role <PAPEL>]. "
    "Para trocar o responsavel de uma cartilha: manage_credentials.sh "
    "set-course-owner --course-id <ID_CARTILHA> --cpf <CPF_DO_PROFESSOR>. "
    "As senhas iniciais geradas no provisionamento estao no arquivo restrito ao "
    "root do VPS: /root/tutor-tds-platform-1/tooling/ops/provisioned_accounts_prod.json. "
    "Nunca compartilhe senhas por mensagem; use o comando acima para redefinir."
)

LOGIN_STEPS = [
    "Abra o aplicativo Tutor TDS (Android) ou acesse https://cartilhas.ipexdesenvolvimento.cloud.",
    "Na tela de boas-vindas, toque em \"Entrar\" / \"Ja tenho conta\".",
    "Informe seu CPF (somente numeros) e sua senha.",
    "Ao entrar, o aplicativo abre a tela inicial com os contextos liberados pelo servidor.",
    "Em Configuracoes voce pode escolher o tema Claro, Escuro ou Sistema. Novas instalacoes abrem sempre em Claro.",
]

# ---------------------------------------------------------------- contas ----

ACCOUNT_TABLE_HEADERS = ["Caso de uso / Papel", "Nome da conta", "CPF", "Escopo"]
ACCOUNT_TABLE_ROWS = [
    ["Aluno titular (QA fisico)", "rafael luciono", "(CPF real - sob custodia do titular)", "11 turmas/cartilhas, estudo, check-in, certificado"],
    ["Aluno demonstracao", "Aluno TDS Demonstracao", "32020200139", "11 turmas/cartilhas, estudo, check-in, certificado"],
    ["Monitor / Tutor", "Monitor TDS Geral (Tutoria)", "32020200210", "Monitor das 11 turmas, excecoes de frequencia, apoio ao aluno"],
    ["Coordenador de programa", "Coordenador Geral TDS (Revisao/Gestao)", "32020200309", "Revisao de certificados, gestao de turmas e indicadores do programa"],
    ["Editor de conteudo", "Editor de Conteudo TDS (PEQUI-UFT)", "32020200481", "Editor de cursos: edita e publica versoes das cartilhas"],
    ["Operador de programa", "Operador de Programa TDS (Matriculas)", "32020200562", "Matriculas, turmas e reconciliacao contextual"],
    ["Financeiro / Comercial", "Gestor Financeiro TDS", "32020200643", "Consulta a receitas e repasses (ledger)"],
    ["Administrador global", "Administrador Institucional TDS", "32020200724", "Acesso total a todas as areas e revisao global"],
    ["Administrador QA (existente)", "QA Release Reviewer 14013", "(ja existente)", "Revisao de certificados e gates de release"],
]

TEACHER_TABLE_HEADERS = ["#", "Cartilha", "Conta do responsavel", "CPF", "Turma 2026"]
TEACHER_TABLE_ROWS = [
    ["1", "Agricultura Sustentavel", "Prof. Resp. Agricultura Sustentavel", "31010100122", "Turma 2026 Agricultura Sustentavel"],
    ["2", "Aspectos Juridicos para Startups (PEQUI-UFT/Finep)", "Prof. Resp. Aspectos Juridicos (PEQUI-UFT/Finep)", "31010100203", "Turma 2026 Aspectos Juridicos para Startups (PEQUI-UFT)"],
    ["3", "Atendimento ao Cliente", "Prof. Resp. Atendimento ao Cliente", "31010100394", "Turma 2026 Atendimento ao Cliente"],
    ["4", "Audiovisual para o Dia a Dia", "Prof. Resp. Audiovisual para o Dia a Dia", "31010100475", "Turma 2026 Audiovisual para o Dia a Dia"],
    ["5", "Cooperativismo e Credito", "Prof. Resp. Cooperativismo e Credito", "31010100556", "Turma 2026 Cooperativismo e Credito"],
    ["6", "Economia do Lar", "Prof. Resp. Economia do Lar", "31010100637", "Turma 2026 Economia do Lar"],
    ["7", "Educacao Financeira", "Prof. Resp. Educacao Financeira", "31010100718", "Turma 2026 Educacao Financeira"],
    ["8", "Inteligencia Artificial e Inclusao Digital", "Prof. Resp. Inteligencia Artificial e Inclusao Digital", "31010100807", "Turma 2026 Inteligencia Artificial e Inclusao Digital"],
    ["9", "Agricultura Familiar e Politicas Publicas", "Prof. Resp. Agricultura Familiar e Politicas Publicas", "31010100980", "Turma 2026 Agricultura Familiar e Politicas Publicas"],
    ["10", "Sistemas Agroflorestais (SAF)", "Prof. Resp. Sistemas Agroflorestais (SAF)", "31010101013", "Turma 2026 Sistemas Agroflorestais (SAF)"],
    ["11", "Inspecao e Certificacao (SIM/SIMA)", "Prof. Resp. Inspecao e Certificacao (SIM/SIMA)", "31010101102", "Turma 2026 Inspecao e Certificacao (SIM/SIMA)"],
]

# ---------------------------------------------------------------- guias -----

GUIDES = []

GUIDES.append({
    "filename": "00-contas-e-credenciais",
    "title": "Contas provisionadas e gestao de credenciais",
    "subtitle": "Tutor TDS - matriz de contas por caso de uso e caminho oficial de alteracao",
    "blocks": [
        ("h1", "1. Matriz de contas por caso de uso"),
        ("p", "Todas as contas abaixo foram provisionadas na API de producao "
              "(ead.ipexdesenvolvimento.cloud/tutor-api) e no ambiente de staging. "
              "Senhas iniciais ficam somente no arquivo restrito ao root do VPS "
              "/root/tutor-tds-platform-1/tooling/ops/provisioned_accounts_prod.json."),
        ("table", {"headers": ACCOUNT_TABLE_HEADERS, "rows": ACCOUNT_TABLE_ROWS}),
        ("h1", "2. Um responsavel por cartilha"),
        ("p", "Cada uma das 11 cartilhas possui um professor responsavel dedicado, "
              "vinculado a sua turma 2026 (status ativo, versao publicada fixada, "
              "7200 segundos planejados), com papel 'teacher' no usuario, no programa "
              "e na turma (cohort)."),
        ("table", {"headers": TEACHER_TABLE_HEADERS, "rows": TEACHER_TABLE_ROWS}),
        ("h1", "3. Caminho oficial para alterar credenciais"),
        ("p", CREDENTIAL_HELP),
        ("h2", "3.1 Alterar senha (e opcionalmente CPF/nome/papel)"),
        ("p", "ssh no VPS, depois:\n"
              "/root/tutor-tds-platform-1/tooling/ops/manage_credentials.sh set-password \\\n"
              "  --cpf 32020200139 --new-password 'NovaSenhaForte2026!'\n"
              "Parametros opcionais: --new-cpf <NOVO_CPF> --name '<NOVO_NOME>' "
              "--role <student|monitor|teacher|coordinator|creator|program_operator|finance|admin>"),
        ("h2", "3.2 Trocar o responsavel de uma cartilha"),
        ("p", "/root/tutor-tds-platform-1/tooling/ops/manage_credentials.sh set-course-owner \\\n"
              "  --course-id aspectos-juridicos-startups --cpf 31010100203"),
        ("h2", "3.3 Reprovisionar tudo (idempotente)"),
        ("p", "Para recriar/atualizar todas as contas, turmas, ofertas e vinculos "
              "canonicos: /root/tutor-tds-platform-1/tooling/ops/manage_credentials.sh "
              "provision-all  (use TUTOR_API_CONTAINER=tutor-tds-staging-api-staging-1 "
              "para aplicar no staging)."),
        ("h1", "4. Boas praticas de seguranca"),
        ("bullets", [
            "Troque as senhas iniciais no primeiro acesso operacional.",
            "Senhas precisam ter ao menos 12 caracteres (a ferramenta valida).",
            "Nao envie CPF e senha juntos por canais abertos; o CPF e o login.",
            "O arquivo provisioned_accounts_prod.json deve permanecer com permissao 600 do root.",
        ]),
        ("h1", "5. Referencias"),
        ("bullets", [
            "API Tutor TDS: ead.ipexdesenvolvimento.cloud/tutor-api",
            "App web: cartilhas.ipexdesenvolvimento.cloud",
            "Ferramenta: /root/tutor-tds-platform-1/tooling/ops/manage_credentials.py (app.auth, app.context_memberships)",
            "Relatorio gerado: /root/tutor-tds-platform-1/tooling/ops/provisioned_accounts_prod.json e provisioned_accounts_staging.json",
        ]),
    ],
})

GUIDES.append({
    "filename": "01-guia-aluno",
    "title": "Guia do Aluno",
    "subtitle": "Tutor TDS - estudar, registrar presenca e pedir certificado",
    "blocks": [
        ("h1", "1. O que voce pode fazer"),
        ("bullets", [
            "Acessar as cartilhas das turmas em que esta matriculado (11 cartilhas no programa).",
            "Responder perguntas interativas e acompanhar seu progresso de estudo.",
            "Fazer check-in/check-out nas sessoes de frequencia (inclusive offline).",
            "Solicitar o certificado ao atingir a carga horaria da turma (2h por cartilha).",
            "Acompanhar o status do pedido (pendente, aprovado) na carteira de certificados.",
        ]),
        ("h1", "2. Primeiro acesso"),
        ("bullets", LOGIN_STEPS),
        ("h1", "3. Estudar uma cartilha"),
        ("bullets", [
            "Na tela inicial, toque em \"Minhas turmas\".",
            "Escolha a turma (ex.: Turma 2026 Aspectos Juridicos para Startups).",
            "Abra a edicao da turma para ver as secoes; leia as mensagens e responda as perguntas.",
            "O tempo de estudo e contabilizado automaticamente; a meta de cada cartilha e 2 horas.",
        ]),
        ("h1", "4. Frequencia (check-in/check-out)"),
        ("bullets", [
            "No dia da sessao, o professor/monitor informa um codigo (token) de check-in.",
            "Em \"Presenca\", digite o codigo para registrar entrada e depois saida.",
            "Sem internet: o app guarda o registro e envia quando a conexao voltar (fila offline).",
        ]),
        ("h1", "5. Pedir o certificado"),
        ("bullets", [
            "Ao concluir a carga horaria, acesse a turma e toque em \"Certificado\" / \"Solicitar\".",
            "O pedido entra na fila de revisao humana; a aprovacao NAO emite automaticamente.",
            "A emissao final depende da liberacao institucional; acompanhe o status na Carteira.",
        ]),
        ("h1", "6. Credenciais e seguranca"),
        ("p", CREDENTIAL_HELP),
        ("h1", "7. Referencias"),
        ("bullets", [
            "App: Tutor TDS (com.tutortds_cartilhas) - telas Minhas turmas, Presenca, Certificados, Configuracoes.",
            "Portal web: cartilhas.ipexdesenvolvimento.cloud",
        ]),
    ],
})

GUIDES.append({
    "filename": "02-guia-monitor",
    "title": "Guia do Monitor / Tutor",
    "subtitle": "Tutor TDS - apoio as turmas e excecoes de frequencia",
    "blocks": [
        ("h1", "1. O que voce pode fazer"),
        ("bullets", [
            "Acompanhar as 11 turmas como monitor vinculado (CohortMembership + ClassMonitor).",
            "Tratar excecoes de frequencia dos alunos (tela de excecoes do monitor).",
            "Apoiar alunos no fluxo de estudo, presenca e pedido de certificado.",
        ]),
        ("h1", "2. Primeiro acesso"),
        ("bullets", LOGIN_STEPS),
        ("h1", "3. Rotina diaria"),
        ("bullets", [
            "Abra a area de Gestao; as ferramentas aparecem conforme o servidor confirma seu acesso.",
            "Em \"Equipe/Frequencia\", revise as excecoes pendentes de presenca das suas turmas.",
            "Auxilie o professor responsavel na sessao: divulgue o codigo de check-in aos alunos.",
        ]),
        ("h1", "4. Credenciais e seguranca"),
        ("p", CREDENTIAL_HELP),
        ("h1", "5. Referencias"),
        ("bullets", [
            "Telas: Gestao, Excecoes do monitor, Acompanhamento do aluno.",
            "Conta provisionada: Monitor TDS Geral (Tutoria) - ver documento 00-contas-e-credenciais.",
        ]),
    ],
})

GUIDES.append({
    "filename": "03-guia-professor-responsavel",
    "title": "Guia do Professor Responsavel",
    "subtitle": "Tutor TDS - um responsavel por cartilha (11 cartilhas)",
    "blocks": [
        ("h1", "1. O que voce pode fazer"),
        ("bullets", [
            "Ser o professor responsavel (teacher) da sua cartilha e da Turma 2026 correspondente.",
            "Abrir sessoes de frequencia e gerar o codigo de check-in para os alunos.",
            "Revisar pedidos de certificado da sua turma na fila de revisao.",
            "Acompanhar alunos, presenca e progresso no painel da turma.",
        ]),
        ("h1", "2. Mapa responsavel x cartilha"),
        ("table", {"headers": TEACHER_TABLE_HEADERS, "rows": TEACHER_TABLE_ROWS}),
        ("h1", "3. Primeiro acesso"),
        ("bullets", LOGIN_STEPS),
        ("h1", "4. Conduzir uma sessao de frequencia"),
        ("bullets", [
            "Entre na sua turma (Minhas turmas / Gestao) e abra uma sessao de presenca.",
            "Compartilhe o codigo gerado com os alunos; eles fazem check-in e check-out.",
            "Ao final, confira os registros; o monitor trata excecoes e faltas justificadas.",
        ]),
        ("h1", "5. Revisar certificados"),
        ("bullets", [
            "Os pedidos dos alunos aparecem na fila de revisao da sua turma.",
            "Aprove somente quando a carga horaria (7200s) e as evidencias estiverem corretas.",
            "Aprovacao humana nao emite o certificado sozinha; a emissao final e institucional.",
        ]),
        ("h1", "6. Credenciais e seguranca"),
        ("p", CREDENTIAL_HELP),
        ("h1", "7. Referencias"),
        ("bullets", [
            "Telas: Painel da turma, Presenca/Equipe, Fila de revisao de certificados.",
            "Contas: ver documento 00-contas-e-credenciais (secao 2).",
        ]),
    ],
})

GUIDES.append({
    "filename": "04-guia-coordenador",
    "title": "Guia do Coordenador de Programa",
    "subtitle": "Tutor TDS - revisao, gestao de turmas e indicadores",
    "blocks": [
        ("h1", "1. O que voce pode fazer"),
        ("bullets", [
            "Visao de todas as 11 turmas do programa (role coordinator).",
            "Revisar pedidos de certificado de qualquer cartilha.",
            "Gerenciar turmas, responsaveis e acompanhar indicadores do programa.",
        ]),
        ("h1", "2. Primeiro acesso"),
        ("bullets", LOGIN_STEPS),
        ("h1", "3. Rotina de coordenacao"),
        ("bullets", [
            "Em Gestao, valide que cada turma esta ativa e com professor responsavel vinculado.",
            "Revise a fila de certificados; confirme carga horaria e evidencias antes de aprovar.",
            "Acompanhe frequencia e excecoes junto ao Monitor TDS Geral.",
            "Para trocar o responsavel de uma cartilha, peca ao operador o comando set-course-owner (secao 4).",
        ]),
        ("h1", "4. Credenciais e seguranca"),
        ("p", CREDENTIAL_HELP),
        ("h1", "5. Referencias"),
        ("bullets", [
            "Telas: Gestao do programa, Participantes, Equipe, Frequencia, Revisao.",
            "Conta provisionada: Coordenador Geral TDS (Revisao/Gestao).",
        ]),
    ],
})

GUIDES.append({
    "filename": "05-guia-editor-conteudo",
    "title": "Guia do Editor de Conteudo",
    "subtitle": "Tutor TDS - editar e publicar versoes das cartilhas",
    "blocks": [
        ("h1", "1. O que voce pode fazer"),
        ("bullets", [
            "Editar a estrutura das cartilhas no Editor de Cursos (secoes, mensagens, perguntas, materiais).",
            "Publicar novas versoes; turmas ficam fixadas na versao publicada vigente.",
            "Manter referencias e atribuicoes do conteudo (ex.: PEQUI-UFT / INOVATO / Finep).",
        ]),
        ("h1", "2. Primeiro acesso"),
        ("bullets", LOGIN_STEPS),
        ("h1", "3. Editar uma cartilha"),
        ("bullets", [
            "Abra Gestao > Conteudo (Editor de cursos).",
            "Escolha a cartilha; edite secoes, mensagens e perguntas interativas.",
            "Salve e publique: a nova versao passa a ser a referencia das turmas.",
            "Conteudo juridico: mantenha as citacoes legais e o aviso de material educacional.",
        ]),
        ("h1", "4. Credenciais e seguranca"),
        ("p", CREDENTIAL_HELP),
        ("h1", "5. Referencias"),
        ("bullets", [
            "Telas: Editor de cursos, Estrutura, Dialogos de mensagem e material.",
            "Conta provisionada: Editor de Conteudo TDS (PEQUI-UFT).",
        ]),
    ],
})

GUIDES.append({
    "filename": "06-guia-operador-programa",
    "title": "Guia do Operador de Programa",
    "subtitle": "Tutor TDS - matriculas, turmas e reconciliacao contextual",
    "blocks": [
        ("h1", "1. O que voce pode fazer"),
        ("bullets", [
            "Operar matriculas (enrollments) e vinculos de turma (class_enrollments).",
            "Manter a reconciliacao contextual canonica (context_id, membership_id, course_version_id).",
            "Executar ferramentas administrativas de provisionamento e credenciais no VPS.",
        ]),
        ("h1", "2. Primeiro acesso"),
        ("bullets", LOGIN_STEPS),
        ("h1", "3. Operacoes comuns"),
        ("bullets", [
            "Matricular aluno: garantir Enrollment ativo + ClassEnrollment vinculado a turma.",
            "Reconciliar vinculos: usar bind_student/bind_membership (app.context_memberships), nunca criar IDs manuais.",
            "Provisionar contas: manage_credentials.sh provision-all (idempotente).",
        ]),
        ("h1", "4. Credenciais e seguranca"),
        ("p", CREDENTIAL_HELP),
        ("h1", "5. Referencias"),
        ("bullets", [
            "Codigo: api/app/context_memberships.py, api/app/certificate_requests.py.",
            "Conta provisionada: Operador de Programa TDS (Matriculas).",
        ]),
    ],
})

GUIDES.append({
    "filename": "07-guia-financeiro",
    "title": "Guia do Financeiro / Comercial",
    "subtitle": "Tutor TDS - consulta a receitas e repasses",
    "blocks": [
        ("h1", "1. O que voce pode fazer"),
        ("bullets", [
            "Consultar o ledger de receitas e repasses do programa.",
            "Acompanhar dados comerciais vinculados as ofertas do programa.",
        ]),
        ("h1", "2. Primeiro acesso"),
        ("bullets", LOGIN_STEPS),
        ("h1", "3. Observacoes de escopo"),
        ("bullets", [
            "O papel financeiro e de leitura/consulta; alteracoes operacionais ficam com o Operador/Coordenador.",
            "Relatorios oficiais sao exportados pela equipe de operacao mediante solicitacao.",
        ]),
        ("h1", "4. Credenciais e seguranca"),
        ("p", CREDENTIAL_HELP),
        ("h1", "5. Referencias"),
        ("bullets", [
            "Conta provisionada: Gestor Financeiro TDS.",
        ]),
    ],
})

GUIDES.append({
    "filename": "08-guia-administrador",
    "title": "Guia do Administrador Global",
    "subtitle": "Tutor TDS - acesso total e revisao global",
    "blocks": [
        ("h1", "1. O que voce pode fazer"),
        ("bullets", [
            "Acesso a todas as areas do programa (role admin).",
            "Revisao global de certificados, gestao de contas, turmas e vinculos.",
            "Operar as ferramentas do VPS (provisionamento, credenciais, release).",
        ]),
        ("h1", "2. Primeiro acesso"),
        ("bullets", LOGIN_STEPS),
        ("h1", "3. Responsabilidades"),
        ("bullets", [
            "Zelar pela seguranca das contas: trocar senhas iniciais e aplicar menor privilegio.",
            "Manter o arquivo provisioned_accounts_prod.json restrito ao root.",
            "Seguir o contrato operacional do AGENTS.md para mudancas permanentes.",
        ]),
        ("h1", "4. Credenciais e seguranca"),
        ("p", CREDENTIAL_HELP),
        ("h1", "5. Referencias"),
        ("bullets", [
            "Contas provisionadas: Administrador Institucional TDS; QA Release Reviewer 14013.",
            "Ferramentas: manage_credentials.sh, unlock_release_status.py, verify_release_readiness.dart.",
        ]),
    ],
})

GUIDES.append({
    "filename": "09-guia-cartilha-aspectos-juridicos",
    "title": "Cartilha - Aspectos Juridicos para Startups",
    "subtitle": "O que proteger desde o primeiro teste - PEQUI-UFT / INOVATO / Finep",
    "blocks": [
        ("note", "Material educacional. Este guia NAO substitui aconselhamento juridico "
                 "individualizado; consulte um advogado para decisoes concretas."),
        ("h1", "1. Realizacao e caso condutor"),
        ("p", "Realizacao: PEQUI-UFT (Parque de Empreendedorismo, Qualidade Socioambiental "
              "e Inovacao Tecnologica da UFT), INOVATO (Agencia de Inovacao da UFT) e "
              "Finep (Inovacao e Pesquisa)."),
        ("p", "Caso \"Nosso Time\": tres fundadores criam uma plataforma de agendamento. Um "
              "freelancer fez o MVP, ha uma lista de interessados e uma empresa aceitou "
              "testar. A startup ainda nao vendeu, mas ja tem marca escolhida, produto em "
              "desenvolvimento, lista de interessados e uma promessa a um parceiro. "
              "Pergunta central: o que ela ja tem a perder?"),
        ("h1", "2. Ativos intangiveis e por que proteger desde o primeiro teste"),
        ("p", "92% do valor de mercado das empresas do S&P 500 esta em ativos intangiveis "
              "(marca, software, dados, know-how, contratos); em 1975 eram 17% "
              "(Ocean Tomo, Intangible Asset Market Value Study, 2025)."),
        ("bullets", [
            "Evitar disputas: titularidade definida evita retrabalho e brigas.",
            "Licenciar e negociar: direitos claros dao seguranca para licenciar e ceder.",
            "Preservar o diferencial: o que o time criou continua do time.",
            "Mostrar ao investidor: due diligence verifica quais ativos pertencem ao negocio.",
        ]),
        ("p", "No Brasil o direito a marca nasce do registro (sistema atributivo): em regra, "
              "leva quem deposita primeiro (Lei 9.279/1996 - LPI, art. 129)."),
        ("h1", "3. Inventario de ativos, PI e registro de marca"),
        ("table", {"headers": ["Ativo", "O que protege", "Onde / como", "Prazo"], "rows": [
            ["Marca", "Nome, logo e slogan", "INPI, por classe (NCL)", "10 anos, renovaveis"],
            ["Software", "O codigo, nao a ideia", "Direito autoral (INPI opcional, Lei 9.609/1998)", "50 anos"],
            ["Patente de invencao", "Solucao tecnica nova", "INPI, antes de divulgar", "20 anos"],
            ["Modelo de utilidade", "Melhoria funcional em objeto", "INPI", "15 anos"],
            ["Desenho industrial", "Forma plastica ornamental", "INPI", "Ate 25 anos"],
            ["Segredo de negocio", "Algoritmo, base, know-how", "Contrato + acesso restrito", "Enquanto sigiloso"],
            ["Dominio", "Endereco na internet", "Registro.br", "Enquanto renovado"],
        ]}),
        ("p", "Regra de ouro: ideia abstrata, sozinha, nao recebe protecao, e o programa de "
              "computador \"em si\" nao e patenteavel (LPI, art. 10, V e VIII)."),
        ("p", "Marca no INPI: (1) busca de sinais semelhantes; (2) escolha das classes - "
              "R$ 440 por classe com desconto de 50% para ME/EPP/MEI/Inova Simples/ICT/pessoa "
              "fisica em especificacao pre-aprovada (integral R$ 880 - Portaria INPI/PR "
              "10/2025); (3) pedido e acompanhamento - depositar nao garante concessao "
              "(exame formal, publicacao para oposicao, exame de merito)."),
        ("p", "Casos reais: Meta x Meta - empresa brasileira de TI registrou \"Meta\" em 2008; "
              "quando o Facebook virou Meta (2021), o TJ-SP ordenou em fev/2024 que a big tech "
              "parasse de usar a marca em 30 dias (ordem suspensa em mar/2024; disputa segue). "
              "Licao: o registro antigo poe a pequena empresa a mesa com uma gigante. "
              "Gradiente x Apple - a Gradiente pediu \"G Gradiente iphone\" em 2000 e obteve o "
              "registro em 2008; o STJ manteve em 2018 a marca mista sem exclusividade sobre "
              "\"iPhone\" isolado e o caso segue no STF (RE 1.338.807). Licao: deposite cedo, "
              "prefira sinais distintivos e use a marca."),
        ("h1", "4. Titularidade do codigo, patente x segredo e NDA"),
        ("bullets", [
            "Fundadores (pre-CNPJ): o que nasceu antes da sociedade precisa ir formalmente para a empresa (cessao ou integralizacao).",
            "Empregado (CLT): a Lei do Software (Lei 9.609/1998, art. 4o) atribui a empresa o que nasce da funcao contratada - escreva isso de forma expressa.",
            "Freelancer ou PJ: defina titularidade, cessao patrimonial (ou licenca), entregaveis (codigo-fonte, documentacao, credenciais) e componentes preexistentes.",
            "Universidade (NIT/ICT): se usou laboratorio, bolsa ou infraestrutura, verifique a politica de inovacao da ICT (Lei 10.973/2004 e Lei 13.243/2016) e os instrumentos do NIT (na UFT, a INOVATO). Revise licencas open source (GPL, MIT, Apache), imagens e fontes.",
        ]),
        ("p", "Patente ou segredo de negocio? A decisao precede a divulgacao. Patente exige "
              "novidade, atividade inventiva e aplicacao industrial; o Brasil concede periodo "
              "de graca de 12 meses (LPI, art. 12), que nao vale em todos os paises - um pitch "
              "publico pode destruir a novidade. Segredo de negocio dura enquanto houver "
              "sigilo efetivo (NDA, acesso por necessidade, registro de quem viu) e nao impede "
              "criacao independente legitima (LPI, art. 195, XI)."),
        ("p", "NDA - 7 pontos essenciais: (1) informacoes protegidas e excecoes legitimas; "
              "(2) finalidade de uso definida; (3) quem pode acessar (need-to-know); "
              "(4) prazo - o sigilo pode sobreviver ao contrato; (5) devolucao ou descarte; "
              "(6) registro e limitacao de acessos; (7) consequencias proporcionais e "
              "foro/resolucao de conflitos. Atencao: NDA nao transfere PI, nao substitui a "
              "LGPD e nao e proibicao generica de concorrencia."),
        ("h1", "5. LGPD na pratica, regime de pequeno porte e seguranca"),
        ("p", "LGPD desde o primeiro formulario (Lei 13.709/2018, arts. 3o, 5o a 11 e 15 a 18). "
              "No caso \"Nosso Time\", o formulario pedia CPF, data de nascimento e endereco, "
              "mas o teste so precisava de um contato: retirar campos sem justificativa "
              "(minimizacao), explicar a finalidade, definir base legal e prazo de retencao "
              "e garantir o exercicio dos direitos do titular."),
        ("p", "Pequeno porte (Resolucao CD/ANPD 2/2022, arts. 6o, 9o, 11, 13 e 14): dispensa "
              "de encarregado formal (mantido canal de atendimento), registro simplificado, "
              "prazos em dobro (inclusive comunicacao de incidentes) e politica de seguranca "
              "simplificada. Atencao: se houver tratamento de alto risco (1 criterio geral, "
              "ex. larga escala, + 1 especifico, ex. tecnologia emergente/IA, dados sensiveis "
              "ou vigilancia), a startup perde as dispensas (art. 4o). Continuam valendo "
              "para qualquer porte: base legal, direitos dos titulares, seguranca e "
              "transparencia com fornecedores."),
        ("p", "Privacidade na operacao (LGPD, arts. 5o, 37, 39, 46 e 48; Resolucao CD/ANPD "
              "15/2024; Guia ANPD para pequeno porte): acessos individuais com MFA e revogacao "
              "no desligamento; inventario e base legal; backups testados e sistemas "
              "atualizados; plano de incidente - comunicacao a ANPD e titulares em 3 dias "
              "uteis (6 dias uteis para pequeno porte, Res. CD/ANPD 15/2024); um responsavel "
              "e um canal ao titular; fornecedores (nuvem, CRM, pagamentos) com papeis de "
              "controlador/operador em contrato."),
        ("h1", "6. Compliance, acordo de socios, contrato de piloto e Marco Legal"),
        ("p", "Compliance no tamanho da startup (Lei 12.846/2013; Decreto 11.129/2022; Lei "
              "14.133/2021; Diretrizes CGU para Empresas Privadas, 2024): multa de 0,1% a 20% "
              "do faturamento bruto com responsabilidade objetiva; programa de integridade "
              "efetivo anterior ao fato pode reduzir ate 5% na dosimetria. Quatro perguntas "
              "para comecar: quem aprova despesas e contratos? como tratar conflitos de "
              "interesse? quais condutas o time nao aceita? como relatar e corrigir um "
              "problema?"),
        ("p", "Acordo de socios - 8 pontos essenciais (CC, arts. 1.052 a 1.087; LC 182/2021, "
              "art. 5o): (1) participacao e vesting com cliff; (2) dedicacao e papeis; "
              "(3) good e bad leaver; (4) PI na empresa; (5) nao concorrencia e nao "
              "aliciamento com prazo e escopo razoaveis; (6) tag along e drag along; "
              "(7) decisoes, quoruns, vetos e resolucao de impasse; (8) novos investidores "
              "(diluicao, preferencia, mutuo conversivel)."),
        ("p", "Contrato de piloto/cliente - 10 clausulas criticas (CC, arts. 421, 421-A e "
              "422; Lei 9.609/1998, art. 9o; LGPD, arts. 39 e 46): partes e poderes; escopo e "
              "entregas; criterios de aceite; preco, prazo e mudancas; piloto (duracao, "
              "usuarios, ambiente, metrica de sucesso); PI e limites de uso (preexistente x "
              "melhoria; licenca nao e cessao); sigilo; dados e seguranca; limitacao de "
              "responsabilidade; saida, transicao e foro/arbitragem."),
        ("p", "Marco Legal das Startups (LC 182/2021, arts. 4o, 13 e 14; Portaria INPI/PR "
              "10/2025; Res. CD/ANPD 2/2022): enquadramento ate R$ 16 milhoes de receita "
              "anual, ate 10 anos de CNPJ e modelo inovador declarado ou adesao ao Inova "
              "Simples. Beneficios: 50% de desconto e fila prioritaria no INPI; regime "
              "simplificado na ANPD; CPS (Contrato Publico para Solucao Inovadora) de ate "
              "R$ 1,6 milhao por contrato (art. 13)."),
        ("h1", "7. Checklist final - 10 passos antes de faturar"),
        ("bullets", [
            "1. CNPJ e enquadramento (ME, EPP, Inova Simples).",
            "2. Acordo de socios com vesting, assinado.",
            "3. Cessao da PI de fundadores, devs e freelancers.",
            "4. Mapa de dados, aviso de privacidade e canal do titular.",
            "5. Busca e deposito da marca no INPI.",
            "6. Registro do software no INPI.",
            "7. Patente avaliada antes de qualquer divulgacao.",
            "8. NDA padrao (mutuo) pronto para usar.",
            "9. Codigo de conduta e canal de denuncias.",
            "10. Contrato-padrao de cliente/piloto com as 10 clausulas.",
        ]),
        ("h1", "8. Referencias normativas e fontes"),
        ("bullets", [
            "Lei 9.279/1996 (LPI): arts. 10 (V e VIII), 12, 129, 195 (XI).",
            "Lei 9.609/1998 (Lei do Software): arts. 4o e 9o.",
            "Lei 13.709/2018 (LGPD): arts. 3o, 5o a 11, 15 a 18, 37, 39, 46 e 48.",
            "Resolucao CD/ANPD 2/2022 (pequenos agentes): arts. 4o, 6o, 9o, 11, 13 e 14.",
            "Resolucao CD/ANPD 15/2024 (comunicacao de incidente).",
            "Lei 12.846/2013 (Anticorrupcao); Decreto 11.129/2022; Diretrizes CGU 2024.",
            "Lei 14.133/2021 (Nova Lei de Licitacoes).",
            "Codigo Civil: arts. 421, 421-A, 422 e 1.052 a 1.087.",
            "LC 182/2021 (Marco Legal das Startups): arts. 4o, 5o, 13 e 14; Inova Simples.",
            "Portaria INPI/PR 10/2025 (tas e descontos); Registro.br (dominios).",
            "Lei 10.973/2004 (Inovacao) e Lei 13.243/2016 (Marco Legal de CT&I).",
            "Ocean Tomo, Intangible Asset Market Value Study (resultados 2025).",
            "Casos: Meta x Meta (TJ-SP, 2024); Gradiente x Apple (STJ 2018; STF RE 1.338.807).",
        ]),
    ],
})

# ---------------------------------------------------------------- docx ------

def build_docx(guide: dict, path: str) -> None:
    doc = Document()
    t = doc.add_heading(guide["title"], level=0)
    t.alignment = WD_ALIGN_PARAGRAPH.CENTER
    st = doc.add_paragraph(guide["subtitle"])
    st.alignment = WD_ALIGN_PARAGRAPH.CENTER
    st.runs[0].italic = True if st.runs else False
    doc.add_paragraph("")
    for kind, payload in guide["blocks"]:
        if kind == "h1":
            doc.add_heading(payload, level=1)
        elif kind == "h2":
            doc.add_heading(payload, level=2)
        elif kind == "p":
            doc.add_paragraph(payload)
        elif kind == "note":
            p = doc.add_paragraph()
            run = p.add_run(payload)
            run.italic = True
            run.bold = True
        elif kind == "bullets":
            for item in payload:
                doc.add_paragraph(item, style="List Bullet")
        elif kind == "table":
            tbl = doc.add_table(rows=1 + len(payload["rows"]), cols=len(payload["headers"]))
            tbl.style = "Table Grid"
            for j, h in enumerate(payload["headers"]):
                cell = tbl.rows[0].cells[j]
                cell.text = h
                for r in cell.paragraphs[0].runs:
                    r.bold = True
            for i, row in enumerate(payload["rows"], start=1):
                for j, val in enumerate(row):
                    tbl.rows[i].cells[j].text = str(val)
        elif kind == "pagebreak":
            doc.add_page_break()
    doc.save(path)


# ----------------------------------------------------------------- pdf ------

class GuidePDF(FPDF):
    def footer(self):
        self.set_y(-15)
        self.set_font("arial", "I", 8)
        self.cell(0, 10, f"Tutor TDS - {self.page_no()}", align="C")


def build_pdf(guide: dict, path: str) -> None:
    pdf = GuidePDF()
    pdf.add_font("arial", "", os.path.join(FONT_DIR, "arial.ttf"))
    pdf.add_font("arial", "B", os.path.join(FONT_DIR, "arialbd.ttf"))
    pdf.add_font("arial", "I", os.path.join(FONT_DIR, "ariali.ttf"))
    pdf.add_font("arial", "BI", os.path.join(FONT_DIR, "arialbi.ttf"))
    pdf.set_auto_page_break(auto=True, margin=20)
    pdf.add_page()
    pdf.set_font("arial", "B", 20)
    pdf.multi_cell(0, 10, guide["title"], align="C", **MC)
    pdf.ln(4)
    pdf.set_font("arial", "I", 12)
    pdf.multi_cell(0, 8, guide["subtitle"], align="C", **MC)
    pdf.ln(8)
    for kind, payload in guide["blocks"]:
        if kind == "h1":
            pdf.set_font("arial", "B", 14)
            pdf.ln(4)
            pdf.multi_cell(0, 8, payload, **MC)
            pdf.ln(1)
        elif kind == "h2":
            pdf.set_font("arial", "B", 12)
            pdf.multi_cell(0, 7, payload, **MC)
        elif kind == "p":
            pdf.set_font("arial", "", 10.5)
            pdf.multi_cell(0, 5.5, payload, **MC)
            pdf.ln(2)
        elif kind == "note":
            pdf.set_font("arial", "BI", 10.5)
            pdf.multi_cell(0, 6, "AVISO: " + payload, **MC)
            pdf.ln(3)
        elif kind == "bullets":
            pdf.set_font("arial", "", 10.5)
            for item in payload:
                pdf.multi_cell(0, 5.5, "  - " + item, **MC)
            pdf.ln(2)
        elif kind == "table":
            headers = payload["headers"]
            rows = payload["rows"]
            n = len(headers)
            w = 190.0 / n
            cpl = max(1, int(w / 1.9))
            def cell_lines(val):
                v = str(val)
                return max(1, (len(v) // cpl) + 1)
            pdf.set_font("arial", "B", 9)
            for h in headers:
                pdf.cell(w, 7, str(h)[:30], border=1)
            pdf.ln()
            pdf.set_font("arial", "", 9)
            for row in rows:
                h_row = max(cell_lines(v) for v in row) * 5
                if pdf.get_y() + h_row > pdf.page_break_trigger:
                    pdf.add_page()
                x0, y0 = pdf.get_x(), pdf.get_y()
                for val in row:
                    pdf.multi_cell(w, h_row / cell_lines(val), str(val), border=1,
                                   new_x=XPos.RIGHT, new_y=YPos.TOP)
                pdf.set_xy(x0, y0 + h_row)
            pdf.ln(3)
        elif kind == "pagebreak":
            pdf.add_page()
    pdf.output(path)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for guide in GUIDES:
        docx_path = os.path.join(OUT_DIR, guide["filename"] + ".docx")
        pdf_path = os.path.join(OUT_DIR, guide["filename"] + ".pdf")
        build_docx(guide, docx_path)
        build_pdf(guide, pdf_path)
        print("OK", guide["filename"])
    print("Saida:", OUT_DIR)


if __name__ == "__main__":
    main()
