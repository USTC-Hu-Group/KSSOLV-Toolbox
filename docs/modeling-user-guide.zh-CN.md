# KSSOLV Toolbox 建模用户指南

## 快速开始

1. 在 Home 中新建 Structure 或 Molecule，或导入 CIF/XYZ/MOL/SDF/MOL2/PDB。
2. 激活 3D 文档后进入“晶体建模”或“分子建模”。上下文 Tab 会随当前文档切换，
   只显示适用于该类模型的命令；不可用项显示原因。
3. 高频编辑使用视窗选择、右键菜单和快捷键；多参数构建使用当前建模 Tab 中的专用菜单。
4. 参数对话框的预览不会修改项目；确认后形成一条原子历史记录。保存才写回 Project。
5. 两个建模 Tab 的“历史”区均可直接打开“建模指南”；该指南、API 文档和快捷键图随 Toolbox 安装包交付。

## 视窗操作

- 点击、Shift+点击、框选 `B`、套索 `L`；可按元素或连通组扩展选择。
- `G` 移动、`R` 旋转，随后按 `X/Y/Z` 约束轴；晶体可在 Cartesian/Fractional 间切换。
- `⌘/Ctrl+Z` 撤销，`Shift+⌘/Ctrl+Z` 重做，`Esc` 取消工具。
- `?` 打开完整快捷键面板。面板跟随 KSSOLV 的中英文语言设置：常用视图、选择、
  历史和直接变换优先显示；3D 草绘、通用吸附质和精确工具排在后面并各占一整行。
  当前单键映射固定；输入控件聚焦时视窗快捷键不会触发。

完整的 macOS 双语速查图见 [建模快捷键图](images/modeling-shortcuts.svg)。
- Selection Set 保存 source-site ID，因此显示重复范围或重建场景后仍可解析。

## 分子建模

- 在分子视窗中按 `S` 激活 3D Sketch：在空白处点击放置孤立原子；从已有原子左键拖动可实时预览新原子、键和键长，松开后创建带键的新原子；拖到另一个已有原子上松开则直接建立两原子间的键。单击或小于 0.60 Å 的短拖拽使用 MATLAB 参数层下发的标准键长，并按鼠标方向预览；拖过阈值后采用用户的精确拖拽长度。连接到过近的已有原子仍显示红色且不会提交。
- Sketch 工具栏可在草绘前选择元素、单键/芳香键/双键/三键和 3–8 元环；每次松开只提交一条可单独撤销的事务。
- 选中分子中的化学键后，在 MATLAB `建模` 工具栏中选择键级编辑命令，可修改 1、1.5、2、3 键级或删除显式拓扑键。
- Set Bond Order 支持 1、1.5、2、3；Set Atom Chemistry 编辑元素、形式电荷与杂化提示。
- Add/Remove Hydrogens 按显式价态规则修改；Diagnose Molecule 报告非法价、异常键长和碰撞。
- 补氢与价态规则的发布门覆盖 20 个化学家族、200 个独立分子图，包括烷/烯/炔、
  环、含氧/氮/硫官能团、三类卤代烃和芳香杂环；预期分子式来自独立闭式 oracle，
  同时检查重原子拓扑、每个氢的连接度和删氢回环。
- Set Distance/Angle/Dihedral 进行精确几何反向编辑；Align Geometry 与 Clean Geometry 不冒充能量最小化。
- 新建键与片段的默认键长通过 `GeometryParameterProvider` 查询元素、键级、芳香性和
  局部环境；当前场景只携带所需宿主元素的可追溯 `constructionBonds` 参数表，前端不
  硬编码科学键长。只有找不到类型参数时才使用标记了 `fallback` 和来源的原子半径回退。
- Optimize Geometry 使用明确标识的 `kssolv-generic-mm-v2` 做局部能量最小化，并报告
  初末能量、最大力、迭代数、收敛状态、参数来源与 fallback。该模型含谐和键/角、
  通用周期二面角和短程排斥，但不含静电或色散吸引，也不等同于 Materials Studio 的
  COMPASS 或其他品牌力场；最终计算结构仍应使用适用于体系的力场或电子结构方法弛豫。
- Attach Fragment 使用连接头装配，Save User Fragment 保存版本化用户片段。

### 精确变换与实时测量

