import { access, cp, mkdir, rm } from 'node:fs/promises';
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
];

for (const { source, target } of mappings) {
  await access(source);

  if (!target.startsWith(`${repositoryDirectory}${path.sep}`)) {
    throw new Error(`Refusing to write outside the repository: ${target}`);
  }

  await rm(target, { recursive: true, force: true });
  await mkdir(path.dirname(target), { recursive: true });
  await cp(source, target, { recursive: true });
  console.log(`${path.relative(repositoryDirectory, source)} -> ${path.relative(repositoryDirectory, target)}`);
}
