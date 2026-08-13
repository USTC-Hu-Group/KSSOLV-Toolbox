# KSSOLV 三维体数据查看器详细开发计划

## 1. 目标、边界与最终完成定义

本计划用于把 KSSOLV Toolbox 当前的原子结构查看器扩展为 MATLAB
负责科学数据、Vue/Three.js 负责交互渲染的三维体数据查看器。

首批输入格式：

- VASP：`CHGCAR`、`CHG`；
- Cube：`.cube`、`.cub` 以及现有 matgenlab 已支持的压缩变体；
- XCrySDen：包含二维/三维 Datagrid 的 `.xsf`；
- 后续兼容：BXSF Bandgrid、VASP 非共线磁化分量、Cube 多数据集。

首批显示方式：

- 正/负等值面；
- I/J/K 方向切片；
- 直方图、数值探针和范围控制；
- GPU 直接体渲染；
- 原子、化学键、单胞、多面体和晶格方向标叠加。

以下条件全部满足时，项目才算完成：

1. 三种首批格式均由 MATLAB/matgenlab 解析，TypeScript 不重复解析科学文件。
2. 非正交晶格、非零原点、周期边界和体素顺序均有明确协议，不能依赖隐含约定。
3. 体数据不通过 JSON 数值数组传输，大文件不会冻结 MATLAB UI 或浏览器主线程。
4. 等值面、切片、探针和直接体渲染使用同一坐标变换，能够与 MATLAB 数值交叉验证。
5. 结构叠加与体数据共用同一相机、旋转中心和导出视图。
6. 所有自动测试、真实 `uihtml` 测试、性能门槛和资源释放测试通过。

## 2. 全阶段通用规则

### 2.1 科学正确性规则

- MATLAB 是格式解释、单位换算、通道语义和物理量积分的唯一权威。
- 前端只接收规范化的笛卡尔变换、通道元数据和连续体素缓冲区。
- 所有网格统一为 `[nx, ny, nz]`，线性索引统一为：

```text
index = x + nx * (y + ny * z)
```

- 所有坐标最终以 Å 为长度单位；数据值单位必须由通道元数据明确给出。
- 禁止通过转置、镜像或“看起来正确”的旋转修补坐标错误。
- 任意格式转换都必须有至少三个不变量：尺寸、选定探针值、积分或统计值。

### 2.2 工程规则

- 运行时目录由 `pnpm sync:runtime` 生成，不直接手工编辑。
- MATLAB 与前端协议必须带 `schemaVersion`、`requestId` 和 `transferId`。
- 新请求到达后，旧请求必须可取消；旧数据不得覆盖新场景。
- Worker、GPU Texture、Geometry、Material 和事件监听器都必须有显式释放路径。
- 所有改变网格或几何的操作保持相机位置、姿态、target 和 zoom，除非用户主动重置。

### 2.3 每阶段统一退出门槛

每个阶段合并前必须满足：

- 新增单元测试全部通过；
- 既有 crystal-viewer 测试全部通过；
- TypeScript 类型检查、ESLint、Prettier 和生产构建通过；
- MATLAB 代码通过 Code Analyzer，相关 `matlab.unittest` 测试通过；
- 没有未说明的控制台错误、Promise rejection 或 WebGL 警告；
- 文档、协议示例和错误信息与实现一致。

## 3. 测试数据矩阵

开始功能开发前先固定下列可再分发的小型样例，并记录 SHA-256：

| 编号 | 格式 | 样例 | 必须验证的内容 |
| --- | --- | --- | --- |
| F01 | CHGCAR | Si 或 NaCl，非自旋 | 晶格、原子、尺寸、总电荷积分、周期顺序 |
| F02 | CHGCAR | 自旋极化体系 | `total`、`diff`、`up`、`down` 通道关系 |
| F03 | CHGCAR | 非共线小体系 | `diff_x/y/z` 通道和矢量模 |
| F04 | Cube | H2O 电荷密度 | Bohr→Å、非零原点、单数据集 |
| F05 | Cube | 有正负值的分子轨道 | 正负等值面、零附近阈值 |
| F06 | Cube | 负 `NATOMS`/dataset IDs | 多数据集选择及错误处理 |
| F07 | Cube | `NVAL > 1` | 每体素多值顺序 |
| F08 | XSF | 非正交晶格、单个 3D grid | 原点、跨距矢量、非正交坐标 |
| F09 | XSF | 多个带标签 3D grids | 标签、通道选择、独立统计 |
| F10 | XSF | 2D grid | 二维切片和缺失第三维处理 |
| F11 | 解析无关 | 解析式球场 | 等值面半径、法线和面积 |
| F12 | 解析无关 | 线性标量场 `f=x+2y+3z` | 插值、切片、探针和非正交变换 |
| F13 | 错误样例 | 截断、NaN、尺寸溢出 | 拒绝路径和错误信息 |

每个样例保存一份独立的 oracle 元数据：

```text
dimensions
origin
voxelVectors
periodicity
channels
minimum/maximum/mean/standardDeviation
selected index/value pairs
integral when physically meaningful
```

## 4. 阶段 P0：基线冻结与技术决策

### 4.1 工作步骤

1. 记录现有 crystal-viewer 生产构建大小、测试数量、首帧时间和 10,000
   原子压力测试结果。
2. 固定 `three`、Vue 和 Vite 的版本；记录 VTK.js 的评估版本和未打包结论。
3. 建立 ADR：
   - ADR-001：MATLAB 负责文件解析；
   - ADR-002：独立 `VolumeSceneSpec`；
   - ADR-003：分块二进制 `uihtml` 传输；
   - ADR-004：Three.js 作为唯一渲染器；
   - ADR-005：Worker 中执行等值面和统计。
4. 建立 F01-F13 fixture 清单、来源、许可证、大小和 SHA-256。
5. 建立参考环境说明：MATLAB 版本、macOS/Windows、GPU、浏览器内核和 DPR。

### 4.2 验收标准

- 五份 ADR 均包含“选择、备选方案、放弃理由、风险、撤销条件”。
- F01-F13 每项都有明确来源和期望 oracle；缺失样例必须有责任阶段和替代数据。
- 能在干净工作区执行一条命令完成当前前端测试和构建。
- 基线报告包含生产 gzip 大小、首帧时间、峰值内存和测试版本信息。
- 没有开始复制 VTK.js、NGL 或 Mol* 源码；许可证审查先于源码引入。

### 4.3 阶段输出

- `dev/volume-viewer/docs/adr/volume-viewer-*.md`
- `+kssolv/+ui/+test/+fixtures/+volume/manifest.json`
- `dev/volume-viewer/docs/volume-viewer-baseline.md`

## 5. 阶段 P1：共享前端基础与原子查看器回归保护

### 5.1 工作步骤

1. 抽取 `AtomicSceneSpec`、验证器和公共类型到
   `frontend/packages/atomic-scene`。
2. 抽取相机、Trackball、方向标、selection、导出和 GPU 资源释放工具到
   `frontend/packages/three-scene`。
3. 抽取 Atom/Bond/Cell/Polyhedron/Magmom 图层，但保持 crystal-viewer
   对外行为不变。
4. 为公共相机建立显式 API：
   - `fit(bounds, preserveOrientation)`；
   - `reset(direction)`；
   - `snapshot()`/`restore()`；
   - `setLatticeAxis(a|b|c|a*|b*|c*)`。
5. 保持 Pretty 和 Materials：
   - 相同卡片布局规则；
   - 相同默认 Visibility；
   - 相同拟合和方向标视口；
   - 相同默认 Fast/Phong 路径；
   - 不同主题美术参数。

### 5.2 自动测试

- 所有现有 57 项前端测试继续通过。
- 新增包级测试覆盖：
  - 正交与非正交晶格方向标；
  - 任意相机姿态 snapshot/restore；
  - 空格只拟合缩放和中心，不改变 quaternion；
  - 资源 `dispose()` 可重复调用；
  - 主题切换不改变科学 scene。

### 5.3 验收标准

- crystal-viewer 的 DOM 结构、快捷键、菜单和 MATLAB 事件名称没有意外变化。
- 主题切换前后 atom/bond/cell/polyhedra 的 ID、数量和坐标逐项相同。
- 在 a/b/c/a*/b*/c* 六个视图及任意拖拽姿态下，方向标箭头均不被裁切。
- `snapshot → 改变视图 → restore` 后，相机 position、quaternion、target、zoom
  的误差均小于 `1e-9`。
