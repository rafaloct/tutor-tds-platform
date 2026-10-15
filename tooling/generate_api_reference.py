#!/usr/bin/env python3
"""Export the candidate contract without starting the API or touching a database.

Run with the API's locked Python environment. --check detects stale generated
artifacts and validates request/typed response examples with the real models.
"""
from __future__ import annotations

import argparse
import ast
import inspect
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import textwrap
from urllib.parse import urlencode

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "api"
sys.path.insert(0, str(ROOT / "api"))
# A schema export must never inherit a real database or deployment environment.
os.environ["DATABASE_URL"] = "sqlite+pysqlite:///:memory:"
os.environ["TUTOR_ENVIRONMENT"] = "development"

from fastapi.routing import APIRoute  # noqa: E402
from pydantic import TypeAdapter  # noqa: E402
from app.main import app  # noqa: E402

UUID = "00000000-0000-4000-8000-000000000001"
VALUES = {
    "cpf": "12345678909", "phone": "00000000000",
    "password": "Apenas-exemplo-nao-utilizar-2026", "name": "Pessoa Sintética QA",
    "title": "Curso Sintético QA", "author": "Equipe Sintética QA",
    "reason": "Validação com dados sintéticos", "reason_code": "verified",
    "idempotency_key": "qa-command-20261013-0001", "id": UUID,
    "course_id": "curso-qa", "slug": "curso-qa", "module_id": "modulo-qa",
    "source": "app", "source_type": "manual", "source_digest": "a" * 64,
    "content_hash": "a" * 64, "content_digest": "a" * 64,
    "item_digest": "a" * 64, "document_digest": "a" * 64,
    "report_digest": "a" * 64, "document_hash": "a" * 64,
    "verification_url": "https://example.org/verify/qa-certificate",
    "provider_asset_id": "dQw4w9WgXcQ", "language": "pt-BR",
    "reference": "https://example.org/qa/captions.vtt",
    "private_reference": "qa:documento-sintetico", "kind": "assessment",
    "access_token": "ACCESS_TOKEN_SINTETICO", "refresh_token": "REFRESH_TOKEN_SINTETICO",
    "activation_token": "ACTIVATION_TOKEN_SINTETICO",
    "token": "TOKEN_SINTETICO", "identity_proof": "IDENTITY_PROOF_SINTETICA",
    "checkin_code": "000000", "code": "000000", "token_type": "bearer",
    "role": "student", "topic": "Tema sintético", "question": "Questão sintética?",
    "explanation": "Explicação sintética", "formal_hours": 80,
    "status": "active", "sync_status": "pending", "expires_in": 900,
    "start_date": "2026-10-13", "end_date": "2026-10-14",
    "starts_at": "2026-10-13T12:00:00Z", "ends_at": "2026-10-13T13:00:00Z",
    "window_start": "2026-10-01T00:00:00Z", "window_end": "2026-10-02T00:00:00Z",
    "period_start": "2026-10-01T00:00:00Z", "period_end": "2026-10-02T00:00:00Z",
    "limit": 20, "offset": 0,
    "institution_id": UUID, "organization_id": UUID,
    "program_id": "00000000-0000-4000-8000-000000000002",
    "class_id": "00000000-0000-4000-8000-000000000003",
    "cohort_id": "00000000-0000-4000-8000-000000000003",
    "user_id": "00000000-0000-4000-8000-000000000004",
    "owner_id": "00000000-0000-4000-8000-000000000004",
    "person_id": "00000000-0000-4000-8000-000000000004",
    "teacher_id": "00000000-0000-4000-8000-000000000005",
    "mentor_id": "00000000-0000-4000-8000-000000000005",
    "enrollment_id": "00000000-0000-4000-8000-000000000007",
    "legacy_enrollment_id": "00000000-0000-4000-8000-000000000007",
    "version_id": "00000000-0000-4000-8000-000000000008",
    "course_version_id": "00000000-0000-4000-8000-000000000008",
    "source_version_id": "00000000-0000-4000-8000-000000000008",
    "session_id": "00000000-0000-4000-8000-000000000009",
    "count": 1, "unique_users": 1,
}


def routes(items):
    """FastAPI 0.135+ keeps included routers lazily; older versions flatten them."""
    for route in items:
        if isinstance(route, APIRoute) and route.include_in_schema:
            yield route
        elif hasattr(route, "original_router"):
            if route.include_context.prefix:
                raise ValueError("Nested include prefix needs explicit support")
            yield from routes(route.original_router.routes)


