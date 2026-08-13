# 晶体结构渲染性能与界面细节验收计划

## 目标与范围

本轮优化聚焦于晶体结构从 MATLAB 模型到 CEF/WebGL 首帧的加载路径，同时覆盖通知、焦点、快捷键窗口、Toolstrip 图标和嵌入式浏览器缩放行为。科学数据、键连接算法和导出格式不做降级。

## 性能实施计划

1. 以 atoms-first 方式加载：中大型模型先发送无连接预览，让用户尽早看到原子，再用精确连接场景替换。
2. 缓存稳定资源：元素配色表在 MATLAB 会话内只解析一次；Three.js 球面几何采用有界缓存，在连续打开或重建结构时复用。
3. 降低缓存管理开销：场景缓存容量以 MATLAB 实际内存占用估算，不再为了估算大小额外执行一次完整 JSON 序列化。
4. 保留精确场景缓存：相同结构和选项再次加载时直接命中 `CrystalSceneCache`，只刷新请求标识。
5. 向量化周期邻居查询：批量生成周期镜像并一次性计算距离，避免 CrystalNN 在 MATLAB 对象层逐点构造与坐标转换。
6. 缩短序列化热路径：输入晶体不再做无意义深拷贝；原子坐标直接由数值分数坐标与晶格矩阵计算，减少重复 `subsref` 和对象构造。
7. 并行启动：MATLAB bridge 就绪后立即开始预览场景编译，与 WebGL renderer 的剩余初始化重叠；所有非空模型都先显示 atoms-first 帧。

## MATLAB R2026b 真实环境实测（2026-08-12）

测试环境为本机 `/Applications/MATLAB_R2026b.app`。MATLAB 编译基准使用独立 `-batch` 冷进程；端到端基准使用可见 `uifigure`、真实 `uihtml/CEF` 和 WebGL，不使用浏览器 mock。

| 指标 | 优化前 | 优化后冷进程/真实 CEF | 结果 |
| --- | ---: | ---: | --- |
| 1,000-site atoms-first MATLAB 编译 | 1,032 ms | 730 ms | 通过 `< 1,000 ms` |
| LiFePO4 atoms-first MATLAB 编译 | 189 ms | 108 ms（独立基准）；138 ms（E2E） | 通过 `< 500 ms` |
| LiFePO4 CrystalNN 精确编译 | 5,838 ms | 2,969 ms（独立冷进程）；2,135 ms（E2E） | 通过 `< 3,500 ms` |
| 晶体缓存命中 | 61 ms | 41 ms | 通过 `< 250 ms` |
| LiFePO4 CEF 传输 + WebGL 首帧 | 未测 | 149 ms | 通过 `< 1,000 ms` |
| LiFePO4 客户端 WebGL 绘制 | 未测 | 30 ms | 通过 `< 500 ms` |
| LiFePO4 预览编译至可见 | 未测 | 287 ms | 通过 `< 1,000 ms` |
| 冷 CEF bridge ready | 未测 | 1,218 ms | 记录项；同一 viewer 后续切换不重复发生 |

结论：已经打开的晶体 viewer 内，常见结构从请求到可见约 0.29 秒；1,000-site MATLAB atoms-first 编译也在 1 秒内。全新 CEF 实例的首次冷启动仍约 1.22 秒，因此“结构渲染秒开”已达到，应用级全冷启动约 1.5 秒，后续可通过拆分/延迟加载 2.2 MB 单文件 bundle 继续优化。

## 自动验收

| 验收项 | 自动检查 | 通过标准 |
| --- | --- | --- |
| 通知生命周期 | `WarningStack.test.ts` | 默认在 5,000 ms 后消失，仍支持手动关闭和定位 |
| 浏览器全局缩放 | `browserZoom.test.ts` | 拦截 pinch、Ctrl/Cmd+滚轮和页面缩放快捷键；普通滚动不受影响 |
| 快捷键窗口 | `components.test.ts` | 36 项完整、说明文案已移除、分区可切换、三类鼠标按键图标存在 |
| WebGL 几何缓存 | `layers.test.ts` | 第二次构建无新增球面缓存 miss，缓存不超过 32 项 |
| 大结构前端构建 | `layers.test.ts` | 10,000 原子保持单一批处理网格，测试环境内构建小于 3 s |
| 常见晶体 atoms-first | `kssolv.ui.test.benchmark.CrystalViewer` | LiFePO4 小于 500 ms |
| 大晶体 atoms-first | 同上 | 1,000 site 无连接首帧小于 1 s |
| 精确晶体场景 | 同上 | LiFePO4 CrystalNN 小于 3.5 s，不阻塞 atoms-first 首帧 |
| 重复加载缓存 | 同上 | 同一晶体场景缓存命中且小于 250 ms |
| 真实 CEF 首帧 | `kssolv.ui.test.benchmark.CrystalViewerEndToEnd` | 预览编译至可见小于 1 s、客户端绘制小于 500 ms、无客户端错误 |
| CEF 启动顺序 | `CrystalViewerRuntimeTest` | 同步 MATLAB `setup` 代理必须位于 module bundle 之前 |
| 资源完整性 | `CommandPresentationCatalog.validate` | 所有命令、分类和 History 图标均有 16/24 PNG 与 16/24/64 SVG |
| 发布产物一致性 | `pnpm verify:runtime` | frontend dist 与 MATLAB 内嵌 runtime 哈希一致 |

前端自动验收命令：

```bash
cd frontend
pnpm --filter @kssolv/crystal-viewer test
pnpm --filter @kssolv/crystal-viewer typecheck
pnpm --filter @kssolv/crystal-viewer build
pnpm build:tree-table
pnpm sync:runtime
pnpm verify:runtime
```

MATLAB 性能验收命令：

```matlab
report = kssolv.ui.test.benchmark.CrystalViewer(true)
```

真实 CEF/WebGL 验收必须在 MATLAB Desktop（非 `-batch`）中运行，因为隐藏窗口或 batch 模式会延迟 Chromium 创建：

```matlab
report = kssolv.ui.test.benchmark.CrystalViewerEndToEnd(true)
```

## 人工视觉验收

1. 打开任意非空晶体，确认先出现原子预览，随后补齐键和多面体，期间界面可响应。
2. 连续打开同一晶体两次，第二次应明显更快；统计信息和科学连接结果应一致。
3. 检查 Modeling > History：Undo、Redo、Reset、Start Recording、Save Recording、Jobs、Libraries、Guide 八个动作图标均可快速区分。
4. 检查 Lattice Editor、Enumerate Point Defects、Generate SQS Model：铅笔尖、加号和外围描边不得贴边或裁切。
5. 单击晶体画布，不出现蓝色焦点框；键盘操作仍可用。
6. 在 Project Browser、Command Window、晶体/体数据 viewer 中测试触控板 pinch 与 Ctrl/Cmd+滚轮，CEF 页面比例不得变化；普通滚动和晶体相机缩放仍正常。
