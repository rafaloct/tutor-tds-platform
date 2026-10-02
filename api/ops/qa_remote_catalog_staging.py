"""Exercise one synthetic editorial catalog course against the approved staging API."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import httpx

API = "https://tutor-tds-staging.fastapicloud.dev"
COURSE = "validacao-dinamica-tds"
PROGRAM = "qa-dynamic-program"
TITLE = "Curso Dinâmico de Validação TDS"
AUTHOR = "Equipe TDS"
DEFINES = Path(__file__).resolve().parents[2] / "tmp/cloud-dynamic-learning-defines.json"


def sections(updated: bool = False) -> list[dict]:
    first = {
        "id": "modulo-1", "title": "Módulo 1 — Catálogo dinâmico", "messages": [
            {"id": "intro", "type": "bot", "content": "Este curso foi publicado no catálogo remoto do Tutor TDS sem atualizar o aplicativo."},
            {"id": "pergunta-versao", "type": "question", "content": "Este curso precisou de uma nova versão do aplicativo para aparecer?", "options": [
                {"label": "Não.", "isCorrect": True, "feedback": "Correto: o conteúdo veio do catálogo remoto."},
                {"label": "Sim.", "isCorrect": False, "feedback": "O catálogo pode atualizar sem recompilar o aplicativo."},
            ]},
        ],
    }
    second = {
        "id": "modulo-2", "title": "Módulo 2 — Atualização e fallback", "messages": [
            {"id": "modulo-2-intro", "type": "bot", "content": "Responda às três perguntas sobre publicação remota e uso offline."},
            {"id": "quiz-catalogo", "type": "quiz", "content": "De onde vem o curso dinâmico?", "options": [
                {"label": "Do catálogo remoto.", "isCorrect": True},
                {"label": "Somente dos assets do APK.", "isCorrect": False},
            ]},
            {"id": "quiz-offline", "type": "quiz", "content": "O que acontece se a API estiver indisponível?", "options": [
                {"label": "O app usa o cache ou os cursos locais.", "isCorrect": True},
                {"label": "O app precisa recompilar.", "isCorrect": False},
            ]},
            {"id": "quiz-editorial", "type": "quiz", "content": "Como publicar uma atualização editorial?", "options": [
                {"label": "Publicar uma nova versão no backend.", "isCorrect": True},
                {"label": "Gerar um novo APK.", "isCorrect": False},
            ]},
        ],
    }
    if updated:
        second["messages"].append({
            "id": "pergunta-atualizacao", "type": "question", "content": "Esta alteração apareceu após recompilar o aplicativo?", "options": [
                {"label": "Não, veio da atualização do catálogo.", "isCorrect": True},
                {"label": "Sim, foi necessário um novo APK.", "isCorrect": False},
            ],
        })
    return [first, second]


def request(client: httpx.Client, method: str, path: str, *, token: str | None = None, body: dict | None = None, status: int = 200) -> dict:
    response = client.request(method, path, headers={"Authorization": f"Bearer {token}"} if token else {}, json=body)
    if response.status_code != status:
        raise RuntimeError(f"{method} {path}: HTTP {response.status_code}, esperado {status}")
    return response.json()


def actor(client: httpx.Client, defines: dict, name: str) -> str:
    result = request(client, "POST", "/auth/login", body={
        "cpf": defines[f"QA_DYNAMIC_{name}_CPF"],
        "password": defines[f"QA_DYNAMIC_{name}_PASSWORD"],
    })
    token = result["access_token"]
    context = request(client, "GET", "/editor/context", token=token)
    programs = [entry for entry in context["programs"] if entry["id"] == PROGRAM]
    if len(programs) != 1 or programs[0]["role"] != {"AUTHOR": "teacher", "PUBLISHER": "coordinator"}[name]:
        raise RuntimeError(f"Vínculo editorial QA {name} não confirmado")
    if name == "PUBLISHER" and not programs[0]["can_publish"]:
        raise RuntimeError("Publicador QA sem permissão de publicação")
    return token


def transition(client: httpx.Client, action: str, view: dict, token: str) -> dict:
    return request(client, "POST", f"/courses/{COURSE}/{action}", token=token, body={
        "version_id": view["version_id"], "expected_revision": view["revision"],
    })


def main(phase: str) -> dict:
    defines = json.loads(DEFINES.read_text(encoding="utf-8-sig"))
    if defines.get("TUTOR_ENVIRONMENT") != "staging" or defines.get("TUTOR_API_URL") != API or defines.get("TUTOR_STAGING_API_URL") != API or defines.get("QA_DYNAMIC_PROGRAM_ID") != PROGRAM:
        raise RuntimeError("Definições QA não pertencem ao staging autorizado")
    with httpx.Client(base_url=API, timeout=25) as client:
        author = actor(client, defines, "AUTHOR")
        publisher = actor(client, defines, "PUBLISHER")
        public = request(client, "GET", "/courses")["courses"]
        existing = [course for course in public if course["id"] == COURSE]
        if phase == "first":
            if existing:
                raise RuntimeError("Curso-alvo já publicado; não sobrescrever")
            draft = request(client, "POST", "/courses", token=author, status=201, body={
                "course_id": COURSE, "program_id": PROGRAM, "title": TITLE, "author": AUTHOR,
            })
            source_id = None
        else:
            if len(existing) != 1 or existing[0].get("version_number") != 1 or existing[0]["title"] != TITLE:
                raise RuntimeError("Publicação v1 esperada não encontrada")
            source_id = existing[0]["course_version_id"]
            draft = request(client, "POST", f"/courses/{COURSE}/versions", token=author, status=201, body={"source_version_id": source_id})
        title = TITLE + " — Atualizado" if phase == "second" else TITLE
        saved = request(client, "PATCH", f"/courses/{COURSE}", token=author, body={
            "version_id": draft["version_id"], "expected_revision": draft["revision"],
            "title": title, "author": AUTHOR, "sections": sections(phase == "second"),
        })
        reviewed = transition(client, "submit", saved, author)
        published = transition(client, "publish", reviewed, publisher)
        catalog = request(client, "GET", "/courses")["courses"]
        matching = [course for course in catalog if course["id"] == COURSE]
        if len(matching) != 1 or matching[0]["title"] != title or matching[0]["course_version_id"] != published["version_id"] or len(matching[0]["sections"]) != 2:
            raise RuntimeError("Projeção pública diverge da versão publicada")
        if phase == "second" and not any(item.get("content") == "Esta alteração apareceu após recompilar o aplicativo?" for section in matching[0]["sections"] for item in section["messages"]):
            raise RuntimeError("Nova questão não apareceu no catálogo público")
        return {"phase": phase, "api": API, "course_id": COURSE, "source_version_id": source_id,
                "version_id": published["version_id"], "revision": published["revision"],
                "version_number": published["version_number"], "status": published["status"],
                "title": matching[0]["title"], "catalog_count": len(catalog)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=["first", "second"])
    args = parser.parse_args()
    try:
        print(json.dumps(main(args.phase), ensure_ascii=False))
    except (KeyError, ValueError, httpx.HTTPError, RuntimeError) as error:
        print(f"QA editorial falhou: {type(error).__name__}: {error if isinstance(error, RuntimeError) else 'verifique configuração/autorização sem expor credenciais'}")
        raise SystemExit(1) from None
