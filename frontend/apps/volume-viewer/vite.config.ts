import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  base: './',
  plugins: [vue()],
  build: {
    target: 'es2020',
    sourcemap: false,
    chunkSizeWarningLimit: 950,
    rolldownOptions: {
      output: {
        entryFileNames: 'assets/volume-viewer.js',
        assetFileNames: 'assets/volume-viewer.[ext]',
      },
    },
  },
  test: {
    environment: 'happy-dom',
  },
});
