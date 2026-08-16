# KSSOLV Toolbox 远程计算开发与验收计划

状态：实施中  
基线日期：2026-08-14  
本机验收环境：macOS、MATLAB R2026b  
目标后端：Standard、Bridge、Mirror 和 Cloud 四种互斥顶层模式。本文前半部分保留第一阶段 Parallel Server + Slurm 实现及其历史验收记录；第 11 节是 2026-08-14 确认的四模式生产化重构规范，后续开发和完成判定以第 11 节为准。

## 1. 目标

在 KSSOLV Toolbox 中交付生产级“远程计算”功能，使用户可以：

1. 保存和管理多个 MATLAB Parallel Server + Slurm 集群配置；
2. 使用已有 MATLAB Cluster Profile 或由 KSSOLV 管理的 Slurm Profile；
3. 使用 SSH Agent、Identity File、Password 或 Multifactor（含 2FA）认证；
4. 从 Home Tab 快速选择“不使用远程计算”或一个已保存集群；
5. 将完整 KSSOLV 工作流异步提交到 Slurm；
6. 查询、取消、恢复、查看日志、回收并导入远程结果；
7. 关闭 MATLAB 后让远程作业继续执行，并在下次启动时恢复；
8. 保持现有本地工作流行为兼容。

第一版把一个完整 KSSOLV 工作流作为一个 `batch` 作业提交。工作流节点仍按拓扑顺序执行，节点内部可以使用 batch pool。第一版不把每个工作流节点分别映射为 Slurm 作业。

## 2. 目录与依赖边界

所有新增非 UI 远程功能放在：

```text
+kssolv/+services/+remote/
```

所有新增对话框和 UI 放在：

```text
+kssolv/+ui/+features/+remote/
+kssolv/+ui/+components/+tab/HomeTab.m
+kssolv/+ui/resources/locales/
```

现有 workflow/task 类只允许进行建立无 UI 执行边界所必需的接口改造。集群配置、Profile、作业状态、持久化、远程 runner 和结果回收逻辑不得散落到 UI 层。

## 3. 安全契约

以下规则是发布门禁：

- 密码只能按用户明确操作由本机 RSA-OAEP 公钥加密后写入配置；
- TOTP seed 仅在用户勾选保留后加密写入配置；本机私钥与配置分离并限制权限；
- 自动 OTP 必须按 RFC 6238 在登录瞬间生成，不持久化生成值；
- Standard、Bridge、Mirror 的 Password 和 Multifactor 密码通过主配置对话框输入并以本机 RSA-OAEP 加密；未保留的 OTP 和登录后提示凭据仍只交给交互式认证流程；
- Identity File 只保存路径，不复制或读取私钥内容；
- 配置、作业记录、日志、错误、测试产物和 MATLAB command history 不得包含密码、OTP、TOTP seed 或私钥；
- 认证取消、超时或过期映射为 `ConnectionRequired`，不能误报为远程计算失败；
- 真实测试凭据不得写入仓库、fixture 或自动化测试；
- 真实测试前轮换已在开发对话中出现过的密码和 TOTP seed。

交互式 2FA 只进行人工验收。自动测试只验证配置映射、取消和认证过期状态，不持有真实第二因素。

## 4. 用户交互契约

Home Tab 菜单目标：

```text
远程计算 ▼
├── 使用远程计算 >
│   ├── ✓ 不使用
│   ├──   配置 1
│   └──   集群 2
├── ─────────────
├── 管理集群...
├── 测试当前集群
└── 远程作业...
```

快速选择必须满足：

- 始终恰好一个选项带对号；
- 点击当前项不能清空选择；
- 关闭远程计算必须显式选择“不使用”；
- 当前配置被禁用或删除时回退到“不使用”；
- 选择按稳定 UUID 保存，显示名称可以修改；
- 不修改 MATLAB 自带 Parallel 菜单的默认 Profile；
- 当前选择只影响 KSSOLV 工作流运行入口。

## 5. 配置模型

每个配置使用稳定 UUID，并至少包含：

