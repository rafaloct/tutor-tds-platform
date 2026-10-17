import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import polib
from build import build_catalog, valid_translation, read_glossaries


class SiteI18nTests(unittest.TestCase):
    def test_printf_formats_not_broken(self):
        self.assertEqual(valid_translation("%1$s e %2$d itens", "%1$s e %2$d aulas"), (True, ""))
        self.assertEqual(valid_translation("%1$s e %2$d itens", "%1$d e %2$d aulas")[0], False)

    def test_markup_not_broken(self):
        self.assertEqual(valid_translation("Faça <strong>%s</strong>", "Faça <strong>%s</strong>")[0], True)
        self.assertEqual(valid_translation("Faça <strong>%s</strong>", "Faça %s")[0], False)

    def test_glossary_specific_overrides_original(self):
        with tempfile.TemporaryDirectory() as d:
            a, b = Path(d) / "old.json", Path(d) / "specific.json"
            a.write_text(json.dumps({"Lessons": "Lições"}), encoding="utf8")
            b.write_text(json.dumps({"Lessons": "Aulas"}), encoding="utf8")
            self.assertEqual(read_glossaries([a, b])["Lessons"], "Aulas")

    def test_build_output_plural_and_context(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            pot = polib.POFile()
            pot.metadata = {"Content-Type": "text/plain; charset=UTF-8"}
            pot.append(polib.POEntry(msgid="Last updated"))
            pot.append(polib.POEntry(msgid="%d Lesson", msgid_plural="%d Lessons"))
            pot.append(polib.POEntry(msgid="Next", msgctxt="course-item-navigation"))
            pot.save(str(path / "learnpress.pot"))
            glossary = path / "mapping.json"
            glossary.write_text(json.dumps({
                "Last updated": "Última atualização",
                "%d Lesson": "%d aula",
                "%d Lessons": "%d aulas",
                "Next": "Próximo"
            }, ensure_ascii=False), encoding="utf8")
            r = build_catalog(path / "learnpress.pot", "learnpress", [glossary], path / "output", None, True)
            self.assertEqual(r["translated"], 3)
            self.assertEqual(r["result"], "PASS")
            translated = polib.pofile(str(path / "output" / "learnpress-pt_BR.po"))
            self.assertEqual(translated.find("Next",msgctxt="course-item-navigation").msgstr, "Próximo")
            self.assertEqual(translated.find("%d Lesson").msgstr_plural[1], "%d aulas")
            self.assertTrue((path / "output" / "learnpress-pt_BR.mo").exists())

    def test_rejects_legacy_portuguese_portugal_disguised_as_brazil(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            pot = polib.POFile();pot.append(polib.POEntry(msgid="Lessons"));pot.save(str(path / "t.pot"))
            old = polib.POFile()
            old.metadata = {"Language": "pt", "Content-Type": "text/plain; charset=UTF-8"}
            old.append(polib.POEntry(msgid="Lessons", msgstr="Lições"))
            old.save(str(path / "old.po"))
            mapping = path / "mapping.json"
            mapping.write_text(json.dumps({"Lessons":"Aulas"}), encoding="utf8")
            with self.assertRaisesRegex(ValueError, "Fallback inseguro"):
                build_catalog(path / "t.pot", "learnpress", [mapping], path / "out", path / "old.po", False)

    def test_report_fails_critical_when_missing(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)
            pot = polib.POFile()
            pot.append(polib.POEntry(msgid="Lifetime"))
            pot.save(str(path / "t.pot"))
            mapping = path / "empty.json"
            mapping.write_text("{}", encoding="utf8")
            r = build_catalog(path / "t.pot", "learnpress", [mapping], path / "out", None, True)
            self.assertEqual(r["result"], "BLOCKED")
            self.assertIn("Lifetime",r["missing_critical"])


if __name__ == "__main__":
    unittest.main()
