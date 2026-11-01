#!/usr/bin/env python3
"""Gera a pagina 'amostra' HTML da cartilha no padrao das amostras da loja :8091."""
import html
import json
import re
import sys

TEMPLATE_PATH = r"C:\Users\Usuario\tds-release-14013-build\tmp\amostra-101.html"
JSON_PATH = r"C:\Users\Usuario\tds-release-14013-build\cartilhas_app\assets\data\lessons\aspectos-juridicos-startups.json"
OUT_PATH = r"C:\Users\Usuario\tds-release-14013-build\tmp\amostra-aspectos-juridicos.html"

EAD_URL = "https://ead.ipexdesenvolvimento.cloud/courses/aspectos-juridicos-startups/"
APP_URL = "https://cartilhas.ipexdesenvolvimento.cloud"
PLAY_URL = "https://play.google.com/store/apps/details?id=com.tutortds_cartilhas"

tpl = open(TEMPLATE_PATH, encoding="utf-8").read()
css = re.search(r"<style>(.*?)</style>", tpl, re.S).group(1)
script = re.search(r"(<script>.*?</script>)", tpl, re.S).group(1)

data = json.load(open(JSON_PATH, encoding="utf-8"))
sections = data["sections"]
n_sec = len(sections)
n_q = sum(1 for s in sections for m in s["messages"] if m["type"] == "question")

e = html.escape

def toc_title(t: str) -> str:
    t = re.sub(r"^\d+\.\s*", "", t)
    return t if len(t) <= 52 else t[:49].rstrip() + "..."

parts = []
parts.append("<!-- wp:html -->")
parts.append('<link rel="preconnect" href="https://fonts.googleapis.com">')
parts.append('<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>')
parts.append('<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">')
parts.append(f"<style>{css}</style>")
parts.append('<div id="cartilha">')
parts.append('<a class="skip" href="#conteudo">Pular para o conteúdo da cartilha</a>')
parts.append(
    f'  <header class="topbar"><div class="in">\n'
    f'    <div class="mark" aria-hidden="true">T</div>\n'
    f'    <div class="t">Cartilha — Aspectos Jurídicos para Startups<small>Amostra real · formato do app Tutor TDS</small></div>\n'
    f'    <a class="free" href="{EAD_URL}" target="_blank" rel="noopener">Curso gratuito na EAD ↗</a>\n'
    f'    <div class="pct" id="pct">0%</div>\n'
    f'  </div><div class="progress" role="progressbar" aria-label="Progresso de leitura" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0"><i id="bar"></i></div></header>'
)
parts.append(
    '  <div class="hero"><div class="card">\n'
    '    <span class="tag">Cartilha gratuita · PEQUI-UFT / INOVATO / Finep</span>\n'
    '    <h1>O que proteger na sua startup desde o primeiro teste</h1>\n'
    '    <p>Marca, código, dados, segredos e contratos — conversa simples, pergunta por pergunta, com o mesmo conteúdo que o aluno vê no app Tutor TDS. Material educacional elaborado pelo PEQUI-UFT, INOVATO/UFT e Finep.</p>\n'
    f'    <div class="meta"><span><b>{n_sec}</b> seções</span><span><b>{n_q}</b> perguntas do tutor</span><span>Leitura de <b>~15 min</b></span><span><b>Grátis</b> também no app</span></div>\n'
    '  </div></div>'
)
toc_links = "".join(
    f'      <a href="#{s["id"]}"{" class=\"on\"" if i == 0 else ""}><span class="n">{i+1}</span>{e(toc_title(s["title"]))}</a>\n'
    for i, s in enumerate(sections)
)
parts.append(
    '  <div class="layout">\n'
    '    <nav class="toc" id="toc" aria-label="Sumário da cartilha">\n'
    f'      <div class="cap">Sumário — {n_sec} seções</div>\n'
    f'{toc_links}'
    '      <a href="#apoio"><span class="n">🎓</span>Apoio e canais</a>\n'
    '      <div class="sep">Cartilha completa</div>\n'
    f'      <a href="{EAD_URL}" target="_blank" rel="noopener">Curso gratuito na EAD ↗</a>\n'
    f'      <a href="{PLAY_URL}" target="_blank" rel="noopener">Google Play ↗</a>\n'
    f'      <div class="demo">Esta é a <a href="{APP_URL}" target="_blank" rel="noopener">cartilha real do app</a> — mesmas mensagens e perguntas que o aluno vê no Tutor TDS, aqui em formato web.</div>\n'
    '    </nav>\n'
    '    <main id="conteudo">'
)

