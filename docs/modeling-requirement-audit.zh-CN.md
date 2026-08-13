# P1–P10 建模系统要求级完成审计

审计日期：2026-08-09。目标环境：macOS、MATLAB R2026b。本文逐项审计
`modeling-development-plan.zh-CN.md`；场景通过不能替代要求级证据。

状态含义：`已证明`表示当前源码和可复现证据直接覆盖要求；`待重建`表示
生产代码已修复但发布包和候选场景尚未重新冻结；`已暂停`表示按开发决策
暂不执行；`外部门`表示必须依赖授权软件、参与者或人工审计，禁止用合成
数据代替。

## P1：统一模型与事务

| 要求 | 状态 | 当前证据 |
| --- | --- | --- |
| P1.1 科学基线 | 已证明 | `FormatPersistenceFunctionalTest` 对 CIF/XYZ/MOL/SDF/MOL2/PDB 各 10 个编辑样本执行导入、导出、项目保存与重开，并核对 canonical hash。 |
| P1.2 CommandCapability | 已证明 | 模型种类、选择上下界、结果种类和预览能力由同一合同提供，UI 启用态由合同派生。 |
| P1.3 共用编辑/键拓扑 | 已证明 | Crystal/Molecule 共用原子命令；Molecule 的 source topology、键级与 site metadata 持久化。 |
| P1.4 Preview/Commit/Cancel | 已证明 | revision 事务、无副作用 Preview、原子 Commit、Cancel 与陈旧提交拒绝均有测试。 |
| P1.5 上下文编辑和历史 | 已证明 | 晶体/分子均支持上下文编辑、Undo/Redo/Reset。 |
| P1.6 保存/关闭/导出 | 已证明 | 原子保存、安全关闭和上述 60 个格式项目重开证据通过。 |

## P2：选择与直接操纵

| 要求 | 状态 | 当前证据 |
| --- | --- | --- |
| P2.1 选择模式 | 已证明 | click/toggle、box、lasso、同元素、键连通组与按分子选择均有前端测试。 |
| P2.2 Selection Set | 已证明 | 稳定 site ID 通过复制、移动、删除、范围变化和项目重开。 |
| P2.3–P2.5 Gizmo/snap/keymap | 已证明 | Move/Rotate、轴约束、坐标模式、snap、焦点安全、可配置快捷键及 Help UI 已覆盖。 |
| P2.6 压力测试 | 已证明 | 1,000/10,000 原子选择与直接操纵性能门有自动报告。 |
| Materials Studio 点击比 | 外部门 | 需要授权 Materials Studio 的同硬件、同任务受控用户数据。 |

## P3–P4：分子 Sketch、化学与精确几何

| 要求 | 状态 | 当前证据 |
| --- | --- | --- |
| P3.1–P3.5 Sketch/键/化学/氢 | 已证明 | 空白分子、原子/环/键级/电荷/杂化、补删氢均进入生产命令、菜单和真实 GUI 场景。 |
| P3.6 实时 Warning Stack | 已证明 | 持久 Warning Stack 随模型更新，显示碰撞、键长、价态，支持定位和安全降级；Vitest 覆盖。 |
| P3 六分子与 50 个补氢样本 | 已证明 | 六个分子 oracle、50 个补氢规则样本和 MOL/SDF 键级回环通过。 |
| P3 两分钟用户任务 | 外部门 | 需纳入 P10 的至少 10 名真实领域用户计时。 |
| P4.1–P4.3 Monitor/movement/alignment | 已证明 | Inspector 可编辑距离/角/二面角并选择 atom/subtree/fragment/fixed side；数值误差门与主轴/法向对齐通过。 |
| P4.4–P4.5 片段库 | 已证明 | Fragment Browser 支持搜索、连接头、预览、用户片段版本化存储及导入/导出。 |
| P4.6 Clean | 已证明 | 规则 Clean 保持组成/拓扑，并明确不冒充能量最小化。 |

## P5–P6：晶体、表面与界面

| 要求 | 状态 | 当前证据 |
| --- | --- | --- |
| P5.1–P5.3 Crystal Builder | 已证明 | 空间群建晶、等价位/Wyckoff/占位率/重合表、P1/原胞/常规胞/超胞已接入参数 UI 和结果呈现。 |
| P5.4 保留/打破对称 | 已证明 | `SymmetryEditPlanner` 在提交前给出影响范围并要求 preserve/break 选择。 |
| P5.5 缺陷向导 | 已证明 | 等价归并、简并度、净电荷、最短接触和派生结构结果齐全。 |
| P5.6 20 晶体 frozen oracle | 已证明 | `crystal-builder-v1.json` 的 20 个结构逐一核对组成、空间群/坐标与 hash。 |
| P6.1–P6.2 Surface Builder | 已证明 | Miller、slab、终止面枚举、真空、居中、表面超胞和摘要已产品化。 |
| P6.3 Adsorbate Placement | 已证明 | 位点、锚点、方向、高度和最短接触由生产命令及 GUI 场景覆盖。 |
| P6.4 层选择/固定底层 | 已证明 | 几何层编号写入 site properties，可按底部层数固定并持久化。 |
| P6.5 界面候选表 | 已证明 | 候选按面积/主应变/旋转角/原子数排序；非零旋转候选经真实命令构建测试。 |
| P6.6 莫尔预检 | 已证明 | 原子数、应变、角度误差和上限在大分配前检查。 |
| 三种 slab oracle | 已证明 | `surface-builder-v1.json` 冻结 Pt(111)、Si(001)、MgO(100) 的原子数、组成、晶格与 hash。 |