- 生产构建 gzip 大小相对基线增长不超过 5%，否则必须解释并批准。
- crystal-viewer 在真实 MATLAB `uihtml` 中完成一次打开、切换主题、旋转、关闭，
  控制台无错误。

## 6. 阶段 P2：MATLAB 格式适配和解析器加固

### 6.1 工作步骤

1. 新建 `kssolv.ui.scene.volume.VolumeFileReader`，仅负责格式路由和标准错误包装。
2. CHGCAR 适配：
   - 复用 `io.vasp.Chgcar.from_file`；
   - 映射 `total`、`diff`、`diff_x/y/z`；
   - 计算实际密度单位和电子数积分；
   - 忽略但保留 augmentation 元数据说明。
3. Cube 适配：
   - 复用并加固 `VolumetricData.from_cube`；
   - 支持正/负 `NATOMS`；
   - 支持 dataset IDs 和 `NVAL`；
   - 明确轴行中的单位符号和 Bohr→Å；
   - 保留任意非正交 voxel vectors 和非零 origin。
4. XSF 适配：
   - 复用 `XSF.from_file`、`XSFGrid`；
   - 将每个带标签 Datagrid 映射为一个 channel；
   - 区分 2D/3D、periodic/general grid；
   - 记录是否存在周期末端重复采样面。
5. 为三种格式输出统一的 MATLAB `VolumeDataset` 值对象。
6. 在分配大数组前检查维度乘积、文件长度、最大元素数和数值有限性。

### 6.2 自动测试

- F01-F10 和 F13 全部进入参数化 MATLAB 测试。
- 与 matgenlab 原对象交叉验证：
  - dimensions 完全相等；
  - origin/voxel vectors 绝对误差 `< 1e-10 Å`；
  - oracle 探针在 Double 精度下误差 `< 1e-12 × max(1, range)`；
  - CHGCAR 积分误差 `< max(1e-6, 1e-6 × NELECT)`；
  - `up=(total+diff)/2`、`down=(total-diff)/2` 逐点成立。
- 截断、额外数据、NaN/Inf、零尺寸、整数溢出、未知通道均有独立错误 ID。

### 6.3 验收标准

- F01、F04、F08 能产生同一 `VolumeDataset` API，不需要格式条件分支才能查询
  dimensions、transform、channels 和 samples。
- Cube F06/F07 不再被当作普通单通道 Cube 误读；支持时正确拆分，不支持的组合明确拒绝。
- XSF 多 grid 的标签、顺序和数据不串位。
- CHGCAR x-fastest 顺序通过至少 8 个不对称索引探针验证，不能只验证 min/max。
- 任何错误文件都不会造成超过配置上限的预分配，也不会留下半有效对象。
- 读取压缩与未压缩的同一 fixture 产生完全相同的规范化对象。

## 7. 阶段 P3：VolumeSceneSpec 1.0 与双端验证

### 7.1 工作步骤

1. 实现 MATLAB `VolumeSceneBuilder`：
   - source、grid、channels、atomic overlay、warnings；
   - 计算 min/max/mean/std/integral；
   - 生成 stable channel ID。
2. 实现 MATLAB `VolumeSceneValidator`。
3. 在 `frontend/packages/volume-scene` 实现 TypeScript 类型、运行时验证器和
   测试 builder。
4. 为协议增加明确字段：
   - `sampling: cell-periodic | point-inclusive`；
   - `periodic: [bool,bool,bool]`；
   - `indexOrder: x-fastest`；
   - `valueEncoding`；
   - 原子 overlay 的 schema 版本。
5. 编写一份小型 JSON manifest 示例；样本值仍走二进制，不嵌入 JSON。
6. 定义 1.x 向后兼容策略和未知字段处理规则。

### 7.2 自动测试

- 同一 manifest 在 MATLAB 和 TypeScript 验证器中结论相同。
- 使用属性化/参数化测试覆盖：
  - 负尺寸、零尺寸、乘积溢出；
  - 奇异 voxel matrix；
  - 重复 channel ID；
  - 无穷统计值；
  - transport byteLength 与尺寸不一致；
  - 不兼容 schemaVersion；
  - stale requestId。
- JSON round trip 后数值和字段不丢失。

### 7.3 验收标准

- F01-F10 均能生成合法 manifest。
- MATLAB 和 TypeScript 对全部错误样例的接受/拒绝结果 100% 一致。
- manifest 在不包含体素值的情况下，小型样例小于 100 KiB。
- 新增可选字段不会破坏 1.0 reader；新增必需字段必须提升 schema 版本。
- 原子 overlay 缺失时体数据仍可独立显示；overlay 非法时不能拖垮体数据错误报告。

## 8. 阶段 P4：LOD、二进制分块和 uihtml 传输

### 8.1 工作步骤

1. 实现 `VolumeChunkEncoder`：
   - Little-endian Float32；
   - 可选 Uint16 linear quantization；
   - 256-512 KiB chunk；
   - 每块 CRC32 和完整缓冲区校验；
   - sequence、chunkCount、byteLength。
2. 实现命名事件状态机：

```text
volume:begin
volume:manifest
volume:chunk
volume:complete
volume:cancel
volume:error
```

3. 实现前端 `VolumeTransferAssembler`：
   - out-of-order 缓存；
   - 重复 chunk 去重；
   - 缺失 chunk 检测；
   - stale transfer 丢弃；
   - ArrayBuffer 重组和校验。
4. 实现自适应 LOD：
   - 默认交互目标不超过 `128^3`；
   - 保持物理长宽比；
   - 标量使用体积守恒或明确的平均/插值策略；
   - 全分辨率数据留在 MATLAB。
5. 增加取消、超时、进度和 backpressure。

### 8.2 自动测试

- 以确定性伪随机数据验证 `16^3`、`64^3`、`128^3`。
- 测试顺序：
  - 正常顺序；
  - 完全逆序；
  - 随机顺序；
  - 重复一个 chunk；
  - 删除一个 chunk；
  - 篡改一个字节；
  - 完成前取消；
  - 新 transfer 覆盖旧 transfer。
- Float32 重组必须 byte-for-byte 相同。
- Uint16 量化误差必须小于 `range/65535 + 1e-7 × max(1,|value|)`。

### 8.3 验收标准

- `128^3` Float32（8 MiB）可在真实 MATLAB `uihtml` 中完整传输并重建。
- 传输过程中 UI 有 0-100% 单调进度；取消后 200 ms 内停止继续组装。
- 缺失、重复、损坏和 stale chunk 不会显示半成品场景。
- 失败后按钮恢复可操作状态，错误信息指出阶段、transferId 和可行建议。
- 前端组装期间主线程单次阻塞不超过 100 ms。
- 完成、取消或关闭文档后，chunk 缓冲区可被垃圾回收，没有持续增长。

## 9. 阶段 P5：Volume Viewer 应用外壳与状态机

### 9.1 工作步骤

1. 创建 `frontend/apps/volume-viewer`：
   - Vue 3；
   - Vite；
   - Composition API；
   - TypeScript；
   - Vitest。
2. 建立显式状态：
   - idle；
   - receiving；
   - decoding；
   - building；
   - ready；
   - cancelled；
   - error。
3. 建立基础布局：
   - 左上源信息卡；
   - 右侧 Display settings；
   - 底部 histogram/probe 区；
   - 当前 channel、representation 和进度。
4. 支持 Materials/Pretty 两主题并复用原子查看器规则。
5. 实现快捷键、全屏、PNG 和简洁模式的公共入口。
6. 实现 capability 检测：
   - WebGL2；
   - `MAX_3D_TEXTURE_SIZE`；
   - float/half-float texture；
   - Worker；
   - 可用内存的保守预算。

### 9.2 自动测试

- 状态机覆盖每一条合法和非法转换。
- `scene A begin → scene B begin → scene A complete` 不得覆盖 B。
- representation/channel 改变时状态、进度和错误清零规则明确。
- capability 缺失时生成稳定 fallback 配置。

### 9.3 验收标准

- 无数据时不会出现空白 WebGL 错误；显示明确空状态。
- receiving/building/error 状态均不会遮挡结构区域中央，提示位于设置面板状态区。
- 所有设置控件有 label、键盘焦点和禁用状态。
- 默认主题、Visibility 和 Fast/Phong 规则与 crystal-viewer 一致。
- app 初始入口 gzip 不超过 250 KiB；重型体算法必须动态加载或进入 Worker chunk。
- 在 DPR=1 和 DPR=2、窄 MATLAB 文档面板和全屏下均无水平滚动条。