```text
Id, DisplayName, Enabled
ProfileSource: ManagedSlurm | ExistingMatlabProfile
ConnectionMode: SSH | Direct
Host, Username
AuthenticationMode: Agent | IdentityFile | Password | Multifactor
IdentityFile
ExistingProfileName, ManagedProfileName
ClusterMatlabRoot, RemoteJobStorageLocation, HasSharedFilesystem
RequiresOnlineLicensing, LicenseNumber
NumWorkers, PoolSize, Partition, Account, QoS, Walltime
AdditionalSubmitArgs
CodeDeploymentMode: ClusterInstalled | AttachCurrentToolbox
RemoteKssolvRoot
SubmissionMode: DirectParallelServer | RemoteMatlabBridge
RemoteBridgeProfileName
```

配置保存到 `prefdir/KSSOLV/remote/configurations-v1.json`，当前选择保存到同目录的选择文件。写入必须原子化，格式必须有版本号和迁移入口。

## 6. 作业模型与状态机

本地作业记录至少包含：

```text
LocalJobId, ConfigurationId, MatlabProfileName
MatlabJobId, SchedulerJobIds
SubmissionMode, BridgeMatlabRelease, RemoteWorkspace
WorkflowName, ProjectIdentity
SubmittedAt, LastCheckedAt, State
ResultImported, ErrorSummary
```

状态机：

```text
Created -> Preparing -> Authenticating -> Submitting -> Queued -> Running
Running -> Finished -> Fetching -> Retrieved
任意远程访问 -> ConnectionRequired | Unknown
Queued/Running -> Cancelling -> Cancelled
提交或执行 -> Failed
```

查询、取消、结果导入和清理必须幂等。作业删除与远端数据清理必须由用户显式确认。

## 7. 无 UI 执行契约

远程 worker 不得访问或创建：

- `DataStorage`；
- `AppContainer`；
- Workflow HTML；
- `RunBrowser`；
- `ProjectBrowser`；
- toolstrip、figure、uifigure 或任务 options UI。

本地在提交前生成纯数据 snapshot，至少包含工作流拓扑、任务标识、任务选项、结构输入、工具箱版本、MATLAB release 和赝势配置。科学执行逻辑必须由本地和远程共用，不能复制两套 SCF/NSCF 实现。

结果只能在本地 UI 线程导入 Project Results。

## 8. 分阶段工作和验收

### P0 文档、范围和安全基线

工作：冻结本文的范围、数据模型、状态机、安全规则和完成定义。

验收：

- [x] 本文进入仓库；
- [x] 每个后续阶段都有可追踪的工作和证据位置；
- [x] 仓库内没有真实测试凭据。

### P1 配置、选择和持久化

工作：实现配置值对象、验证、原子 JSON store、选择 store、迁移和损坏恢复。

验收：

- [x] 可新增、编辑、复制、禁用、删除多个配置；
- [x] MATLAB 重启后配置顺序和选择保持；
- [x] 同名配置通过 UUID 正确区分；
- [x] 删除当前配置回退到“不使用”；
- [x] 损坏文件安全回退并产生可读警告；
- [x] JSON 中无秘密字段或秘密值。

### P2 Slurm Profile、认证和验证

工作：实现 Existing Profile 和 Managed Slurm Profile；映射四种认证方式；分阶段预检和最小 smoke job。

验收：

- [x] 四种认证模式映射正确；
- [x] 2FA 只请求密码和一次性验证码，不请求或保存 seed；
- [x] 认证取消不保存半成品配置；
- [x] 检查远端目录、Slurm CLI、MATLAB root、release 和许可证；
- [x] 测试失败不覆盖用户 Profile；
- [x] 不改变 MATLAB 默认 Profile；
- [x] 最小 smoke job 返回 hostname、release、Slurm ID 和 worker 信息。

### P2B 跨 release 集群端提交桥接

工作：保留受支持的同 release `parcluster/batch` 直接路径；增加 SSH/2FA 传输层，在集群登录节点使用与 Parallel Server 匹配的 MATLAB release 建立、查询、取消和回收 Slurm 作业。本地 R2026b 与远端桥接器之间只传版本中性的 snapshot、状态 JSON、ZIP bundle 和 MAT 结果，不传跨 release MATLAB Job 对象。

验收：

