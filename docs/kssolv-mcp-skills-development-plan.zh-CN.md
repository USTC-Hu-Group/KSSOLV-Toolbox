# KSSOLV Toolbox MCP 与科研 Skills 开发方案

日期：2026-10-22。依据：当前工作区，HEAD `40369fd`，包含未提交变更；这不是一个已经冻结的发布基线。本文为设计交付，不表示拟议工具、skills 或验收项已经实现。

目标：让外部 Agent 通过稳定接口完成“数据库取结构—建模—计算—文献复现—分析—双语论文准备”，用户可在 Toolbox 中检查、编辑与接管。以 COMSOL 官方公开的完整计算闭环和桌面可审阅定位为产品参考，不推断其内部实现。

## 1. 本次深入检查带来的设计修订

| 已核实事实 | 源码位置 | 设计决定 |
| --- | --- | --- |
| 任务构造立即创建选项 UI：AbstractTask 调 setupOptionsUI，AbstractTaskUI 调 setupUI，SCF UI 创建控件 | `+kssolv/+services/+workflow/+module/AbstractTask.m:45`；`AbstractTaskUI.m:26`；`+computation/SCFTaskUI.m:30` | P0 提取任务描述、默认参数与验证；无界面请求直接构建纯数据快照。旧任务/UI 类名保持兼容，整体重构懒加载后置 |
| 新画布节点默认构造 SCF；已有节点可能重建 UI | `+kssolv/+services/+workflow/WorkflowGraph.m:26` | 画布 JSON 是界面格式，不作为对外工作流协议 |
| 快照仅保留排序后的任务序列；runner 共享一个 context；资源继承也依赖全局顺序 | `+remote/+execution/WorkflowSnapshotBuilder.m:15`；`RemoteWorkflowRunner.m:87`；`+workflow/ExecutionResources.m:112`，均在 `+kssolv/+services/` 下 | 初期支持明确校验的线性链。扫描为独立快照/作业；通用 DAG 必须另行设计输入绑定和隔离 |
| executionTimeLimit、taskInput/taskOutput 等属性未形成对应执行保证 | `+kssolv/+services/+workflow/+module/AbstractTask.m:34` 及执行路径检索 | 不能从属性存在推断超时、端口隔离已实现；需要 Worker/服务端执行并测试 |
| 作业存储是全库读取—修改—写回；文件原子替换不等于多写互斥 | `+kssolv/+services/+remote/+job/RemoteJobStore.m:76`；`+remote/+internal/AtomicJsonFile.m:24` | 所有 GUI/MCP 更新经过一个状态写入者，或经验证的锁/版本协议；Worker 只提交独立事件 |
| 项目保存前修改同 handle 的 dirty 状态，再直接 save；version 是格式版本 | `+kssolv/+services/+filemanager/@Project/Project.m:7`、`:33` | M0/M1 完成无界面项目身份、revision、同目录临时文件校验与替换、失败恢复 dirty；GUI 同步后置；存量格式逐项迁移验证 |
| GUI dataset 保存删除 molecule，并访问当前 GUI 项目 | `+kssolv/+services/+workflow/+codegeneration/CodeGenerator.m:136` | ResultBundle 必须先独立归档，再导入 GUI；不能把展示 dataset 当完整科研档案 |
| 建模 API 不转发 collection 的 models/labels | `+kssolv/+api/+v1/+modeling/execute.m:20`；`+kssolv/+modeling/SurfaceCommands.m:179` | 结果联合类型 `model/analysis/collection`；只发布完成适配的命令子集 |
| 命令目录主要是 ID 和 UI 文案；能力契约没有完整参数 Schema | `+kssolv/+modeling/CommandCatalog.m:111`；`+contracts/CommandCapability.m:53` | 增加命令描述表，包含类型、默认值、边界、单位、索引和输出种类 |
| EditTransaction 校验调用者提供的 revision，但不拥有项目状态与持久化 | `+kssolv/+modeling/+contracts/EditTransaction.m:43` | 服务端负责原子比较更新及 revision 递增；skill 的 preview/commit 不能替代原子性 |
| OperationRecorder 记录显式参数和 seed，没有展开默认值或完整环境 | `+kssolv/+modeling/+provenance/OperationRecorder.m:15` | 保存 effectiveParameters、schema/code version、种子、哈希；计算来源另建契约 |
| 无序/部分占位结构转换选择最高占位元素后 warning 并继续 | `+kssolv/+services/+fileparser/StructureIO.m:513` | 允许只读导入和显示；进入计算前 strict preflight 拒绝未确认的有损转换 |
| 对象往返转换不保留全部来源/属性；ModeledStructureData.rawFileContent 是重新导出内容 | `StructureIO.m:153`、`:215`；`ModeledStructureData.m:27`，在 `+kssolv/+services/+fileparser/` 下 | 原始下载 bytes 单独保存，显示文件与原始证据分开；电荷/自旋/PBC 等逐字段核实 |
| MP 已有默认 nativeTransport；COD/OPTIMADE 仍需显式 transport | `+kssolv/+analysis/+matgenlab/+ext/+matproj/MPRester.m:506`、`:868`；`+cod/COD.m:64`；`+optimade/OptimadeRester.m:290` | 复用 MP；统一传输边界与响应适配，为其他客户端注入 transport。不能声称数据库能力都需从零编写 |
| OPTIMADE convenience 方法只取 structure，provider/条目失败可能 warning 后继续 | `OptimadeRester.m:127`、`:159`、`:404` | 保留原始/SNL 来源；返回 partial、失败 provider/page/record 明细 |
| SCF 只保存 info；band/DOS 直接消费密度，没有收敛门禁 | `+kssolv/+services/+workflow/+module/+computation/SCFTask.m:68`；`+postprocessing/BandProcessingTask.m:64`；`+visualization/DOSTask.m:55` | 下游正式分析默认要求电子收敛及输入身份匹配；不收敛结果可作诊断，必须标记 |
| NSCF 节点只配置参数，实际数值求解在能带/DOS 消费端 | `+kssolv/+services/+workflow/+module/+computation/NSCFTask.m:76` | 工具与状态准确描述 configured，不能称数值计算已完成 |
| TDDFT 声明依赖 Build，但实际消费 SCFOptions/H/X；弛豫有电子/离子两套状态 | `TDDFTTask.m:17`、`:48`；`RelaxationTask.m:56`，在 `+kssolv/+services/+workflow/+module/+computation/` 下 | 任务表声明真实 consumes/produces；分开记录电子和离子收敛，未完成适配前不开放这些任务 |
| 内置聊天工具只有两个 GUI 包装，验证主要覆盖 JSON 与必填字段 | `+kssolv/+services/+llm/+internal/tools.m:18`、`:93` | 提取供应商无关 ToolDescriptor；分别适配 MCP 与聊天助手，稳定验证由业务层执行 |
| server 已分 runtime/portal/admin；MATLAB payload 排除 server/scripts | `server/README.md`；`docs/development-layout.md`；`+kssolv/+util/+test/PackagingTestFileTest.m:16` | MCP 单独打包；不能只放进 server/ 就声称 Toolbox/独立应用已携带。新增 staging、安装及包内容验证 |