- 选中原子后按 `G`。拖动仍按 Snap 增量移动；也可在 `Exact Δx Δy Δz` 输入笛卡尔位移并用 `Apply Δ` 精确提交。晶体切换为 `Fractional` 后输入的是精确 `Δa/Δb/Δc`，预览会换算为真实笛卡尔位移，后端仍按分数位移提交。
- 按 `R` 后选择 Screen/X/Y/Z 旋转轴，在 `Exact angle` 输入任意有限角度。输入期间围绕选择质心实时预览，`Apply angle` 作为一次旋转事务提交。
- 选择 2、3、4 个显示原子时，视窗顶部自动显示按选择顺序得到的距离、角度或二面角。
- 从测量菜单启动 Distance/Angle/Dihedral 后，每一步点击都会画出几何标注；在下一个原子上悬停时，视窗顶部连续更新五位小数距离或三位小数角度。完成后可在测量面板输入目标值，并选择 Atom/Subtree/Fragment 反向修改几何。
- 对周期晶体，测量与 Set Distance/Angle/Dihedral 自动使用最近周期映像；编辑前临时展开
  跨边界几何，提交时重新包装到输入晶胞，避免把跨晶胞相邻原子误当作相距一个晶格矢量。
  Clean/Optimize Geometry 仍限于 Molecule，不能把当前通用分子力场误用于周期固体。

## 晶体、表面与界面

- “晶体建模”将晶格、超胞和对称性集中到“晶体与晶胞”，将缺陷、合金和纳米结构
  集中到“晶体材料”。“分子组分”可对晶体中的吸附分子、溶剂或其他选定原子组分
  执行移动、旋转、对齐以及距离、角度和二面角编辑；这些操作仍保留周期晶格。
- 补氢、键级、片段连接和通用分子力场优化仍要求独立 Molecule 文档。它们不会被
  直接用于整个周期结构，以免错误处理跨周期拓扑或移动晶体宿主。

- Crystal Builder 输入空间群、晶格、元素和非对称坐标并展开等价位。
- Make P1 保留笛卡尔几何；Build Supercell 改变真实模型，Display Repeat 只改变显示。
- Point Defect Enumeration 先给出对称等价构型与简并度，再创建派生结构。
- Surface Builder 可枚举终止面、标注几何层并固定底层；Add Vacuum 与 Adsorption Sites/Adsorbate 具有实测高度/接触诊断。
- Heterostructure 使用二维 Hermite 超胞矩阵配对和最优旋转对齐，候选表可按面积、主应变、旋转角或原子数排序；Moiré 在创建前检查 atom limit、应变和角度误差。

### Materials Studio 风格的通用吸附质直接草绘

对 slab 在视窗中按 `O` 激活通用 Adsorbate 草绘，并从瞬时选择器中选择 OH、
COOH、NH2、CH3、CO、CO2、H2O 或同一数据契约提供的项目/用户片段。OH 只是普通
预置，不存在 OH 专用入口、专用状态机或兼容元数据：

1. 从一个表面原子按住左键并拖动，预览 Host–Anchor 键和所选片段的锚原子；不拖动时使用片段的默认 Host–Anchor 长度并沿表面法向放置。第一段拖动时按 `Alt` 可沿当前 Host–Anchor 方向改变深度/键长。
2. 松开后再次左键拖动，确定整个片段的朝向；`Shift+Alt+左键拖动` 沿当前方向伸缩锚点距离。
3. 第二次松开后使用右键拖动，使整个片段绕 Host–Anchor 键轴旋转；数值框可精确设置 Host–Anchor 长度。
4. 视窗实时显示锚点键长、片段式和接触诊断；碰撞或过短键以红色提示。按 `Enter` 或 `Apply` 将完整片段作为一条原子事务提交，按 `Esc` 或 `Cancel` 放弃预览。

提交仅使用通用 `adsorbateSpecies`、`adsorbateCoordinates`、`adsorbateBonds`、
`anchorAtomIndices` 和片段名称，直接保存拖拽得到的全片段笛卡尔坐标与锚点，不经过
吸附位候选序号。需要 top/bridge/hollow 对称性候选时，使用 Adsorption Locator；
交互草绘只生成计算初始构型，随后仍需使用适用的力场或电子结构方法弛豫。

