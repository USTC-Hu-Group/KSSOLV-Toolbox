# KSSOLV Toolbox 对标 Materials Studio 建模体验 P1–P6 执行计划

## 1. 目标与完成定义

本计划把 KSSOLV Toolbox 的晶体/分子建模体验推进到可与 BIOVIA
Materials Studio Visualizer 对照验收的水平，范围包括：

- 通用 3D Sketcher，而不是针对单一 OH 基团的专用手势；
- Fragment Sketcher、内置片段和用户自定义片段；
- 规则 Clean、价态/补氢诊断和具有明确能量模型的几何优化；
- 精确移动、旋转、定位、键级/杂化编辑与实时几何 Monitor；
- 任意分子/混合物的表面放置和可验证的 Adsorption Locator；
- 与生产 KSSOLV 完全一致的 QA 宿主、构建产物和真实输入路径；
- 统一、简洁且语义可辨的 Modeling Tab 图标系统。

只有 P1–P6 的实现、自动测试、真实 MATLAB GUI 证据、视觉证据和逐项审计
全部通过，才能宣告本计划完成。已有命令类或精简 AppContainer 场景通过，不能
替代生产 UI 验收。

## 2. 当前基线审计

### 2.1 QA 与生产组件的关系

初始审计发现旧 `openInteractiveModelingQA` 和部分阶段脚本曾自行创建精简
AppContainer，只挂载 Modeling Tab，并以 `previewModelingCommand` 或
`CommandExecutor` 回调冒充用户输入。该缺口现已纠正：发布门禁从正式 `kssolv()`
启动，通过生产 Project 服务创建条目，并使用与用户会话完全相同的
`kssolv.ui.components.figuredocument.MoleculeDisplay`、Toolstrip、Project Browser、
Command Window、Footer 和文档生命周期。候选 `dist`、同步 runtime 与实际加载
`MoleculeDisplay/CrystalViewer/index.html` 由 manifest/SHA 三方比对；解析到旧
Add-On 源码会立即以 `AcceptanceSourceMismatch` 失败。

命令级测试仍作为数值 oracle，但不再替代真实输入证据。需要物理输入的关闭项
单独保存在 `*-physical-pointer-*` 报告中。P2 六参考分子的生产键鼠矩阵已经关闭；
尚未完成的是 P1 的人工签字，以及 P6 的独立用户视觉签字；P6 真实右键拖动、
坐标几何和截图哈希已经由 fail-closed 审计器分别通过；
3024×1964 → 1512×982 的系统 2× 缩放和生产组件 Web/UI 内容 200% 均已完成实机检查。

### 2.2 当前能力缺口

- 表面直接草绘现已改为数据驱动的通用 `AdsorbateDraft`，OH、COOH、NH2、CH3、
  CO、CO2、H2O、项目分子和用户片段共用选择、锚定、取向、绕键旋转和提交管线；
  OH 只是普通预置，不保留专用入口或旧 metadata。
- 通用 `place_adsorbate` 协议和后端 builder 已支持一/多锚点及统一事务；当前只写
  单一 schema v2：共享逐原子 `species/coordinates/bonds` 和锚点原子，直接拖拽与
  位点放置分别使用 `host*` 字段和嵌套 descriptor。旧 schema v1 与旧顶层字段没有
  读写兼容分支，并由 20 项表面测试中的禁止字段断言守卫；
  Locator 已支持项目分子解析、位点/高度/旋转穷举、周期最短映像碰撞检查、取消、
  确定性排序、结果表及候选预览/应用。默认评分明确为几何接触分数而非吸附能；
  刚性混合吸附质、严格的外部评分器契约，以及带周期宿主镜像、H–Lr 元素参数和
  来源/适用范围声明的内置 UFF 12-6 范德华相互作用评分已接入。该 UFF 模型只比较
  刚性宿主–吸附质的交叉非键相互作用，不含静电、成键、荷移、溶剂或弛豫。
  Rybolt–Pierotti 原始低覆盖实验（DOI `10.1063/1.438015`）的 Ne/Ar/Kr/Xe–石墨
  冻结基准现已通过：未经拟合的 UFF 顺序完全一致，能量 MAE `0.00842 eV`，势阱
  距离 MAE `0.080 Å`。该预测声明严格限制在石墨稀有气体物理吸附，不外推为
  化学吸附、极性表面或弛豫吸附焓。