以上为设计前需要处理的边界，不是本次已经修复的 bug 列表。文中的相对源码路径均以仓库根为基准；工作区变化后需重新核对行号。

## 2. 三层职责与部署边界

1. **MATLAB 领域服务**：结构转换、建模、任务有效参数、物理校验、计算、结果适配。由版本化 API 暴露，支持脚本、GUI、MCP 共用。
2. **MCP 网关/作业控制**：协议、请求验证、对象身份、幂等、预算、状态、artifact 访问与客户端兼容。首期采用 Node.js/JavaScript 与官方 SDK 发布包；锁定并审计完整依赖树。
3. **Skills**：研究决策、来源选择、缺失信息处理、实验设计、结果论证及写作。它们消费已经存在的工具，不另写单位转换、哈希、调度或计算验证。

现有 Python 标准库 Online 服务保持其职责。网关与这些服务通过明确接口组合，不直接复用人工命令窗口的任意 evalc 路径。首次集成默认本地 stdio；远程 HTTP、身份隔离与配额按后续里程碑发布。

MCP SDK 版本与协议版本分别锁定，针对实际客户端支持的版本形成兼容表。不能仅按网页的 latest 字样承诺所有客户端兼容。工具的清单、排序与权限行为遵守所选协议版本，执行环境能力通过 capabilities 数据报告，不依赖“切换一个 skill 就改变协议能力”的假设。

首期不用 MATLAB Python Engine 或新增 MEX。计算采用固定 MATLAB 入口；短调用与计算作业先经独立进程验证，是否增加常驻进程由冷启动和内存测量决定。已有进程内赝势设置等全局状态须隔离。

GUI 对打开项目保有状态所有权，MCP 经会话适配器提交操作；无界面项目由服务拥有。交接时有显式版本与锁，任何时候同项目只有一个状态写入者。跨进程传递数据和事件，不共享 MATLAB handle，也不并发修改同一 .ks 文件。

单写者必须覆盖真实调用链：不能让多个 MATLAB 控制 Worker 各自调用 RemoteJobManager 后并发写其 store。远程提交/查询/取消串行进入一个 MATLAB 控制进程；计算 Worker 可以独立运行。JobService 的状态库与既有 backend journal 明确所有权，禁止对同一文件双写。现有 HTTP worker 的 jobs 是有超时清理的内存代理请求，不能直接替代持久化 DFT 调度。

