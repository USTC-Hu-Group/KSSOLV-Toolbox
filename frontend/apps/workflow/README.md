# Workflow

用于 KSSOLV Toolbox 的工作流组件。

## 开发

在 `frontend` 目录安装依赖：

```bash
pnpm install
```

## 调试

执行下面的命令后，打开浏览器访问本地开发链接：

```bash
pnpm --filter @kssolv/workflow dev
```

在控制台输入下面的命令可以模拟 MATLAB 环境：

```javascript
debug();
```

若控制台有大量 `addEventListener called with: ` 字样的输出则说明 hook 成功。

构建该组件：

```bash
pnpm build:workflow
```
