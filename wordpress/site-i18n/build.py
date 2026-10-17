#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gerador independente de pacotes de tradução pt-BR para WordPress.
Não utiliza serviços remotos ou altera o site. Requer: pip install -r requirements.txt.
"""
import argparse
import json
import re
import sys
from pathlib import Path

try:
    import polib
except ImportError as exc:
    raise SystemExit("Instale dependências: python -m pip install -r requirements.txt") from exc

PRINTF = re.compile(r'%(?!%)(?:[1-9][0-9]*\$)?[-+ #0]*[0-9]*(?:\.[0-9]+)?[bcdeEfFgGiosuxX]')
TAGS = re.compile(r'<\s*/?\s*([a-zA-Z][a-zA-Z0-9:-]*)\b')
HTML_ENTITIES = re.compile(r'&(?:[A-Za-z][A-Za-z0-9]{1,30}|#[xX]?[0-9a-fA-F]+);')
CRITICAL = {
    "learnpress": [
        "Last updated", "Lifetime", "Expand all sections", "Collapse all sections",
        "All levels", "Share", "Copy to Clipboard",
        "Enrollment in the course is not mandatory. You can access course for learning now.",
    ],
    "astra": ["Skip to content", "Scroll to Top"],
    "learnpress-course-review": ["Reviews", "Rating", "Write a review"],
}


def placeholders(value: str) -> list[str]:
    return sorted(PRINTF.findall(value.replace("%%", "")))


def tags(value: str) -> list[str]:
    return sorted(TAGS.findall(value))


def valid_translation(original: str, translation: str) -> tuple[bool, str]:
    if not translation:
        return False, "vazio"
    if placeholders(original) != placeholders(translation):
        return False, "marcadores_printf"
    if tags(original) != tags(translation):
        return False, "tags_html"
    # Escape sequences from WordPress i18n (do not change newlines/control tokens).
    for entity in HTML_ENTITIES.findall(original):
        if entity in ("&hellip;", "&raquo;", "&laquo;", "&nbsp;", "&copy;") and entity not in translation:
            return False, "entidade_html"
    return True, ""


def read_glossaries(paths: list[Path]) -> dict[str, str]:
    resolved = {}
    for path in paths:
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in data.items()):
            raise ValueError(f"Glossário inválido: {path}")
        resolved.update(data)  # Later specific glossary intentionally wins.
    return resolved


def build_catalog(pot: Path, domain: str, glossary_files: list[Path], output: Path,
                  existing: Path | None, critical: bool) -> dict:
    template = polib.pofile(str(pot), check_for_duplicates=True)
    glossary = read_glossaries(glossary_files)
    previous = {}
    if existing:
        old = polib.pofile(str(existing), check_for_duplicates=True)
        locale = old.metadata.get("Language", "").replace("-", "_")
        if locale != "pt_BR":
            raise ValueError(f"Fallback inseguro: {existing} declara {locale!r}, não pt_BR")
        previous = {(e.msgctxt, e.msgid): e for e in old}
    po = polib.POFile(wrapwidth=84)
    po.metadata = {
        "Project-Id-Version": "Tutor TDS " + domain,
        "Language": "pt_BR",
        "Language-Team": "Projeto Tutor TDS",
        "Content-Type": "text/plain; charset=UTF-8",
        "Content-Transfer-Encoding": "8bit",
        "MIME-Version": "1.0",
        "Plural-Forms": "nplurals=2; plural=(n != 1);",
        "PO-Revision-Date": "2026-10-17 14:00+0000",
        "X-Generator": "site-i18n/build.py",
    }
    rejected, translated, reused, uncovered, covered_critical = [], 0, 0, [], set()
    glossary_hits = set()
    for entry in template:
        if not entry.msgid or entry.obsolete:
            continue
        out = polib.POEntry(
            msgid=entry.msgid, msgid_plural=entry.msgid_plural,
            msgctxt=entry.msgctxt, occurrences=entry.occurrences,
            comment=entry.comment, flags=list(entry.flags),
        )
        old = previous.get((entry.msgctxt, entry.msgid))
        variants = [entry.msgid]
        if entry.msgid_plural:
            variants.append(entry.msgid_plural)
        complete = True
        for index, original in enumerate(variants):
            candidate = glossary.get(original)
            if candidate is not None:
                glossary_hits.add(original)
            elif old:
                candidate = old.msgstr_plural.get(index, old.msgstr_plural.get(str(index), "")) if entry.msgid_plural else old.msgstr
                if candidate:
                    reused += 1
            else:
                candidate = ""
            valid, problem = valid_translation(original, candidate)
            if not valid:
                complete = False
                if candidate:
                    rejected.append({"msgid": original, "cause": problem})
                candidate = ""
            if entry.msgid_plural:
                out.msgstr_plural[str(index)] = candidate
            else:
                out.msgstr = candidate
        if complete:
            translated += 1
            covered_critical.add(entry.msgid)
        else:
            if len(uncovered) < 150:
                uncovered.append(entry.msgid[:180])
        po.append(out)
    missing_critical = [
        x for x in CRITICAL.get(domain, [])
        if x in {e.msgid for e in template} and x not in covered_critical
    ]
    output.mkdir(parents=True, exist_ok=True)
    po_file = output / f"{domain}-pt_BR.po"
    mo_file = output / f"{domain}-pt_BR.mo"
    po.save(str(po_file))
    po.save_as_mofile(str(mo_file))
    report = {
        "domain": domain, "language": "pt_BR", "source_pot": pot.name,
        "total": len(po), "translated": translated,
        "untranslated": len(po) - translated, "reuse_count": reused,
        "mapping_entries": len(glossary), "mapping_hits": len(glossary_hits),
        "unmapped_glossary_keys": sorted(set(glossary) - glossary_hits),
        "rejected": rejected, "missing_critical": missing_critical,
        "uncovered_sample": uncovered,
        "out_po": po_file.name, "out_mo": mo_file.name,
        "result": "BLOCKED" if rejected or (critical and missing_critical) else "PASS",
    }
    (output / (domain + "-report.json")).write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pot", type=Path, required=True, help="POT da versão instalada")
    parser.add_argument("--domain", choices=("learnpress", "learnpress-course-review", "astra"), required=True)
    parser.add_argument("--glossary", action="append", type=Path, required=True)
    parser.add_argument("--existing", type=Path, help="PO pt_BR anterior confiável; pt_PT é recusado")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--fail-on-critical", action="store_true", help="Falhar se rótulos públicos críticos estiverem sem tradução")
    args = parser.parse_args(argv)
    report = build_catalog(args.pot, args.domain, args.glossary, args.out, args.existing, args.fail_on_critical)
    print(json.dumps({k: report[k] for k in (
        "domain","total","translated","untranslated","rejected","missing_critical","result"
    )}, ensure_ascii=False))
    return 0 if report["result"] == "PASS" else 2


if __name__ == "__main__":
    sys.exit(main())