## 3. 最小数据契约

| 对象 | 必需内容 | 首期存储策略 |
| --- | --- | --- |
| CommandDefinition / TaskDefinition | type、schemaVersion、optionsSchema、默认值、单位、索引基准、consumes/produces、resultKind、validator | 仓库维护并生成对外描述；MATLAB 端再次做权威校验 |
| SourceRecord | provider、record ID、请求/页、获取 UTC、数据库/API 版本（缺失明确 unknown）、原始 bytes 哈希、引用/使用条件 | JSON 清单 + 原始文件，秘密字段脱敏 |
| StructureArtifact | 来源对象、matgenlab 表示、计算结构、单位、PBC、电荷/自旋传递状态、转换映射 | 原始/规范/计算表示分别保存 |
| WorkflowSpec / ValidatedPlan | 明确 taskType、有效参数、结构 revision、线性依赖、资源、预算、validator version、manifest hash | 纯数据；适配为现有 v1 snapshot，保留 legacy 读取 |
| JobRecord / Event | intent、幂等键与输入 hash、backend identity、执行状态、心跳、事件序号、取消请求、错误 | 单写者 journal/快照；Worker 每作业独立事件文件 |
| ResultBundle | 输入和输出结构、有效参数、PP 文件 SHA、程序构建身份、单位、必需科学结果、状态、保留策略与清单 hash | MATLAB 保存数值；大型可选重启状态按策略保留，网关返回有界摘要 |
| AnalysisArtifact / FigureSpec | 注册分析 recipe、输入结果 hash、单位/归一化/参考态、参数/代码版本、排除点理由、图数据与配置 | 纯数据与可重建脚本/配置，不把生成式图片当结果图 |
| MethodEvidence / Claim | 文献定位、reported/inferred/assumed/unknown、结果字段指针、适用范围、支持/反证、审阅状态 | JSON；允许有缺项草稿，不能提升为已验证结论 |
| ManuscriptRevision | 共享 claim/data、双语文本、术语、引用、目标期刊配置及核验日期 | 稿件源、图表、SI、引用库与验证报告 |

M0/M1 只实现 SourceRecord、JobInput、ResultBundle 及其 `parentRefs + dependencyKind`；不建设完整 ResearchCase/Claim 图数据库。后续在同一身份规则上扩展，避免过度平台化拖延首个闭环。

ResultBundle 的“完整”是相对声明的产物合同：必需科学结果和复现输入不能丢失，可选 H/X 等重启状态单列，派生图表单列。manifest 明示哪些保留、哪些可重算，以及能否继续 band/DOS/重启；不能强制每次落盘全部巨大对象，也不能在缺状态时假装可续算。

三类身份分别处理：原始 bytes 的归档 hash、确定性计算输入 hash、带算法版本的结构等价关系。原胞/常规胞可物理等价，但不能直接拿它们的字节 hash 去重并删除来源。

程序构建身份需要包括 Toolbox/core 版本与源码清单哈希或明确的构建标识；工作区有修改时不能只记录 Git HEAD。脱敏请求保留用于重现的非秘密参数，API key 不进入原始归档、日志或论文。

ResultBundle 分别报告 execution、scientific、artifact 三类状态。科学验证至少包括 finite、电子收敛、适用时离子收敛、残差和输入身份。未收敛输出可以诊断，不默认进入正式 band/DOS/Claim。恢复作业身份不明时进行 reconciliation，不能自动重提。

依赖失效按语义传播：PP/泛函/结构/电子态变化失效下游计算；拟合区间或分析代码变化失效分析以后；图颜色/版式只更新图和排版；语言润色不重跑 DFT。新数据库版本/论文更正提示差异，不覆盖冻结证据；采用新证据后建立新版本。

## 4. MCP 工具面与优化

首个可用版本控制在约 18 项基础工具，按端到端验收逐步开放，不以工具数量为目标：

| 工具 | 合同重点 |
| --- | --- |
| capabilities_get、command_describe | 枚举安装能力、参数 Schema、适用模型和当前限制；分别报告软件声明、环境检测和验证状态 |
| project_create/open/inspect/save | 显式 ID、revision、当前 owner；原子保存，不隐式改变其他打开项目；open/save 只发布已通过无界面加载/迁移测试的格式版本，不支持项明确报错 |
| structure_import/inspect/preview/commit | 原始来源保留；严格计算资格；preview 产生内容 hash 和 baseRevision，commit 做原子检查 |
| workflow_validate | 输入 WorkflowSpec，返回规范化参数、依赖、资格、预算与 manifest；不执行计算 |
| job_submit/get/logs/cancel | submit 绑定有效 manifest 与幂等键；get 可恢复；logs 游标读取；cancel 独立于 MCP 请求取消 |
| result_summary/export、artifact_read | 只读可重复、分页、有界字段/数组读取、文件大小和 hash；导入 GUI 与读取分开 |

