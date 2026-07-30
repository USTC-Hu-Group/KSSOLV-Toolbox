# KSSOLV 前端组件

这里保存嵌入 MATLAB `uihtml` 组件的前端源代码。

## 目录

- `apps/tree-table`：Project Browser 使用的 TreeTable 静态组件。
- `apps/workflow`：Workflow 使用的 Vite/Vue 应用。
- `apps/crystal-viewer`：基于 matgenlab `AtomicSceneSpec 2.0` 协议和 Three.js
  批渲染的晶体/分子结构查看器。
- `apps/volume-viewer`：读取 MATLAB `VolumeSceneSpec 1.0` 与分块二进制数据，
  显示 CHGCAR、Cube、XSF 的等值面、晶格切片、GPU 体渲染和原子结构叠加。
- `packages/atomic-scene`、`three-scene`、`matlab-bridge`、`volume-scene`：
  两个查看器共享的协议、相机和 MATLAB 通信基础。

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

单独开发并测试 Crystal Viewer：

```bash
pnpm --filter @kssolv/crystal-viewer dev
pnpm --filter @kssolv/crystal-viewer test
```

单独开发并测试 Volume Viewer：

```bash
pnpm --filter @kssolv/volume-viewer dev
pnpm --filter @kssolv/volume-viewer test
```

Volume Viewer 默认等待 MATLAB 发送体数据。如需在独立浏览器中加载内置演示数据，
请在开发服务器地址后添加 `?debugVolume=1`。

体数据格式、交互和故障排查见
[`docs/volume-viewer-user-guide.zh-CN.md`](../docs/volume-viewer-user-guide.zh-CN.md)。
