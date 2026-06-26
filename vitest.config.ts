import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: {
    extensions: ['.ets', '.ts', '.js'],
  },
  esbuild: {
    // 让 esbuild 把 .ets 当 TypeScript 处理
    include: /\.(ts|ets)$/,
    loader: 'ts',
  },
  test: {
    globals: true,
    include: ['tests/**/*.test.ts'],
    setupFiles: ['tests/setup.ts'],
  },
});