- Fragment Library、几何编辑、Clean 和显式力场 Optimize 已在真实生产宿主中形成
  指针证据；P2 六参考分子以及 P5 周期距离、角度、二面角、撤销/重做与自动复测
  矩阵均已关闭。
- 默认键长、原子类型、键角、二面角和非键排斥已统一到可追溯的参数 schema v2；
  `ForceFieldProvider` 允许注入满足严格结果契约的其他能量模型。当前默认模型仍是
  通用局部几何优化模型，不等同于 COMPASS/UFF，也不包含静电或色散吸引。
- Modeling Tab 已生成 89 个独立语义主图并派生 16/24/64 像素资源；自动 hash、
  构建、生产截图和 200% 内容缩放已通过，仍需补独立用户识别签字。

## 3. 阶段依赖与状态规则

```text
P1 -> P2 -> P3 -> P4 -> P5 -> P6
```

状态仅允许：`未开始`、`进行中`、`已实现待生产验收`、`已验收`。

| 阶段 | 当前状态 | 关闭阶段所需的核心证据 |
| --- | --- | --- |
| P1 | 进行中 | 生产 `kssolv()` 宿主、runtime 指纹、真实输入和视觉基线已通过；待独立人工签字 |
| P2 | 已验收 | 六种参考分子已在当前 runtime 用真实鼠标/键盘重录并通过 SHA 门禁 |
| P3 | 已验收 | 通用片段端口、COOH 多连接模式、100 次装配回归及两项真实指针任务齐全 |
| P4 | 已验收 | 200 个标准分子诊断、参数 schema v2、数值梯度和生产 GUI 证据齐全 |
| P5 | 已验收 | 精确几何、周期实例、当前 runtime 键鼠输入、撤销/重做和布局证据均通过 |
| P6 | 进行中 | 用户/混合吸附质、UFF 交叉能量契约、外部预测基准及真实 button-2 轴向拖动已通过；独立视觉终验待关闭 |

## 4. P1：生产组件与 QA 完全统一

### 开发步骤

1. 新增从正式 `kssolv()` 启动的生产验收入口，不再以精简 AppContainer 作为
   最终验收宿主。
2. 通过生产 Project/Project Browser 创建、导入、打开和保存 Molecule、Crystal
   与 Slab；测试不得直接把模型对象塞给孤立的测试文档来代替用户路径。
3. 前端构建写入 build manifest：源码 revision、构建时间、schema 版本和主资源
   SHA-256；MATLAB 启动时可读取该 manifest。
4. `sync-runtime` 在复制后比较规范化摘要；生产 QA 启动时再次比较实际加载的
   runtime 与候选构建，任何不一致立即失败。
5. 把交互验收分为组件测试、内嵌 HTML 集成测试、生产 AppContainer E2E 和人工
   视觉签字四层；不得用较低层证据替代较高层。
6. 用户交互任务必须通过真实键盘和鼠标完成；直接命令调用只允许作为结果 oracle。

### 验收标准

- QA 中的 AppContainer、Toolstrip、数据浏览器、Footer、QAB、项目服务和文档
  生命周期与生产 `kssolv()` 相同。
- `dist`、同步 runtime 和实际加载 runtime 的 manifest/SHA 一致。
- Molecule、Crystal、Slab 均由真实项目条目打开、编辑、保存、关闭和重开。
- 1200×800、1440×900、1920×1080、200% 缩放和中英文环境全部通过。
- 不允许测试专用 CSS、测试专用快捷键或测试专用后端分支。
- 每个场景保存环境、候选 revision、操作日志、结构导出、截图和结果 JSON。

## 5. P2：通用 3D Sketcher

### 开发步骤

1. 建立通用 Sketch 状态机：Idle、PlaceAtom、DragBond、ConnectAtoms、EditBond、
   Preview、Commit 和 Cancel。