数据库阶段增加 database_search/fetch_structure；复现阶段增加 literature_import、evidence_get、reproduction_plan/compare；分析阶段增加 registered analysis/figure/claim 工具。后续名称和数量经行为评估调整。

避免一个无限 parameters 对象接收任意 MATLAB 参数。常用命令采用有限 discriminated union/专用 Schema；扩展命令由 command_describe 发现精确 Schema，并由服务端严格验证。若泛化工具导致模型频繁选错或漏参数，再把高频操作拆成独立工具。

优化顺序：

1. **先正确**：错误分类、单位、revision、幂等、显式任务映射；外部不接受任意 ClassName、函数或 shell。
2. **再减少调用与上下文**：单次返回摘要/下一步所需 ID；大数组留 artifact；规范参数说明按需读取；批量查询/对比但保留逐项错误。
3. **再改善延迟**：schema/immutable artifact 缓存；数据库有 TTL、查询和 provider 版本的缓存；有界批处理和 backpressure；基于指标选择常驻 Worker。
4. **最后扩展并发**：每实验独立作业，预算限制并发；多分支 DAG 需先具备节点输入绑定及资源继承隔离。

核心可靠性：先持久化 submission intent 再启动；同键同输入返回同作业，同键不同输入冲突；启动后响应前崩溃通过 backend identity/输入 hash 核对。exactly-once 不能只靠文件重命名宣称实现；业务应验证去重和恢复窗口。

stdio 仅发协议消息，MATLAB stdout/stderr 捕获为日志。轮询是基础能力，通知是优化；客户端断线与请求取消不默认终止持久化计算。协作取消有检查点，超时后只能终止服务自有 Worker，并核实取消和完成竞态。

数据库网络层补齐总耗时/响应上限、分页上限、429/Retry-After、有限重试、取消、partial 结果、凭证脱敏。不同客户端的 `status_code` 与 `status` 响应形状在适配层统一。真实联网不纳入每次离线 PR 的硬依赖。

工具只读取当前项目允许的 artifact，校验路径/符号链接与大小，来源文本始终当数据处理。HTTP 发布阶段再完善身份、项目隔离、授权与部署设置；这些要求也写成明确测试，不依赖 skill 提醒。

## 5. Skills 目录、边界与交付步骤

建议最终 6 个核心领域 skills，不按数据库、求解器或语言重复拆分。最小首发为 source-structures 与 run-study；prepare-model 只有命令 Schema、结果联合类型和原子提交验收后才发布，其余按能力分期交付。用户无需每次逐项显式调用 skill。以下名称与工具依赖都是拟议，当前未安装。

| Skill | 何时触发 / 边界 | 必需输入 → 输出 | 依赖与按需参考 |
| --- | --- | --- | --- |
| kssolv-source-structures | 查找并获取数据库结构；不自动弛豫、不用化学式唯一确定晶相 | 查询、相/来源约束 → 候选、SourceRecord、结构 ID、资格报告 | database、source、structure validate；provider 特征、partial 与无序说明 |
| kssolv-prepare-model | 超胞、缺陷、表面、吸附等派生建模；保留来源副本 | structure revision + 意图 → preview/commit、派生结构、recipe | command describe、事务；PBC、Å/bohr、1-based 索引、collection |
| kssolv-run-study | 单点、弛豫、收敛和扫描；不无限追加或假设任务已求解 | 目标、结构、方法、预算 → Experiment、jobs、停止依据 | preflight/validate/submit/status/cancel；single-point、convergence、sweeps 分别放 references |
| kssolv-reproduce-paper | 复现指定论文的指定图表/性质；不能用默认值冒充原文设置 | 论文/SI/目标 → 定位证据表、缺失项、方法兼容性、复现协议、差异报告 | literature/evidence/experiment/compare；允许先用作者确认的参数及原文片段，不等待全自动解析 |
| kssolv-analyze-results | 比较、拟合、能带/DOS 解释和科研图；不把相关性自动写成机制 | 冻结结果、问题 → Analysis、Figure、Claim 候选及限制 | registered recipes、比较资格、figure/claim；参考态与单位 |
| kssolv-write-manuscript | 基于证据写方法、结果报告、完整稿件、双语和期刊适配；不含投稿动作 | evidence/claims + 目标 → 对应成熟度的报告/稿件、SI、引用和检查报告 | evidence audit、数字绑定、文档导出；methods、results、bilingual、journal references |

可选 kssolv-review-research 后置，用于用户明确请求科研审校时进行独立复核，不在每次查询中强制全量审稿。也不增加一个重复所有领域说明的大总入口 skill。

每个 skill 的发布步骤：

