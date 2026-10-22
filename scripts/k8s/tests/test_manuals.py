
import _k8s_paths
from pathlib import Path
import tempfile
import unittest
import json
from manuals import build_context, validate_pdf


class ManualBuildTest(unittest.TestCase):
    def source(self, directory):
        project=Path(directory)/'source'
        root=project/'scripts/k8s'; root.mkdir(parents=True)
        (root/'Dockerfile').write_text('fixture')
        portal=project/'server/portal'; portal.mkdir(parents=True)
        for name in ['portal.py','kube.py','profiles.py','portal_control.py','portal_protocol.py','nginx.conf']:
            (portal/name).write_text('fixture')
        (portal/'public').mkdir(); (portal/'public/app.js').write_text('fixture')
        return root

    def test_manuals_can_both_be_omitted(self):
        with tempfile.TemporaryDirectory() as directory:
            with build_context(self.source(directory)) as context:
                self.assertEqual(json.loads((context/'manuals/manifest.json').read_text()),{})
                self.assertEqual(list((context/'manuals').glob('*.pdf')),[])

    def test_each_language_is_optional_independently(self):
        for locale in ['zh-CN','en-US']:
            with self.subTest(locale=locale), tempfile.TemporaryDirectory() as directory:
                root=self.source(directory)
                pdf=Path(directory)/'manual.pdf';pdf.write_bytes(b'%PDF-1.3\nfixture\n%%EOF\n')
                with build_context(root, pdf if locale=='zh-CN' else None,
                                   pdf if locale=='en-US' else None) as context:
                    self.assertEqual(list(json.loads((context/'manuals/manifest.json').read_text())),[locale])
                    self.assertEqual([p.name for p in (context/'manuals').glob('*.pdf')],[locale+'.pdf'])

    def test_build_cli_accepts_omitted_manual_parameters(self):
        from deploy import parse_args
        args=parse_args(['--context','test','--secrets-dir','/tmp/test-secrets',
                         '--accept-runtime-license','--build'])
        self.assertIsNone(args.manual_zh); self.assertIsNone(args.manual_en)

    def test_isolated_context_preserves_source_bytes_and_records_checksums(self):
        import hashlib
        import json
        with tempfile.TemporaryDirectory() as directory:
            zh, en = Path(directory)/'中文.pdf', Path(directory)/'English.pdf'
            zh.write_bytes(b'%PDF-1.3\nChinese bytes\n%%EOF\n')
            en.write_bytes(b'%PDF-1.3\nEnglish bytes\n%%EOF\n')
            root = self.source(directory)
            (root/'admin').mkdir()
            with build_context(root, zh, en) as context:
                for locale, source in [('zh-CN',zh), ('en-US',en)]:
                    target=context/'manuals'/(locale+'.pdf')
                    self.assertEqual(target.read_bytes(),source.read_bytes())
                    manifest=json.loads((context/'manuals/manifest.json').read_text())
                    self.assertEqual(manifest[locale]['sha256'],hashlib.sha256(source.read_bytes()).hexdigest())
                self.assertFalse((context/'admin').exists())
                self.assertTrue((context/'Dockerfile').exists())
                self.assertTrue((context/'portal/portal.py').is_file())
                self.assertTrue((context/'portal/public/app.js').is_file())
                self.assertFalse((context/'portal.py').exists())
            self.assertFalse(context.exists())
            self.assertTrue(zh.exists())

    def test_non_pdf_missing_and_truncated_inputs_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            file=Path(directory)/'bad.pdf'
            for content in [b'not PDF', b'%PDF-1.7\ntruncated']:
                file.write_bytes(content)
                with self.assertRaises(ValueError): validate_pdf(file)
            with self.assertRaises(FileNotFoundError): validate_pdf(Path(directory)/'missing.pdf')
            # An explicit but invalid input must not silently fall back to GitHub.
            with self.assertRaises(ValueError):
                with build_context(Path(__file__).parents[1],file,None):
                    self.fail('invalid explicit PDF was accepted')
