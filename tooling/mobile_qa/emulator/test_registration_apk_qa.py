import argparse
import tempfile
import unittest
import zipfile
import subprocess
import copy
from pathlib import Path
from unittest.mock import patch

import registration_apk_qa as q

PKG = q.PLAY + '.dev.dynamicqa.r' + 'a' * 32
URL = 'https://' + q.HOST + '/cadastro/?utm_source=tutor_tds_app&utm_medium=app&utm_campaign=ead_signup&utm_content=welcome_signup'


def tree(package=PKG, body=''):
    return '<hierarchy><node package="' + package + '">' + body + '</node></hierarchy>'


class RegistrationQATest(unittest.TestCase):
    def test_text_evidence_bytes_are_portable_without_crcrlf(self):
        with tempfile.TemporaryDirectory() as tmp:
            runner = self.runner(tmp)
            runner.save('output.txt', 'first\r\nsecond\n')
            self.assertEqual((runner.out/'output.txt').read_bytes(), b'first\nsecond\n')

    def test_dom_requires_focused_correct_form_visible_fields_and_post_action(self):
        fields = [{'name': n, 'type': t, 'visible': True, 'disabled': False}
                  for n, t in [('nome', 'text'), ('email', 'email'), ('senha', 'password'), ('', 'submit')]]
        data = {'url': URL, 'ready': 'complete', 'visible': 'visible', 'focus': True,
                'forms': [{'action': f'https://{q.HOST}/wp-admin/admin-post.php', 'method': 'post',
                           'institutional': True, 'fields': fields}]}
        self.assertTrue(q.dom_form_loaded(data))
        for change in ({'focus': False}, {'visible': 'hidden'}, {'ready': 'loading'}, {'url': 'about:blank'}):
            self.assertFalse(q.dom_form_loaded(dict(data, **change)))
        for key, value in [('action', 'https://evil.test/'), ('method', 'get'), ('institutional', False)]:
            bad = copy.deepcopy(data)
            bad['forms'][0][key] = value
            self.assertFalse(q.dom_form_loaded(bad))
        for key, value in [('visible', False), ('disabled', True)]:
            bad = copy.deepcopy(data)
            bad['forms'][0]['fields'][2][key] = value
            self.assertFalse(q.dom_form_loaded(bad))

    def test_dom_probe_does_not_read_values_or_submit(self):
        self.assertNotIn('.submit(', q.FORM_PROBE)
        self.assertNotIn('cookie', q.FORM_PROBE)
        self.assertNotIn('e.value', q.FORM_PROBE)

    def runner(self, tmp):
        return q.Runner(argparse.Namespace(output=str(Path(tmp) / 'run'), source_commit='a' * 40,
                        sha256='b' * 64, package=PKG, serial='emulator-5554', adb_port=5037))

    def test_uiautomator_stderr_failure_is_preserved_even_with_exit_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            runner = self.runner(tmp)
            with patch.object(q.subprocess, 'run', return_value=subprocess.CompletedProcess(
                    ['adb'], 0, b'', b'ERROR: null root node')):
                self.assertEqual(runner.command(['adb'], combined=True), b'ERROR: null root node')

    def test_failed_dump_does_not_read_stale_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            runner = self.runner(tmp)
            with patch.object(runner, 'foreground', return_value=PKG + '/.Main'), \
                 patch.object(runner, 'shell', return_value='ERROR: null root node') as shell:
                with self.assertRaises(q.CheckFailed):
                    runner.snapshot('welcome', PKG)
            self.assertEqual(shell.call_count, 1)  # No cat of an old XML.
            self.assertIn(runner.run_id, shell.call_args.args[2])
            self.assertTrue((runner.out / 'welcome-dump.txt').exists())

    def test_wrong_foreground_prevents_any_ui_inspection(self):
        with tempfile.TemporaryDirectory() as tmp:
            runner = self.runner(tmp)
            with patch.object(runner, 'foreground', return_value='old.qa/.Main'), \
                 patch.object(runner, 'shell') as shell:
                with self.assertRaises(q.CheckFailed):
                    runner.snapshot('welcome', PKG)
            shell.assert_not_called()

    def test_engine_abi_not_inferred_from_plugin_libraries(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / 'mixed.apk'
            with zipfile.ZipFile(apk, 'w') as z:
                z.writestr('lib/arm64-v8a/libflutter.so', b'engine')
                z.writestr('lib/x86_64/libsqlite3.so', b'plugin')
            self.assertEqual(q.flutter_abis(apk), ['arm64-v8a'])

    def test_launcher_from_apk_not_first_installed_package(self):
        self.assertEqual(q.parse_badging("package: name='" + PKG + "' versionCode='15'\nlaunchable-activity: name='com.tutortds_cartilhas.MainActivity'"),
                         (PKG, 'com.tutortds_cartilhas.MainActivity'))
        with self.assertRaises(q.CheckFailed):
            q.parse_badging('package: name=missing')

    def test_resumed_activity_not_historical_task(self):
        data = 'Hist #0: ActivityRecord{a u0 wrong/.Main t1}\n topResumedActivity=ActivityRecord{b u0 ' + PKG + '/com.tutortds_cartilhas.MainActivity t2}'
        self.assertTrue(q.resumed_component(data).startswith(PKG + '/'))
        with self.assertRaises(q.CheckFailed):
            q.resumed_component(data.split('\n')[0])

    def test_multiple_resumed_displays_are_ambiguous(self):
        with self.assertRaises(q.CheckFailed):
            q.resumed_component('topResumedActivity=ActivityRecord{a u0 p/.A}\ntopResumedActivity=ActivityRecord{b u0 q/.B}')

    def test_null_malformed_and_wrong_package_never_pass(self):
        for data in ('ERROR: null root node', '<hierarchy/>', '<bad', tree('old.qa')):
            with self.subTest(data=data), self.assertRaises(q.CheckFailed):
                q.current_tree(data, PKG)

    def test_cta_must_be_exact_enabled_clickable_and_unique(self):
        node = f'<node package="{PKG}" content-desc="{q.CTA}" enabled="true" clickable="true" bounds="[10,20][110,80]"/>'
        root = q.current_tree(tree(body=node), PKG)
        self.assertEqual(q.center(q.select_cta(root, PKG)), (60, 50))
        for body in (node + node, node.replace('clickable="true"', 'clickable="false"'), node.replace(PKG, 'old.qa')):
            with self.subTest(body=body), self.assertRaises(q.CheckFailed):
                q.select_cta(q.current_tree(tree(body=body), PKG), PKG)

    def test_url_requires_exact_origin_path_and_campaign_without_extra_data(self):
        self.assertTrue(q.registration_url(URL))
        for invalid in (URL.replace('https:', 'http:'), URL.replace('/cadastro/', '/wp-login.php'),
                        URL.replace(q.HOST, q.HOST + '.evil.test'), URL + '&email=private',
                        URL + '&utm_source=other', URL + '#fragment',
                        URL.replace(q.HOST, 'user@' + q.HOST), URL.replace(q.HOST, q.HOST + ':443')):
            with self.subTest(url=invalid):
                self.assertFalse(q.registration_url(invalid))

    def test_browser_toolbar_and_error_page_cannot_prove_form(self):
        root = q.current_tree(tree('com.android.chrome', '<node text="Nome E-mail Senha Criar conta"/>'), 'com.android.chrome')
        self.assertFalse(q.form_visible(root, 'com.android.chrome'))

    def test_form_requires_three_editable_fields_inside_browser_webview(self):
        body = '<node class="android.webkit.WebView" package="com.android.chrome" text="Nome E-mail Senha Criar conta">'
        body += '<node class="android.widget.EditText" enabled="true"/>' * 3 + '</node>'
        root = q.current_tree(tree('com.android.chrome', body), 'com.android.chrome')
        self.assertTrue(q.form_visible(root, 'com.android.chrome'))
        root = q.current_tree(tree('com.android.chrome', body.replace('enabled="true"', 'enabled="false"')), 'com.android.chrome')
        self.assertFalse(q.form_visible(root, 'com.android.chrome'))

    def test_empty_bounds_rejected(self):
        with self.assertRaises(q.CheckFailed):
            q.center({'bounds': '[0,0][0,0]'})

    def test_failed_prerequisite_leaves_e2e_not_run_and_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            args = argparse.Namespace(output=str(Path(tmp) / 'run'), source_commit='a' * 40,
                                      sha256='b' * 64, package=PKG, serial='emulator-5554', adb_port=5037)
            runner = q.Runner(args)
            with patch.object(runner, 'execute', side_effect=q.CheckFailed('bad artifact')):
                self.assertEqual(runner.run(), 1)
            self.assertEqual(runner.record['e2e'], 'NOT_RUN')
            self.assertEqual(runner.record['results']['artifact'], 'FAIL')
            self.assertEqual(runner.record['results']['handoff'], 'NOT_RUN')
            self.assertTrue((Path(args.output) / 'receipt.json').exists())

    def test_failed_form_cannot_be_e2e_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            args = argparse.Namespace(output=str(Path(tmp) / 'run'), source_commit='a' * 40,
                                      sha256='b' * 64, package=PKG, serial='emulator-5554', adb_port=5037)
            runner = q.Runner(args)
            runner.stage = 'registration_form'
            with patch.object(runner, 'execute', side_effect=q.CheckFailed('network error page')):
                self.assertEqual(runner.run(), 1)
            self.assertEqual(runner.record['e2e'], 'FAIL')
            self.assertEqual(runner.record['results']['return_to_app'], 'NOT_RUN')


if __name__ == '__main__':
    unittest.main()