1. 先写 2 个正向任务、1 个相邻但不适用任务、至少 1 个缺失/失败任务；确认实际调用路径。
2. 检查所需 tool/capability 和 schema 版本已经可用；dependency manifest 的机器可读格式由项目定义，不能臆造宿主的标准字段。
3. SKILL.md 只放触发、关键决策、真实约束及输出要求；参数表由服务描述提供；大段例程/模式放 references。
4. 仅将确需复用的确定性工作放 scripts；脚本调用同一 API，不能复制一套验证或 API key 管理。
5. 用 skill-creator quick_validate 检查格式，再做独立行为测试。格式通过不代表科研行为可靠。
6. 与无 skill 的同模型同预算对照，重复运行并比较动作、产物、成本；再测 holdout。
7. 随能力版本发布源码与安装说明；MCP prompts 可提供轻量任务模板，但不是 skill 安装协议，也不复制完整 SKILL.md。不假设全部客户端支持 skills/resources/prompts 的相同交互。

文档制作按目标宿主的实际能力复用 documents、pdf 等现有专用 skills 或等价导出适配器，承担 DOCX/PDF 渲染与版面检查；科研 skill 仍负责证据与论证。它们不是所有客户端的必装依赖，接入前还需核验本项目无 JVM/无新增编译源约束。引用核验与数字绑定不能交给版面 skill 代替。

首批评估场景：

| Skill | 正向任务 A | 正向任务 B | 边界/对抗任务 |
| --- | --- | --- | --- |
| source | 明确 mp-id 获取并保留 raw hash | 多晶型查询并比较候选 | 无序结构/部分 provider 失败，不静默宣称完整、可算 |
| prepare | 指定超胞及原子数核验 | 平移/缺陷并验证 PBC 与 recipe | 过期 revision、0-based 索引、NEB collection，不覆盖/丢输出 |
| run | LiH 单链 SCF | 有限预算截断能收敛扫描 | submit 响应丢失、不收敛、预算耗尽；不重复启动、不假成功 |
| reproduce | 完整方法表复现一个量 | 已声明替代方法的比较 | 只有摘要、缺 PP/U、图表冲突；不编条件或调参追答案 |
| analyze | 同条件每原子能量比较 | 已注册拟合与可重建图表 | 不同组成/参考态直接排总能，或 NaN/失效结果；拒绝无效正式结论 |
| manuscript | 从已核验作业生成 Methods | 双语结果简报并绑定同一数据 | DOI 存在但不支持论断、数据更新、只要求润色；不虚构、不擅自运行/发布 |

至少形成 24 个固定行为场景（每 skill 含正向、缺失、失败、越界维度），另设未见变体。由评估器检查工具 trace 与实际产物；不能只匹配标题或措辞。文献里的“执行 shell/忽略规则”等文本只作为来源内容。

## 6. 分阶段开发与可评审变更

### M0：修复科研合同与最小无界面接口

- D01：CommandDefinition/TaskDefinition，effectiveParameters；真实 consumes/produces；model/analysis/collection 结果联合类型。先覆盖 Build + SCF 与小型建模子集，存量 Task/UI 类名不改。
- D02：StructurePreflight，显式单位/索引/PBC/无序/电荷自旋传递；原始来源与转换 mapping。未验证的排序/SQS 策略不作为自动修复能力发布。
- D03：WorkflowSpec + ValidatedPlan，纯 DTO 构建 legacy snapshot；限制线性依赖和 NSCF 继承；ResultBundle 与科学状态适配；未收敛诊断和正式分析区分。
- 同阶段先完成无界面 ProjectService 的 ID/revision、单 owner、原子比较更新、临时保存与失败 dirty 恢复。首发 project_open/save 仅支持已通过加载/迁移测试的格式版本；兼容失败不通过 setter 隐式重建任务。GUI 所有权交接和实时事件仍在 M2。
- 验收：不构建 UI 控件完成输入校验和 LiH；collection 不丢失；结构往返与电子/离子状态错误有确定性失败。

### M1：数据库—本地计算闭环与最小 skills

- D04：SourceService，MP native 路径复用；COD/OPTIMADE transport、raw 归档、版本/partial、限流与分页上限。
- D05：JobService 单写者、intent/幂等、Worker 事件/心跳/取消、reconciliation、完整结果先归档；复用 remote 服务的能力而不直接暴露任意函数提交。
- D06：MCP stdio 网关、核心工具、artifact 有界读取、错误 Schema；独立包的依赖与安装检查。
- D07：先发布 source/run skills；prepare 通过独立门槛后再启用。提供从 executed snapshot 与 ResultBundle 生成的中英文 Methods/结果简报；有限写作模式通过字段绑定验证后可同阶段发布，不能把草稿/诊断当完整论文。最小能力清单与行为回归同步交付。
- 验收：数据库录制样本→结构→SCF→结果；离线归档重算；丢响应不重复作业；网关重启仍能查询。至少一个真实端点 smoke 单独记录；无凭证不伪装通过 MP live。

