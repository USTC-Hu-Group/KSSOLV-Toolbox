# KSSOLV Toolbox 生产级建模系统 P1-P10 开发与验收计划

> Materials Studio 交互建模、力场、生产 QA 和 Modeling Tab 图标重构的当前
> P1–P6 执行台账见
> [`ms-modeling-parity-p1-p6.zh-CN.md`](ms-modeling-parity-p1-p6.zh-CN.md)。
> 新台账关闭 P1 生产一致性门之前，本文历史阶段状态不能作为当前候选的最终
> 视觉或真实用户路径验收结论。

## 1. 文档状态

- 目标：全面完成 P1-P10，使 KSSOLV Toolbox 日常原子级材料建模的手感、可靠性和工作流成熟度达到 Materials Studio Visualizer 同等级别。
- 当前平台范围：macOS 与本机 MATLAB R2026b。Windows/Linux 暂不作为阶段验收阻塞项，但实现不得主动引入平台绑定的科学语义或数据格式。
- 实现要求：生产级代码、稳定目录边界、真实 MATLAB `AppContainer + uihtml` 验证；浏览器单元测试不能替代 MATLAB 集成测试。
- 完成条件：只有 P1-P10 的全部交付物和验收证据均通过，才能宣告总目标完成。
- 维护规则：每完成一个工作项，必须在本文件的验收台账中登记测试命令、候选提交、日志或报告位置。计划文本不能替代实现和测试证据。

## 2. 开发背景与当前基线

Materials Studio 的成熟体验并不只来自功能数量，而是来自以下能力形成的闭环：

1. 分子和晶体使用一致的选择、移动、旋转、测量和属性编辑方式；
2. 3D Sketch、键级、芳香性、价态、自动补氢、片段和几何清理形成快速分子建模流程；
3. 空间群、非对称单元、超胞、缺陷、切面、真空层、吸附和层状结构形成连续晶体/表面工作流；
4. 聚合物、混合物、非晶盒和受限层具备组成、密度、随机种子和碰撞控制；
5. 每次操作都具有预览、应用、取消、撤销、重做、保存和脚本重放能力；
6. 快捷键、上下文菜单、选择集、参数记忆、错误诊断和教程降低建模成本。

KSSOLV 当前已经具有较强的科学算法基础：原子和晶格编辑、超胞、点缺陷、SQS、表面、吸附位、表面钝化、溶剂层、异质结、莫尔超晶格、NEB 插值、纳米管、纳米带、纳米线、量子点以及对称性分析已经进入命令目录。Atomic Viewer 也已经支持晶体和有限分子的统一渲染、周期键、多重键、测量、选择、导出和撤销/重做。

当前主要断点是：

- Modeling Tab 和视窗上下文编辑仍限制为晶体；
- 视窗上下文只暴露删除、替换、移动和平移四类命令；
- 参数输入以通用文本/数值对话框为主，缺少实时预览和直接操纵；
- 键拓扑尚不是统一可编辑的一等模型；
- 分子 Sketch、化学语义、片段、聚合物和完整非晶构建缺失；
- 快捷键、操作记录、GUI E2E、故障恢复和任务级可用性基准不足。

> 候选版本状态（2026-08-09）：上述断点已由 P1-P9 实现和 P10 自动可靠性门补齐；本段保留为立项基线。旧候选因运行时缺陷已作废，当前优先继续调整和修复代码，不执行四小时测试。尚未关闭的外部门包括重新冻结候选后的稳定性资格评估，以及至少 10 名领域用户在授权 Materials Studio 环境中的同硬件盲测。详见第 17 节台账。

因此，本计划优先建立统一编辑与交互底座，再扩展分子、晶体、表面、聚合物和非晶能力，最后完成自动化和发布级成熟度。不能用增加更多孤立对话框来代替交互底座，也不能用算法单测代替真实 GUI 验收。

## 3. 设计原则与工程目录

### 3.1 科学数据所有权

- MATLAB/matgenlab 是结构、拓扑、周期性、化学语义和命令执行的唯一科学事实源。
- TypeScript/Vue 负责低延迟交互、预览和显示，不得静默推断或提交化学事实。
- 前端预览结果必须携带基线 revision；MATLAB 只接受与当前文档 revision 匹配的 commit 请求。
- 所有建模命令均在副本上执行；只有场景构建、验证和渲染成功后才能提交。