## 10. 阶段 P6：原子结构叠加与统一相机

### 10.1 工作步骤

1. 加载 `atomicOverlay` 并复用共享 Atom/Bond/Cell/Polyhedron 图层。
2. 以 volume grid 的八角点和 atomic overlay 的球包围体共同计算 bounds。
3. 建立一个 scene、一个 camera、一个 controls 和一个 selection/raycast 管线。
4. 统一：
   - 左键旋转；
   - 滚轮缩放；
   - 右键平移；
   - 空格仅居中和拟合；
   - a/b/c/a*/b*/c*；
   - `(1,1,1)` reset。
5. 保证 channel、isovalue、LOD 或 representation 更新不改变 camera snapshot。

### 10.2 自动测试

- 仅 volume、仅 atoms、两者同时存在的 bounds。
- 非正交网格八角点变换。
- 改变 channel、isovalue、LOD 后 snapshot 数值不变。
- 选择原子后隐藏其 visibility，selection marker 同步消失。

### 10.3 验收标准

- F01、F04、F08 的原子坐标与网格位置视觉和数值一致。
- 旋转中心为联合 bounds 中心，不随角原子或网格原点漂移。
- 空格不改变 quaternion；reset 才恢复 `(1,1,1)`。
- 非正交晶格方向标与晶格矢量夹角一致。
- 所有结构 visibility 与体数据 visibility 相互独立。
- 更新体表示前后相机四元数误差 `<1e-9`、zoom 误差 `<1e-9`。

## 11. 阶段 P7：等值面 MVP

### 11.1 工作步骤

1. 在 `isosurface.worker.ts` 中实现等值面接口。
2. 实现小型、可测试的 marching tetrahedra 核心；VTK.js 只作为评估过的
   备选方案，不引入 VTK renderer/camera。
3. 将输出转换为 Three.js `BufferGeometry`：
   - position；
   - index；
   - normal；
   - bounds。
4. 将索引空间顶点通过 voxel matrix 变换到笛卡尔空间。
5. 支持：
   - absolute；
   - sigma；
   - percentile；
   - 正负双等值面；
   - 独立颜色/透明度；
   - 周期包裹；
   - 可选平滑。
6. 建立缓存键：

```text
transferId + channel + lod + isovalue + sign + smoothing + periodic
```

7. 新请求到达时取消过期 worker 任务。

### 11.2 自动测试

- F11 解析式球场：
  - 半径；
  - bounds；
  - 法线；
  - 三角形非退化；
  - 不同 LOD 收敛。
- F12 线性场的平面等值面位置。
- 非正交 voxel matrix 的顶点变换。
- F05 正负轨道生成两个独立 mesh。
- 周期边界跨面连续性和去重。

### 11.3 验收标准

- 解析式球半径误差不超过 `1.5 × 最大体素边长`。
- 99% 以上非退化三角形法线朝向与解析梯度一致。
- F12 等值平面到理论平面的最大距离不超过 `1.5` 个体素。
- F05 正负表面没有颜色串位，单独隐藏任一表面不触发重新解析。
- `128^3` 首次等值面在参考桌面上 2 s 内完成；缓存命中 100 ms 内显示。
- 拖动阈值时旧任务被取消，最终画面必须对应最后一个输入值。
- worker 计算期间相机仍可保持至少 30 FPS。

## 12. 阶段 P8：切片、直方图和数值探针

### 12.1 工作步骤

1. 先实现 I/J/K 对齐切片，避免把非正交网格错误当作 XYZ 正交网格。
2. 使用 DataTexture 或等价纹理显示切片。
3. 增加：
   - nearest/linear interpolation；
   - index 和分数坐标输入；
   - 色图；
   - 对称/非对称 range；
   - NaN mask；
   - histogram；
   - 鼠标 probe。
4. Worker 中计算 histogram、percentile 和切片数据。
5. 任意笛卡尔平面仅在重采样实现后开放；未实现前明确禁用。

### 12.2 自动测试

- F12 的 I/J/K 切片逐点与解析值比较。
- 非正交 F08 中用笛卡尔坐标反求网格坐标并探针。
- histogram bin 总数等于有限样本数。
- percentile 与 MATLAB oracle 一致。
- range 改变只更新纹理/材质，不重新传输体数据。

### 12.3 验收标准

- Float32 探针误差 `< max(1e-6, 5e-5 × channel range)`。
- I/J/K index=0 和末端平面没有 off-by-one。
- histogram 所有 bin 计数和等于有效 voxel 数。
- percentile 1/50/99 与 MATLAB 结果误差小于一个 histogram bin 或精确算法容差。
- 256×256 切片更新在参考桌面上 100 ms 内完成。
- 非正交网格的切片平面方向与 voxel vectors 一致。
- 任意 Cartesian slice 未达到数值验收前不得伪装成可用功能。

## 13. 阶段 P9：GPU 直接体渲染

### 13.1 工作步骤

1. 使用 Three.js `Data3DTexture` 上传 Float32、HalfFloat 或量化数据。
2. 实现 ray-marching Shader：
   - grid box 求交；
   - 世界坐标到 texture 坐标；
   - transfer function；
   - scalar opacity；
   - gradient opacity；
   - early termination；
   - adaptive step；
   - clipping planes。
3. 支持透明体与原子结构的深度组合。
4. 根据 capability 和数据大小选择：
   - Float32；
   - HalfFloat；
   - Uint16/Uint8；
   - 自动回退到等值面/切片。
5. 相机运动前后保持采样步长和 device-pixel ratio 稳定，避免点击或停止旋转时
   出现体渲染跳变；性能由显式 Sampling quality 选项控制。

### 13.2 自动测试

- Shader 参数和坐标变换的 CPU 参考测试。
- 体纹理上传的 x/y/z 定向颜色测试。
- transfer function 端点、透明区和对称范围测试。
- capability 矩阵和 fallback 测试。
- WebGL context loss/recovery 测试。

### 13.3 验收标准

- F12 的 x/y/z 定向测试无轴交换、镜像或转置。
- F01/F04/F08 的体渲染与等值面使用相同世界坐标 bounds。
- 支持设备上旋转时至少 30 FPS，按下、旋转和释放过程中体渲染质量不跳变。
- 不支持 Float32 3D texture 时能自动使用 HalfFloat/量化或回退，不能显示空白。
- 超过 `MAX_3D_TEXTURE_SIZE` 时在上传前降采样或拒绝，并给出明确提示。
- context 恢复后纹理和材质重新创建，旧 GPU 资源不泄漏。
- 直接体渲染与原子球透明叠加没有稳定可复现的深度遮挡错误。

## 14. 阶段 P10：格式高级能力和周期逻辑

### 14.1 工作步骤

1. CHGCAR：
   - total/diff；
   - spin up/down 派生；
   - non-collinear x/y/z；
   - magnetization magnitude。
2. Cube：
   - dataset ID；
   - `NVAL`；
   - 多轨道选择；
   - 单位和 origin 变体。
3. XSF：
   - 多 Datagrid；
   - 2D grid；
   - general/periodic；
   - 后续 BXSF/Fermi surface。
4. 实现周期末端重复平面检测，避免双层表面。
5. 支持以单胞或扩胞范围裁切/包裹体数据。

### 14.2 自动测试

- F02/F03/F06/F07/F09/F10。
- 通道切换、派生通道和统计独立性。
- periodic wrap 前后边界连续性。
- duplicated terminal plane 去重前后的 bounds/integral。

### 14.3 验收标准

- F02 的 `up/down` 关系逐点成立，统计和等值面均使用正确派生值。
- F03 x/y/z 不串位，magnitude 与 MATLAB `sqrt(x²+y²+z²)` 一致。
- F06/F07 所有数据集可独立选择，标签与源文件一致。
- F09 切换 grid 不重新打开文件，不保留上个通道的 histogram/阈值。
- periodic grid 扩展后表面跨边界连续，不产生一层重复等值面。
- 2D XSF 自动使用切片模式，不尝试创建空的 3D volume texture。

## 15. 阶段 P11：导出、性能、稳定性和安全边界

### 15.1 工作步骤

1. 导出：
   - PNG；
   - scene manifest JSON；
   - 等值面 glTF、PLY、STL；
   - 当前切片 PNG/CSV；
   - MATLAB 侧全分辨率数据导出沿用 matgenlab。