### M2：桌面协同与最小文献复现

- D08：在 M0/M1 的无界面 ProjectService 身份、revision、原子保存上接入 GUI ownership 交接、adapter 与变更事件；复用 EditTransaction，但由服务完成原子提交。GUI 的 job 更新也经过同一写入者；未完成迁移前明确禁止同 store 并发。扩展存量 .ks/.wf 与界面行为兼容测试。
- D09：LiteratureRecord/MethodEvidence/ReproductionStudy；先支持用户提供原文、SI 和明确位置，自动检索/抽取逐步加入。人工确认参数可进入协议，保留确认身份/时间。
- D10：复现 skill；先选择参数公开、规模适中的公开案例，事先固定目标量、可比条件与容差。
- 验收：GUI/MCP 交替编辑拒绝旧版本；指定文献目标产出复现/替代验证/条件不足三种准确报告；结果重复导入幂等。

### M3：实验、分析和早期科研写作

- D11：Experiment，独立作业扫描、预算和停止条件；注册的 comparison/fitting/figure recipes；可比较资格、反证与失效传播。
- D12：analyze skill；扩展早期 Methods/双语报告为实验比较报告，增加参考文献核验；write skill 的 report 模式按能力放行，明确草稿/验证成熟度。
- D13：按需求适配现有 remote backends；保留各自能力和环境限制。远程计算不必等待完整论文引擎。
- 验收：一个收敛实验有真实停止依据；图从数据可重建；修改数据同步失效报告；只改图色不重算 DFT；不把科学无效结果变正式论断。

### M4：完整论文与投稿准备

- D14：ClaimRegistry、论证结构、证据覆盖报告、引用定位、双语术语/否定/不确定性检查、稿件版本与 SI。
- D15：目标期刊 profile；文档渲染、图表尺寸和格式验证；生成正文、数据/代码可用性、真实作者信息相关声明及投稿材料包。生成材料不包含自动投稿/公开上传。
- 验收：主要数字和论断可追溯，无虚构引用；所有明确 blocking 项有状态；作者确认科学充分性和创新性。复现成功不自动标记原创论文就绪。

### M5：远程 MCP、跨平台和扩展

- D16：Streamable HTTP、身份与项目隔离、配额和部署；客户端兼容矩阵；Windows/macOS/Linux 的路径、替换、取消及打包验证。
- 根据性能数据再决定常驻 Worker、存储迁移和真正的 DAG；TDDFT、GPU/PCT、复杂弛豫逐项校验后开放。不能从串行 LiH 通过推断全部能力。

开发顺序是依赖顺序，不是日历承诺；每个 D 项可以拆成一至数个可评审 PR，代码体量和失败反馈决定拆分。未经用户明确授权不新增编译源；提交标题/body 遵守仓库英文格式。

## 7. 测试分层与持续优化

| 层 | 场景与已有基础 | 运行时机 |
| --- | --- | --- |
| 合同/纯逻辑 | 命令结果 union、effective 参数、单位/索引、无序 preflight、真实依赖、schema 迁移；复用 ModelingAPIFunctionalTest/ScientificValidityTest | 每次相关 PR，MATLAB -nojvm |
| 网络/来源 | MP/COD/OPTIMADE fixtures；loopback 429/超时/断流/大分页/partial/脱敏；真实端点另列 | 离线 PR + 可选 live smoke，不混报 |
| 作业/崩溃 | 同键重复/冲突；启动前后故障；lost update；取消与完成竞态；旧身份；损坏输出；保存失败 | 每次作业层变更，受控假 Worker + 真进程小样本 |
| 科学数值 | LiH 基准，刻意不收敛、NaN、旧密度、缺 H/X；弛豫电子/离子状态；band/DOS 依赖 | PR 小基准，扩展任务发布前全覆盖 |
| GUI/兼容 | 存量 .ks/.wf、UI 延迟重建、ownership、revision 冲突、结果导入去重与撤销 | 会话/持久化修改时，图形测试独立环境 |
| MCP 协议 | tools/list/call、schema、structured output、分页、未知工具、错误映射、stdio 干净、取消/断线语义、版本组合 | 网关 PR + 目标客户端集成 |
| 科研证据 | raw 与显示导出区分；hash 篡改；PP 变化失效；DOI 真但不支持；图表冲突；双语数据一致 | evidence/analysis/manuscript PR |
| skills 行为 | 24 固定场景 + holdout；无 skill 对照；工具 trace/产物、预算、恢复、证据与双语 | skill/工具合同变更后，按影响范围运行 |
| 包装与部署 | gateway/skills 独立交付；MATLAB payload 明确清单；无 Java/JVM、无新增编译源；路径/权限/安装 | 发布候选 |