已提交结构只写入统一的通用吸附 metadata schema v2，不读取或写回旧字段。共同字段为
`placementMode`、完整逐原子 `species/coordinates/bonds`、
`anchorAtomIndices` 和 `guestFormula`。直接拖拽使用
`hostAnchorSites/hostAnchorLabels/hostBondLengths`；Locator/位点放置使用嵌套的
`siteDescriptor/orientationDescriptor`。OH 与 COOH 一样只是片段数据，不存在专用入口、
专用命令或兼容 metadata。

### Adsorption Locator 评分模型

Locator 参数窗口可明确选择评分模型：

- `Geometric contact score` 是默认快速筛选，只按周期最短接触和几何代价排序，
  `isEnergyModel=false`，结果不是吸附能。
- `UFF van der Waals interaction energy (rigid, eV)` 使用 UFF 12-6 势、H–Lr 元素参数、
  几何组合规则和周期宿主镜像，计算刚性宿主–吸附质的交叉范德华相互作用能。
  结果表明确显示“相互作用能 (eV)”，并把模型 ID、版本、来源、验证范围和限制保存到
  候选及已应用结构的 metadata。

内置 UFF 评分不含静电、成键、荷移、溶剂、宿主/吸附质弛豫或温度效应，不能解释为
弛豫吸附焓，也不能替代面向具体表面体系验证过的力场或 DFT。它适合做可审计、可重复的
刚性构型初筛；最终构型和相对稳定性仍应由适用的物理模型复核。

## 高分子与非晶

- Repeat Unit Library 支持 PE、PP、PS、PEO、PPO 和用户 JSON 重复单元，并显式保存头、尾与离去原子。
- Polymer 菜单支持多链、端基、初始构象、均聚、superunit 嵌段、精确/概率/反应活性比无规、头尾序列、支化和基础 dendrimer；显式 seed 保证重放。对话框会在分配前显示原子数预估。
- Amorphous 支持精确分子数、摩尔分数、质量分数、目标密度、seed、最短接触和 A/B/C 受限区域，也可保留既有盒内容或排除纳米粒子区域。
- Density ramp 会真实执行分阶段刚体中心压缩；batch ID/count、close contact、ring piercing 和 chain interlock 会写入诊断/元数据。
- 构建结果标记 `constructed_not_equilibrated` 或 `packed_not_equilibrated`。必须在真实 NVT/NPT/退火任务成功后才能称为平衡结构。
- 不可满足的密度/接触约束、环穿刺和 atom limit 会在提交前失败；调整密度、tolerance、seed 或分子数后重试。

## 自动化、批量和恢复

- `kssolv.api.v1.modeling.execute` 是 schema v1 的无 GUI API。
- `OperationRecorder` 保存 command、完整参数、seed、父/结果 SHA-256 与 UTC 时间；recipe 可在干净会话重放。
- 参数对话框可保存/载入版本化预设；Presets &amp; Templates 浏览器统一管理参数、项目模板、片段和重复单元。
- `BatchModeler.run` 隔离内存输入；`FileBatchModeler.run` 执行文件导入、API、验证、原子导出和逐文件错误汇总。
- Modeling Jobs 保存原子 JSON checkpoint，可查看 queued/running/interrupted/complete/cancelled 状态并恢复或取消。
- 有项目标识的未保存文档会在每次提交、撤销和重做后原子更新恢复快照。正常保存/放弃会清除；异常退出后用 `RecoveryJournal.scan()` 检查，只有 schema 与 hash 同时通过才恢复。

## 故障排查

| 症状 | 处理 |
| --- | --- |
| 命令灰色 | 激活正确文档并满足选择数量；查看 disabled reason |
| Stale transaction | 结构已在预览后变化，重新打开参数并预览 |
| Packing infeasible | 降低密度/tolerance、增大区域、减少分子数或换 seed |
| Ring piercing | 换 seed 或先降低装填密度；错误结果不会提交 |
| Atom limit | 在预估摘要中减小链长、超胞或莫尔搜索范围 |
| Recovery corrupt/hash mismatch | 不覆盖原项目，保留快照供诊断并从最近正常项目重建 |
| Viewer scene build error | 原模型保持不变；记录错误标识、模型格式和复现步骤 |