2. 建立缓存：
   - channel statistics；
   - histogram；
   - LOD；
   - isosurface；
   - transfer function texture。
3. 建立内存预算和 LRU 淘汰。
4. 增加异常与安全边界：
   - 文件大小；
   - voxel 数量；
   - channel 数；
   - mesh 三角形数；
   - worker 时间；
   - JSON 深度；
   - checksum。
5. 建立性能 benchmark 和泄漏测试。

### 15.2 自动测试

- 导出后重新读取 glTF/PLY/STL，比较 bounds、顶点/面数量。
- PNG 尺寸、背景、透明度和 DPR。
- 连续加载 50 次小场景并记录 heap/GPU 资源。
- 连续改变 isovalue 200 次，验证取消和缓存上限。
- 超大/恶意 manifest 在分配前被拒绝。

### 15.3 验收标准

- glTF/PLY/STL round trip 后 bounds 每轴误差 `<1e-5 Å`。
- PNG 像素尺寸与用户选择一致，1×/1.5×/2× 不被浏览器 DPR 二次放大。
- 参考桌面上：
  - `128^3` decode + 首等值面 `<2 s`；
  - 切片更新 `<100 ms`；
  - 缓存等值面 `<100 ms`；
  - 交互旋转 `≥30 FPS`；
  - 峰值浏览器内存 `<400 MiB`。
- 50 次打开/关闭后，heap 稳定值相对第 10 次增长不超过 10%；
  Three.js `renderer.info.memory` 回到允许基线范围。
- 初始 app entry gzip `<250 KiB`，所有延迟加载算法 chunk 合计 gzip
  `<750 KiB`；超出需有 bundle 分析和批准。
- 任何被拒绝输入都不能触发浏览器崩溃、无限 spinner 或 MATLAB UI 永久 busy。

## 16. 阶段 P12：MATLAB 产品集成和发布验收

### 16.1 工作步骤

1. 新建 `kssolv.ui.components.figuredocument.VolumeDisplay`。
2. File manager/StructureIO 增加路由：
   - `CHGCAR`/`CHG`；
   - `.cube`/`.cub`；
   - `.xsf`；
   - 压缩扩展名。
3. 定义文档标题、项目树图标、错误对话框和重复打开策略。
4. 加入 `pnpm sync:runtime`。
5. 加入第三方许可证和版本清单。
6. 在 macOS/Windows MATLAB `uihtml` 做端到端验证。
7. 编写用户文档和故障排查：
   - 大文件 LOD；
   - GPU fallback；
   - 通道含义；
   - CHGCAR 单位；
   - Cube 多数据集；
   - XSF 非正交切片。

### 16.2 端到端场景

1. 双击 F01 CHGCAR，切换 total/isovalue/slice/volume，导出 PNG 和 glTF。
2. 双击 F05 Cube，同时显示正负轨道，探针并导出。
3. 双击 F08 XSF，验证非正交单胞、方向标和切片。
4. 正在加载大文件时关闭文档。
5. 正在计算等值面时打开另一个文件。
6. GPU 不支持 3D Float texture 时打开文件。
7. 破损文件、未知通道和超限文件。

### 16.3 验收标准

- 项目浏览器能够正确识别并打开三种格式，不再经过分子/晶体字符串解析路径。
- 每个端到端场景都在 macOS 和 Windows 的受支持 MATLAB 版本通过。
- 关闭文档后 500 ms 内取消传输和 worker；无继续到达的 UI 更新。
- 打开第二个文件后，第一个文件的 stale result 不会污染新文档。
- runtime 目录与最新 production build 校验和一致。
- `THIRD-PARTY-LICENSES.md` 包含实际打包依赖；未打包的参考项目不误写为运行时依赖。
- 用户文档能够仅凭界面步骤完成 CHGCAR、Cube、XSF 的打开、通道选择、显示和导出。
- 发布候选版本连续运行 30 分钟、重复交互与切换表示后，无无限 spinner、崩溃或持续内存增长。

## 17. 建议的合并顺序

每个阶段使用独立、可回滚的变更集：

1. P0：fixtures、ADR、基线；
2. P1：共享包抽取，不包含体功能；
3. P2-P3：MATLAB normalization 与协议；
4. P4：传输；
5. P5-P6：应用外壳和结构叠加；
6. P7：等值面 MVP，形成第一个可用版本；
7. P8：切片、直方图、探针；
8. P9：直接体渲染；
9. P10：高级格式；
10. P11-P12：导出、性能、产品集成和发布。

不建议把 P2-P9 合并为一个大改动。第一个对用户可交付的里程碑是
P7：三种格式均能以正确坐标显示原子结构和等值面。P8-P10 在此基础上递增，
不会阻塞基础格式查看能力。

## 18. 阶段验收记录模板

每个阶段完成时填写：

```text
阶段：
提交/版本：
测试环境：
完成的工作项：
未完成或延期项：
自动测试命令及结果：
MATLAB 测试结果：
真实 uihtml 测试结果：
性能结果与基线差异：
内存/GPU 资源结果：
已知问题：
验收人：
结论：通过 / 附条件通过 / 不通过
```

“附条件通过”必须列出截止阶段，不能把科学正确性、数据顺序、坐标变换、
取消机制或内存泄漏作为可延期条件。

## 19. 逐步骤 WBS、完成定义与验收证据

本节把 P0-P12 进一步拆成可独立执行、测试和签收的工作项。前文阶段级
验收标准仍然有效；本节的逐项标准是阶段验收的前置条件，不能用“界面看起来
正常”替代数值、协议、性能或资源释放证据。

### 19.1 工作项状态和证据规则

每个工作项只能处于以下状态之一：

- `未开始`：依赖尚未满足或尚未产生代码/文档；
- `进行中`：已有实现，但逐项验收尚未全部通过；
- `阻塞`：存在外部环境、数据或设计决策阻塞，必须记录责任人和解除条件；
- `待验收`：实现、自动测试和自测完成，等待独立复核；
- `完成`：本项全部验收标准通过，证据已登记；
- `延期`：仅允许非科学正确性功能延期，必须记录目标版本。

每个 `完成` 工作项至少登记以下证据：

```text
工作项 ID：
可开始条件（DoR）：
输入 fixture / oracle：
代码/文档路径：
提交或工作区版本：
测试命令：
测试结果：
人工验收步骤：
截图或日志：
性能/内存数据（适用时）：
测试平台：
失败注入与恢复结果：
遗留限制：
验收结论：
```

每个工作项进入 `进行中` 前必须满足 Definition of Ready（DoR）：

1. 上游依赖均已完成，或已用书面接口/fixture 冻结，不依赖尚未确定的隐含行为；
2. 输入、预期输出、坐标/单位、错误行为和资源上限均可从文档或 oracle 得到；
3. 自动测试的入口、真实产品中的人工验证入口和证据保存位置已经确定；
4. 涉及第三方代码或数据时，许可证、固定版本和再分发条件已确认；
5. 涉及性能时，参考机器、DPR、浏览器/MATLAB 版本、冷/热路径和测量区间已固定。

每个工作项进入 `完成` 前必须满足 Definition of Done（DoD）：

1. 产出物已落到计划指定的生产路径，不以临时脚本、开发服务器或截图替代；
2. 正常、边界、非法输入、取消/关闭和重复执行路径均有测试，命令退出码为 0；
3. 数值类功能与 frozen oracle 或独立实现交叉验证，UI 类功能在真实 `uihtml`
   中复核；
4. 新增资源具有明确 owner，重复 rebuild/open/close 后能够释放；
5. 错误包含稳定 ID、所处阶段、实际值和可执行建议，不出现永久 busy/spinner；
6. 文档、类型、MATLAB/TypeScript 双端协议、runtime 构建产物与实现同步；
7. 验收记录包含原始日志或机器可解析报告，不只登记“通过”。

单项验收按固定顺序执行：`静态检查 → 单元测试 → contract/oracle →
production build → 真实 uihtml → 失败注入 → 性能/内存 → 文档复核`。其中某项
不适用时必须写明原因；不能静默跳过。任何 S0/S1 立即把当前项退回 `进行中`，
并使依赖它的阶段停止签收。

验收失败按严重度处理：

