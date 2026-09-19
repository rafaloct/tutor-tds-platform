// ============================================================
// GOOGLE APPS SCRIPT — TDS Analytics + Certificados
// Conta: tdsdados@gmail.com
//
// COMO INSTALAR:
//   1. Abra sua planilha em sheets.google.com
//   2. Extensões > Apps Script
//   3. Apague o conteúdo e cole TODO este código
//   4. Salve (Ctrl+S), nomeie o projeto como "TDS Analytics"
//   5. Clique em "Implantar" > "Nova implantação"
//   6. Tipo: "App da Web"
//   7. Executar como: "Eu (tdsdados@gmail.com)"
//   8. Quem tem acesso: "Qualquer pessoa"
//   9. Clique "Implantar" e copie a URL gerada
//  10. Cole a URL em:
//      cartilhas_app/lib/services/data_sync_service.dart
//      no campo _webhookUrl
// ============================================================

var ADMIN_EMAIL        = 'tdsdados@gmail.com';
var SHEET_EVENTOS      = 'Eventos';
var SHEET_ALUNOS       = 'Alunos';
var SHEET_POR_CARTILHA = 'Por Cartilha';

// ── Recebe dados do app Flutter ──────────────────────────────
function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    _logEvento(data);
    _atualizarAluno(data);
    _atualizarPorCartilha(data);
    if (data.eventType === 'COMPLETED') {
      _enviarCertificado(data);
    }
    return ContentService
      .createTextOutput('OK')
      .setMimeType(ContentService.MimeType.TEXT);
  } catch (err) {
    return ContentService
      .createTextOutput('ERRO: ' + err.message)
      .setMimeType(ContentService.MimeType.TEXT);
  }
}

// ── Grava cada evento na aba Eventos ─────────────────────────
function _logEvento(data) {
  var sheet = _getOuCriarAba(SHEET_EVENTOS,
    ['Data/Hora', 'Nome', 'WhatsApp', 'CPF', 'Evento', 'Detalhe']);
  sheet.appendRow([
    new Date(),
    data.name      || '',
    data.phone     || '',
    data.cpf       || '',
    data.eventType || '',
    data.detail    || ''
  ]);
}

// ── Um registro por aluno, com contadores ────────────────────
function _atualizarAluno(data) {
  if (!data.cpf || data.cpf === 'N/A') return;

  var sheet = _getOuCriarAba(SHEET_ALUNOS,
    ['CPF', 'Nome', 'WhatsApp', 'Primeiro Acesso',
     'Último Acesso', 'Trilhas Iniciadas', 'Trilhas Concluídas']);

  var dados    = sheet.getDataRange().getValues();
  var linhaIdx = -1;
  var agora    = new Date();

  for (var i = 1; i < dados.length; i++) {
    if (dados[i][0] === data.cpf) { linhaIdx = i + 1; break; }
  }

  if (linhaIdx === -1) {
    sheet.appendRow([
      data.cpf,
      data.name  || '',
      data.phone || '',
      agora,
      agora,
      data.eventType === 'STARTED'   ? 1 : 0,
      data.eventType === 'COMPLETED' ? 1 : 0
    ]);
  } else {
    sheet.getRange(linhaIdx, 5).setValue(agora);
    if (data.eventType === 'STARTED') {
      var ini = sheet.getRange(linhaIdx, 6).getValue() || 0;
      sheet.getRange(linhaIdx, 6).setValue(ini + 1);
    }
    if (data.eventType === 'COMPLETED') {
      var con = sheet.getRange(linhaIdx, 7).getValue() || 0;
      sheet.getRange(linhaIdx, 7).setValue(con + 1);
    }
  }
}