### 3.2 推荐目录边界

```text
+kssolv/+modeling/
├── +commands/          # atomic/bond/molecule/crystal/surface/... 命令
├── +contracts/         # capability、request/result、revision、transaction
├── +chemistry/         # 价态、补氢、芳香性、杂化和化学检查
├── +geometry/          # 几何约束、对齐和 monitor 反向编辑
├── +builders/          # 晶体、表面、纳米、聚合物、非晶构建器
├── +fragments/         # 内置/用户片段模型和连接点
├── +polymers/          # 重复单元、序列、立构和链构象
├── +packing/           # Construction/Packing/ConfinedLayer
├── +provenance/        # 操作历史、脚本记录和重放
└── +test/              # 科学不变量、契约、功能和性能测试

+kssolv/+ui/+features/+modeling/
├── +dialogs/           # 适合对话框的离散参数任务
├── +interaction/       # 会话、预览、选择、直接操纵和事务协调
├── +presenters/        # 分析结果和派生结构展示
└── +test/

frontend/apps/crystal-viewer/src/modeling/
├── contracts/          # 前端建模协议镜像与验证
├── interaction/        # selection、gizmo、sketch、snap、shortcut
├── tools/              # atom/bond/measure/align/surface 工具状态机
├── components/         # 上下文菜单、属性面板、工具选项、诊断
└── tests/
```

新代码应逐步迁入上述边界。既有文件可以兼容转发，但不得长期继续扩张单体 `ModelingTab.m`、`MoleculeDisplay.m`、`App.vue` 或通用 `ParameterSchema.m`。

### 3.3 UI 变更决策规则

| 功能类型 | 首选入口 | 新增菜单/工具栏条件 |
| --- | --- | --- |
| 高频、选择驱动、一步完成 | 视窗上下文菜单与快捷键 | 对当前选择有效且无复杂参数 |
| 高频、连续交互 | Viewer Toolbar 工具模式 | Sketch、Gizmo、测量修改、对齐 |
| 中频、多个离散参数 | Modeling Tab 专用命令/向导 | 超胞、晶体、表面、聚合物、非晶 |
| 低频分析或批处理 | Modeling Tab/Workflow/API | 构型枚举、批量、脚本和报告 |
| 当前对象属性 | Selection Inspector/Properties | 元素、坐标、键级、约束和 site 属性 |

禁止行为：

- 为每个命令增加一个互不一致的自由文本对话框；
- 在前端和 MATLAB 各维护一套不一致的默认参数；
- 将仅改变显示范围的功能命名为 Supercell；
- 在未提示等价位影响时直接执行对称约束下的破坏性编辑；
- 用离线 HTML 编辑结果冒充已保存的 MATLAB 项目结构。

## 4. 全局 Definition of Done

每个 P 阶段除阶段专属标准外，还必须满足：

1. **科学正确性**：原子数、组成、周期性、坐标、拓扑、site properties 和结构元数据只发生命令声明允许的变化。
2. **事务完整性**：预览不修改文档；Apply 原子提交；Cancel 零副作用；Undo/Redo 可逆；失败不产生半提交结果。
3. **确定性**：无随机性的命令结果稳定；有随机性的命令接受显式 seed 并可重放。
4. **输入安全**：非法形状、NaN/Inf、陈旧 revision、超限原子数和不可满足约束在大分配或提交前被拒绝。
5. **UI 完整性**：入口、disabled 原因、busy、进度、取消、错误和成功状态齐全；中英文文案同步。
6. **测试完整性**：MATLAB 单元/功能测试、前端 Vitest/typecheck/build、真实 MATLAB UI 测试全部通过。
7. **资源完整性**：关闭文档、取消任务和重复预览后，无 timer、listener、worker、临时文件、GPU 资源或缓存泄漏。
8. **文档完整性**：用户教程、API、限制、验收记录和第三方许可证随功能更新。

## 5. 测试环境与证据

### 5.1 固定环境

- macOS 本机；
- MATLAB R2026b；
- 仓库根目录为 MATLAB 当前目录；
- 前端使用仓库锁定依赖；
- GUI 测试使用 production build 同步后的 runtime，而非 Vite dev server。

### 5.2 每阶段最低自动测试