2. 支持空白放置、从原子拖出新原子/键、已有原子连键、重合合并及 3–8 元环。
3. 支持单、双、三、芳香键，以及元素、形式电荷、杂化和芳香性编辑。
4. 元素和键级选项使用 Modeling Tab 或瞬时浮层，不增加底部工具栏，也不增加
   永久“交互建模入口按钮”。
5. 拖动期间实时显示键长、碰撞、价态和非法连接；单击/短拖拽从 MATLAB 下发的
   `constructionBonds` 参数表取得标准键长，超过阈值后尊重精确拖拽；完整手势只产生
   一个事务，前端不得复制科学参数。

### 验收标准

- 仅用真实鼠标键盘从空白构建水、乙醇、甲醛、苯、吡啶和苯甲酰胺。
- 分子式、拓扑、键级、芳香性和形式电荷匹配冻结 oracle。
- 拖到已有原子不得产生重复原子；过短键和非法价态不得静默提交。
- Cancel 后 canonical hash 不变；Undo/Redo 坐标误差 `<1e-10 Å`。
- 1000 原子场景点击反馈 `<100 ms`、拖动 `>=45 FPS`。
- 对标任务点击数不超过 Materials Studio 的 `1.25x`。

## 6. P3：Fragment Sketcher 与用户片段

### 开发步骤

1. 片段 schema 包含原子、键、坐标、一个或多个连接端口、离去原子、默认键级、
   默认朝向和允许的连接数。
2. 首批内置 OH、O、H、COOH、COO、NH2、NH、CH3、CN、NO2、SH、常用芳环
   和配体。
3. 支持搜索、分类、预览、切换端口、绕连接键旋转、翻转、导入、导出和版本迁移。
4. 支持把当前选择保存为用户片段，重启后继续使用。
5. COOH 明确区分表面–C、单齿 O、双齿 O,O 及完整分子非共价放置。

### 验收标准

- OH、COOH、NH2、CH3 使用同一通用状态机，不出现基团专用硬编码分支。
- 至少 100 次片段装配无重复原子、哑原子、错误离去原子或悬空键。
- 用户片段重启后可用，导入导出 round-trip 保持拓扑和端口。
- 单齿、双齿连接具有独立几何、价态和 Undo/Redo 测试。
- 用真实交互完成“苯环添加 COOH”和“表面添加 COOH”。

## 7. P4：力场、Clean 与化学诊断

### 7.1 力场策略

KSSOLV 应引入力场参数层，但必须把三个概念分开：

1. **Ideal Geometry**：根据元素、键级、芳香性、杂化和局部化学环境查询平衡
   键长/键角，用于新键和片段的默认几何。
2. **Rule Clean**：基于理想几何做确定性的局部修整、碰撞消除和补氢，不声称
   进行能量最小化。
3. **Optimize Geometry**：使用明确命名、带参数来源和能量/梯度的力场进行迭代
   最小化，报告收敛状态。

第一阶段建立可插拔 `ForceFieldProvider`/`GeometryParameterProvider` 接口，参数记录
来源、版本、适用原子类型和回退原因。默认键长不得只用元素共价半径求和；只有
参数缺失时才允许以共价半径作为显式 warning 的回退。

### 开发步骤

1. 建立原子类型、键参数、角参数、二面角参数、非键参数和参数来源的数据契约。
2. Sketcher 和 Fragment Sketcher 通过同一 provider 获取默认键长/角度。
3. Rule Clean 支持局部/选择/全分子范围、固定原子和预览差异。
4. Optimize Geometry 后端暴露能量、梯度、最大力、迭代数、收敛阈值和取消。
5. 价态、芳香性、形式电荷、补氢失败必须返回可定位诊断。

### 验收标准

- C–C/C=C/C≡C、C–O/C=O、O–H、C–N/C=N 等参考键的默认长度匹配参数 oracle。
- 参数命中、回退和来源可在结果 metadata 中审计。
- Rule Clean 前后组成和拓扑不变，除非用户明确要求补/删氢。
- 200 个标准分子的补氢和价态诊断匹配 oracle。
- Optimize Geometry 报告初末能量、最大力和是否收敛；未收敛不能显示成功。
- Cancel 后模型、选择和历史完全恢复；固定原子位移 `<1e-10 Å`。

