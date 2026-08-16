# KSSOLV Toolbox 远程计算用户指南

KSSOLV 将完整工作流作为可恢复的远程作业提交，并在完成后把结果导回项目。
Home Tab 的“远程计算”支持四种互斥模式：

| 模式 | 适用环境 | 作业实际所有者 | release 要求 |
|---|---|---|---|
| 标准（Standard） | 同版本 MATLAB Parallel Server + Slurm | 本地 MATLAB | 本地、Parallel Server、worker 必须相同 |
| Bridge | 远端 MATLAB + Parallel Server + Slurm | 远端 MATLAB | 本地可不同；远端 MATLAB 与 worker 必须相同 |
| Mirror | 远端普通 MATLAB 单节点 | 远端后台 MATLAB | 本地与远端可以不同 |
| Cloud | Cloud Center、AWS 或私有云生成/提供的 Cluster Profile | 本地 MATLAB/云 Profile | 服从所选云 Profile 的要求 |

Standard、Bridge、Mirror 都支持登录后执行脚本，例如加载 module、提权或跳转
到 `node7`。KSSOLV 不在远端安装常驻服务。

回收结果时，KSSOLV 使用远程作业 ID 标识 Project Results 数据集。即使应用在
数据集写入后、作业标记完成前退出，再次回收也不会重复创建同一结果。

## 使用前准备

- 本机需要 Parallel Computing Toolbox。
- Standard 需要同 release 的 MATLAB Parallel Server 和 Slurm；配置中的
  MATLAB 根目录应包含明确 release，例如 `/opt/MATLAB/R2026b`，KSSOLV 会在
  提交前拒绝已知的不匹配。
- Bridge 需要远端普通 MATLAB、远端已有的 MATLAB Cluster Profile，以及与该
  MATLAB 同 release 的 Parallel Server worker。
- Mirror 只需要目标节点安装普通 MATLAB 和 KSSOLV 所需产品许可，不需要
  Parallel Server、Slurm 或远端 Profile。
- Cloud 第一版消费已经通过 Cloud Center、AWS 参考架构或管理员创建/导入的
  Cluster Profile。MathWorks Cloud Center 的资源位于用户关联的 AWS 账户；
  KSSOLV 不会在未授权时创建计费资源。
- 使用跳转脚本时，登录节点、目标节点以及相关 worker 必须共同看到“远程作业
  存储目录”。

## 新建配置

打开“远程计算 → 配置远程集群…”，新增配置后先选择执行模式。对话框只显示
当前模式相关的字段；切换模式时，无关字段及其占用的行会自动隐藏。

右侧配置区分为两个页签：“连接”包含 SSH、认证凭据、提示规则、登录后脚本和
连接测试；提示规则位于登录后脚本上方。“计算”包含计算命令模板、Profile、
云资源、MATLAB 根目录、远程存储、Worker/Pool、Slurm 参数、KSSOLV 部署和许可，
底部另有“探测资源/取消探测”按钮。资源探测成功后会自动切换到“计算”页签，
便于检查自动回填结果。
可留空或可由连接探测回填的输入项统一在标签后显示“（可选）”；自动探测的具体
行为仍由相应帮助 Tooltip 说明。

左侧配置表和右侧配置区共用同一底边。窗口最下方的固定高度操作栏依次放置
“新增/复制/删除”、单行配置提示以及“保存/关闭”；较长的配置诊断不会改变按钮
高度，完整内容可从提示文本的悬停说明查看。

共同字段包括名称、最大 worker、Pool worker、KSSOLV 部署方式。前三种模式还
包括：

- SSH 主机和用户名；
- `Agent`、`IdentityFile`、`Password` 或 `Multifactor` 认证；
- 远端 MATLAB 根目录和远程作业存储目录；
- 登录后执行脚本、命令模板及按顺序排列的交互提示规则。

模式专属字段：

- Standard：Managed Slurm 或现有 MATLAB Profile、Slurm 分区/账户/QoS、
  walltime、许可和共享文件系统设置；
