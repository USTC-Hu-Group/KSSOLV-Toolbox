import { createHash } from 'node:crypto';
import { access, cp, mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url));
const frontendDirectory = path.resolve(scriptsDirectory, '..');
const repositoryDirectory = path.resolve(frontendDirectory, '..');

const mappings = [
  {
    source: path.join(frontendDirectory, 'apps/tree-table/dist'),
    target: path.join(
      repositoryDirectory,
      '+kssolv/+ui/+components/+databrowser/@ProjectBrowser/TreeTable',
    ),
  },
  {
    source: path.join(frontendDirectory, 'apps/workflow/dist'),
    target: path.join(
      repositoryDirectory,
      '+kssolv/+ui/+components/+figuredocument/@Workflow/workflow',
    ),
  },
  {
    source: path.join(frontendDirectory, 'apps/crystal-viewer/dist'),
    target: path.join(
      repositoryDirectory,
      '+kssolv/+ui/+components/+figuredocument/@MoleculeDisplay/CrystalViewer',
    ),
  },
  {
    source: path.join(frontendDirectory, 'apps/volume-viewer/dist'),
    target: path.join(
      repositoryDirectory,
      '+kssolv/+ui/+components/+figuredocument/@VolumeDisplay/VolumeViewer',
    ),
  },
];

async function normalizeTextArtifacts(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      await normalizeTextArtifacts(file);
      continue;
    }
    if (!/\.(?:css|html|js)$/u.test(entry.name)) continue;
    const source = await readFile(file, 'utf8');
    const normalized = source.replace(/[\t ]+$/gmu, '');
    if (normalized !== source) await writeFile(file, normalized, 'utf8');
  }
}

async function verifyBuildManifest(directory) {
  const manifestPath = path.join(directory, 'build-manifest.json');
  try {
    await access(manifestPath);
  } catch (error) {
    if (error?.code === 'ENOENT') return;
    throw error;
  }
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  if (manifest.schemaVersion !== 1 || typeof manifest.entryFile !== 'string') {
    throw new Error(`Invalid runtime build manifest: ${manifestPath}`);
  }
  const entryPath = path.join(directory, manifest.entryFile);
  const digest = createHash('sha256').update(await readFile(entryPath)).digest('hex');
  if (digest !== manifest.entrySha256) {
    throw new Error(
      `Runtime entry hash mismatch for ${entryPath}: expected ${manifest.entrySha256}, got ${digest}`,
    );
  }
}

for (const { source, target } of mappings) {
  await access(source);
  await verifyBuildManifest(source);

  if (!target.startsWith(`${repositoryDirectory}${path.sep}`)) {
    throw new Error(`Refusing to write outside the repository: ${target}`);
  }

  await rm(target, { recursive: true, force: true });
  await mkdir(path.dirname(target), { recursive: true });
  await cp(source, target, { recursive: true });
  await normalizeTextArtifacts(target);
  await verifyBuildManifest(target);
  console.log(`${path.relative(repositoryDirectory, source)} -> ${path.relative(repositoryDirectory, target)}`);
}