## 8. P5：精确编辑与实时几何 Monitor

### 开发步骤

1. 统一鼠标直接操作与数值精确操作的事务、作用域和 Undo/Redo。
2. 支持 Cartesian/Fractional 平移，屏幕轴、晶格轴和自定义轴旋转。
3. 支持单原子、连通子树、片段和选择集作用域，以及质心/原子/自定义旋转中心。
4. 距离、角度和二面角 Monitor 可直接编辑，统一周期最小映像。
5. 键级、杂化和形式电荷编辑与 Sketch/Fragment 共用化学契约。

### 验收标准

- 键长误差 `<1e-6 Å`，键角/二面角误差 `<1e-5°`。
- 晶格轴/表面法向对齐误差 `<0.01°`。
- 一次拖动只有一个历史记录；跨周期编辑使用正确最小映像。
- MOL/SDF round-trip 保持键级和芳香性。
- 输入控件获得焦点时，S/O/X/Y/Z/Space 不触发 Viewer 快捷键。
- 测量标签、选择面板、菜单和快捷键窗口不得重叠或遮挡目标对象。

## 9. P6：通用吸附放置、Adsorption Locator 与产品终验

### 开发步骤

1. 用通用 `AdsorbateDraft` 取代 OH 专用 draft，接受片段、项目分子、导入分子
   和多组分混合物。
2. 支持 atop、bridge、hollow、自定义位点、单/多锚点、高度、朝向、绕轴旋转和
   内部扭转。
3. Locator 支持位点枚举、平移/旋转/扭转采样、确定性 seed、可插拔能量评分、
   候选聚类和结果排序；内置 UFF 评分必须显式处理周期宿主镜像并记录参数来源、
   截断/平滑策略、单位、验证范围和科学限制。
4. 没有经过验证的能量模型时，功能名称必须是“几何候选搜索”，不得声称得到
   低能吸附构型。
5. 搜索结果可回到手动编辑器继续调整，并可完整记录和重放。

### 验收标准

- OH、COOH、NH2、CH3、CO、CO2、H2O 和混合吸附质使用同一管线。
- Pt(111)、MgO(100)、Si(001) 位点数和位置匹配 frozen oracle。
- 单/双齿锚点距离误差 `<0.01 Å`；周期包装不拆分或复制分子。
- 相同 seed、参数和实现版本产生相同候选顺序。
- 参考体系排序匹配冻结能量 oracle；搜索可取消且无残留任务或半提交结构。
- UFF H–Lr 参数覆盖、异种原子组合规则、势能最低点、截断连续性、斜晶胞周期镜像和
  晶格平移不变性通过独立解析 oracle；结果只能标为“相互作用能”，不得标为弛豫吸附焓。
- 完成“选择吸附质—位点—调整—搜索—比较—提交”的生产 UI 全链路验收。

## 10. Modeling Tab 图标设计规范

### 10.1 视觉语言

- 使用同一 64×64 设计网格并派生 24×24、16×16；禁止分别随意绘制三套图形。
- 主轮廓线宽、端点、圆角和透视方向保持一致；小尺寸允许光学校正。
- 使用现有 KSSOLV 蓝/青主色、暖色操作强调和中性灰辅助色；每个图标最多三种
  功能颜色，不使用渐变、阴影或照片式细节。
- “新增、删除、移动、旋转、测量、构建、搜索、保存”具有稳定的视觉语法。
- 每个 Modeling 命令必须有独立的主轮廓，不能只替换同一个角标来冒充不同语义。

### 10.2 图标族

1. 原子/键编辑：原子球、键线和局部操作符。
2. 几何：距离、角度、二面角、坐标轴和旋转弧。
3. 分子/片段：结构轮廓、连接端口和片段库。
4. 晶体/表面：晶胞、切面、层、位点和吸附物。
5. 聚合物/装箱：链段、重复单元、盒和密度。
6. 自动化/诊断：搜索、检查、保存、任务和报告。