- [x] Direct 模式在已知 release 不匹配时继续拒绝并给出可操作错误；
- [x] Bridge 模式允许桌面端与集群端 MATLAB release 不同；
- [x] Bridge 支持 Password、IdentityFile、Agent 和 Multifactor 认证；Password 与 Multifactor 的 SSH 密码可在主对话框内加密保存；
- [x] 连接 smoke test 比较远端桥接 MATLAB 与 Parallel Server worker release；
- [ ] 提交后本地 MATLAB 可退出，重开后凭持久记录恢复；
- [x] 状态、取消、diary、结果取回和连接测试清理均通过桥接器完成，并有无网络 mock 覆盖；
- [x] snapshot 使用 `-v7` 数据格式，MAT 结果使用 `-v7.3`，Bridge runner 独立于桌面 release 检查；
- [x] 小型 LiH 在目标集群现有 MATLAB release 上通过真实 Slurm 验收。

### P3 作业生命周期

工作：实现 `batch` 提交、状态映射、轮询、取消、diary、fetch、恢复和原子作业 store。

验收：

- [x] 认证完成后提交不阻塞 UI 等待计算结束；
- [x] MATLAB 关闭重开后可恢复；
- [x] 结果不会重复导入；
- [x] 查询和取消幂等；
- [x] 网络断开为 `Unknown` 或 `ConnectionRequired`；
- [x] worker 异常、Slurm 状态和 diary 可诊断；
- [x] 清理操作需要明确确认。

### P4 工作流 snapshot 和 headless runner

工作：提取任务 options 和执行计划；建立共用的纯计算入口；实现结果 envelope 和代码部署 bundle。

验收：

- [x] snapshot 可序列化往返且无 UI handle；
- [x] 同一 snapshot 可在无 UI MATLAB 进程执行；
- [x] worker 不创建 UI 对象；
- [x] 本地和远程共用科学执行入口；
- [x] 不支持远程的节点在提交前完整列出；
- [x] 结果可导入 Project Results；
- [x] 工具箱版本不匹配时拒绝或明确警告；
- [x] bundle 排除 `.git`、`dev`、日志、缓存和凭据。
- [x] 自动部署使用单一 ZIP 附件和 worker bootstrap，不让临时 bundle 污染客户端 MATLAB 路径或类缓存。

### P5 对话框

工作：实现集群管理、配置编辑和远程作业对话框。

验收：

- [x] 字段和错误均有中英文本地化；
- [x] Bridge/Mirror 多因子配置在主对话框内提供掩码的 SSH 密码和可选 TOTP seed 输入，不使用额外弹窗；
- [x] 连接测试提交后由定时器轮询，期间对话框保持响应、允许取消，并在结束后恢复控件；
- [x] MFA 取消后按钮状态恢复；
- [x] 删除被作业引用的配置会提示；
- [x] 作业表区分失败和重新认证；
- [x] 关闭对话框不取消远程作业。

### P6 Home Tab

工作：实现动态互斥对号菜单、配置管理入口、测试入口、作业入口和本地/远程运行路由。

验收：

- [x] 始终恰好一项带对号；
- [x] 新建、重命名、禁用、删除后即时同步；
- [x] 重启后保持选择；
- [x] 缺少 Parallel Computing Toolbox 时错误清晰；
- [x] 远程选择走异步提交，本地选择保持原行为；
- [x] 不改变 MATLAB 默认 Profile。

### P7 自动化和回归

工作：单元、mock 集成、UI 合约、部署兼容性和本地工作流回归。

验收：

- [x] 非网络逻辑无需真实集群即可覆盖；
- [x] 覆盖成功、失败、取消、断网、MFA 取消、认证过期、重启恢复、下载重试和重复 fetch；
- [x] 自动测试无真实凭据；
- [x] 失败测试不留下 Profile、作业或 bundle；
- [x] R2026b 相关测试全部通过；
- [x] 本地 workflow 和 Results 回归通过。

### P8 真实集群验收

工作：在测试 Slurm 集群上人工完成 2FA，运行预检、smoke job、小型 LiH、恢复和取消测试。

验收：

- [x] Slurm CLI、R2024a 远端 MATLAB、Parallel Server 许可和共享目录预检通过；
- [x] smoke job 返回 hostname、release、Slurm ID 和计算结果；
- [x] LiH 原胞、`ecut=4`、2--4 workers 的 SCF 完成；
- [x] 远端结果有限、收敛状态正确，与本地关键能量相对误差不超过 `1e-6`；
- [ ] 结果导入 Project Results；
- [ ] 关闭 MATLAB 后作业继续，重开后回收；
- [x] 取消真实映射到 Slurm cancelled；
- [x] MFA 取消和重新认证行为正确；
- [x] 配置、日志、历史和测试报告均无秘密。

