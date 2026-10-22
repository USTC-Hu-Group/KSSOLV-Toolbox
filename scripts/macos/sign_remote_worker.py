"""Sign native macOS code inside the portable remote MATLAB worker archive."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import zipfile


MACHO_MAGIC = {bytes.fromhex(value) for value in (
    'feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
    'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def sign_archive(archive, identity, report_path):
    archive = Path(archive)
    report_path = Path(report_path)
    input_hash = sha256(archive)
    previous = json.loads(report_path.read_text()) if report_path.is_file() else {}
    source_hash = (previous['SourceArchiveSHA256']
                   if previous.get('ArchiveSHA256') == input_hash else input_hash)
    native_files = []
    mode = stat.S_IMODE(archive.stat().st_mode)
    with tempfile.TemporaryDirectory(prefix='kssolv-sign-worker-') as directory:
        directory = Path(directory)
        with zipfile.ZipFile(archive) as source:
            entries = source.infolist()
            source.extractall(directory)
        for entry in entries:
            if entry.is_dir():
                continue
            path = directory / entry.filename
            with path.open('rb') as stream:
                magic = stream.read(4)
            if magic not in MACHO_MAGIC:
                continue
            description = subprocess.check_output(['file', '-b', str(path)], text=True)
            if 'Mach-O' not in description:
                continue
            subprocess.run(['codesign', '--force', '--options', 'runtime',
                            '--timestamp', '--sign', identity, str(path)], check=True)
            subprocess.run(['codesign', '--verify', '--strict', str(path)], check=True)
            signature = subprocess.check_output(['codesign', '-dvv', str(path)],
                                                stderr=subprocess.STDOUT, text=True)
            if 'Authority=Developer ID Application:' not in signature or 'Timestamp=' not in signature:
                raise RuntimeError('Worker native code requires Developer ID and a secure timestamp: ' + entry.filename)
            native_files.append({'Path': entry.filename, 'SHA256': sha256(path)})
        manifest_path = directory / 'remote-bundle-manifest.json'
        manifest = json.loads(manifest_path.read_text())
        if manifest['Version'] != 2:
            raise ValueError('Unsupported remote worker manifest version')
        paths = manifest['Files']
        if isinstance(paths, str):
            paths = [paths]
        canonical = '\n'.join(name + ':' + sha256(directory / name) for name in paths)
        manifest.update(FileCount=len(paths),
                        TotalBytes=sum((directory / name).stat().st_size for name in paths),
                        ContentIndexSha256=hashlib.sha256(canonical.encode('utf-8')).hexdigest())
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, separators=(',', ':')))
        with tempfile.TemporaryDirectory(prefix='.signed-worker-', dir=archive.parent) as output:
            result = Path(output) / archive.name
            with zipfile.ZipFile(result, 'w') as target:
                for entry in entries:
                    data = b'' if entry.is_dir() else (directory / entry.filename).read_bytes()
                    target.writestr(entry, data)
            result.chmod(mode)
            os.replace(result, archive)
    report = {'Version': 1, 'Archive': archive.name, 'SourceArchiveSHA256': source_hash,
              'ArchiveSHA256': sha256(archive), 'NativeFiles': native_files}
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--identity', required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(sign_archive(args.archive, args.identity, args.report), indent=2))