### 10.3 验收标准

- 图标资源清单中不存在非有意的相同 SVG path/hash。
- 16×16、24×24、64×64 contact sheet 在浅色背景上均可辨识。
- 5 名未参与绘制的用户只看图标识别一级功能，正确率 `>=80%`；结合标签后
  任务选择成功率 `>=95%`。
- Modeling Tab 在 1200×800 和 200% 缩放下无挤压、裁切、重复视觉噪声。
- 图标、标签、tooltip 和 disabled reason 语义一致。

## 11. 视觉与可用性发布门禁

- 生产宿主截图覆盖 1200×800、1440×900、1920×1080、200% 缩放和中英文。
- DOM 自动检查文字溢出、意外横向滚动、不可见控件、面板相交和错误层级。
- 非 WebGL UI 使用像素基线；WebGL 使用固定结构、固定相机、固定 DPR 和容差基线。
- 快捷键窗口必须重新提供至少两种原型供产品签字；常用操作优先，高级操作后置，
  长说明整行显示，禁止省略号和密集不平衡卡片。
- 不恢复已删除的底部视窗，不增加永久交互建模入口按钮。
- S0/S1/S2 缺陷为零，并取得明确人工视觉签字后，阶段才能标记“已验收”。

## 12. 阶段证据台账

每个阶段在 `dev/modeling/acceptance/reports/` 下保存独立目录，并至少包含：

```text
environment.json
build-manifest.json
report.json
commands-or-events.jsonl
before-structure.*
after-structure.*
screenshots/
README.md
```

最终统一回归 `p1-p6-release-20260812-174800` 在 MATLAB R2026b 中依次执行
16 个 P1–P6 生产、科学 oracle、真实指针证据和图标视觉场景，结果 16/16。
去除通用片段中的旧 O–H 专名标识并补充 ready 草稿的可见 Apply 动作后，当前运行时 SHA-256 为
`bb8eb628…8955d0`；P2 六参考分子证据
`p2-six-molecule-pointer-20260812-125404` 和 P5 周期几何证据
`p5-periodic-pointer-20260812-145945` 的结构与交互证据不受该纯标识改名影响，已重新
绑定并由 SHA 门禁复核。
P1 快捷键窗口另以 `p1-shortcut-layout-20260812-151559` 完成中英文、三种窗口尺寸
和 200% 的 16/16 生产截图矩阵。汇总报告把 `automatedPassed=true` 与仍为 false 的
`releaseReady` 分开记录，并显式保留 P1 独立
A1–A5、B1–B5、C1–C5 视觉签字和 P6 可验证右键轴向拖动/独立视觉签字，不允许用程序化回调替代
这些关闭条件。

最终关闭使用 `P1-P6-external-closure-template.json` 和
`auditP1P6ExternalClosure`。P1 必须逐项签署 A1–A5、B1–B5、C1–C5；P6 必须
记录真实鼠标 `button=2` 的 Host–Anchor 轴向拖动、旋转前后完整坐标、旋转角、两张
生产截图及其 SHA-256，并由独立视觉审计人确认旋转的是完整吸附质而非相机。审计器
独立验证 Rodrigues 旋转、内部距离不变性、图片格式/尺寸/哈希和当前运行时 SHA；
左拖、回调事务、坐标篡改或未签字证据均不能把 `releaseReady` 置为 true。

`p1-p6-physical-pointer-20260812-030247` 由 Computer Use 直接操作 MATLAB R2026b
桌面和完整 `kssolv()` 生产壳：物理 `/` 键和滚动通过快捷键常用/高级区；真实原子
点击、对话框键盘输入、Move/Rotate Apply 及 Undo/Redo 通过坐标 Inspector 复核；
`O` 打开的瞬时库同时显示 7 个内置片段和临时用户 Formyl，COOH 经两段左拖、2.1 Å
数值键长、Enter 提交及 8/12 sites Undo/Redo 通过；`S` 草绘的空白单击、从原子左拖
生成原子/键和短拖参数化几何路径通过。本次也发现并修复 Rotate Atoms 底部操作区
裁切，复测截图已完整。六分子完整矩阵随后已由 P2 生产键鼠证据关闭；COOH 的
真实 mouse button-2 从 `(738,365)` 到 `(818,365)` 已在生产 WebWindow 重做，完整
片段绕 Host–C 轴旋转而相机保持不变。`physical-right-drag.json` 记录 40° Rodrigues
重建坐标和两张原始截图哈希，外部审计的 physical、coordinate、screenshot 三门均
通过；独立视觉签字仍保持未通过。200% 内容显示已在生产组件中完成实机检查。