- Bridge：远端 MATLAB 中已有的 Parallel Server Profile 名称；
- Mirror：不需要 Profile；Worker/Pool 数量可由连接探测自动填写，也可手动调整；
- Cloud：Provider、现有云 Profile、资源名称和区域；这些云服务字段不会在
  Standard、Bridge 或 Mirror 模式下显示。可用“发现配置…”从
  `parallel.listProfiles` 结果中选择并验证 Profile。

Standard、Bridge、Mirror 在 SSH 连接下选择 `Password` 或 `Multifactor` 时，
都会直接显示掩码的“SSH 密码”输入框。选择 `Multifactor` 并勾选
“保留 2FA TOTP 密钥”后，还会显示掩码的 Base32 TOTP 密钥输入框。
“保存”或“测试连接”时，KSSOLV 使用本机安装专属的 3072 位 RSA-OAEP
密钥加密这些输入；只有点击“保存”才把密文写入配置并清空输入框。已有密文时
留空即可继续使用原凭据，无需重复输入；填写新值则会更新对应密文。登录时 MATLAB 按
[RFC 6238](https://www.rfc-editor.org/rfc/rfc6238.html) 和默认 30 秒时间步即时
生成六位验证码。未勾选时只自动填写密码，OTP 仍在每次新会话建立时安全询问。

RSA 私钥单独保存在 `prefdir/KSSOLV/remote/credentials` 并限制为当前本机用户
读写；配置、日志和作业记录不包含明文密码、TOTP 密钥或生成的 OTP。复制配置
到另一台电脑时还必须安全迁移这份本机私钥，否则原密文无法解密。该方案支持
无人值守运行，但不能防御已经取得本机用户文件访问权的攻击者。Standard 的
资源探测使用该加密凭据；正式 Parallel Server 作业仍接入 MATLAB 官方
RemoteClusterAccess 生命周期。

## 登录后脚本、命令模板与多提示规则

“登录后执行脚本”以及“连接”“计算”页签中的配置项，标签右侧都有与其他
KSSOLV 对话框一致的帮助图标。悬停可查看用途、填写规则和示例，点击则会在帮助
提示框中显示相同内容。

“登录后执行脚本”用于初始化目标 shell，例如：

```bash
source /etc/profile
module load matlab/R2024a
export TMPDIR=/scratch/$USER/tmp
```

脚本在每条目标命令前执行，必须以退出码 0 结束；脚本失败时不会继续资源探测或
运行远程命令。

计算命令模板位于“计算”页签，必须恰好包含一次 `{command}`，它代表 KSSOLV 已
按 shell 规则引用的最终命令。模板作用于“探测资源”和正式计算，“测试连接”
不会使用它。需要跳转节点时可填写：

```bash
exec ssh node7 -- {command}
```

需要提权时建议使用边界明确的命令：

```bash
sudo -S sh -lc 'exec ssh node7 -- {command}'
```

例如先以 `user` 登录 master，再免密切换到 root、免密 SSH 到 `gpu6`，最后切换
为 `yliu7949`，应保持“登录后执行脚本”为空，并填写：

```bash
sudo -n -- ssh -o BatchMode=yes -o ConnectTimeout=10 gpu6 -- su - yliu7949 -c {command}
```

点击“探测资源”后，自动回填的 MATLAB 根目录和 Worker/Pool 来自 `gpu6` 的
`yliu7949` 环境，而不是 master。成功结果中的主机名也应为 `gpu6`。

SSH 登录本身的密码和 2FA 先由认证层完成。模板随后出现的 `sudo`、`su` 或第二
跳密码提示，通过“登录后提示规则”按表格顺序处理。每条规则包含提示正则和凭据
说明，每条最多回答一次；未知、乱序或重复提示会安全失败。登录节点需安装
`expect` 和 `openssl`。

提示凭据只缓存在当前 MATLAB 会话内存中。每次执行使用一次性 RSA 公钥加密后
传到登录节点，临时私钥、密文和 Expect 脚本在命令结束后删除。凭据不会出现在
JSON、MAT、日志、命令行或作业记录中。

Standard 的登录后模板覆盖 `sbatch`、`squeue`/`sacct` 和 `scancel`，因此提交、
查询、取消必须经过同一路由。若登录节点的文件暂存路径在跳转目标不可见，连接
预检会拒绝配置。

## 测试、选择与提交

“测试连接”和“取消测试”位于“连接”页签内。测试严格按“SSH 连接 → 按顺序处理
登录后提示规则 → 执行登录后脚本”运行；它不会使用计算命令模板，也不会查找或
回填计算参数。使用现有 MATLAB Profile/Cloud 时会提交最小 worker 可达性作业，
但不会收集 MATLAB 根目录或 Worker/Pool 参数。连接状态及详细错误显示在按钮
正下方。

“探测资源”和“取消探测”位于“计算”页签底部。Bridge、Mirror 以及 Managed
Slurm + SSH 的 Standard 配置不要求先填写 MATLAB 根目录或远程作业目录；资源
探测会通过计算命令模板到达最终节点，启动 MATLAB 并回填根目录、release、最大
Worker、建议 Pool 和远程作业目录候选。回填结果只修改当前表单，检查无误后再
点击“保存”。两条操作分别维护按钮、后台会话、取消状态和诊断信息，互不混用。

不同模式的测试行为如下：

- Managed Slurm + SSH 的 Standard、Bridge 和 Mirror 的连接测试只验证 SSH、
  提示规则和登录后脚本；资源探测才通过计算命令模板启动远端 MATLAB。Bridge
  优先读取所填远端 Profile 的 Worker/Pool 上限，Mirror/Standard 则读取目标
  MATLAB 的本地计算资源；
- 使用现有 MATLAB Profile 的 Standard 和 Cloud 通过最小 smoke job 验证 Profile；
  只有点击“探测资源”时，才把 worker 返回的 MATLAB/Worker 信息回填到表单。

Home Tab 的“使用远程计算”菜单显示 `[标准]`、`[Bridge]`、`[Mirror]`、`[Cloud]`
前缀。选择“不使用”恢复本地执行；选择按稳定 UUID 保存，重启后仍有效。

“远程执行命令行窗口的命令”是独立于上述四种工作流执行模式的 Command Window
开关，不会作为第五种模式出现在集群配置中。首次提交命令时，KSSOLV 通过所选
配置的 SSH、认证、登录后路由、远端 MATLAB 根目录和远程作业目录启动一个长驻
MATLAB；它不连接或提交到 MATLAB Parallel Server。后续命令进入同一个 MATLAB
进程的 base workspace，因此变量和进程内状态会保留。切换远程目标、取消勾选、
选择“不使用”或关闭 Command Window 时，会话停止且临时会话目录被清理。

该开关要求所选配置提供 SSH 主机、用户名、远端 MATLAB 根目录和远程作业目录；
只有 MATLAB Profile 而没有这些直连字段的 Standard/Cloud 配置不能用于远程
Command Window。输入和输出均以 `[remote]` 标记，便于与本地命令区分。

正式提交时，KSSOLV 生成不含 UI 对象的工作流快照和运行时代码包：

- Standard/Cloud 由本地 `batch` 持有 MATLAB Job；
- Bridge 把快照交给远端 MATLAB，再由它调用 `parcluster/batch`；
- Mirror 通过 `nohup` 启动单节点 MATLAB，SSH 断开不会终止计算。

Bridge/Mirror 选择 `AttachCurrentToolbox` 时并不会为每个作业重复上传 KSSOLV。
代码包以实际源文件内容的 SHA-256 为键，首次上传后缓存在远程作业存储目录的
`.kssolv-cache/toolbox/<内容哈希>` 下；相同代码的后续作业只上传请求和工作流
快照并复用该缓存。任一打包文件内容变化都会得到新哈希并建立新缓存。清理单次
workspace 或本地传输包不会删除远端缓存。选择 `ClusterInstalled` 时则始终直接
使用管理员部署的“集群 KSSOLV 根目录”。Standard/Cloud 的
`AttachCurrentToolbox` 仍由 MATLAB `batch` 的附件传输机制管理；若需要明确地
完全避免附件传输，应使用 `ClusterInstalled`。

作业记录会冻结提交时的完整非敏感配置快照，因此之后修改或删除配置不会让已有
作业切换后端。Bridge/Mirror 保存唯一 workspace；Mirror 取消前会同时核对 PID
和包含该 workspace 的进程命令，避免 PID 复用时误杀其他 MATLAB。
作业记录本身不保存密码或 TOTP 密文；刷新、取消和取回时，KSSOLV 按稳定配置 ID
从已保存集群配置中补回加密凭据，再自动建立 SSH 连接，不会重复询问已经保存的
SSH 密码。主机、执行模式、路径和计算参数仍使用提交时冻结的快照。
运行时不再提供临时补输 SSH 密码的弹窗；若 Password 模式没有可解密的已保存
密码，操作会直接提示返回集群配置页保存凭据。未选择“保留 2FA TOTP 密钥”时，
一次性验证码仍需在新会话建立时输入。

## 作业、结果与恢复

打开“远程计算 → 远程作业与结果…”：

- “刷新”查询远端状态；
- “取消作业”取消排队、运行中或 Mirror 后台作业；
- “查看 Diary”查看非敏感远端输出；
- “取回并导入”把结果 envelope 加入当前 Project Results；
- “清理本地包”删除已不需要的传输包。

配置保存在 `prefdir/KSSOLV/remote/configurations-v2.json`，作业保存在
`jobs-v2.json`。从 v1 首次读取时会原子写出 v2 并保留 v1 文件作为回滚副本。
作业可在 MATLAB 重启后按冻结快照恢复查询、取消和取回。

## Cloud 说明

Cloud Center、直接 AWS 和私有云适配器负责发现、验证并消费已有 Profile；它们
不抓取云控制台网页。Cloud Center/AWS 管理入口只用于用户自行配置资源。启动
或扩大计费资源前应确认预算和授权，验收后检查实例、集群、卷和费用。

若 Profile 缺失、无法构造、许可失效或不能提交 smoke job，KSSOLV 会在正式提交
前给出诊断。Provider 标签是配置元数据；实际调度、网络和许可仍由 Profile 及云
管理员负责。

## 故障处理

- `ConnectionRequired`：网络中断或 2FA 会话失效；重新刷新并完成认证。
- `Unknown`：暂时无法读取状态，不表示远端作业已经失败。
- Standard release 不匹配：使用同 release Parallel Server，或改用 Bridge。
- Bridge worker release 不匹配：修正远端 Profile，使 worker 与远端 MATLAB
  相同。
- Mirror 进程丢失：检查 `standalone.log`、普通 MATLAB 许可和目标目录权限。
- 登录后命令等待：检查模板最终执行 `{command}`、提示规则顺序及
  `expect`/`openssl`。
- Slurm 提交失败：检查分区、账户、QoS、walltime 和附加 `sbatch` 参数。
- Cloud Profile 不可用：先在 Cluster Profile Manager 或相应云管理入口修复。

附加 `sbatch` 参数只接受简单参数文本；shell 控制符和命令替换会被拒绝。

## 安全说明

配置只保存连接元数据和私钥路径，不复制私钥内容。不要把密码、OTP 或 TOTP seed
写入名称、路径、命令模板、Slurm 参数或环境变量。真实验收报告只保存 mode、
release、hostname、Slurm ID、科学指标、耗时及 diary/代码包哈希。

任何曾出现在聊天、工单或日志中的长期密码或 TOTP seed 都应立即轮换。