def dereference(schema, spec):
    if "$ref" in schema:
        return spec["components"]["schemas"][schema["$ref"].split("/")[-1]]
    return schema


def sample(schema, spec, name="", depth=0):
    if depth > 12:
        raise ValueError("Recursive example needs an explicit override")
    schema = dereference(schema, spec)
    if "const" in schema:
        return schema["const"]
    if "enum" in schema:
        return schema["enum"][0]
    if "default" in schema and schema["default"] is not None:
        return schema["default"]
    for key in ("anyOf", "oneOf"):
        if key in schema:
            if any(s.get("type") == "null" for s in schema[key]):
                return None
            return sample(schema[key][0], spec, name, depth + 1)
    kind = schema.get("type", "object")
    if kind == "object":
        return {key: sample(value, spec, key, depth + 1)
                for key, value in schema.get("properties", {}).items()
                if key in schema.get("required", []) or "default" in value}
    if kind == "array":
        count = max(1, schema.get("minItems", 0))
        return [sample(schema.get("items", {}), spec, name.removesuffix("s"), depth + 1)
                for _ in range(count)]
    if name in VALUES:
        value = VALUES[name]
    elif kind in {"integer", "number"}:
        value = max(0, schema.get("minimum", 0), schema.get("exclusiveMinimum", -1) + 1)
        if kind == "integer":
            value = int(value)
    elif kind == "boolean":
        value = False
    elif kind == "null":
        return None
    elif schema.get("format") == "date-time":
        value = "2026-10-01T12:00:00Z"
    elif schema.get("format") == "date":
        value = "2026-10-01"
    elif schema.get("format") in {"uri", "url"}:
        value = "https://example.org/qa"
    elif name.endswith("_id") or name.endswith("_ids"):
        value = UUID
    else:
        value = "qa-example"
    if kind == "string":
        value = str(value)
        if len(value) < schema.get("minLength", 0):
            value += "a" * (schema["minLength"] - len(value))
        value = value[:schema.get("maxLength", len(value))]
    return value


def authentication(route):
    names, roles = set(), set()
    def walk(dependency):
        call = dependency.call
        if call:
            names.add(call.__name__)
            if call.__name__ == "authorized_role":
                roles.update(inspect.getclosurevars(call).nonlocals["allowed"])
        for child in dependency.dependencies:
            walk(child)
    for dependency in route.dependant.dependencies:
        walk(dependency)
    if "optional_access_claims" in names:
        return "Bearer opcional; visibilidade revalidada no servidor."
    if roles:
        return "Bearer obrigatório; papel global: " + ", ".join(sorted(roles)) + "."
    if "access_claims" in names:
        return "Bearer obrigatório; vínculos e permissões adicionais abaixo."
    return "Sem Bearer."


def curl_example(method, url, route, body):
    """Anonymous examples must not send an empty optional Authorization header."""
    curl = f'curl --request {method} "${{TDS_API_BASE}}{url}"'
    if authentication(route).startswith("Bearer obrigatório"):
        curl += ' \\\n  --header "Authorization: Bearer ${TDS_ACCESS_TOKEN}"'
    if body is not None:
        curl += " \\\n  --header 'Content-Type: application/json' \\\n  --data " + shlex.quote(json.dumps(body, ensure_ascii=False))
    return curl


def source_link(function):
    path = Path(inspect.getsourcefile(function)).relative_to(ROOT).as_posix()
    return path, inspect.getsourcelines(function)[1]


def source_errors(function, visited=None):
    """Literal exceptions in endpoint and directly referenced local helpers.

    This is a source inventory, not a proof of reachability of every branch.
    Dynamic detail strings retain the expression and are never fabricated.
    """
    visited = set() if visited is None else visited
    if function in visited or not inspect.isfunction(function):
        return set()
    if not function.__module__.startswith("app."):
        return set()
    visited.add(function)
    tree = ast.parse(textwrap.dedent(inspect.getsource(function)))
    results = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if isinstance(node.func, ast.Name) and node.func.id == "HTTPException":
            keywords = {item.arg: item.value for item in node.keywords}
            status = keywords.get("status_code", node.args[0] if node.args else None)
            detail = keywords.get("detail", node.args[1] if len(node.args) > 1 else None)
            if isinstance(status, ast.Constant):
                code = status.value
            elif isinstance(status, ast.Attribute) and status.attr.startswith("HTTP_"):
                code = int(status.attr.split("_")[1])
            else:
                continue
            message = detail.value if isinstance(detail, ast.Constant) else "Expressão: " + ast.unparse(detail) if detail else ""
            results.add((code, str(message)))
        elif isinstance(node.func, ast.Name):
            helper = function.__globals__.get(node.func.id)
            if inspect.isfunction(helper):
                results.update(source_errors(helper, visited))
        elif isinstance(node.func, ast.Attribute):
            # Auth handlers delegate their literal errors to AuthService methods.
            service = function.__globals__.get("AuthService")
            helper = getattr(service, node.func.attr, None) if service else None
            if inspect.isfunction(helper):
                results.update(source_errors(helper, visited))
    return results


