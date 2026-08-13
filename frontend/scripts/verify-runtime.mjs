import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url));
const frontendDirectory = path.resolve(scriptsDirectory, '..');
const repositoryDirectory = path.resolve(frontendDirectory, '..');

const sourceDirectory = path.join(frontendDirectory, 'apps/crystal-viewer/dist');
const runtimeDirectory = path.join(
  repositoryDirectory,
  '+kssolv/+ui/+components/+figuredocument/@MoleculeDisplay/CrystalViewer',
);

async function readManifest(directory) {
  const value = JSON.parse(await readFile(path.join(directory, 'build-manifest.json'), 'utf8'));
  if (
    value.schemaVersion !== 1 ||
    value.application !== 'crystal-viewer' ||
    typeof value.entryFile !== 'string' ||
    !/^[a-f0-9]{64}$/u.test(value.entrySha256)
  ) {
    throw new Error(`Invalid CrystalViewer build manifest in ${directory}`);
  }
  return value;
}

async function entryDigest(directory, manifest) {
  return createHash('sha256')
    .update(await readFile(path.join(directory, manifest.entryFile)))
    .digest('hex');
}

const sourceManifest = await readManifest(sourceDirectory);
const runtimeManifest = await readManifest(runtimeDirectory);
const sourceDigest = await entryDigest(sourceDirectory, sourceManifest);
const runtimeDigest = await entryDigest(runtimeDirectory, runtimeManifest);

if (sourceDigest !== sourceManifest.entrySha256) {
  throw new Error(`CrystalViewer dist hash mismatch: ${sourceDigest}`);
}
if (runtimeDigest !== runtimeManifest.entrySha256) {
  throw new Error(`CrystalViewer runtime hash mismatch: ${runtimeDigest}`);
}
if (JSON.stringify(sourceManifest) !== JSON.stringify(runtimeManifest)) {
  throw new Error('CrystalViewer dist and MATLAB runtime manifests differ. Run pnpm sync:runtime.');
}

console.log(
  `CrystalViewer runtime verified: ${runtimeManifest.sourceRevision} ${runtimeManifest.entrySha256}`,
);
