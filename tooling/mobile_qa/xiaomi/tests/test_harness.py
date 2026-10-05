import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", ".."))
from mobile_qa.xiaomi import harness as h  # noqa: E402

QA = "com.tutortds_cartilhas.dev.dynamicqa.r123"


class HarnessTests(unittest.TestCase):
    def test_package_validation(self):
        self.assertEqual(h.validate_package(QA), QA)
        for bad in ("com.tutortds_cartilhas", "com.tutortds_cartilhas.dev", "", "com.other", QA + ";rm"):
            with self.assertRaises(h.InvalidPackage):
                h.validate_package(bad)

    def test_destructive_blocked(self):
        for args in (["uninstall", QA], ["shell", "pm", "clear", QA], ["install", "a.apk"],
                     ["shell", "screencap", "/sdcard/a.png"], ["shell", "rm", "-rf", "/"], ["reboot"]):
            with self.assertRaises(h.BlockedCommand):
                h.build_command("adb", None, args)

    def test_allowed(self):
        self.assertEqual(h.build_command("adb", "S", ["shell", "pidof", QA]), ["adb", "-s", "S", "shell", "pidof", QA])
        with self.assertRaises(h.BlockedCommand):
            h.build_command("adb", None, ["shell", "pidof", "com.tutortds_cartilhas.dev"])

    def test_sanitize(self):
        s = h.sanitize_text("****** ****** cpf 123.456.789-09 a@b.com serial ABCD1234", "ABCD1234")
        for leak in ("abc", "xyz.1", "123.456.789-09", "a@b.com", "ABCD1234"):
            self.assertNotIn(leak, s)

    def test_parsers(self):
        d = h.parse_adb_devices("List of devices attached\nABC123\tdevice\nXYZ\tunauthorized\n")
        self.assertEqual([x["state"] for x in d], ["device", "unauthorized"])
        self.assertEqual(h.parse_package_version("versionCode=7 minSdk=1\n versionName=1.2.3"),
                         {"versionName": "1.2.3", "versionCode": 7})
        self.assertEqual(h.parse_pid("123 456\n"), [123, 456])

    def test_dry_run_default(self):
        r = h.collect(QA, None, False)
        self.assertEqual(r["mode"], "dry-run")
        self.assertEqual(r["screenshot"], "disabled")
        self.assertNotIn("device", r)


if __name__ == "__main__":
    unittest.main()