```bash
cd frontend
pnpm --filter @kssolv/crystal-viewer test
pnpm --filter @kssolv/crystal-viewer typecheck
pnpm --filter @kssolv/crystal-viewer lint:check
pnpm --filter @kssolv/crystal-viewer build
pnpm sync:runtime
```

MATLAB R2026b 必须实际执行相关 suites，并最终执行：

```matlab
cd('/Users/liu/Documents/GitHub/KSSOLV-Toolbox');
addpath(fullfile(pwd, '+kssolv', '+core', 'kssolv-3o'));
KSSOLV.startup();
results = runtests({ ...
    '+kssolv/+modeling/+test', ...
    '+kssolv/+ui/+test', ...
    '+kssolv/+analysis/+matgenlab/+test'});
assertSuccess(results);
```

阶段验收还必须启动真实 KSSOLV Toolbox，完成相应 `AppContainer + uihtml` GUI 场景，保存日志、截图或结构导出文件。只运行命令类不能证明 UI 完成。

### 5.3 证据目录

```text
dev/modeling/acceptance/
├── baselines/          # 冻结输入、结构哈希和科学 oracle
├── reports/            # MATLAB/Vitest/性能/可用性报告
├── scenarios/          # 真实 GUI 场景驱动
└── README.md            # 候选版本、命令、环境和结果索引
```

## 6. P1：统一 Crystal/Molecule 可编辑模型与事务契约

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P1.1 | 冻结现有命令、AtomicSceneSpec、项目保存和导入/导出的科学基线。 | 无；建立证据。 |
| P1.2 | 建立模型种类、选择要求、参数、预览能力和结果种类的声明式 CommandCapability。 | Modeling Tab 按能力启用/禁用并显示原因。 |
| P1.3 | 抽象 Crystal/Molecule 共用原子编辑接口，键拓扑成为可编辑一等对象。 | 分子文档显示 Modeling Tab；不适用命令禁用。 |
| P1.4 | 建立带 revision 的 Preview/Commit/Cancel 事务协议和 MATLAB/TS validator。 | 新增统一预览状态条、Apply/Cancel。 |
| P1.5 | 使删除、替换、移动、平移、Undo/Redo/Reset 同时适用于 Molecule。 | 分子右键菜单启用现有四项；历史区可用。 |
| P1.6 | 完成项目持久化、导出和关闭保存/丢弃对 Molecule 的回归。 | 保存提示统一。 |

### 验收标准

- CIF、XYZ、MOL、SDF、MOL2、PDB 各至少 10 个样本导入、编辑、保存、重开后非目标数据无损；带源拓扑格式保持键级。
- Crystal/Molecule 均可执行四类上下文命令和历史操作。
- Cancel 后模型 canonical hash 与预览前一致；陈旧 revision 的 commit 100% 被拒绝。
- 命令不支持当前模型时，UI disabled 且给出原因，不能等执行后才抛错。
- P1 前全部自动测试继续通过；新增契约测试覆盖无效、陈旧、混合模型和超限请求。
- 真实 MATLAB 中分别打开晶体和分子完成编辑、撤销、保存、关闭、重开。

## 7. P2：选择、快捷键、Gizmo 与直接操纵

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P2.1 | click/toggle/add、矩形、套索、按元素、按连通组、按分子选择。 | Viewer Toolbar 新增 Selection；右键增加选择扩展。 |
| P2.2 | 建立命名 Selection Set，保存 site ID 而非渲染实例 ID。 | Modeling Tab 增加 Selection Sets。 |
| P2.3 | 实现 translate/rotate Gizmo、X/Y/Z 约束、Cartesian/Fractional 模式。 | Toolbar 新增 Move/Rotate；Inspector 数值微调。 |
| P2.4 | 建立 snap、键长保持、周期映像映射和低成本预览。 | Tool Options 显示轴、步长和坐标。 |
| P2.5 | 扩展快捷键路由和可配置 keymap；输入控件焦点安全。 | Help/Shortcut 面板与 tooltip。 |
| P2.6 | 建立交互性能和选择正确性压力测试。 | 无。 |

### 验收标准