可复用的现有测试：

- `+kssolv/+services/+remote/+test/WorkflowRemoteTest.m:186`：LiH 收敛、末残差 < 1e-6、能量基准 -5.9666002670969，AbsTol 1e-8。该阈值是当前测试基线，不可推广为所有物理模型的精度保证。
- `+kssolv/+services/+remote/+test/MirrorTransportTest.m:5`：真实 detached MATLAB、恢复与 LiH 结果，不只是 mock；本次未运行。
- `+kssolv/+services/+remote/+test/RemoteJobManagerTest.m:64`：获取重试、恢复、取消、凭证与导入行为；应扩充崩溃窗口和并发写测试。
- `+kssolv/+modeling/+test/ModelingAPIFunctionalTest.m`：recipe、batch 隔离、取消、恢复与损坏 journal；不是 skills 行为测试。
- `scripts/docker/tests/test_http_worker.py`：loopback 请求、错误脱敏、取消与重试；可复用测试方式，不能直接当 DFT 作业调度已通过。

指标：schema 字节数与 tools/list 大小、工具选择/参数错误率、有效工具调用次数、缓存命中、冷启动/热调用 p50/p95、队列/内存、完成率、证据覆盖、恢复与重复作业。先测基线，再设发布阈值。论文成熟度还需作者科研判断，自动通过不能证明论断充分或文章会被接收。

严格回归项：静默单位或占位率错误、覆盖新 revision、重复高成本作业、虚构数值/引用、把未收敛写成有效结论，在约定回归集上必须为零；这只是发布条件，不能宣称真实所有场景绝对零错误。

迭代节奏：收集脱敏 trace 与失败样本 → 归因到服务、协议、skill 或数据源 → 最小修订 → 独立重放失败场景 → 受影响回归 → holdout → 更新兼容表和能力说明。不要为每次措辞偏差增加全局硬规则。

## 8. 本次验证记录

实际运行与静态推断分开记录：

| 项目 | 环境 / 结果 | 限制 |
| --- | --- | --- |
| NativeUtilitiesTest 的 digestVectors / fileDigestPreservesBytes | MATLAB R2026b，-nojvm，2/2 通过 | 证明当前哈希小样本路径，不代表全部原生工具测试通过 |
| MatprojInventoryTest | 同一 -nojvm 会话，6/6 通过 | frozen mock，不是真实 MP 访问 |
| CodInventoryTest | 同一 -nojvm 会话，4/4 通过 | fixture CIF 有缺显式对称操作的 warning；不能证明真实 COD 可用 |
| OptimadeInventoryTest | 同一 -nojvm 会话，6/6 通过 | mock/provider fixtures，未验证实时 provider |
| Python HTTP worker | `python3 -m unittest discover -s scripts/docker/tests -p test_http_worker.py`，3/3 通过 | loopback HTTP，不是 DFT Worker |
| LiH 无界面科学回归 | R2026b -nojvm，smallLiHWorkflowRunsScientificallyHeadless 1/1 通过；6 次 SCF 迭代，Etot=-5.9666002670969 Ha，末密度残差约 9.091e-9 | 只验证当前串行小样本。输出包含 PP 价电子与周期表不一致 warning，需在正式证据中保留；不代表 GPU/PCT/弛豫/TDDFT/远程或参数收敛精度已验证 |
| 新 MCP/skills | 未实施，未运行 | 本文提出验收项；没有现成服务或 skills 行为通过证据 |

MATLAB 不在 PATH，但可执行文件位于 `/Applications/MATLAB_R2026b.app/bin/matlab`。上述 MATLAB 命令均先断言 JVM 未启用，再通过 matlab.unittest 运行并 assertSuccess；未使用实际数据库凭证。

## 9. 多专家交叉评审与修订记录

本轮由三个独立代理角色进行源码审阅：MCP 架构、skills 设计、科研证据与数值可靠性；主代理整合并运行上述测试。角色审阅不是外部领域专家签字或期刊审稿。

