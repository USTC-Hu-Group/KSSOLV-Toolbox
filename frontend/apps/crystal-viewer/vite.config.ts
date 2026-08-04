import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vitest/config';
import { viteSingleFile } from 'vite-plugin-singlefile';

export default defineConfig({
  base: './',
  plugins: [vue(), viteSingleFile()],
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