- `S0`：数据错误、坐标错误、通道串位、崩溃或数据损坏；阻止后续阶段。
- `S1`：取消失效、无限 spinner、明显泄漏、主要功能不可用；阻止阶段签收。
- `S2`：交互或布局明显不符合规格；可以继续开发，但发布前必须修复。
- `S3`：文案、轻微视觉或低频兼容问题；可带明确期限延期。

### 19.2 P0：基线冻结与技术决策

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P0.1 | 无 | 固定 MATLAB、Node、pnpm、浏览器内核、操作系统、GPU、DPR 和显示分辨率，写入 `volume-viewer-baseline.md`。 | 在同一机器重新执行版本采集命令，结果与文档一致；不允许只写“最新版”；macOS 和 Windows 缺失的平台必须明确标记为“未测试”。 |
| P0.2 | P0.1 | 记录 crystal-viewer 单元测试数、生产入口大小、首次可交互时间、10,000 原子旋转帧率、峰值 JS heap 和 `renderer.info.memory`。 | 每项都有命令、输入 fixture、测量起止点和三次测量的中位数；构建产物 gzip 由实际文件计算，不使用 Vite 控制台四舍五入值代替。 |
| P0.3 | 无 | 完成五份 ADR，明确解析端、协议、传输、渲染器和 Worker 决策。 | 每份 ADR 均包含背景、选择、至少两个备选、放弃理由、风险、撤销条件；ADR 之间没有相互矛盾的所有权描述。 |
| P0.4 | 无 | 建立 F01-F13 fixture manifest，记录来源、许可证、大小、SHA-256、生成脚本和 oracle。 | `manifest.json` 可被解析；所有仓库内文件的 SHA-256 与清单一致；生成型 fixture 能由脚本稳定复现；不可再分发文件不得提交。 |
| P0.5 | P0.4 | 为每个 fixture 固化 dimensions、origin、voxel vectors、通道、统计和至少 8 个非对称探针。 | oracle 不依赖待测解析器在测试运行时现算；对称结构也必须选择能暴露轴交换的索引；F13 明确预期错误 ID。 |
| P0.6 | P0.1-P0.5 | 建立基线一键命令和阶段验收记录模板。 | 新工作区按文档执行后能完成安装、测试、构建和基线采集；命令非交互执行并以非零退出码表示失败。 |

P0 阶段签收还必须确认：所有后续性能比较均引用同一基线；引入第三方源码前已
完成许可证评估；任何未取得的 fixture 都有替代生成数据和补齐阶段。

### 19.3 P1：共享前端基础与 crystal-viewer 回归保护

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P1.1 | P0 | 盘点 crystal-viewer 中 scene contract、相机、controls、方向标、图层、选择和导出代码，形成抽取边界清单。 | 清单逐文件标明“抽取/保留/废弃”；没有在同一变更中修改科学场景语义；现有 57 项测试在抽取前通过。 |
| P1.2 | P1.1 | 建立 `atomic-scene` 包，迁移 `AtomicSceneSpec`、类型、验证器和测试 builder。 | crystal-viewer 只从共享包导入同一类型；非法 atom/bond/cell/polyhedron 输入仍被拒绝；序列化结果与迁移前快照一致。 |
| P1.3 | P1.1 | 建立 `three-scene` 包，迁移 camera、controls、方向标、selection、export 和资源释放工具。 | 包不依赖 Vue app 单例；每个 GPU 资源都有 owner 和 `dispose()`；重复调用 dispose 不抛错。 |
| P1.4 | P1.2-P1.3 | 实现 `fit/reset/snapshot/restore/setLatticeAxis` 公共相机 API。 | 单测覆盖正交、单斜、三斜晶格；`fit(..., true)` 前后 quaternion 误差 `<1e-9`；restore 后 position、target、zoom 误差 `<1e-9`。 |
| P1.5 | P1.3 | 实现 a/b/c 与倒易 a*/b*/c* 视向，并让方向标使用真实晶格夹角。 | 六个按钮的视线向量分别与目标正/倒易矢量平行，点积绝对值 `>1-1e-9`；非正交晶格方向标角度误差 `<0.1°`；箭头不被 inset 裁切。 |
| P1.6 | P1.2-P1.5 | 对齐 Pretty/Materials 的布局规则、默认 Visibility、拟合和 Fast/Phong 默认路径，仅保留美术参数差异。 | 两主题切换前后 scene 中科学对象 ID、数量、坐标完全相同；Pretty 视觉快照无非预期变化；Materials 默认设置与规格一致。 |
| P1.7 | P1.2-P1.6 | 运行 crystal-viewer 自动和真实 `uihtml` 回归。 | 所有既有测试通过；真实 MATLAB 完成打开、旋转、缩放、平移、六轴视向、主题切换、PNG、关闭；控制台无 error/rejection/WebGL warning；gzip 增长不超过 5% 或有批准记录。 |

P1 不允许以“volume-viewer 尚未使用该 API”为理由跳过真实 crystal-viewer 回归；
共享代码一旦影响旧应用，P1 即不通过。

### 19.4 P2：MATLAB 格式适配和解析器加固

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P2.1 | P0.4-P0.5 | 定义不可变 `VolumeDataset`：source、grid、channels、atomic structure、warnings 和原始元数据。 | 构造时验证正尺寸、有限 transform、样本数和唯一 channel ID；对象创建后外部无法使 samples 与 dimensions 失配。 |
| P2.2 | P2.1 | 实现格式 registry 和 `VolumeIO/VolumeFileReader`，按无扩展名 VASP 名称及扩展名路由。 | `CHGCAR`、`CHG`、`.cube/.cub`、`.xsf` 和允许的压缩扩展正确命中；未知格式使用稳定错误 ID，不进入 `Structure.from_str`。 |
| P2.3 | P2.1 | 实现 CHGCAR 标准化，映射 total/diff/non-collinear 分量、单位、周期性和原子结构。 | F01-F03 dimensions、晶格、8 个探针和通道顺序与 oracle 一致；非共线数据不错误派生 collinear up/down；积分在规定容差内。 |
| P2.4 | P2.1 | 实现 Cube 标准化，处理 Bohr/Å、非零原点、负 NATOMS、dataset IDs、NVAL 和斜 voxel vectors。 | F04-F07 全部通过；每体素多值拆分顺序正确；负 NATOMS dataset 标签不丢失；单位转换误差 `<1e-10 Å`。 |
| P2.5 | P2.1 | 实现 XSF 2D/3D、多个带标签 grid、periodic/general 和终端重复面元数据。 | F08-F10 标签、顺序、维度、origin、span vectors 和探针全部匹配；2D grid 明确标为 2D，不伪造第三维体数据。 |
| P2.6 | P2.2-P2.5 | 在大数组分配前实施文件大小、维度乘积、channel 数、数值有限性和配置上限检查。 | F13 的截断、零尺寸、溢出、NaN/Inf 在大分配前被拒绝；MATLAB 内存峰值没有与声明尺寸不相称的突增；错误包含文件、字段和建议。 |
| P2.7 | P2.3-P2.6 | 建立压缩/未压缩、matgenlab 原对象和 frozen oracle 三向交叉测试。 | 同一数据压缩前后规范化对象相同；适配器与 matgenlab 的尺寸/坐标/样本一致；全部错误均有独立 MATLAB 测试。 |

P2 阶段签收时必须提供逐格式解析日志和 oracle 差异报告；仅比较 min/max
不能作为数据顺序正确的证据。

### 19.5 P3：VolumeSceneSpec 1.0 与双端验证

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P3.1 | P2.1 | 冻结 `VolumeSceneSpec 1.0` 字段、单位、坐标、sampling、periodic、indexOrder、transport 和 warnings 语义。 | 协议文档能独立回答“第 n 个值在何处”“终端面是否重复”“单位是什么”；samples 不以内联 JSON 数组出现。 |
| P3.2 | P3.1 | 实现 MATLAB `VolumeSceneBuilder`，生成 stable channel ID、统计、grid 和 atomic overlay 引用。 | 同一输入重复构建的 channel ID 和 manifest JSON 稳定；统计只忽略明确允许的缺失值；警告顺序确定。 |
| P3.3 | P3.1-P3.2 | 实现 MATLAB `VolumeSceneValidator`。 | 对负/零尺寸、奇异 transform、重复 ID、非有限统计、样本字节数错误和不兼容版本逐项拒绝并返回稳定错误 ID。 |
| P3.4 | P3.1 | 实现 TypeScript 类型、运行时 validator、builder 和错误对象。 | 不使用仅编译期类型替代运行时验证；对同一合法/非法 corpus 与 MATLAB 结论完全一致。 |
| P3.5 | P3.3-P3.4 | 建立双端 contract corpus 和 JSON round-trip 测试。 | 所有 F01-F10 manifest 双端通过；所有 F13 manifest 双端拒绝；round trip 后整数、浮点、布尔和可选字段不丢失。 |
| P3.6 | P3.1-P3.5 | 定义 1.x 兼容和升级策略。 | 未知可选字段被安全忽略或保留；缺失必需字段被拒绝；breaking change 有 schemaVersion 提升测试；manifest 小于 100 KiB。 |