def schema_text(schema, spec):
    if "$ref" in schema:
        name = schema["$ref"].split("/")[-1]
        return f"[{name}](SCHEMAS.md#schema-{name})"
    if "anyOf" in schema or "oneOf" in schema:
        return " / ".join(schema_text(item, spec) for item in schema.get("anyOf", schema.get("oneOf")))
    if schema.get("type") == "array":
        return "array de " + schema_text(schema.get("items", {}), spec)
    if "const" in schema:
        return "const " + json.dumps(schema["const"], ensure_ascii=False)
    if "enum" in schema:
        return "enum " + json.dumps(schema["enum"], ensure_ascii=False)
    return schema.get("type", "qualquer JSON") + (" (" + schema["format"] + ")" if "format" in schema else "")


def constraints(schema):
    pieces = []
    for key in ("default", "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "minLength", "maxLength", "minItems", "maxItems", "maxProperties", "pattern", "additionalProperties", "writeOnly"):
        if key in schema:
            pieces.append(f"{key}={json.dumps(schema[key], ensure_ascii=False)}")
    if "anyOf" in schema:
        for variant in schema["anyOf"]:
            detail = constraints(variant)
            if detail != "—":
                pieces.append(detail)
    return "; ".join(pieces).replace("|", "\\|") or "—"


def block(value):
    return "```json\n" + json.dumps(value, ensure_ascii=False, indent=2) + "\n```\n"


def validate_links(artifacts):
    """Check local documentation targets and anchors, including generated files."""
    checked = 0
    sources = {name: text for name, text in artifacts.items() if name.endswith(".md")}
    sources["README.md"] = (DOCS / "README.md").read_text()
    for filename, content in sources.items():
        prose = re.sub(r"```.*?```", "", content, flags=re.S)
        for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", prose):
            if "://" in target:
                continue
            relative, _, anchor = target.partition("#")
            path = (DOCS / relative).resolve() if relative else DOCS / filename
            if path.parent == DOCS.resolve() and path.name in artifacts:
                linked = artifacts[path.name]
            elif path.exists():
                linked = path.read_text()
            else:
                raise ValueError(f"Broken documentation link in {filename}: {target}")
            if anchor:
                ids = set(re.findall(r'<a id="([^"]+)"', linked))
                for heading in re.findall(r"^#+\s+(.+)$", linked, flags=re.M):
                    slug = re.sub(r"[^\w -]", "", heading.lower()).replace(" ", "-")
                    ids.add(slug)
                if anchor not in ids:
                    raise ValueError(f"Broken documentation anchor in {filename}: {target}")
            checked += 1
    return checked


def generate():
    spec = app.openapi()
    api_tree = subprocess.check_output(["git", "rev-parse", "HEAD:api"], cwd=ROOT, text=True).strip()
    notes = json.loads((DOCS / "operation-notes.json").read_text())
    overrides = json.loads((DOCS / "response-overrides.json").read_text())
    typed_overrides = json.loads((DOCS / "typed-response-overrides.json").read_text())
    body_overrides_path = DOCS / "request-overrides.json"
    body_overrides = json.loads(body_overrides_path.read_text()) if body_overrides_path.exists() else {}
    by_key = {f"{method} {route.path}": route for route in routes(app.routes) for method in route.methods}
    expected = {f"{method.upper()} {path}" for path, operations in spec["paths"].items() for method in operations if method in {"get", "post", "put", "patch", "delete", "head", "options"}}
    if set(by_key) != expected or set(notes) != expected:
        raise ValueError(f"Operation coverage mismatch: source={len(by_key)} openapi={len(expected)} notes={len(notes)}; missing notes={sorted(expected-set(notes))}")
    untyped = {key for key, route in by_key.items()
               if route.response_model is None or str(route.response_model).startswith("dict")}
    if set(overrides) != untyped:
        raise ValueError(f"Untyped response coverage mismatch: missing={sorted(untyped-set(overrides))} extra={sorted(set(overrides)-untyped)}")
    if not set(typed_overrides) <= expected - untyped:
        raise ValueError(f"Typed response overrides must target structured response models: {sorted(set(typed_overrides)-(expected-untyped))}")
    overrides.update(typed_overrides)
    artifacts, examples = {}, {}
    reference = ["# Referência completa de endpoints\n", "Gerada pelo contrato candidato. Leia primeiro [o guia](README.md). Exemplos são sintéticos; IDs devem apontar para fixtures do mesmo ambiente. A validação Pydantic confirma tipos/validadores dos exemplos tipados, sem executar comandos ou comprovar autorização relacional.\n", f"Árvore Git da fonte: `{api_tree}`. Operações: **{len(expected)}**.\n", "## Índice\n"]
    for index, key in enumerate(sorted(expected), 1):
        reference.append(f"- [{key}](#operacao-{index:03d})")
    request_count = response_count = model_response_count = mapping_response_count = 0
    for index, key in enumerate(sorted(expected), 1):
        method, path = key.split(" ", 1)
        route, operation, note = by_key[key], spec["paths"][path][method.lower()], notes[key]
        file, line = source_link(route.endpoint)
        reference.extend([f"\n<a id=\"operacao-{index:03d}\"></a>\n\n## `{key}`\n", f"{operation.get('summary', route.endpoint.__name__)}. Fonte: [{file}:{line}](../../{file}).\n", f"**Autenticação:** {authentication(route)}\n", f"**Permissão:** {note['permission']}\n", f"**Comportamento:** {note['behavior']}\n", "**Flags/gates:** " + (", ".join(f"`{flag}`" for flag in note['flags']) or "Nenhuma flag adicional.") + "\n"])
        parameters = operation.get("parameters", [])
        reference.extend(["### Parâmetros\n", "| Nome | Local | Obrigatório | Tipo | Default / limites |", "| --- | --- | --- | --- | --- |"])
        for parameter in parameters:
            reference.append(f"| `{parameter['name']}` | {parameter['in']} | {'sim' if parameter.get('required') else 'não'} | {schema_text(parameter['schema'], spec)} | {constraints(parameter['schema'])} |")
        if not parameters:
            reference.append("| — | — | — | — | — |")
        body = None
        if "requestBody" in operation:
            body_schema = operation["requestBody"]["content"]["application/json"]["schema"]
            body = body_overrides.get(key, sample(body_schema, spec))
            # FastAPI's compatibility field returns errors instead of raising.
            _, errors = route.body_field.validate(body)
            if errors:
                raise ValueError(f"Invalid request example for {key}: {errors}")
            request_count += 1
            reference.append("\n**Body JSON:** " + schema_text(body_schema, spec) + ". Todos os campos e limites estão no schema vinculado.\n")
        query = {p["name"]: sample(p["schema"], spec, p["name"]) for p in parameters if p["in"] == "query" and p.get("required")}
        url = path
        for parameter in parameters:
            if parameter["in"] == "path":
                url = url.replace("{" + parameter["name"] + "}", str(sample(parameter["schema"], spec, parameter["name"])))
        if query:
            url += "?" + urlencode(query)
        curl = curl_example(method, url, route, body)
        reference.extend(["\n### Exemplo de requisição\n", "```bash\n" + curl + "\n```\n"])
        response = overrides.get(key)
        if response is None:
            status = int(next(code for code in operation["responses"] if code.startswith("2")))
            response_schema = operation["responses"][str(status)].get("content", {}).get("application/json", {}).get("schema")
            response = {"status": status, "body": sample(response_schema, spec) if response_schema else None, "note": "Exemplo sintético do modelo de resposta."}
            if isinstance(body, dict) and isinstance(response["body"], dict):
                for field in set(body) & set(response["body"]):
                    response["body"][field] = body[field]
            if isinstance(response["body"], dict) and "total" in response["body"]:
                collections = [len(value) for value in response["body"].values() if isinstance(value, list)]
                if collections:
                    response["body"]["total"] = max(collections)
        if route.response_model is not None and response["body"] is not None and response["status"] < 300:
            TypeAdapter(route.response_model).validate_python(response["body"])
            response_count += 1
            if str(route.response_model).startswith("dict"):
                mapping_response_count += 1
            else:
                model_response_count += 1
        examples[key] = {"request": {"path": url, "body": body}, "response": response}
        reference.extend(["### Contrato de resposta\n", "| HTTP declarado | Descrição | Schema |", "| --- | --- | --- |"])
        for code, item in operation["responses"].items():
            schema = item.get("content", {}).get("application/json", {}).get("schema")
            reference.append(f"| {code} | {item['description']} | {schema_text(schema, spec) if schema else 'Sem schema JSON declarado.'} |")
        if key in untyped:
            reference.append("\nEsta operação não declara um modelo de resposta com propriedades fixas. O exemplo foi conferido no serializer; o OpenAPI bruto mantém essa limitação do código.\n")
        reference.extend(["### Exemplo de resposta\n", f"HTTP **{response['status']}**. {response['note']}\n", block(response["body"]) if response["body"] is not None else "Sem body JSON.\n"])
        errors = source_errors(route.endpoint)
        if not authentication(route).startswith("Sem"):
            errors.add((401, "Bearer fornecido inválido ou expirado." if authentication(route).startswith("Bearer opcional") else "Token ausente, inválido ou expirado."))
        if "422" in operation["responses"]:
            errors.add((422, "Validação de path/query/body; envelope detail sanitizado."))
        reference.append("### Status e erros\n")
        reference.append("Status declarados no OpenAPI: " + ", ".join(operation["responses"]) + ". As exceções abaixo vêm da operação/helpers referenciados e são condicionais; a ordem de autenticação/flags/estado pode determinar qual aparece.\n")
        reference.extend(["| HTTP | `detail` / condição |", "| --- | --- |"])
        for code, detail in sorted(errors):
            reference.append(f"| {code} | {detail.replace('|', chr(92)+'|').replace(chr(10), ' ')} |")
        if not errors:
            reference.append("| — | Sem HTTPException literal identificada nesta operação. Falhas inesperadas seguem o guia. |")
    artifacts["ENDPOINTS.md"] = "\n".join(reference).rstrip() + "\n"
    schemas = ["# Schemas JSON da API\n", "Gerados do OpenAPI; `required` significa presença obrigatória, e `null` é uma alternativa explícita. Um campo opcional sem `default` serializado pode possuir default/factory no modelo Python. OpenAPI não expressa todos os validadores cruzados: consulte as notas da operação e [regras semânticas](README.md#regras-semanticas).\n", "[Endpoints](ENDPOINTS.md) · [OpenAPI JSON](openapi.json)\n"]
    for name, schema in sorted(spec["components"]["schemas"].items()):
        schemas.extend([f'<a id="schema-{name}"></a>\n\n## {name}\n', "| Campo | Obrigatório | Tipo | Default / limites |", "| --- | --- | --- | --- |"])
        for field, value in schema.get("properties", {}).items():
            schemas.append(f"| `{field}` | {'sim' if field in schema.get('required',[]) else 'não'} | {schema_text(value,spec)} | {constraints(value)} |")
        schemas.append("\nSchema exato:\n" + block(schema))
    artifacts["SCHEMAS.md"] = "\n".join(schemas).rstrip() + "\n"
    artifacts["openapi.json"] = json.dumps(spec, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    artifacts["examples.json"] = json.dumps(examples, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    evidence = {"source_tree": api_tree, "operation_count": len(expected), "path_count": len(spec["paths"]), "schema_count": len(spec["components"]["schemas"]), "validated_request_examples": request_count, "validated_response_examples": response_count, "validated_model_response_examples": model_response_count, "validated_mapping_response_examples": mapping_response_count, "source_reviewed_untyped_responses": len(untyped), "source_reviewed_typed_response_overrides": len(typed_overrides), "example_operation_count": len(examples), "runtime_mutations": False, "production_requests": False}
    evidence["validated_documentation_links"] = validate_links(artifacts)
    artifacts["coverage.json"] = json.dumps(evidence, indent=2, sort_keys=True) + "\n"
    return artifacts, evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate examples and fail on stale artifacts")
    args = parser.parse_args()
    artifacts, evidence = generate()
    stale = []
    for filename, content in artifacts.items():
        path = DOCS / filename
        if args.check:
            if not path.exists() or path.read_text() != content:
                stale.append(filename)
        else:
            path.write_text(content)
    if stale:
        raise SystemExit("API_REFERENCE_STALE: " + ", ".join(stale))
    print("API_REFERENCE_VALID " + json.dumps(evidence, sort_keys=True))


if __name__ == "__main__":
    main()
