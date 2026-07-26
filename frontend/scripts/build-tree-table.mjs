import { cp, mkdir, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url));
const appDirectory = path.resolve(scriptsDirectory, '../apps/tree-table');
const outputDirectory = path.join(appDirectory, 'dist');

await rm(outputDirectory, { recursive: true, force: true });
await mkdir(outputDirectory, { recursive: true });
await cp(
  path.join(appDirectory, 'TreeTable.html'),
  path.join(outputDirectory, 'TreeTable.html'),
);
await cp(
  path.join(appDirectory, 'README.md'),
  path.join(outputDirectory, 'README.md'),
);
await cp(
  path.join(appDirectory, '.gitignore'),
  path.join(outputDirectory, '.gitignore'),
);
await cp(path.join(appDirectory, 'assets'), path.join(outputDirectory, 'assets'), {
  recursive: true,
});