P3 的验收证据必须附一份真实 CHGCAR、一份非零原点 Cube 和一份非正交 XSF
manifest，且三份都不包含体素 JSON 数组。

### 19.6 P4：LOD、二进制分块和 uihtml 传输

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P4.1 | P3 | 实现 Float32 little-endian 编码和可选 Uint16 linear quantization。 | Float32 编码/解码 byte-for-byte 相同；跨端字节序测试通过；Uint16 最大误差不超过公式上限。 |
| P4.2 | P4.1 | 实现 256-512 KiB chunk、sequence、offset、byteLength、CRC/checksum 和 transfer 元数据。 | 首块、末块和非整除块长度正确；任一字节篡改可被检测；checksum 覆盖最终规范缓冲区。 |
| P4.3 | P3 | 实现守恒/平均策略明确的自适应 LOD，默认不超过 `128^3`。 | 输出尺寸保持物理长宽比；常量场保持常量；线性场误差满足约定；积分型数据的守恒误差在文档阈值内；原始全分辨率数据未被修改。 |
| P4.4 | P4.2 | 实现 `volume:begin/manifest/chunk/complete/cancel/error` MATLAB 发送状态机。 | 事件顺序可记录；每个事件带 requestId/transferId；取消后不再发送该 transfer 的 chunk/complete；异常只发一次终态。 |
| P4.5 | P4.2 | 实现前端 `VolumeTransferAssembler` 的乱序、重复、覆盖、缺失和 checksum 处理。 | 正序、逆序、随机序、合法重复均重建相同缓冲区；gap、overlap、变异重复、损坏和缺块均拒绝；半成品永不提交 renderer。 |
| P4.6 | P4.4-P4.5 | 实现 stale request 隔离、30 s 超时、取消、进度和关闭释放。 | A→B→A complete 场景最终只显示 B；进度单调；取消 200 ms 内停止组装；超时恢复按钮并显示 transferId；关闭后 assembler 引用清空。 |
| P4.7 | P4.1-P4.6 | 在真实 MATLAB `uihtml` 传输 `128^3` Float32。 | 8 MiB 数据完整重建并校验；主线程单次 long task `<100 ms`；UI 可拖动；完成、取消和关闭路径均无持续内存增长。 |

### 19.7 P5：Volume Viewer 应用外壳与状态机

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P5.1 | P1、P3 | 创建 Vue 3/Vite/Composition API/TypeScript/Vitest 独立应用并接入 workspace。 | `pnpm test`、类型检查和 production build 可独立运行；volume-viewer 不复制科学文件解析器；入口能被 `sync:runtime` 发现。 |
| P5.2 | P4.4-P4.6 | 实现 idle/receiving/decoding/building/ready/cancelled/error 状态机。 | 每个合法转换有单测；非法转换抛稳定错误；所有异步回调先核对 requestId/generation；error/cancel 后可重新加载。 |
| P5.3 | P5.1 | 完成左上信息卡、右侧设置、底部 histogram/probe、工具栏和状态区布局。 | DPR 1/2、窄面板、全屏均无水平滚动；状态只出现在设置区/底部，不遮挡场景中心；信息卡能被简洁模式隐藏。 |
| P5.4 | P1.6、P5.3 | 接入 Materials/Pretty 主题和统一默认规则。 | 默认主题、Visibility、Atomic radii=Atomic、unit cell/polyhedra 默认值符合规格；主题只改变美术参数，不改变 scene 数据。 |
| P5.5 | P1.4-P1.5 | 接入快捷键、全屏、设置、PNG 和无蓝色选中框的工具按钮。 | Space、I、a/b/c/a*/b*/c* 在非输入控件焦点下工作；输入控件中不拦截文本；按钮具备 `aria-label`、tooltip 和可见 hover/pressed 状态。 |
| P5.6 | P5.1 | 实现 WebGL2、3D texture、float linear、Worker、DPR、最大纹理和保守内存 capability 检测。 | 使用固定 capability matrix 得到确定 fallback；缺少任何可选能力均不会出现空白 viewport；用户能看到回退原因。 |
| P5.7 | P5.1-P5.6 | 控制首包和错误边界。 | 初始入口 gzip `<250 KiB`；Worker/重型算法独立 chunk；空数据、非法 manifest、WebGL 创建失败均显示可恢复错误；控制台无未处理 rejection。 |

### 19.8 P6：原子结构叠加与统一相机

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P6.1 | P1、P3、P5 | 读取 optional `atomicOverlay` 并建立 atoms、bonds、cell、polyhedra、axes 图层。 | overlay 缺失时体数据正常；单层非法只关闭该层并报告；默认显示边界近邻、完整键和多面体的策略与 atomic viewer 一致。 |
| P6.2 | P6.1 | 计算网格八角点、原子球和可见图层的联合 bounds。 | 正交/非正交、非零 origin、仅体、仅原子、两者组合均有解析单测；bounds 不使用晶格原点替代几何中心。 |
| P6.3 | P6.2 | 建立单 scene、单 camera、单 controls、单 raycast/selection 管线。 | renderer 中不存在第二套主视相机/controls；左拖旋转、滚轮缩放、右拖平移围绕联合 target；拖动可连续 360°，无俯仰限位。 |
| P6.4 | P1.4-P1.5、P6.3 | 接入 fit、Space、reset `(1,1,1)` 和六晶格方向。 | Space 只修改 target/zoom，不改变 quaternion；reset 恢复定义的正交 `(1,1,1)` 方向；六轴按钮与矢量点积满足 P1.5。 |
| P6.5 | P6.3 | 保证通道、阈值、LOD、representation 和自动 rebuild 保持 camera snapshot。 | 每种更新前后 position、quaternion、target、zoom 误差 `<1e-9`；只有首次加载、Space 和 reset 允许按各自规则改变相机。 |
| P6.6 | P6.1 | 同步 visibility 与 selection 生命周期。 | 隐藏已选 atom/bond/boundary image 时 selection marker 和信息卡立即消失；删除 geometry 后 raycaster 不再命中旧对象。 |
| P6.7 | P6.1-P6.6 | 真实验证 F01/F04/F08 的结构-体网格配准。 | 至少三个可计算探针同时在 MATLAB、前端网格和原子坐标中对齐；视觉截图只作辅助，数值误差按 Float32 容差判定。 |

### 19.9 P7：等值面 MVP

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P7.1 | P4-P5 | 定义 Worker request/result/cancel 协议和 generation 管理。 | request 含 channel、dimensions、threshold、transform、periodicity；取消和超时只有一个终态；旧 Worker 返回不能更新 scene。 |
| P7.2 | P7.1 | 实现 marching tetrahedra/cubes 核心，输出 position/index/normal/bounds。 | F11 球、F12 平面测试通过；没有 NaN 顶点；退化三角形比例 `<1%`；索引均在顶点范围内。 |
| P7.3 | P7.2 | 实现 gradient 定向、顶点去重和平滑/非平滑法线。 | 解析球 99% 以上法线与梯度同向；smooth 开关改变 normals 而不改变表面 bounds；阈值恰过顶点时不生成零面积面。 |
| P7.4 | P7.2 | 应用 grid→world affine transform，支持斜网格和周期终端包裹。 | F12 斜变换后顶点与理论平面距离满足阈值；周期表面跨边连续；不生成重复终端面。 |
| P7.5 | P7.1-P7.4 | 支持 absolute/sigma/percentile、正负双面、颜色、透明度和 visibility。 | 单位切换阈值与 Worker 统计一致；正负 mesh ID 独立；隐藏/调色不重新解析文件；2D grid 禁用等值面。 |
| P7.6 | P7.1-P7.5 | 实现六项/128 MiB LRU cache、20 s Worker 限时和 400 万三角形上限。 | cache key 覆盖 transfer/channel/LOD/value/sign/smoothing/periodic；命中不新建 Worker；淘汰释放 geometry；超限给出可操作提示。 |
| P7.7 | P7.1-P7.6 | 性能和交互验收。 | 参考机 `128^3` 首次等值面 `<2 s`，缓存 `<100 ms`；计算时相机 `≥30 FPS`；连续快速输入最终只显示最后阈值；无无限 spinner。 |