P8 当前状态：R2026b 客户端不能通过第三方调度器直接向 R2024a Parallel Server 提交受支持的 `batch` 作业。Bridge 已在真实集群验证两条路径：其一在远端登录节点以 R2024a MATLAB 提交 Slurm，由 R2024a worker 完成；其二由计算节点的普通 R2024a MATLAB 以 Mirror 模式直接后台执行，不使用 Parallel Server 或 Slurm。两者都完成并回收真实两原子 KSSOLV LiH 结果。剩余真实验收集中在客户端重启恢复、运行中取消和 Project Results 导入。

## 9. 测试命令与证据

所有验收命令和输出记录到：

```text
dev/remote-computing/acceptance/reports/<run-id>/
```

自动化测试至少执行：

```matlab
results = runtests("+kssolv/+services/+remote/+test", ...
    IncludeSubfolders=true);
results = [results; runtests("+kssolv/+ui/+test", ...
    IncludeSubfolders=true)];
assertSuccess(results);
```

真实集群测试必须使用小体系和有限资源，不运行 Li500H500 或数百 workers。

## 10. 完成定义

只有在 P0--P8 的全部条目都有当前工作树、测试输出或真实集群报告作为证据时，功能才算完成。意图、代码存在、窄测试通过或未发现明显错误都不能替代逐项证据。

## 11. 四模式生产化重构（当前实施规范）

### 11.1 模式定义

四种模式是互斥的顶层 `ExecutionMode`，不得再用 Bridge 的二级执行模式表达 Mirror：

| 模式 | 作业所有者 | release 契约 | 执行拓扑 | 登录后脚本 |
|---|---|---|---|---|
| `Standard` | 本地 MATLAB | 本地、Parallel Server、worker 相同 | 本地 `parcluster/batch` → Slurm | 支持 |
| `Bridge` | 远端 MATLAB | 本地可不同；远端 MATLAB、Profile、worker 相同 | SSH → 远端 MATLAB → Slurm/Parallel Server | 支持 |
| `Mirror` | 远端普通 MATLAB | 本地与远端可不同 | SSH → 远端单节点 MATLAB 后台进程 | 支持 |
| `Cloud` | 云端 Cluster Profile | 服从云端 Profile；直连 Profile 通常要求客户端匹配 | Cloud Center、AWS 或私有云 Profile | 不要求 |

`Mirror` 是产品模式名称，表示把 release-neutral snapshot 和运行时代码镜像到单个远端 MATLAB 执行；它不使用 `RemoteClusterAccess` 的 JobStorage mirror。

Cloud Provider 第一版定义为：

```text
MathWorksCloudCenter | AWS | PrivateCloud
```

Cloud Center 当前是在用户关联的 AWS 账户中创建和管理资源，不把它描述为 MathWorks 自有算力。KSSOLV 第一版消费官方发现或导入的 Cluster Profile，不抓取 Cloud Center 网页，也不在未授权时创建计费资源。

### 11.2 v1 到 v2 迁移

配置和作业格式升级到 v2。迁移必须原子写入新文件，保留 v1 原文件，成功读取并校验 v2 后才切换：

| v1 | v2 |
|---|---|
| `DirectParallelServer` | `Standard` |
| `RemoteMatlabBridge + ParallelServer` | `Bridge` |
| `RemoteMatlabBridge + StandaloneMatlab` | `Mirror` |
| 无 | `Cloud` |

迁移作业时按 `ConfigurationId` 联接迁移时的 v1 配置，把模式写入作业记录。配置缺失或无法判定的历史作业不得丢弃；保留 legacy 标记和可诊断的只读恢复状态。

v2 配置公共字段：

```text
Version, Id, DisplayName, Enabled, ExecutionMode
CodeDeploymentMode, RemoteKssolvRoot
```

前三种模式共享连接路由字段：

```text
ConnectionMode, Host, Username, AuthenticationMode, IdentityFile
RemoteJobStorageLocation
PostLoginCommandTemplate
PostLoginPromptRules[]: Pattern, CredentialLabel
```

模式专属字段：

