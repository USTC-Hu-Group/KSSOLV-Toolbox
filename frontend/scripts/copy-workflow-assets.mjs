import { cp, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url));
const appDirectory = path.resolve(scriptsDirectory, '../apps/workflow');
const outputAssetsDirectory = path.join(appDirectory, 'dist/assets');

await mkdir(outputAssetsDirectory, { recursive: true });

for (const assetDirectory of ['data', 'icons']) {
  await cp(
    path.join(appDirectory, 'src/assets', assetDirectory),
    path.join(outputAssetsDirectory, assetDirectory),
    { recursive: true },
  );
}