### 19.10 P8：切片、直方图和数值探针

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P8.1 | P4-P5 | 实现 I/J/K 数据抽取，保持 x-fastest 语义。 | F12 三个方向 index 0、中间、末端逐点匹配；没有 x/y/z 交换；切片长度精确等于对应两维乘积。 |
| P8.2 | P8.1 | 用 2D `DataTexture` 和 grid-space 四边形显示切片。 | 正交和斜网格平面四角与 voxel vectors 一致；超过 3D texture 上限时仍可显示切片；纹理更新不泄漏。 |
| P8.3 | P8.1-P8.2 | 实现 nearest/linear、index/分数坐标、colormap、对称/非对称 range 和 NaN mask。 | 插值与 CPU oracle 误差符合 Float32 阈值；只改 range/colormap 不重新传输或重建几何；NaN 不污染 histogram。 |
| P8.4 | P7.5 | 在 Worker 计算完整有限样本 histogram、percentile 和 sigma 数据。 | 所有 bin 计数之和等于有限 voxel 数；1/50/99 percentile 与 MATLAB oracle 在约定容差内；不在主线程扫描完整大数组。 |
| P8.5 | P8.1-P8.4 | 实现鼠标 probe 和状态显示。 | 屏幕点→平面→grid index→value 链路有数值测试；F08 非正交探针与 MATLAB 误差 `<max(1e-6,5e-5×range)`；越界显示无值而非错误旧值。 |
| P8.6 | P8.1-P8.5 | 完成性能和功能边界验收。 | 256×256 切片更新 `<100 ms`；拖动 index 无主线程长卡顿；任意 Cartesian slice 未实现时控件禁用并说明，不展示伪结果。 |

### 19.11 P9：GPU 直接体渲染

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P9.1 | P5.6、P8 | 实现 Float32/HalfFloat/量化 `Data3DTexture` 上传和预检。 | 上传前检查三维尺寸和估算显存；x/y/z 定向纹理测试通过；超限在创建 texture 前回退。 |
| P9.2 | P9.1 | 实现 world/grid/texture 坐标变换和 ray-box intersection。 | CPU 参考与 shader 参数测试一致；F01/F04/F08 的 volume bounds 与 slice/iso bounds 相同；斜网格无镜像。 |
| P9.3 | P9.2 | 实现 transfer function、scalar/gradient opacity、adaptive step、early termination 和 clipping。 | transfer 端点、透明段、对称范围和 clipping 有确定测试图；参数变化只更新 uniform/texture，不重传源数据。 |
| P9.4 | P9.2-P9.3 | 处理透明体、原子结构和 unit cell 的深度组合。 | 前后旋转多个视角无稳定复现的错误遮挡；关闭体层后原子深度恢复；透明排序不产生整帧闪烁。 |
| P9.5 | P9.1-P9.4 | 实现运动时低质量、静止恢复和 capability fallback。 | controls `start/end` 正确切换采样/DPR；支持设备旋转 `≥30 FPS`；不支持时自动回退到 slice/iso 并显示原因。 |
| P9.6 | P9.1-P9.5 | 实现 WebGL context lost/restored。 | lost 时停止渲染并显示可恢复状态；restore 后重新创建 texture/material 并恢复 camera；旧资源引用释放；无空白永久状态。 |

### 19.12 P10：格式高级能力和周期逻辑

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P10.1 | P2、P7-P9 | 完成 CHGCAR total/diff/up/down/non-collinear x/y/z/magnitude 通道。 | F02 up/down 逐点公式成立；F03 magnitude 逐点与 `sqrt(x²+y²+z²)` 一致；非共线不显示错误 up/down。 |
| P10.2 | P2、P7-P9 | 完成 Cube dataset ID、负 NATOMS、NVAL 和多轨道选择。 | F06/F07 每个数据集标签、样本和统计独立；切换不重读文件；选择轨道后 iso/slice/probe 使用同一 channel。 |
| P10.3 | P2、P8 | 完成 XSF 多 Datagrid、2D grid、general/periodic。 | F09 切换 grid 清理上个 histogram/阈值/cache；F10 自动进入 slice 并禁用 direct volume/iso；标签与文件一致。 |
| P10.4 | P2、P7-P9 | 检测 duplicated terminal plane 并统一 periodic wrapping。 | 去重前后物理 bounds 和积分符合 sampling 语义；扩展表面跨界连续且只保留一层；三轴 periodic 可独立控制。 |
| P10.5 | P6、P10.4 | 支持单胞/扩胞范围内体数据与 atomic overlay 的共同裁切。 | 1×1×1、2×1×1、2×2×2 的体和原子使用同一平移；边界键不重复爆炸；camera target 仍为联合中心。 |
| P10.6 | P10.1-P10.5 | 运行高级格式 frozen fixture 回归。 | F02/F03/F06/F07/F09/F10 全通过；每个通道保存一张数值结果表而非只保存截图；切换 100 次无 stale 数据。 |

### 19.13 P11：导出、性能、稳定性和安全边界

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P11.1 | P7-P9 | 实现 PNG、scene JSON、glTF/GLB、PLY、STL、slice PNG/CSV 导出。 | 导出按钮有进行/成功/失败状态；文件名含源文件、channel 和表示；失败不破坏当前 scene/camera。 |
| P11.2 | P11.1 | 建立 mesh/PNG/CSV round-trip 测试。 | GLB/PLY/STL 重新读取后 bounds 每轴误差 `<1e-5 Å`，面数/顶点数符合格式语义；indexed geometry 不丢面；CSV 行列/值与切片一致。 |
| P11.3 | P11.1 | 校准 PNG 的 1×/1.5×/2×、DPR、背景和透明度。 | 实际像素尺寸精确等于用户选择，不被 DPR 二次放大；导出前后 renderer pixelRatio、camera 和 viewport 完全恢复。 |
| P11.4 | P7.6、P8.4 | 实现 statistics、histogram、LOD、isosurface 和 transfer texture 的有界缓存/LRU。 | 每个 cache 有条目和字节上限；key 覆盖全部影响结果的参数；淘汰时 dispose；缓存命中结果与重算 byte/geometry 等价。 |
| P11.5 | P2.6、P7.6 | 实施文件、voxel、channel、mesh、worker、JSON、checksum 和 GPU 内存安全上限。 | 每个限制都有边界值/超限测试；拒绝发生在大分配或 GPU 上传前；错误指出限制、实际值和降低 LOD 等建议。 |
| P11.6 | P11.1-P11.5 | 运行 50 次打开/关闭、200 次阈值变化、30 分钟交互稳定性和 context recovery。 | 第 50 次稳定 heap 相对第 10 次增长 `≤10%`；`renderer.info.memory` 回到允许基线；无无限 spinner、stale 结果、崩溃或持续增长。 |
| P11.7 | P7.7、P8.6、P9.5 | 固化性能报告和 bundle budget。 | `128^3` decode+iso `<2 s`、slice `<100 ms`、cache `<100 ms`、orbit `≥30 FPS`、峰值 `<400 MiB`；entry gzip `<250 KiB`，所有延迟 chunk gzip 合计 `<750 KiB`。 |

性能验收使用三次冷启动的中位数；缓存测试必须明确冷/热路径；浏览器任务管理器、
JS heap 和 `renderer.info.memory` 需分别记录，不能把其中一个当作全部内存证据。

### 19.14 P12：MATLAB 产品集成和发布验收