```text
Standard: ProfileSource, ExistingProfileName, ManagedProfileName,
          ClusterMatlabRoot, Slurm/worker/license fields
Bridge:   ClusterMatlabRoot, RemoteBridgeProfileName, PoolSize
Mirror:   ClusterMatlabRoot, standalone process fields
Cloud:    CloudProvider, ExistingProfileName, CloudResourceName,
          CloudRegion
```

作业记录必须固定保存 `ExecutionMode`、`CloudProvider`、后端协议版本、远端 workspace、MATLAB/Profile/调度器标识和 release；配置之后被编辑不能改变已提交作业的归属。

### 11.3 统一 Backend 契约

`RemoteJobManager` 只依赖 Backend 契约：

```text
testConnection
submitWorkflow
refresh
cancel
fetch
cleanup
```

生产类拆分为 `StandardBackend`、`BridgeBackend`、`MirrorBackend`、`CloudBackend` 和 `RemoteBackendFactory`。状态、错误、恢复和结果 envelope 对四种模式一致。模式特有逻辑不得继续散落为 `RemoteJobManager` 中的字符串条件分支。

验收：

- [x] 四个 Backend 通过相同生命周期合约测试；
- [x] 状态统一映射且查询、取消、fetch、cleanup 幂等；
- [x] MATLAB 重启后四种作业都能按持久记录恢复（Standard/Cloud 使用本地真实 Profile，Bridge/Mirror 使用协议测试，Mirror 另有独立 MATLAB 实测）；
- [x] 配置修改或删除不导致现有作业被错误后端接管。

### 11.4 登录后脚本与交互凭据

Standard、Bridge、Mirror 使用两个边界明确的字段：`PostLoginScript` 是每条目标
命令前执行的 shell 初始化脚本，以 `set -e` 运行；任一命令失败即停止，资源探测
和实际目标命令均不再执行。`PostLoginCommandTemplate` 是含一个 `{command}` 的
目标路由模板。典型配置：

```bash
# PostLoginScript
source /etc/profile
module load matlab/R2024a

# PostLoginCommandTemplate
exec ssh node7 -- {command}
```

需要提权时应使用具有明确边界的命令，例如：

```bash
sudo -S sh -lc 'exec ssh node7 -- {command}'
```

第一层 SSH 的 2FA 由认证层完成；Bridge/Mirror 可用本机私钥解密配置中的密码密文，并在用户选择保留 TOTP seed 时按 RFC 6238 即时生成 OTP。之后按有序 `PostLoginPromptRules` 匹配脚本提示。每条规则最多响应一次。明文秘密不写入 JSON、MAT、日志、命令行或历史。

验收：

- [x] 三种模式均支持独立初始化脚本和 `ssh node7 -- {command}` 路由；
- [x] 连接失败或初始化脚本非零退出时不会执行资源探测；
- [x] MFA 后的单次 sudo/root 提示成功；
- [x] 多条已声明提示按顺序处理，未知或重复提示安全失败；
- [x] 提交、status、cancel 均实际在目标路由执行；
- [x] 登录节点与目标节点看不到同一 workspace 时预检拒绝；
- [x] 仓库、配置、作业记录、日志、进程参数和产物无明文秘密。

### 11.5 各模式实施与验收

#### P9 Standard

工作：保留本地 `parallel.cluster.Slurm`/`batch` 所有权；严格检查同 release；为登录后脚本实现覆盖 `sbatch`、`squeue/sacct` 和 `scancel` 的 scheduler 路由；兼容 Existing Profile 和 KSSOLV Managed Slurm Profile。

验收：

- [ ] R2026b 客户端向 R2026b Parallel Server/Slurm 完成真实 LiH；
- [ ] Slurm ID 非空且 worker hostname 不是登录节点；
- [x] R2026b → R2024a 在提交前拒绝；
- [ ] 经登录后脚本的提交、查询、取消和重启恢复通过。

#### P10 Bridge

工作：`RemoteMatlabBridge` 只保留 Parallel Server 语义；本地传 release-neutral snapshot/代码包；远端 MATLAB 持有 `parcluster/batch/fetchOutputs`；持久关联本地作业、远端 MATLAB Job 和 Slurm Job。

验收：