- 1000 原子点击反馈 `<100 ms`、拖动 `>=45 FPS`；10000 原子框选不阻塞 UI 超过 `500 ms`。
- 周期映像正确归一到 site，删除或移动不重复执行。
- 一次 pointer drag 只生成一个历史记录；Undo/Redo 坐标误差 `<1e-10 Å`。
- Selection Set 在重复范围变化、渲染重建和项目重开后仍指向正确 site。
- 输入框中输入 Space/I/X/Y/Z 不触发 Viewer 命令。
- 对标选择、移动、旋转和删除任务的点击数不超过 Materials Studio 的 `1.25x`。

## 8. P3：分子 3D Sketch 与化学语义

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P3.1 | 创建空白 Molecule 文档和 Sketch 工具状态机。 | Home/New 增加 Molecule；Toolbar 增加 Sketch。 |
| P3.2 | 实现原子链、原子插入、合并、连接/删除键和 3-8 元环。 | Sketch Options 增加元素、环尺寸。 |
| P3.3 | 实现单/双/三/芳香键及键级/芳香性编辑。 | Bond 上下文菜单和 Properties。 |
| P3.4 | 实现元素、形式电荷、杂化、价态诊断。 | Atom Properties 增加 Chemistry。 |
| P3.5 | 实现自动补氢、删氢和显式氢策略。 | Modeling/Molecule 增加 Adjust Hydrogen。 |
| P3.6 | 实时显示碰撞、异常键长和非法价态。 | Warning Stack 可定位对象。 |

### 验收标准

- 从空白构建水、苯、乙醇、甲醛、吡啶和苯甲酰胺，分子式/拓扑匹配 oracle。
- MOL/SDF round-trip 保持单、双、三和芳香键语义。
- 至少 50 个标准有机分子自动补氢正确率 `>=98%`；失败不得静默修改。
- 每次原子、键、环、元素、补氢操作均独立可撤销。
- 训练用户构建苯甲酰胺中位时间 `<=2 min`。
- 非法价态具有明确 warning/error；规则 Clean 不得表述为能量最小化。

## 9. P4：精确几何编辑、对齐与片段库

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P4.1 | 将距离、角度和二面角 Measurement 升级为可编辑 Monitor。 | Inspector 增加 Edit Value 与固定端模式。 |
| P4.2 | 支持移动单原子、连通子树、片段及周期最小映像。 | Tool Options 增加 movement scope。 |
| P4.3 | 实现质心、最佳拟合线/面、主轴及点/轴/面对齐。 | Modeling 增加 Geometry/Align。 |
| P4.4 | 建立内置片段目录、连接头、预览和搜索。 | Toolbar 增加 Fragment；Fragment Browser。 |
| P4.5 | 支持用户定义片段、版本化存储和导入/导出。 | My Fragments。 |
| P4.6 | 实现规则几何 Clean，并为力场优化预留接口。 | Molecule 菜单增加 Clean。 |

### 验收标准

- 目标键长、键角、二面角误差分别 `<1e-6 Å`、`<1e-5°`、`<1e-5°`。
- 跨周期边界测量和反向编辑使用同一最小映像。
- 片段连接后无哑原子、重复原子和悬空错误键；形式价正确。
- 至少 100 个片段装配回归通过；用户片段重启后可用并保持 schema 兼容。
- 分子轴/表面法向对齐误差 `<0.01°`。
- Clean 前后组成和拓扑不变；异常输入返回诊断而非随机重排。

## 10. P5：晶体构建器、对称性与缺陷

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P5.1 | 从空间群、晶格和非对称单元建立晶体。 | New/Modeling 增加 Crystal Builder。 |
| P5.2 | 实时展开等价位，显示 Wyckoff、占位率和重合诊断。 | Builder live preview/table。 |
| P5.3 | 贯通 Make P1、原胞、常规胞、超胞和显示重复范围。 | Symmetry 新增 Make P1。 |
| P5.4 | 编辑对称位前预估影响，支持保留/打破对称性。 | 破坏性编辑确认。 |
| P5.5 | 点缺陷构型枚举、等价归并、简并度、净电荷和最短距离。 | Defect Wizard/Results。 |
| P5.6 | 建立晶体构造和缺陷 frozen oracle。 | 无。 |

### 验收标准