| ID | 依赖 | 执行内容与产出物 | 逐项验收标准 |
| --- | --- | --- | --- |
| P12.1 | P2-P5 | 实现 `VolumeDisplay` 文档、ready/scene/chunk/cancel/error 桥接和关闭生命周期。 | 真实 `AppContainer+uihtml` 完成握手；关闭时清空 dataset/request/transfer；关闭后的回调不访问无效 HTML 组件。 |
| P12.2 | P2.2、P12.1 | File manager 正确路由 CHGCAR/CHG/Cube/XSF/压缩文件并提供中英文文件选择文案。 | 双击/文件选择均进入 `VolumeDisplay`；不调用 `Structure.from_str(...,'xyz')` 等错误路径；未知格式仍走原有安全提示。 |
| P12.3 | P12.1 | 完成项目树类型、文档标题、图标、重复打开、错误对话框和 busy 状态。 | 同一文件策略确定且有测试；错误对话框不泄漏堆栈给普通用户但日志保留错误 ID；任一路径不会永久 busy。 |
| P12.4 | P5.1 | 将 production build 纳入 `pnpm sync:runtime`，禁止直接编辑 runtime。 | 清理后 build+sync 可复现；`dist` 与 MATLAB runtime 相对文件列表和 SHA-256 完全一致；runtime 修改由生成命令覆盖。 |
| P12.5 | P0.3、P12.4 | 更新第三方许可证、README、架构、用户指南、故障排查和验收记录。 | 许可证只列实际打包依赖；参考但未打包项目注明“设计参考”；用户能按文档独立完成三格式打开、通道选择、表示切换和导出。 |
| P12.6 | P12.1-P12.5 | 在 macOS 执行七个端到端场景及完整 `kssolv('',false)`。 | 七场景全部通过；实际 dimensions/channelCount 与 oracle 一致；加载/计算中关闭、打开第二文件、GPU fallback 和坏文件均可恢复。 |
| P12.7 | P12.1-P12.5 | 在受支持 Windows MATLAB 执行与 macOS 相同的测试矩阵。 | 不允许用浏览器单测代替 Windows `uihtml`；版本、GPU、DPR、日志和结果登记；平台差异有修复或明确发布限制。 |
| P12.8 | P11.6-P12.7 | 发布候选终验和签收。 | 自动测试、Code Analyzer、build、checksum、两平台 E2E、30 分钟稳定性全部通过；不存在 S0/S1，S2 为零，S3 有版本和责任人；验收记录签字。 |

### 19.15 阶段依赖和允许并行关系

```text
P0
 ├─ P1 ───────────────┐
 └─ P2 ─ P3 ─ P4 ─ P5 ─ P6
                      ├─ P7 ─ P8 ─┐
                      └──────── P9 ├─ P10 ─ P11 ─ P12
                                   ┘
```

- P1 的类型/相机抽取可与 P2 的 MATLAB 格式适配并行，但 P5/P6 开始前必须合并。
- P3 contract 冻结前不得开始正式 P4 传输，避免同时维护多个不兼容 schema。
- P8 的 histogram Worker 可在 P7 后半段并行；切片坐标必须复用已经验收的 grid
  transform。
- P9 可在 P8 基础纹理和 capability 检测完成后并行开发，但不能绕过 P8 的
  x/y/z 定向测试。
- P10 必须复用 P2 adapters，不得在前端增加格式特判解析。
- P11 的安全限制从 P2/P4/P7 起逐步加入，P11 负责统一压力验证而不是最后才补。

### 19.16 每阶段最终签收检查表

阶段负责人提交验收前逐项确认：

- [ ] 本阶段所有工作项均为“完成”，或非关键项有批准的“延期”记录。
- [ ] 自动测试命令从干净构建开始执行并返回 0。
- [ ] MATLAB 测试和 Code Analyzer 没有新增 warning/error。
- [ ] crystal-viewer 回归通过，Pretty 主题没有非预期视觉变化。
- [ ] 真实 `uihtml` 路径已测试，不以普通浏览器开发服务器替代。
- [ ] 科学结果与 oracle/MATLAB 交叉验证，不仅依赖截图。
- [ ] 异步取消、stale result、错误恢复和文档关闭路径已测试。
- [ ] 相机位置、姿态、target、zoom 的保持规则已测试。
- [ ] Worker、ArrayBuffer、Geometry、Material、Texture 和监听器已释放。
- [ ] 性能指标注明冷/热路径、数据规模、DPR 和测试机器。
- [ ] runtime 由构建同步生成，源码与运行时校验和一致。
- [ ] 用户文档、错误信息、第三方许可证和实现一致。
- [ ] 已登记未解决问题、严重度、责任人和目标版本。

### 19.17 阶段证据矩阵与发布闸门

下表规定各阶段最少需要交付的证据类型。表中的“自动”必须是可重复执行且返回
退出码的命令；“产品”必须走 MATLAB `AppContainer + uihtml + production
runtime`，普通浏览器预览只能作为补充。

| 阶段 | 自动化证据 | 科学/协议证据 | 真实产品人工动作 | 性能/资源证据 | 阶段失败闸门 |
| --- | --- | --- | --- | --- | --- |
| P0 | 版本采集、fixture SHA、baseline 脚本 | F01-F13 oracle 可独立读取 | 在目标机复跑基线入口 | 三次中位数及测量区间 | 环境或 oracle 不可复现 |
| P1 | atomic/three/crystal 全量测试、typecheck、build | scene snapshot 和相机向量误差 | crystal-viewer 六轴、Space、主题、导出、关闭 | gzip、FPS、GPU resource baseline | 任一 crystal 科学/交互回归 |
| P2 | 各 adapter、registry、limit 的 MATLAB 测试 | 每格式至少 8 个非对称探针和积分/单位 | 从真实文件对话框打开压缩/未压缩样例 | 大声明/坏文件在分配前拒绝 | 轴交换、通道串位、错误路由 |
| P3 | MATLAB/TS validator 与 corpus round-trip | 同一合法/非法 corpus 双端结论一致 | production runtime 接收真实 manifest | manifest `<100 KiB` | 协议含内联体素或双端分歧 |
| P4 | chunk/CRC/乱序/重复/gap/取消/超时测试 | 重建缓冲区 checksum 与源缓冲区一致 | `uihtml` 传输并中途关闭/换文件 | `128^3` 传输、long task、heap | 半成品提交、stale complete、永久 busy |
| P5 | 状态机、capability、组件和无障碍测试 | fallback matrix 与协议状态一致 | 设置、快捷键、全屏、错误恢复 | entry gzip 与首交互时间 | 空白 viewport、不可恢复 error |
| P6 | bounds、camera、axis、selection 测试 | 网格/原子至少 3 个坐标探针对齐 | 旋转/缩放/平移/六轴/隐藏 selection | 连续交互 FPS 与资源回收 | 相机跳变、坐标错位、旧对象可命中 |
| P7 | iso worker、几何、normal、cache、cancel 测试 | 球/平面/斜网格解析 oracle | 阈值快速拖动、正负面、关闭重开 | `128^3` 冷/热耗时与 FPS | stale mesh、NaN/退化爆炸、无限 spinner |
| P8 | I/J/K、texture、histogram、probe 测试 | 切片逐点、percentile、非正交 probe | 三方向切换、range/colormap、越界 probe | 256² 更新和主线程 long task | 轴交换、旧值残留、NaN 污染 |
| P9 | texture orientation、shader 参数、fallback/context 测试 | ray/grid/world 变换与 CPU 参考一致 | 旋转透明体、clipping、context 恢复 | 运动/静止采样、FPS、GPU memory | 镜像、错误遮挡、context 后永久空白 |
| P10 | 高级通道/多 grid/periodic frozen 回归 | 逐点公式、标签、积分和边界连续性 | 100 次通道/grid/扩胞切换 | cache/heap 不持续增长 | 通道公式错误、重复边界、键爆炸 |
| P11 | 全导出 round-trip、limits、LRU 测试 | mesh bounds/面数、CSV 数值、PNG 像素尺寸 | 每格式导出、失败恢复、场景保持 | 50 次开关、200 次阈值、30 分钟 soak | 导出损坏、泄漏、超过预算 |
| P12 | MATLAB suites、Code Analyzer、build、sync checksum | 全 fixture dimensions/channel/oracle 报告 | macOS/Windows 七场景及完整 KSSOLV | 两平台日志、DPR/GPU、长期稳定性 | 任一 S0/S1、S2 未清零、runtime 不一致 |

发布候选只有在 P12.8 的全部输入证据均来自同一候选版本时才有效。任何 production
源码、依赖锁文件、MATLAB bridge 或 runtime 文件发生变化，都必须重新执行受影响
阶段及其下游阶段；不能沿用旧构建的截图、性能数据或 checksum。

P12.7 的逐条操作、PowerShell 命令、七场景矩阵和证据归档格式见
[Windows 发布验收执行单](volume-viewer-windows-acceptance.zh-CN.md)。