## P7：聚合物

| 要求 | 状态 | 当前证据 |
| --- | --- | --- |
| P7.1 用户重复单元 | 已证明 | `RepeatUnitLibrary` 管理内置/用户 JSON、头尾和离去原子，支持重开。 |
| P7.2 均聚物 | 已证明 | 链长、链数、端基、extended/zigzag/random-coil 构象及原子数预估。 |
| P7.3 嵌段共聚物 | 已证明 | block、superunit 与多独立链具有精确序列语义。 |
| P7.4 无规共聚物 | 已证明 | probability/exact composition/seed 与 terminal reactivity-ratio 模型确定性通过。 |
| P7.5 立构/头尾翻转 | 已证明 | tacticity、regular/alternating/random head-tail 和完整序列元数据通过。 |
| P7.6 支化/树枝状 | 已证明 | 定间隔支化及按代数、核官能度、支化数构造的基础 dendrimer 通过精确拓扑测试。 |
| 10,000 原子性能/UI 预估 | 已证明 | 9,998/9,999 原子门低于 60 s；所有架构在对话框分配前显示估算和超限 warning。 |

## P8：非晶、混合物与受限层

| 要求 | 状态 | 当前证据 |
| --- | --- | --- |
| P8.1 Construction | 已证明 | 数量/摩尔/质量组成、密度、seed、未平衡状态和溯源齐全。 |
| P8.2 Packing | 已证明 | 新盒、保留既有盒内容、区域约束和纳米粒子排除均有生产命令与测试。 |
| P8.3 Confined Layer | 已证明 | A/B/C 轴受限区域及表面溶剂层路径通过。 |
| P8.4 高级装填 | 已证明 | density ramp 实际分阶段压缩，batch size/ID/count 写入模型元数据。 |
| P8.5 诊断/取消 | 已证明 | close contact、ring piercing、chain interlock、进度和原子取消通过 fixture。 |
| P8.6 平衡模板 | 已证明 | density-ramp NPT、anneal NVT、equilibrate NPT 模板及显式未平衡状态可追溯。 |

## P9：自动化与溯源

| 要求 | 状态 | 当前证据 |
| --- | --- | --- |
| P9.1 API v1 | 已证明 | 版本化 schema、精确错误和 API 文档通过十步重放测试。 |
| P9.2 Recorder | 已证明 | GUI 十步记录、JSON recipe、父/结果 hash 校验和干净会话重放通过。 |
| P9.3 预设/模板/用户库 | 已证明 | 参数预设、项目模板、recipe、片段和重复单元库均版本化；对话框/Library Browser 有产品入口。 |
| P9.4 文件批处理 | 已证明 | 文件导入、API 执行、验证、原子导出与逐文件错误汇总通过。 |
| P9.5 lineage | 已证明 | 父/结果 hash、命令、参数、seed、版本和时间均可追溯。 |
| P9.6 Jobs/恢复 | 已证明 | JSON 原子 checkpoint、queued/running/interrupted/complete/cancelled、Jobs Browser、取消与恢复通过。 |

## P10：产品成熟度与终验

| 要求 | 状态 | 当前证据或关闭条件 |
| --- | --- | --- |
| P10.1 GUI/故障注入 | 已证明 | 真实 AppContainer/uihtml 覆盖陈旧请求、后端、渲染、保存和 4,096 原子加载中关闭，均保持原子状态。 |
| P10.2 恢复/安全关闭 | 已证明 | SHA-256 恢复日志、损坏保留诊断、恢复/丢弃 UI、正常保存清理和三选项安全关闭通过。 |
| P10.3 双语/无障碍 | 已证明（自动）/外部门（人工） | 双语 XML、tooltip、disabled reason、焦点安全、ARIA、键盘快捷键自动覆盖；200% 缩放与完整键盘路径须按 `dev/modeling/acceptance/P10-accessibility-audit.zh-CN.md` 人工签字。 |
| P10.4 教程/示例 | 已证明 | 用户/API/排障文档、快捷键 SVG 和三个由生产 API 生成且可重开的 `.ks` 示例项目齐全。 |
| P10.5 soak | 已暂停 | 500 次编辑短门已通过；正式长测在约 56 分钟发现 Modeling Guide 运行时回调缺陷后作废。缺陷已修复并通过路径回归；按当前开发决策不再执行四小时测试，待其他调整完成并重新冻结候选后再评估。 |
| P10.6 十二任务对标 | 外部门 | 必须取得授权 Materials Studio，并由至少 10 名领域用户在同硬件完成盲测；当前不能诚实生成。 |
| P10.7 发布审计 | 待重建 | 最新源码建模 120/120、建模/scene/UI 61/61、Code Analyzer 0/0；旧 50 MB `.mltbx` 因 Modeling Guide 回调缺陷已标记 superseded，不能作为当前发布候选。前端 249/249、覆盖率 85.309% 是上一冻结候选证据，最终调整后必须重跑并重建。 |

## 当前结论

P1–P9 的生产实现与自动验收已经关闭。P10 的 Modeling Guide 回调缺陷已
修复并通过真实 macOS 打开验证，但当前没有可发布候选；总目标仍不得标记
完成，直至：

1. 其他调整结束后重跑前端、覆盖率、真实 GUI 场景并重建 production 包；
2. 如恢复 P10.5 正式长测，报告须 `passed=true` 且 `qualified=true`；
3. 200% 缩放/完整键盘人工审计签字；
4. 授权 Materials Studio 环境的至少 10 人、12 任务同硬件盲测达到计划阈值。