// ── Insights por cartilha ────────────────────────────────────
function _atualizarPorCartilha(data) {
  if (!data.detail || data.eventType === 'REGISTERED') return;

  var sheet = _getOuCriarAba(SHEET_POR_CARTILHA,
    ['Cartilha', 'Iniciadas', 'Concluídas', 'Taxa de Conclusão (%)',
     'Últimos 7 dias (Iniciadas)', 'Últimos 7 dias (Concluídas)']);

  var cartilha  = data.detail.replace('Cartilha: ', '');
  var dados     = sheet.getDataRange().getValues();
  var linhaIdx  = -1;
  var agora     = new Date();
  var set7dias  = new Date(agora.getTime() - 7 * 24 * 60 * 60 * 1000);

  for (var i = 1; i < dados.length; i++) {
    if (dados[i][0] === cartilha) { linhaIdx = i + 1; break; }
  }

  if (linhaIdx === -1) {
    sheet.appendRow([
      cartilha,
      data.eventType === 'STARTED'   ? 1 : 0,
      data.eventType === 'COMPLETED' ? 1 : 0,
      0,
      data.eventType === 'STARTED'   ? 1 : 0,
      data.eventType === 'COMPLETED' ? 1 : 0,
    ]);
    linhaIdx = sheet.getLastRow();
  } else {
    var col = data.eventType === 'STARTED' ? 2 : 3;
    var col7 = data.eventType === 'STARTED' ? 5 : 6;
    var atual = sheet.getRange(linhaIdx, col).getValue() || 0;
    sheet.getRange(linhaIdx, col).setValue(atual + 1);
    var atual7 = sheet.getRange(linhaIdx, col7).getValue() || 0;
    sheet.getRange(linhaIdx, col7).setValue(atual7 + 1);
  }

  // Recalcula taxa de conclusão
  var ini = sheet.getRange(linhaIdx, 2).getValue() || 0;
  var con = sheet.getRange(linhaIdx, 3).getValue() || 0;
  var taxa = ini > 0 ? Math.round((con / ini) * 100) : 0;
  sheet.getRange(linhaIdx, 4).setValue(taxa);

  // Formata taxa com barra de cor condicional
  var rangeFormato = sheet.getRange(linhaIdx, 4);
  if (taxa >= 70) rangeFormato.setBackground('#C8E6C9');      // verde claro
  else if (taxa >= 40) rangeFormato.setBackground('#FFF9C4'); // amarelo
  else rangeFormato.setBackground('#FFCDD2');                  // vermelho claro
}

// ── Envia e-mail de certificado ──────────────────────────────
function _enviarCertificado(data) {
  var destino = data.adminEmail || ADMIN_EMAIL;
  var numero  = 'TDS-'
    + Utilities.formatDate(new Date(), 'America/Sao_Paulo', 'yyyyMMdd')
    + '-' + Math.floor(Math.random() * 9000 + 1000);
  var dataFmt = Utilities.formatDate(new Date(), 'America/Sao_Paulo', 'dd/MM/yyyy HH:mm');

  var assunto = '🎓 Certificado TDS — '
    + (data.name || 'Aluno') + ' concluiu: ' + (data.detail || 'Trilha');

  var html =
    '<!DOCTYPE html><html><head><meta charset="UTF-8">' +
    '<style>' +
    'body{font-family:Arial,sans-serif;background:#f5f5f5;margin:0;padding:20px}' +
    '.card{background:white;border-radius:12px;max-width:560px;margin:0 auto;' +
    '      box-shadow:0 2px 8px rgba(0,0,0,.12);overflow:hidden}' +
    '.hdr{background:#2E7D32;color:white;padding:28px 32px;text-align:center}' +
    '.hdr h1{margin:0;font-size:22px}' +
    '.hdr p{margin:6px 0 0;opacity:.85;font-size:14px}' +
    '.bdy{padding:28px 32px}' +
    'table{width:100%;border-collapse:collapse;margin:16px 0}' +
    'td{padding:10px 12px;font-size:15px;border-bottom:1px solid #eee}' +
    'td:first-child{color:#666;width:40%}' +
    'td:last-child{font-weight:bold}' +
    '.trilha{background:#E8F5E9;border-radius:8px;padding:12px 16px;' +
    '        font-size:16px;font-weight:bold;color:#2E7D32;text-align:center;margin:16px 0}' +
    '.num{text-align:center;font-size:12px;color:#aaa;margin-top:20px}' +
    '.ftr{background:#f5f5f5;padding:14px 32px;text-align:center;font-size:12px;color:#999}' +
    '</style></head><body>' +
    '<div class="card">' +
    '  <div class="hdr">' +
    '    <h1>Certificado de Conclusão</h1>' +
    '    <p>Programa TDS — Territórios de Desenvolvimento Social</p>' +
    '  </div>' +
    '  <div class="bdy">' +
    '    <p style="color:#555;font-size:15px">O seguinte aluno concluiu uma trilha:</p>' +
    '    <table>' +
    '      <tr><td>Nome</td><td>'     + (data.name  || '—') + '</td></tr>' +
    '      <tr><td>WhatsApp</td><td>' + (data.phone || '—') + '</td></tr>' +
    '      <tr><td>CPF</td><td>'      + (data.cpf   || '—') + '</td></tr>' +
    '      <tr><td>Data</td><td>'     + dataFmt             + '</td></tr>' +
    '    </table>' +
    '    <div class="trilha">📚 ' + (data.detail || 'Trilha concluída') + '</div>' +
    '    <div class="num">Nº ' + numero + '</div>' +
    '  </div>' +
    '  <div class="ftr">IPEX · UFT · Programa TDS 2026 · Tocantins</div>' +
    '</div>' +
    '</body></html>';

  GmailApp.sendEmail(destino, assunto, '', { htmlBody: html, name: 'TDS Analytics' });
}

