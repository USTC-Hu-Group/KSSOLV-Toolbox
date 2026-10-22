"""Stage developer-supplied PDFs in an isolated, reproducible image context."""
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import shutil
import tempfile


def validate_pdf(path):
    path = Path(path).expanduser().resolve(strict=True)
    if not path.is_file():
        raise ValueError(f"Manual must be a PDF file: {path}")
    with path.open('rb') as stream:
        if not stream.read(8).startswith(b'%PDF-'):
            raise ValueError(f"Manual has no PDF header: {path}")
        stream.seek(max(0, path.stat().st_size - 2048))
        if b'%%EOF' not in stream.read():
            raise ValueError(f"Manual is incomplete (missing PDF EOF): {path}")
    return path


@contextmanager
def build_context(root, manual_zh=None, manual_en=None):
    sources = {locale: validate_pdf(path) for locale, path in
               [('zh-CN', manual_zh), ('en-US', manual_en)] if path is not None}
    with tempfile.TemporaryDirectory(prefix='kssolv-portal-build-') as directory:
        context = Path(directory)
        # Only image inputs belong in the context; exclude secrets, tests and admin data.
        root = Path(root).resolve()
        portal = root.parents[1] / 'server' / 'portal'
        shutil.copyfile(root / 'Dockerfile', context / 'Dockerfile')
        production = context / 'portal'
        production.mkdir()
        for name in ['portal.py', 'kube.py', 'profiles.py', 'portal_control.py', 'portal_protocol.py', 'nginx.conf']:
            shutil.copyfile(portal / name, production / name)
        shutil.copytree(portal / 'public', production / 'public')
        destination = context / 'manuals'
        destination.mkdir()
        manifest = {}
        for locale, source in sources.items():
            target = destination / (locale + '.pdf')
            shutil.copyfile(source, target)
            target.chmod(0o644)
            manifest[locale] = {'file': target.name, 'bytes': target.stat().st_size,
                                'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
        (destination / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        yield context