- 至少 20 个参考晶体从空间群/非对称坐标重建，空间群号、组成、标准化结构匹配。
- 对称展开分数坐标误差 `<1e-6`；占位率和 site properties 保留。
- Make P1 前后笛卡尔几何不变；Display Repeat 不改变模型原子数。
- Supercell 原子数严格乘以整数矩阵行列式绝对值。
- 单空位只减少一个 site；对称编辑影响范围执行前可见。
- 缺陷向导报告简并度、净电荷和最短接触，并可生成派生结构集合。

## 11. P6：表面、吸附与界面产品化

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P6.1 | Miller 面、切面位置、slab 厚度和终止面实时预览。 | Surface Builder 向导。 |
| P6.2 | 表面超胞、真空、居中和上下表面联动。 | Builder 第二步和摘要。 |
| P6.3 | 吸附位可视化、吸附物拖放、方向/高度/锚点。 | Adsorbate Placement 工具。 |
| P6.4 | 按层选择和固定底层；表面集合持久化。 | 右键/Selection Sets。 |
| P6.5 | 异质结候选按面积、应变、旋转、原子数排序。 | Interface Builder 候选表。 |
| P6.6 | 莫尔构造前预估原子数、应变和角度误差。 | Moire 预检查摘要。 |

### 验收标准

- Pt(111)、Si(001)、MgO(100) slab 的法向、层厚、周期方向和组成正确。
- 真空实测误差 `<0.01 Å`；吸附高度误差 `<0.01 Å`。
- 吸附物不会因周期包装被重复或拆分；锚点/方向可重放。
- 异质结实际主应变不超过上限，报告和模型误差 `<1e-8`。
- 超过 maximumAtoms 时构造前拒绝。
- “切面-扩胞-真空-位点-吸附物-固定底层”不要求手工输入 site index。

## 12. P7：聚合物构建器

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P7.1 | 重复单元头/尾和离去原子定义、校验、库管理。 | Modeling 新增 Polymers/Repeat Unit。 |
| P7.2 | 均聚物：链长、链数、端基、初始构象。 | Homopolymer Wizard。 |
| P7.3 | 嵌段共聚物：block 序列、superunit、独立链。 | Block Copolymer Wizard。 |
| P7.4 | 无规共聚物：概率矩阵、精确组成、反应活性比、seed。 | Random Copolymer Wizard。 |
| P7.5 | 立构规整性、头尾翻转和序列诊断。 | Advanced/Tacticity。 |
| P7.6 | 支化和基础树枝状聚合物。 | Branch/Dendrimer Wizard。 |

### 验收标准

- PE、PP、PS、PEO、PEO-PPO-PEO 的重复单元数、端基和元素组成完全正确。
- 连接处无重复原子、缺键或低于阈值的异常接触。
- 强制组成模式单体数严格匹配；概率模式报告实际组成。
- 相同 seed 产生完全相同序列和初始构象。
- isotactic/syndiotactic/atactic 手性序列 oracle 全部通过。
- 10000 原子线性聚合物初始构造 `<5 s`，构造前显示原子数预估。

## 13. P8：非晶、混合物、溶剂化与受限层

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P8.1 | Construction：组成、分子数、密度、盒形和 seed。 | Modeling 新增 Amorphous/Construction。 |
| P8.2 | Packing：向已有盒、区域、纳米粒子周围填充分子。 | Packing Wizard。 |
| P8.3 | Confined Layer：沿 A/B/C 或表面法向构建受限层。 | Confined Layer Wizard。 |
| P8.4 | 摩尔比、质量比、精确分子数、density ramp、分批装填。 | Composition Table/Advanced。 |
| P8.5 | 环穿刺、链互锁、碰撞、失败诊断和安全取消。 | Diagnostics/Progress。 |
| P8.6 | 压缩、退火、NVT/NPT 模板；明确未平衡状态。 | Finish/Create Workflow。 |

### 验收标准

- 水、乙醇/水、聚合物/增塑剂体系组成和分子数严格匹配。
- 初始盒密度误差 `<0.5%`；不存在低于 tolerance 的非键接触。
- 环穿刺 fixture 零漏报；不可满足装填返回明确失败。
- 相同 seed 可复现；三类任务均可脚本重放。
- 10000 原子目标机 `<60 s`；100000 原子任务提供进度、取消和清理。
- 结果标记 `packed_not_equilibrated`，除非真实平衡任务正常结束。

