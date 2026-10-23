#!/usr/bin/env python3
"""Compile a Linux Online payload; CPU only unless --include-gpu is specified.

Compilation uses a disposable source snapshot, so CPU specialization never edits
working-tree files or the upstream KSSOLV submodule. No Runtime manifest is pruned.
"""
from __future__ import annotations

import argparse
from contextlib import nullcontext
import hashlib
import json
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CORE = Path('+kssolv/+core/kssolv-3o')


def normalize_native_links(root: Path, patchelf: str) -> list[dict]:
    """Relocate existing MEX dependencies in the disposable build snapshot.

    This edits ELF metadata only; it compiles no native source and leaves the
    repository binaries untouched. Runtime's launcher resolves MATLAB libraries.
    """
    binaries = sorted(root.rglob('*.mexa64'))
    if binaries and not shutil.which(patchelf):
        raise RuntimeError('Linux MEX packaging requires patchelf; provide --patchelf PATH')
    matlab_libraries = {'libmex.so', 'libmx.so', 'libmat.so',
                        'libMatlabDataArray.so', 'libMatlabEngine.so'}
    manifest = []
    for binary in binaries:
        def inspect(option):
            return subprocess.check_output([patchelf, option, str(binary)], text=True).strip()
        needed = inspect('--print-needed').splitlines()
        replacements = []
        for library in needed:
            if 'jvm' in library.lower() or 'jawt' in library.lower():
                raise RuntimeError(f'JVM dependency is forbidden: {binary.relative_to(root)}')
            if '/' in library:
                if Path(library).name not in matlab_libraries or not re.search(
                        r'/(?:bin|runtime)/glnxa64/[^/]+$', library):
                    raise RuntimeError(f'Unresolved native dependency in {binary.relative_to(root)}: {library}')
                replacements.extend(['--replace-needed', library, Path(library).name])
        rpath = inspect('--print-rpath').split(':')
        # Keep only paths relative to the packaged binary, never build-host paths.
        portable_rpath = [entry for entry in rpath if entry.startswith('$ORIGIN')]
        if any(rpath) and portable_rpath != rpath:
            replacements.extend(['--set-rpath', ':'.join(portable_rpath)])
        if replacements:
            subprocess.run([patchelf, *replacements, str(binary)], check=True)
        dependencies = inspect('--print-needed').splitlines()
        if any('/' in library for library in dependencies):
            raise RuntimeError(f'Native dependency relocation failed: {binary.relative_to(root)}')
        manifest.append({'File': str(binary.relative_to(root)),
                         'Dependencies': dependencies,
                         'SHA256': hashlib.sha256(binary.read_bytes()).hexdigest()})
    return manifest


def prepare_cpu_sources(root: Path) -> None:
    core = root / CORE / 'src'
    gpu_solvers = sorted((core / 'SCF/diagonalization').glob('*_gpu.m'))
    if len(gpu_solvers) != 6:
        raise RuntimeError('Review CPU specialization: upstream GPU solver set changed')
    for solver in gpu_solvers:
        solver.unlink()
    update = core / 'SCF/diagonalization/updateX.m'
    text = update.read_text()
    text, count = re.subn(r'\b(lobpcg|davidson2?|lanczos|chebyfilt|omm)_gpu\(', r'\1_cpu(', text)
    if count != 9:
        raise RuntimeError(f'Review CPU specialization: expected 9 GPU dispatches, found {count}')
    update.write_text(text)
    for name in ('KSFFT', 'Wavefun'):
        target = core / f'basicclass/{name}.m'
        text = target.read_text()
        text = re.sub(r"isa\(([^,\n]+),\s*'gpuArray'\)", 'false', text)
        text = text.replace('gpuArray.zeros(', 'zeros(')
        target.write_text(text)
    target = core / '+options/+mixin/ParallelComputing.m'
    text = target.read_text()
    original = 'if canUseGPU && gpuDeviceCount > 0'
    if text.count(original) != 1:
        raise RuntimeError('Review CPU specialization: GPU capability check changed')
    text = text.replace(original, 'if false % CPU-only distribution')
    text = text.replace('Parallel features cannot use GPU.',
                        'This distribution does not include GPU computation. Build with --include-gpu to enable it.')
    target.write_text(text)
    # Fail closed if the upstream core introduces another GPU execution path.
    for target in core.rglob('*.m'):
        if any(part in ('test', 'tests', '+test', '+tests') for part in target.parts):
            continue
        for line in target.read_text(errors='replace').splitlines():
            code = line.split('%', 1)[0]
            if re.search(r'\b(gpuArray|canUseGPU|gpuDeviceCount|gpuDevice)\b', code):
                raise RuntimeError(f'Unreviewed GPU dependency in {target.relative_to(root)}')