- [x] R2026b → MFA → R2024a MATLAB → R2024a Parallel Server/Slurm 完成真实 LiH；
- [x] 返回 R2024a、worker hostname 和非空 Slurm ID；
- [x] worker/Bridge release 不一致时连接测试拒绝；
- [ ] 客户端重启后恢复、fetch、Project Results 导入通过；
- [ ] 取消最终映射为 Slurm `CANCELLED`。

#### P11 Mirror

工作：把现有 Standalone 分支独立为 `MirrorBackend`；普通远端 MATLAB 单节点后台执行；原子持久化 PID、启动身份、workspace、日志和状态；安全检测孤儿进程和 PID 复用。

验收：

- [x] R2026b → MFA/脚本 → node7 普通 R2024a MATLAB 完成真实 LiH；
- [x] MATLAB Job ID、Scheduler ID、Slurm ID 为空；
- [x] SSH/提交进程退出不终止 Mirror 计算；
- [x] 立即取消、运行中取消、重启恢复和结果导入通过（本地独立 MATLAB 与 UI 端到端验收）；
- [x] PID 校验不会误杀其他 MATLAB。

#### P12 Cloud

工作：实现 `MathWorksCloudCenter`、`AWS`、`PrivateCloud` Provider 适配层；发现、刷新、验证并消费 Cluster Profile；提供打开 Cloud Center/Provider 管理入口；统一接入作业生命周期。直接 AWS 支持官方 Reference Architecture、AWS Batch 或 EKS 所生成 Profile；私有云消费管理员提供的兼容 Profile。

验收：

- [x] 三种 Provider 的 Profile 发现、选择、缺失、失效和许可诊断通过（自动化/模拟 Profile）；
- [x] Cloud 作业支持提交、取消、重启恢复、fetch 和结果导入（自动化/模拟 Profile）；
- [ ] 至少一个实际云 Provider 完成真实 LiH 后才标记 Cloud MVP 真实通过；
- [ ] 完整发布报告分别列出 Cloud Center、直接 AWS、私有云的真实验收状态；
- [ ] 启动计费资源前取得明确授权，结束后核查实例、集群、卷和费用。

### 11.6 UI 重构

配置对话框顶部先选四模式；Standard、Bridge、Mirror、Cloud 使用独立条件面板；前三种共享 SSH 与“登录后脚本”折叠区；脚本使用多行编辑器，提示规则使用可增删表格。Home Tab 显示带模式前缀的配置：

```text
[标准] 集群 A
[桥接] 集群 B
[镜像] node7
[云端] AWS Cluster
```

验收：

- [x] 每种模式只显示和保存相关字段；
- [x] 切换模式不保留不可见但生效的脏字段；
- [x] v1 配置打开后显示正确 v2 模式；
- [x] 快速选择始终互斥，复制、重命名、禁用、删除即时同步；
- [x] 中英文标签、说明和错误完整。

### 11.7 真实小型 LiH 科学门禁

统一工作负载使用两原子 LiH 原胞、PBE、`ecut=4`、`1×1×1` k-point、Gaussian smear、最多 30 次 SCF；不运行 Li500H500，不申请数百 workers。

每个真实验收必须证明：

- [ ] `info.converge == true`；
- [ ] 最终 `SCFerr < 1e-6`；
- [ ] 总能量有限；
- [ ] 与相同 release 本地参考值的相对误差不超过 `1e-6`；
- [ ] 当前参考值约 `-5.9666002671 Ha`，Build/SCF 均为 `Finished`；
- [ ] 保存 mode、release、hostname、Slurm ID、耗时、diary 和代码包哈希；
- [ ] 结果通过 Project Results 导入，而不只是读取 MAT 文件；
- [ ] 测试后远端 workspace、作业、后台进程和本地 bundle 清理完成。

当前已知环境可执行 Bridge 和 Mirror 的真实 LiH；Standard 需要同 release 的 R2026b Parallel Server/Slurm；Cloud 需要 Cloud Profile、许可和计费授权。缺少外部环境时只能标记代码/模拟验收，不能标记真实通过。

### 11.8 执行顺序与最终门禁

按以下顺序实施，不用后续窄测试替代前置契约：