## 14. P9：自动化、模板、批处理与溯源

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P9.1 | 稳定 `kssolv.api.v1.modeling` API 和 schema/version 策略。 | Help/API 文档。 |
| P9.2 | 操作记录器生成可读 MATLAB 脚本或 recipe。 | Modeling 新增 Recorder。 |
| P9.3 | 参数预设、recipe、项目模板和用户库。 | Presets/Templates。 |
| P9.4 | 批量导入、建模、验证、导出和错误汇总。 | Workflow/Batch Modeling。 |
| P9.5 | 保存来源、命令、参数、seed、版本、父结构、结果 hash。 | Inspector/lineage。 |
| P9.6 | 长任务进度、取消、恢复和隔离。 | Jobs/Run Browser。 |

### 验收标准

- 录制至少 10 步 GUI 建模并重放；确定性步骤结果 hash 一致。
- 旧 minor schema 可兼容或给出可操作迁移错误，不允许静默误读。
- 批处理 100 个结构无会话串扰、句柄泄漏和持续内存增长。
- 取消后无 worker/timer/temp file/半提交结构残留。
- 任一派生结构可追溯到父结构、输入、完整参数、seed 和实现版本。
- Recipe 在干净 MATLAB 会话可运行，不依赖 GUI 隐式状态。

## 15. P10：Mac 产品成熟度与真实 MATLAB 终验

### 开发步骤

| 编号 | 工作项 | UI/菜单影响 |
| --- | --- | --- |
| P10.1 | 建立真实 AppContainer/uihtml 自动化场景和故障注入。 | 测试基础设施。 |
| P10.2 | 自动保存、崩溃恢复、损坏项目诊断和安全关闭。 | 恢复对话框/状态。 |
| P10.3 | 中英文、键盘导航、缩放、tooltip、disabled reason、无障碍。 | 全建模 UI。 |
| P10.4 | 用户教程、快捷键图、示例项目、API 和故障排查。 | Help/Getting Started。 |
| P10.5 | 性能、内存、资源和 soak 基线。 | 开发报告。 |
| P10.6 | 与 Materials Studio 的 12 个任务做同硬件可用性对标。 | 形成报告。 |
| P10.7 | 构建 production runtime/toolbox 并完成 requirement audit。 | About 显示候选版本/schema。 |

### 十二个终验任务

1. 从空白构建苯甲酰胺并导出 MOL/SDF；
2. 从空间群和非对称坐标构建参考晶体；
3. 建立超胞并创建单空位；
4. 创建 Pt(111) slab、表面超胞和真空层；
5. 将分子放到指定吸附位、高度和方向；
6. 建立二维异质结及莫尔候选；
7. 建立指定链长和立构的均聚物；
8. 建立指定 block 序列的嵌段共聚物；
9. 建立指定组成和密度的非晶混合物；
10. 在表面上建立受限溶剂层；
11. 将 GUI 操作录制并在干净会话中重放；
12. 批量处理 100 个结构并生成溯源报告。

### 验收标准

- macOS + MATLAB R2026b 桌面版及本机部署构建通过全部自动和真实 GUI 场景。
- 故障注入覆盖后端异常、渲染失败、保存失败、加载中关闭和陈旧请求，零数据丢失。
- 连续 4 小时、500 次编辑后稳定 heap 增长 `<=10%`；无遗留 worker、timer、listener、临时文件和 WebGL 资源。
- 12 个对标任务的训练用户中位时间和点击数均不超过 Materials Studio 的 `1.2x`。
- 至少 10 名领域用户完成测试，核心任务成功率 `>=95%`，S0/S1/S2 缺陷为零。
- 核心建模分支覆盖率 `>=85%`；每个科学构建器具有独立数值不变量测试。
- production build、runtime sync、MATLAB 测试、Code Analyzer、项目保存/重开和文档检查全部来自同一候选版本。

## 16. 阶段依赖与发布节点

```text
P1 -> P2 -> P3 -> P4 -> P5 -> P6 -> P7 -> P8 -> P9 -> P10
```

允许并行研究，但验收按依赖顺序：

- M1 = P1-P2：统一编辑内核和基础手感；
- M2 = P3-P5：分子、几何和晶体建模日常可用；
- M3 = P6-P8：表面、聚合物和非晶形成完整套件；
- M4 = P9-P10：自动化、可靠性和正式发布成熟度。