`p3-fragment-sketcher-20260812-043415` 进一步使用真实鼠标和键盘在同一生产壳中
从 3D Sketch 放置独立 C，选中后通过 Modeling → Molecule Builder → Fragment
Sketcher 打开通用片段库，选择 Carboxyl/Surface-C 并提交。结构由 5 原子变为
9 原子、7 个键，Undo 和工具栏 Redo 均复核通过；新接入的提交后相机适配使完整
COOH 不再被视口底部或右侧裁切。对已饱和 O 挂接 COOH 会在事务提交前被价态
预检拒绝，结构不变，片段搜索结果也不会因错误而清空。

`p3-benzene-cooh-pointer-20260812-045749` 从 0 原子生产分子开始，经真实菜单
Sketch Ring、选中芳香环碳、Fragment Sketcher Carboxyl/Surface-C、全选和 Add
Hydrogens 得到 C7H6O2（15 原子、15 个键）；`p3-surface-cooh-pointer-20260812-050239`
在真实 Cu slab 上以 `O`、Carboxyl、两段左拖、2.1 Å 数值键长和 Enter 得到
Cu8HCO2（8→12 sites），两项均完成真实 Undo/Redo。至此 P3 的两项物理指针
关闭任务均有生产组件证据。

`p2-escape-water-pointer-20260812-052026` 在真实生产 WKWebView 中复现了元素
下拉框选择后继续占有焦点、Esc 被控件吞掉的问题。最终实现用捕获阶段键盘监听、
Esc keyup 兜底和选择完成后主动 blur 三层处理，真实鼠标/键盘复测证明选择 O 后
单次 Esc 立即退出 Sketcher；过短 O–O 尝试不增加原子，随后 Add Hydrogens 得到
H2O（3 原子、2 键）。同轮还把分子标题从 pymatgen 的元素参考
`reduced_formula` 改为文档实际原子计数，避免单 O 错显为 O2；10 项 MATLAB
MoleculeSceneBuilder 测试覆盖单 O 和 H2O。

