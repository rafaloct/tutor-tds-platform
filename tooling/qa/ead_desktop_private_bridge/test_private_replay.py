"""Offline safety tests: no Android, WordPress or network is accessed."""
from __future__ import annotations
from unittest import TestCase
from unittest.mock import patch
import replay_android as replay
import synthetic_http_audit_proxy as proxy


XML = ('<?xml version="1.0" encoding="UTF-8"?>'
       '<hierarchy rotation="0">'
       '<node text="" content-desc="LABORATÓRIO INTERNO · DADOS FICTÍCIOS" '
       'resource-id="qa-synthetic-learnpress" enabled="true" '
       'bounds="[30,200][500,300]"/>'
       '</hierarchy>')


class SafetyTests(TestCase):
    def test_hierarchy_valid(self):
        nodes = replay.parse_nodes(XML)
        self.assertEqual(len(nodes), 1)
        self.assertEqual(nodes[0]["bounds"], [30, 200, 500, 300])
        self.assertEqual(nodes[0]["id"], "qa-synthetic-learnpress")

    def test_hierarchy_preamble(self):
        self.assertEqual(len(replay.parse_nodes("UI dump succeeded\n" + XML)), 1)

    def test_hierarchy_truncated_fails_closed(self):
        with self.assertRaises(replay.Blocked):
            replay.parse_nodes(XML[:-25])

    def test_hierarchy_invalid_fails_closed(self):
        with self.assertRaises(replay.Blocked):
            replay.parse_nodes("<hierarchy><node></hierarchy>")

    def test_loopback_only_course_and_lesson(self):
        self.assertEqual(
            proxy.route_label("/?rest_route=%2Ftds-learning%2Fv1%2Fcourses%2F12%2Flessons%2F13"),
            "lesson_13")
        self.assertEqual(
            proxy.route_label("/?rest_route=/tds-learning/v1/courses/12/curriculum"),
            "curriculum_12")

    def test_other_courses_never_proxied(self):
        for path in ("/wp-admin/", "/?rest_route=/tds-learning/v1/courses/11/curriculum",
                     "/?rest_route=/tds-learning/v1/courses/12/curriculum&extra=true",
                     "https://ead.ipexdesenvolvimento.cloud/"):
            with self.subTest(path=path):
                self.assertIsNone(proxy.route_label(path))

    def test_timeout_safe_no_coordinate_tap(self):
        with patch.object(replay, "wait_node", return_value=None):
            with patch.object(replay, "adb") as a:
                with self.assertRaises(replay.Blocked):
                    replay.tap("adb", "unauthorized button", timeout=1)
                a.assert_not_called()
