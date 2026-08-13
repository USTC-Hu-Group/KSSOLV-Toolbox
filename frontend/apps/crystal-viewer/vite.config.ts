import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vitest/config';
import { viteSingleFile } from 'vite-plugin-singlefile';

const repositoryDirectory = fileURLToPath(new URL('../../..', import.meta.url));
const outputHtml = fileURLToPath(new URL('./dist/index.html', import.meta.url));
const outputManifest = fileURLToPath(new URL('./dist/build-manifest.json', import.meta.url));
const packageMetadata = JSON.parse(
  readFileSync(new URL('./package.json', import.meta.url), 'utf8'),
) as { version: string };

const sourceRevision = (): string => {
  const override = process.env.KSSOLV_SOURCE_REVISION?.trim();
  if (override) return override;
  try {
    const revision = execFileSync('git', ['rev-parse', 'HEAD'], {
      cwd: repositoryDirectory,
      encoding: 'utf8',
    }).trim();
    const dirty =
      execFileSync('git', ['status', '--porcelain', '--untracked-files=no'], {
        cwd: repositoryDirectory,
        encoding: 'utf8',
      }).trim().length > 0;
    return `${revision}${dirty ? '-dirty' : ''}`;
  } catch {
    return 'unknown';
  }
};

const buildManifestPlugin = () => ({
  name: 'kssolv-build-manifest',
  enforce: 'post' as const,
  apply: 'build' as const,
  closeBundle() {
    const generatedHtml = readFileSync(outputHtml, 'utf8');
    const normalizedHtml = generatedHtml.replace(/[\t ]+$/gmu, '');
    if (normalizedHtml !== generatedHtml) writeFileSync(outputHtml, normalizedHtml, 'utf8');
    const entrySha256 = createHash('sha256').update(normalizedHtml, 'utf8').digest('hex');
    writeFileSync(
      outputManifest,
      `${JSON.stringify(
        {
          schemaVersion: 1,
          application: 'crystal-viewer',
          applicationVersion: packageMetadata.version,
          sourceRevision: sourceRevision(),
          builtAtUtc: new Date().toISOString(),
          entryFile: 'index.html',
          entrySha256,
        },
        null,
        2,
      )}\n`,
      'utf8',
    );
  },
});

export default defineConfig({
  base: './',
  plugins: [vue(), viteSingleFile(), buildManifestPlugin()],
  build: {
    target: 'es2020',
    sourcemap: false,
    chunkSizeWarningLimit: 750,
    rolldownOptions: {
      output: {
        entryFileNames: 'assets/crystal-viewer.js',
        assetFileNames: 'assets/crystal-viewer.[ext]',
      },
    },
  },
  test: {
    environment: 'happy-dom',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json-summary'],
      include: ['src/**/*.{ts,vue}'],
      exclude: ['src/main.ts', 'src/vite-env.d.ts'],
      thresholds: {
        statements: 40,
        branches: 40,
        functions: 40,
        lines: 40,
      },
    },
  },
});