| 阶段 | 实现证据 | 自动测试 | 生产 MATLAB GUI | 视觉/性能 | 状态 |
| --- | --- | --- | --- | --- | --- |
| P1 | runtime manifest、同步/加载时 SHA 门禁、生产验收入口、工作区源码来源断言 | `p1-p6-release-20260812-174800` 中 P1 三门全通过；CrystalViewer 前端 195 项通过；当前运行时 SHA-256 `bb8eb628…8955d0`；解析到旧 Add-On 会以 `AcceptanceSourceMismatch` 失败 | `p1-shortcut-layout-20260812-151559`：中英文、1200×800/1440×900/1920×1080 与 200% 共 16/16；常用在前、高级后置、长说明整行；底部无视窗、无永久交互建模入口 | 89 个唯一语义主图的 16/24/64 contact sheet 通过；独立人工 A1–C5 签字仍保持未通过 | 进行中 |
| P2 | 通用 Sketch draft 状态机、瞬时化学浮层、生产选择握手和焦点安全键盘路由；直接草绘和精确 Sketch Atom 都可采用可追溯的力场理想键长；前后端同时拒绝化学上过短的草绘键 | 前端 195/195；分子构建 14/14；Nano/Surface 20/20；对话框与生命周期 30/30；精确对话框实机确认自动选择宿主、勾选力场键长并隐藏手动坐标 | `p2-six-molecule-pointer-20260812-125404`：H2O、乙醇、甲醛、苯、吡啶和苯甲酰胺 6/6 用真实键鼠完成；随后仅增加 ready-state Apply 控件，不改变草绘算法或证据结构 | 最终苯甲酰胺 H7C7NO 为 16 原子/16 键、无 warning；视图居中且无遮挡 | 已验收 |
| P3 | Fragment schema v2、通用端口、13 个内置片段、用户端口持久化；挂接前价态与碰撞预检；失败保持浏览结果 | P3 生产场景、100 次装配、单/双齿及 round-trip 通过；P3–P4 场景改为先 N-甲基化再补氢，拒绝以非法饱和氮挂接掩盖问题 | `p3-fragment-sketcher-20260812-043415`：通用片段真实挂接和饱和宿主拒绝；`p3-benzene-cooh-pointer-20260812-045749`：从空白得到 C7H6O2；`p3-surface-cooh-pointer-20260812-050239`：Cu slab 两段拖拽、2.1 Å 和 8/12 sites Undo/Redo | COOH 四连接模式及 3D 预览完整；提交后自动适配相机，片段无遮挡；“苯环加 COOH/表面加 COOH”真实鼠标任务均通过 | 已验收 |
| P4 | `ForceFieldProvider`、`GeometryParameterProvider` schema v2、`kssolv-generic-mm-v2` 与确定性 L-BFGS 优化器；原子类型、键、角、二面角及非键排斥均有来源/fallback 契约；Sketch 单击/短拖拽与 Fragment 共用 MATLAB 参数源 | `p4-standard-molecules-20260812-015514`：20 个化学家族 × 10 个成员共 200/200 通过独立闭式分子式、补氢、零价态 issue、重原子拓扑、H 度数及删氢回环；另有 13 项力场和 6 项参数测试，梯度误差 `<2.12e-8` | `p4-force-field-20260812-013329`：修复无向元素对去重后，生产 Clean/Optimize、Undo/Redo、结构前后文件、runtime 清单和事件日志全部通过且无 scene 契约警告 | 失真 H2O 13 次收敛，固定原子位移 0，截图无遮挡；默认模型明确不含静电和色散吸引且不冒充 COMPASS/UFF | 已验收 |
| P5 | 精确距离/角度/二面角、移动/旋转、键级、杂化和实时读数共用事务；周期实例坐标随测量提交，主晶胞回卷后自动解析对应渲染图像并恢复读数；重复源位点在前端明确拒绝 | `p1-p6-release-20260812-174800/10-p5-exact-geometry` 数值门通过；`PeriodicGeometryTest` 覆盖显式周期实例坐标；当前 `p5-pointer-evidence` 同时校验证据数值和截图 | `p5-periodic-pointer-20260812-145945`：生产测量卡用物理指针操作；可见 MATLAB 键盘对活动 `MoleculeDisplay` 事务执行 2.35126→2.40000 Å、Undo/Redo、109.471→112.250° 和 -60→15° 精确编辑 | 全宽目标值、scope/fixed-end 布局无遮挡；后续 Apply 控件改动不触及测量路径 | 已验收 |
| P6 | 数据驱动 `AdsorbateDraft`、7 个预置、用户端口片段、通用一/多锚点 schema v2、项目/刚性混合吸附质 Locator、严格评分器契约、内置 `kssolv-uff-vdw-surface-v1`、外部参考目录与预测 benchmark、候选预览/应用、89 个独立图标；OH 专用入口、schema v1 和旧顶层 metadata 字段均无兼容分支 | `p6-generic-adsorbate-20260812-130913`：生产壳 7/7 片段、COOH 事务、多锚点、Undo/Redo 和单一 schema v2 通过；Nano/Surface 20/20 含禁止旧字段守卫；Locator/UFF/预测历史数值验收仍通过 | 既有全链路证据覆盖通用片段选择、两段左拖、键长、提交和 Undo/Redo；`p6-right-drag-20260812-160115` 新增真实 button-2 轴向旋转及 Apply 提交，审计器确认 physical/coordinate/screenshot 三门 | UFF 只标“相互作用能 (eV)”且预测范围限于石墨物理吸附；独立人工视觉签字仍待补 | 进行中 |