| 轮次 | 关键意见 | 采纳结果 |
| --- | --- | --- |
| 独立审阅 | UI 构造、共享 context/资源继承、job store 多写、GUI 结果不完整 | M0 纯 DTO/线性链，M1 单写者和完整结果先归档，M2 再迁移 GUI |
| 独立审阅 | collection 丢输出、默认参数未展开、事务不拥有 revision | D01 结果 union/effective 参数，D08 服务原子提交 |
| 独立审阅 | 无序转换、NSCF 配置语义、TDDFT 真依赖、双重弛豫状态 | strict 计算资格、真实 consumes/produces 和分层科学状态 |
| 第一轮交叉 | 6 领域 skills，确定性保障应在代码；不按数据库/语言拆分 | 分期发布 6 skills，参数按需读取，测试产物和工具行为 |
| 第二轮反证：架构挑战 | Node 单写者不能防止多个 MATLAB manager 同写；完整结果不等于每次保存全部 H/X | 控制操作串行进同一 MATLAB 控制进程；各 store 明确所有权；结果分必需科学产物、可选重启状态和派生图表 |
| 第二轮反证：skills 挑战 | 六项全部首发过早；工具数硬上限会退化参数类型；完整论文过晚会延误可用报告 | 首发 source/run，prepare 另设门槛；18 是预算；M1 开有限 Methods/结果报告 |
| 第二轮反证：科研挑战 | 无序不能一概拒绝导入；全自动文献解析与全证据数据库不应阻塞 MVP | strict 放转计算模型/正式论断入口；先人工确认参数+原文定位；M0/M1 用最小来源包与 parentRefs |
| 文档终审：阶段依赖反证 | M1 已承诺 project_open/save，但旧草稿把原子保存与 revision 全放 M2 | 无界面项目 ID/revision/原子保存与失败恢复前移 M0/M1；M2 只扩展 GUI 交接/事件/兼容；未验收格式不开放 |

三位专家第二轮分别给出修改意见并互相核对，以上修改已落实到本文。剩余待实证项包括：跨平台原子替换/进程取消、真实网络、并发控制和新网关/skill 行为，未以评审同意代替测试。

## 10. 本次测试重放命令

从仓库根执行；MATLAB 路径按目标安装调整。测试只使用离线 fixtures 和当前仓库小型 LiH，不读取数据库凭证。

```sh
/Applications/MATLAB_R2026b.app/bin/matlab -nojvm -batch "assert(~usejava('jvm')); addpath(pwd); s=matlab.unittest.TestSuite.fromClass(?kssolv.util.test.NativeUtilitiesTest); n=string({s.Name}); s=s(endsWith(n,'/digestVectors') | endsWith(n,'/fileDigestPreservesBytes')); s=[s matlab.unittest.TestSuite.fromClass(?kssolv.analysis.matgenlab.test.ext.MatprojInventoryTest) matlab.unittest.TestSuite.fromClass(?kssolv.analysis.matgenlab.test.ext.CodInventoryTest) matlab.unittest.TestSuite.fromClass(?kssolv.analysis.matgenlab.test.ext.OptimadeInventoryTest)]; r=run(s); disp(table(r)); assertSuccess(r);"

/Applications/MATLAB_R2026b.app/bin/matlab -nojvm -batch "assert(~usejava('jvm')); addpath(pwd); s=matlab.unittest.TestSuite.fromClass(?kssolv.services.remote.test.WorkflowRemoteTest); n=string({s.Name}); s=s(endsWith(n,'/smallLiHWorkflowRunsScientificallyHeadless')); assert(numel(s)==1); r=run(s); disp(table(r)); assertSuccess(r);"

python3 -m unittest discover -s scripts/docker/tests -p test_http_worker.py
```

## 11. 参考与约束

- [COMSOL 官方定位](https://www.comsol.com/press-release/system-level-modeling-and-agentic-ai-take-the-spotlight-in-comsol-multiphysics-version-2027-14722)：完整计算闭环、结果驱动迭代与桌面审阅。
- [MCP 官方 SDK](https://github.com/modelcontextprotocol/typescript-sdk)、[工具规范](https://modelcontextprotocol.io/specification/latest/server/tools)、[资源规范](https://modelcontextprotocol.io/specification/latest/server/resources)：具体发布采用锁定版本与实际客户端兼容测试。
- [Materials Project FAQ](https://docs.materialsproject.org/frequently-asked-questions)：记录并引用数据库版本。
- [OPTIMADE 规范](https://www.optimade.org/specification/latest/)：provider/结构/参考关系按能力处理，不假定各站点具有全部可选字段。
- [Crossref API](https://www.crossref.org/documentation/retrieve-metadata/rest-api/)：用于文献元数据核验，不能替代原文论断证据。
- [Nature Portfolio 政策目录](https://www.nature.com/nature-portfolio/policies/editorial-policies)：期刊要求按目标与核验日期保存，不固定成永久通用规则。
- 仓库 AGENTS：全路径禁止 Java/JVM；新增编译型源码和间接编译依赖需开发者明确许可；英文提交信息遵守 `<type>(<scope>): <subject>`。

新增实现以 MATLAB/JavaScript 为主，PDF/OCR、文档渲染与参考文献依赖也必须做相同审计。不默认使用可能依赖 JVM 的报告生成工具；现有编译运行时与新增编译源要区分，但任何新引入的本地扩展源码/安装编译都不绕过许可。