任何 M 节点都不是总目标完成。P10 终验前，本开发目标保持进行中。

## 17. 完成审计台账

要求级逐项证据和未关闭项见
[`modeling-requirement-audit.zh-CN.md`](modeling-requirement-audit.zh-CN.md)。阶段场景通过
不自动将整阶段标记为“已验收”。

状态只允许：`未开始`、`进行中`、`已实现待验收`、`已验收`。

> 下表 P1–P6 的“已验收”仅表示原有命令/算法基线关闭，不表示 Materials
> Studio 交互体验对标已完成。生产宿主、真实指针、通用吸附、力场和视觉门禁的
> 当前状态以链接的
> [P1–P6 对标执行台账](ms-modeling-parity-p1-p6.zh-CN.md) 为准；该台账目前仍为
> `进行中`。

| 阶段 | 状态 | 实现证据 | 自动测试证据 | MATLAB GUI 证据 | 性能/可用性证据 |
| --- | --- | --- | --- | --- | --- |
| P1 | 已验收 | 统一 capability/revision 事务、Crystal/Molecule 编辑、键拓扑和安全关闭 | 建模全量 120/120；六格式各 10 个项目重开 hash 精确一致 | `runP1MoleculeEditingAcceptance`，R2026b/MACA64 | Preview/Cancel/陈旧 revision/能力禁用均通过 |
| P2 | 已实现待验收 | Selection Set、Box/Lasso、Move/Rotate、轴约束、snap、可配置 keymap | 前端全量 249/249；10,000 投影点选择性能门通过 | `runP2DirectManipulationAcceptance`，单拖拽单历史、误差 0 | 自动门关闭；授权 Materials Studio 点击比并入 P10 外部门 |
| P3 | 已实现待验收 | 3D Sketch、键级、化学语义、补删氢、实时 Warning Stack | 六分子 oracle、50 个补氢样本与格式回环通过 | `runP3P4MoleculeBuilderAcceptance` | 自动门关闭；两分钟真人计时并入 P10 外部门 |
| P4 | 已验收 | 可编辑 Monitor、movement scope、对齐、Fragment Browser/导入导出、Clean | 几何数值门和 100 次片段装配通过 | `p3-p4-20260809-033140` | 自动验收关闭 |
| P5 | 已验收 | Crystal Builder 等价位/Wyckoff/占位率、对称编辑规划、缺陷结果 | 20 晶体 frozen oracle 及功能测试通过 | `runP5P6CrystalSurfaceAcceptance` | 自动验收关闭 |
| P6 | 已验收 | 终止面/层/固定、吸附物、界面旋转候选、莫尔预检 | 三 slab frozen oracle 与非零旋转真实命令测试通过 | `p5-p6-20260809-042831` | 自动验收关闭 |
| P7 | 已验收 | 用户重复单元、多链/端基/构象、superunit、活性比、头尾、dendrimer | `PolymerPackingFunctionalTest` 13/13 | `p7-p8-20260809-042850` | 9,998/9,999 原子低于 60 s，UI 预估已接入 |
| P8 | 已验收 | 既有盒/纳米粒子排除、受限层、真实 density ramp/batch、互锁诊断 | 密度/接触/seed/取消/环穿刺/互锁 fixture 通过 | `p7-p8-20260809-042850` | 自动验收关闭 |
| P9 | 已验收 | API/Recorder、参数预设、项目模板、文件批处理、lineage、Jobs/恢复 | `ModelingAPIFunctionalTest` 11/11 | `p9-20260809-043456` 与 Jobs/Library Browser 构造测试 | 100 项批处理、取消和 checkpoint 恢复通过 |
| P10 | 已实现待验收 | 恢复/安全关闭、双语/无障碍自动层、教程/示例、故障注入、发布打包 | 最新源码建模 120/120、建模/scene/UI 61/61、Code Analyzer 0/0；上一候选前端 249/249、覆盖率 85.309% | 旧候选七场景和 500-edit 曾通过，但因 Modeling Guide 回调缺陷已 superseded；修复后真实 macOS 打开指南通过 | 修复期间不再执行四小时测试；调整完成后须重跑候选门禁，仍需 200%/键盘人工签字和授权 MS 10 用户盲测 |

只有每一行均为“已验收”且证据可从当前候选版本复现时，P1-P10 总目标才算完成。
