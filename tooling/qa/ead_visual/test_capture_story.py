"""Offline negative tests for Android accessibility parser/selector (#241)."""
from __future__ import annotations

import unittest
from unittest.mock import patch

import capture_story as qa


XML = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<hierarchy rotation="0"><node text="" content-desc="Explorar cursos do EAD sem cadastro" '
    'resource-id="ead-public-explore" bounds="[100,200][500,300]" '
    'enabled="true" clickable="true"/></hierarchy>'
)


class AccessibilityRunnerTests(unittest.TestCase):
    def test_parses_native_android_node(self):
        nodes = qa.parse_hierarchy(XML)
        self.assertEqual(len(nodes), 1)
        self.assertEqual(nodes[0]["resource_id"], "ead-public-explore")
        self.assertEqual(nodes[0]["bounds"], (100, 200, 500, 300))
        self.assertTrue(nodes[0]["clickable"])

    def test_handles_shell_preamble_without_leaking_it(self):
        nodes = qa.parse_hierarchy(("UI dump finished\n" + XML + "\nOK").encode())
        self.assertEqual(len(nodes), 1)

    def test_truncated_xml_fails_closed(self):
        with self.assertRaises(qa.QAError):
            qa.parse_hierarchy(XML[:35])
        with self.assertRaises(qa.QAError):
            qa.parse_hierarchy("<hierarchy><node></hierarchy>")

    @patch("capture_story.adb")
    @patch("capture_story.visible_nodes")
    def test_prefers_semantics_resource_id(self, nodes, adb):
        wrong = {"label": "Explorar cursos do EAD sem cadastro",
                 "resource_id": "something-else",
                 "bounds": (10, 10, 30, 30),
                 "enabled": True, "clickable": True}
        right = {"label": "", "resource_id": "ead-public-explore",
                 "bounds": (100, 200, 500, 300),
                 "enabled": True, "clickable": True}
        nodes.return_value = [wrong, right]
        self.assertTrue(qa.tap_text("adb", "emulator-5554", "Explorar cursos do EAD sem cadastro",
                                    resource_id="ead-public-explore", timeout=1))
        adb.assert_called_once_with("adb", "emulator-5554", "shell", "input", "tap",
                                    "300", "250")

    @patch("capture_story.adb")
    @patch("capture_story.visible_nodes")
    def test_content_description_fallback(self, nodes, adb):
        nodes.return_value = qa.parse_hierarchy(XML.replace('resource-id="ead-public-explore"',
                                                            'resource-id=""'))
        self.assertTrue(qa.tap_text("adb", "emulator-5554", "Explorar cursos do EAD sem cadastro",
                                    resource_id="ead-public-explore", timeout=1))
        self.assertEqual(adb.call_args.args[-2:], ("300", "250"))

    @patch("capture_story.adb")
    @patch("capture_story.visible_nodes")
    def test_unknown_action_never_tapped(self, nodes, adb):
        nodes.return_value = qa.parse_hierarchy(XML)
        with patch("capture_story.time.sleep", return_value=None):
            self.assertFalse(qa.tap_text("adb", "emulator-5554", "Enviar dados de aluno",
                                         timeout=0.05))
        adb.assert_not_called()

    @patch("capture_story.time.sleep", return_value=None)
    @patch("capture_story.visible_nodes")
    def test_waits_for_flutter_first_frame(self, nodes, _sleep):
        nodes.side_effect = [[], qa.parse_hierarchy(XML)]
        candidate = qa.locate_node("adb", "emulator-5554", "Explorar cursos do EAD sem cadastro",
                                   timeout=1)
        self.assertEqual(candidate["bounds"], (100, 200, 500, 300))
        self.assertEqual(nodes.call_count, 2)

    @patch("capture_story.adb")
    def test_bad_dump_retried_and_not_reported_as_success(self, adb):
        adb.side_effect = ["", "<hierarchy", "", "<hierarchy", "", ""]
        with patch("capture_story.time.sleep", return_value=None):
            self.assertEqual(qa.visible_nodes("adb", "emulator-5554"), [])
        self.assertEqual(adb.call_count, 6)


if __name__ == "__main__":
    unittest.main()