for i, s in enumerate(sections):
    parts.append(
        f'      <section class="chapter" id="{s["id"]}" aria-labelledby="h-{s["id"]}">\n'
        f'        <div class="kicker">Seção {i+1} de {n_sec}<span class="lp">Conteúdo real da cartilha</span></div>\n'
        f'        <h2 id="h-{s["id"]}">{e(toc_title(s["title"]))}</h2>\n'
        '        <div class="chat">'
    )
    for j, m in enumerate(s["messages"]):
        if m["type"] == "bot":
            parts.append(
                f'          <div class="msg"><div class="av" aria-hidden="true">TV</div>'
                f'<div class="bub">{e(m["content"])}</div></div>'
            )
        elif m["type"] == "question":
            qid = f'q-{s["id"]}'
            opts = "".join(
                f'            <button type="button" class="opt" data-fb="{e(o["feedback"], quote=True)}">'
                f'<span class="dot" aria-hidden="true"></span>{e(o["label"])}</button>\n'
                for o in m["options"]
            )
            parts.append(
                f'          <div class="qcard" data-q role="group" aria-labelledby="{qid}">\n'
                '            <div class="qh">✏️ Pergunta do Tutor</div>\n'
                f'            <div class="qq" id="{qid}">{e(m["content"])}</div>\n'
                f'{opts}'
                '            <div class="fb" aria-live="polite"><span class="ft">Tutor Vizinho responde</span><span class="fv"></span></div>\n'
                '          </div>'
            )
    parts.append('        </div>\n      </section>')

parts.append(
    '\n      <div class="paywall">\n'
    '        <div class="kicker">Cartilha completa acima — gratuita</div>\n'
    '        <h3>Estude a cartilha completa com presença e certificado</h3>\n'
    '        <div class="subs">\n'
    '          <span class="sub">✦ Turma 2026 com professor responsável</span>\n'
    '          <span class="sub">✦ Check-in de frequência no app</span>\n'
    '          <span class="sub">✦ Certificado após revisão humana</span>\n'
    '        </div>\n'
    f'        <a class="cta" href="{EAD_URL}">Abrir o curso gratuito na EAD</a>\n'
    '        <span class="alt">material educacional — não substitui aconselhamento jurídico individualizado</span>\n'
    '      </div>'
)
parts.append(
    '\n      <section class="support" id="apoio" aria-labelledby="h-apoio">\n'
    '        <div class="si" aria-hidden="true">🎓</div>\n'
    '        <div>\n'
    '          <h3 id="h-apoio">Precisa de ajuda com este conteúdo?</h3>\n'
    '          <p>No app <strong style="color:var(--hi)">Tutor TDS</strong> você já tem o botão <strong style="color:var(--hi)">"Ajuda humana"</strong> — chat e WhatsApp com a equipe TDS — além do Tutor IA para dúvidas rápidas. Pela rede de monitores, conectamos você a <strong style="color:var(--hi)">universitários especializados</strong> nas áreas dos conteúdos, conforme disponibilidade.</p>\n'
    '          <div class="row">\n'
    '            <a class="btn b-line" href="https://wa.me/5563993010823" target="_blank" rel="noopener">Suporte TDS</a>\n'
    f'            <a class="btn b-line" href="{APP_URL}" target="_blank" rel="noopener">Abrir o app Tutor TDS</a>\n'
    '            <a class="btn b-line" href="https://ead.ipexdesenvolvimento.cloud/" target="_blank" rel="noopener">Portal EAD</a>\n'
    '          </div>\n'
    '        </div>\n'
    '      </section>\n'
    '\n      <div class="endnav">\n'
    '        <a href="/"><small>Loja</small>← Voltar</a>\n'
    f'        <a href="{EAD_URL}"><small>Curso gratuito</small>Abrir na EAD →</a>\n'
    '      </div>\n'
    '    </main>\n'
    '  </div>\n'
    '</div>'
)
parts.append(script)
parts.append("<!-- /wp:html -->")

out = "\n".join(parts)
open(OUT_PATH, "w", encoding="utf-8").write(out)
print("gerado:", OUT_PATH, len(out), "bytes |", n_sec, "secoes |", n_q, "perguntas")