1. [x] 文档冻结和 v2 schema；
2. [x] v1 配置/作业原子迁移；
3. [x] Backend 契约与 `RemoteJobManager` 重构；
4. [x] 登录后脚本和提示规则；
5. [x] Standard、Bridge、Mirror 生产路径；
6. [x] Cloud Provider/Profile 路径；
7. [x] UI 和本地化；
8. [x] 自动化矩阵；
9. [ ] 四模式真实 LiH 与恢复/取消/导入；
10. [x] 文档报告、零警告 `buildtool validate`、隔离安装包和清理审计。

### 11.9 2026-08-14 实施与真实验收状态

已完成的代码门禁：

- [x] v2 配置和作业 schema、v1 原子迁移并保留 v1 源文件；
- [x] v2 持久对象只暴露四种顶层 `ExecutionMode`，旧字段只在 v1 读取边界出现；
- [x] `RemoteJobManager` 通过 Backend Factory 分派四种后端，作业冻结非敏感配置快照；
- [x] 多行登录后模板和有序多提示规则；未知、乱序、重复提示安全失败；
- [x] Bridge/Mirror MFA 支持本机 RSA-OAEP 加密密码、可选 TOTP seed 和 RFC 6238 自动 OTP；明文秘密不写配置、作业或报告；
- [x] Standard 已知 release 在构造/提交前检查，smoke worker release 再次检查；
- [x] Cloud Center、AWS、Private Cloud Profile 发现/验证适配器及缺失 Profile 诊断；
- [x] 四模式配置 UI、Profile 发现、Home 快速选择模式前缀、作业模式列和中英文本地化；
- [x] Bridge 与 Mirror 真实 LiH 科学门禁、结果 fetch、远端 workspace 和进程清理。
- [x] Project Results 的按钮端到端导入、作业标记、bundle 清理与崩溃重试去重通过；
- [x] Mirror 独立 MATLAB 完成 LiH 后，删除配置并新建 Manager 仍可凭冻结快照回收；
- [x] 远程服务测试 76/76、全量 UI 测试 105/105；`buildtool validate` 6/6，静态检查 0 error、0 warning（2034 个 MATLAB 文件）。

真实报告：

```text
dev/remote-computing/acceptance/reports/2026-08-14-live/bridge.json
dev/remote-computing/acceptance/reports/2026-08-14-live/mirror.json
```

Bridge 实测为本地 R2026b → MFA → 远端 R2024a → R2024a Parallel Server/Slurm，
worker `node5`、Slurm Job 21367。Mirror 实测为本地 R2026b → MFA → 登录后
`ssh node7 -- {command}` → node7 普通 R2024a MATLAB。两者两原子 LiH 均在 6 次
SCF 内收敛，能量 `-5.966600267096851 Ha`，`SCFerr≈9.0907e-9`。

本次真实测试发现并修复 OpenSSH socket 长度、R2024a PID API、字符型 Slurm ID、
跨版本 result load 路径以及失败 workspace 清理问题。后续强化回归还修复了成功提交
错误触发 workspace 清理、跨进程事件 listener 序列化、Results 重试重复导入问题。
验收后确认 Slurm 作业为 0、
Bridge/Mirror workspace 为 0、node7 Mirror 进程为 0，临时预安装副本已删除。

不能标记真实通过的外部门禁：

- Standard 真实验收需要 R2026b Parallel Server/Slurm；现有集群只有 R2024a，
  不以 Bridge 成功替代 Standard 同版本门禁；
- Cloud 真实验收需要用户提供一个实际 Cloud Profile、相关许可和计费资源授权；
  当前只完成 `Processes` Profile 的 Provider/生命周期模拟测试；
- Bridge/Mirror 的真实集群 MATLAB 重启恢复和真实运行中取消仍需单独验收；
  Project Results 已完成完整 UI 自动化，Mirror 也完成独立 MATLAB 进程恢复实测，
  但尚未在目标集群的人工会话中联合复验。

当前环境只读复核：本地 MATLAB 只有 `Processes` 和 `Threads`，没有实际 Slurm
或 Cloud Profile；目标集群的非交互 SSH 认证不可用。继续真实验收需要轮换后的
MFA 凭据、R2026b Parallel Server/Slurm 环境，以及至少一个获得计费授权的 Cloud
Profile。未创建任何云资源，也未产生云端费用。

只有所有适用复选框都有当前源码、测试输出或真实环境报告作为证据时，才允许把四模式目标标记完成。
