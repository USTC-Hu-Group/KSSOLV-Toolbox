# KSSOLV 前端组件

这里保存嵌入 MATLAB `uihtml` 组件的前端源代码。

## 目录

- `apps/tree-table`：Project Browser 使用的 TreeTable 静态组件。
- `apps/workflow`：Workflow 使用的 Vite/Vue 应用。

`+kssolv` 下的对应目录只保存 MATLAB 运行时需要的构建产物，不应直接修改。

## 开发

安装依赖：

```bash
pnpm install
```

构建所有组件：

```bash
pnpm build
```

将构建产物同步到 MATLAB 运行时目录：

```bash
pnpm sync:runtime
```

也可以一次完成构建和同步：

```bash
pnpm deploy
```

单独开发 Workflow：

```bash
pnpm --filter @kssolv/workflow dev
```