// ── Cria aba com cabeçalho se não existir ─────────────────────
function _getOuCriarAba(nome, cabecalho) {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(nome);
  if (!sheet) {
    sheet = ss.insertSheet(nome);
    sheet.appendRow(cabecalho);
    var hdr = sheet.getRange(1, 1, 1, cabecalho.length);
    hdr.setFontWeight('bold')
       .setBackground('#2E7D32')
       .setFontColor('white')
       .setHorizontalAlignment('center');
    sheet.setFrozenRows(1);
  }
  return sheet;
}

// ── Teste manual: rode no editor do Apps Script para validar ──
function testarCertificado() {
  _enviarCertificado({
    name:       'João da Silva',
    phone:      '(63) 99999-1234',
    cpf:        '123.456.789-00',
    detail:     'Educação Financeira',
    adminEmail: ADMIN_EMAIL
  });
  Logger.log('E-mail de teste enviado para ' + ADMIN_EMAIL);
}

// ── Inicialização manual: rode UMA VEZ no editor do Apps Script ─
// Cria as abas com a estrutura correta sem precisar esperar o app enviar dados.
function inicializar() {
  _getOuCriarAba(SHEET_EVENTOS,
    ['Data/Hora', 'Nome', 'WhatsApp', 'CPF', 'Evento', 'Detalhe']);
  _getOuCriarAba(SHEET_ALUNOS,
    ['CPF', 'Nome', 'WhatsApp', 'Primeiro Acesso',
     'Último Acesso', 'Trilhas Iniciadas', 'Trilhas Concluídas']);
  _getOuCriarAba(SHEET_POR_CARTILHA,
    ['Cartilha', 'Iniciadas', 'Concluídas', 'Taxa de Conclusão (%)',
     'Últimos 7 dias (Iniciadas)', 'Últimos 7 dias (Concluídas)']);

  // Pré-popula as cartilhas conhecidas
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_POR_CARTILHA);
  var cartilhas = [
    'Agricultura Sustentável', 'Atendimento ao Cliente', 'Audiovisual',
    'Cooperativismo e Crédito', 'Economia do Lar', 'Educação Financeira',
    'Inteligência Artificial', 'SAF', 'SIM e SIMA'
  ];
  cartilhas.forEach(function(nome) {
    sheet.appendRow([nome, 0, 0, 0, 0, 0]);
  });
  Logger.log('Inicialização concluída — 3 abas criadas com estrutura completa.');
}

// ── BÔNUS: Gera aba de matriz de QA (documentação) ───────────
// Cole o código do Gemini aqui embaixo se quiser a aba de testes também.
// As duas funções coexistem sem conflito.