def build(args: argparse.Namespace) -> None:
    if platform.system() != 'Linux' or platform.machine() != 'x86_64':
        raise RuntimeError('Build the Online payload on Linux x86-64 with MATLAB Compiler')
    if not shutil.which(args.matlab):
        raise RuntimeError('MATLAB executable was not found')
    destination = Path(args.output or ROOT / ('Release/OnlineGPU/build' if args.include_gpu else 'Release/OnlineCPU/build')).resolve()
    if destination.exists() and any(destination.iterdir()):
        raise RuntimeError(f'Output directory must be empty: {destination}')
    work = nullcontext(str(Path(args.work_dir).resolve())) if args.work_dir else tempfile.TemporaryDirectory(prefix='kssolv-compile-')
    with work as directory:
        stage = Path(directory) / 'KSSOLV-Toolbox'
        stage.mkdir(parents=True)
        for source in ROOT.glob('*.m'):
            shutil.copy2(source, stage / source.name)
        for name in ('+kssolv', 'assets', 'resources', 'docs'):
            shutil.copytree(ROOT / name, stage / name,
                            ignore=shutil.ignore_patterns('.git', '.DS_Store', '__pycache__'))
        for name in ('.env.example', 'ks.ks', 'LICENSE', 'COMMERCIAL-LICENSE.md', 'THIRD-PARTY-LICENSES.md'):
            shutil.copy2(ROOT / name, stage / name)
        # Development entry points must not become Runtime startup hooks.
        for name in ('startup.m', 'buildfile.m'):
            (stage / CORE / name).unlink(missing_ok=True)
        if not args.include_gpu:
            prepare_cpu_sources(stage)
        native_libraries = normalize_native_links(stage, args.patchelf)
        command = ('nativeDataset=kssolv.analysis.spglib.Spglib.getDataset(eye(3)*5,[0 0 0],1,1,1e-5); '
                   'assert(nativeDataset.spacegroup_number==221); clear nativeDataset; '
                   'buildInstaller("none", false)')
        if not args.include_gpu:
            verifier = str(ROOT / 'scripts/docker').replace("'", "''")
            core_path = str(stage / CORE).replace("'", "''")
            command = (f"addpath('{verifier}'); verifyCPUBackend('{core_path}'); "
                       f"rmpath('{verifier}'); {command}")
        if args.llm_addon:
            addon = str(Path(args.llm_addon).resolve()).replace("'", "''")
            command = (f"mpminstall('{addon}',InPlace=true,Temporary=true,"
                       f"Prompt=false,InstallDependencies=false); {command}")
        print(f'Compiling Linux application: IncludeGPU={args.include_gpu}', flush=True)
        subprocess.run([args.matlab, '-nojvm', '-batch',
                        command], cwd=stage, check=True)
        payload = stage / '.buildtool/standalone/build'
        manifest = json.loads((payload / 'buildresult.json').read_text())
        gpu_dependencies = [item for item in manifest['RuntimeDependencies']
                            if 'GPU' in item['DisplayName'].upper() and
                            str(item.get('Optional', 'no')).lower() != 'yes']
        if gpu_dependencies and not args.include_gpu:
            raise RuntimeError(f'CPU build still requires GPU Runtime: {gpu_dependencies}')
        metadata_file = payload / 'runtime-metadata.json'
        metadata = json.loads(metadata_file.read_text())
        if metadata['Architecture'] != 'glnxa64' or metadata['JVMEnabled']:
            raise RuntimeError('Online deployment requires Linux x86-64 and no JVM')
        metadata['IncludeGPU'] = args.include_gpu
        metadata['NativeLibraries'] = native_libraries
        metadata_file.write_text(json.dumps(metadata, indent=2) + '\n')
        destination.mkdir(parents=True, exist_ok=True)
        # Output must be new/empty to avoid stale binaries from an earlier build.
        if any(destination.iterdir()):
            raise RuntimeError(f'Output directory must be empty: {destination}')
        shutil.copytree(payload, destination, dirs_exist_ok=True)
        print(f'Payload: {destination}', flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--include-gpu', action='store_true', help='Include GPU computation and Runtime dependencies')
    parser.add_argument('--matlab', default='matlab')
    parser.add_argument('--patchelf', default='patchelf', help='Prebuilt patchelf executable for Linux MEX dependency relocation')
    parser.add_argument('--work-dir', help='New build workspace to retain for diagnostics (default: temporary directory)')
    parser.add_argument('--llm-addon', help='LLM Add-On 4.9+ package folder to load for this build session')
    parser.add_argument('--output', help='Empty payload output directory (default: Release/OnlineCPU/build or Release/OnlineGPU/build)')
    build(parser.parse_args())


if __name__ == '__main__':
    main()
