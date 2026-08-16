# 远程计算验收报告：2026-08-14 / MATLAB R2026b

## 环境

- 本地：macOS，MATLAB R2026b Prerelease Update 3；
- 代码基线：Git `58d6f0c` 加当前工作树；
- 远端：CentOS 7.9、Slurm，集群标识和账户信息从报告中省略；
- 远端 MATLAB：R2024a、R2020a。

本报告不包含密码、OTP、TOTP seed、私钥、可复用会话或真实集群配置文件。

## 自动化证据

### 远程核心与 UI 合约

执行：

```matlab
r = [runtests('+kssolv/+services/+remote/+test', ...
    IncludeSubfolders=true), ...
    runtests('+kssolv/+ui/+test/RemoteComputingUITest.m')];
assertSuccess(r);
```

Bridge 实现后的最新结果见下文最终复跑记录。新增覆盖包括跨 release 配置、SSH 桥接协议、远端控制记录、状态/取消/fetch 分发、远端 profile、bridge/worker release 比较和 Bridge smoke session；所有测试均使用无秘密 fake transport。

早期基线复跑：远程核心 `44/44` 通过，0 failed、0 incomplete；完整 UI `102/102` 通过，0 failed、0 incomplete。Bridge 专项 `6/6` 包括失败提交时本地 ZIP 清理和 bridge/worker release 不匹配拒绝。

Standalone Bridge、目标命令和 2FA 后命令链增强完成后，远程服务与远程 UI 专项最终复跑 `62/62` 通过，0 failed、0 incomplete；其中包括普通 MATLAB 后台任务的完成/回收和经校验 PID 的立即取消。`buildtool validate` 的 6 个任务全部通过，静态分析 2016 个文件为 0 error、0 warning。

### Bridge 本地进程集成

以本地 `Processes` profile 模拟远端匹配 release 的提交端和 worker，Bridge entrypoint 实际完成 ZIP 解压、`batch` 提交、控制记录恢复、状态查询和结果取回。小型 LiH 结果为：

- 6 步 SCF 收敛；
- 最终 SCF 误差约 `9.09e-9`；
- 最终总能量 `-5.9666002670969 Ha`；
- 取回状态为 `Retrieved`。

测试发现桥接进程在 `fetchOutputs` 前若未加入 KSSOLV core 路径，MATLAB 会无法完整加载 `Crystal`、`BlochHam` 等结果对象。实现已在每次 bridge action 前恢复 toolbox/core 路径，并设置 `AutoAddClientPath=false`，避免把登录会话的无关路径传给 worker。独立 smoke probe 返回 `Result=3`，作业只含一个明确的 AdditionalPath。

### 小型 LiH 无界面工作流

`WorkflowRemoteTest/smallLiHWorkflowRunsScientificallyHeadless` 使用 2 原子 LiH 原胞、`ecut=4`、PBE、Gaussian、Gamma 点运行 `BuildMoleculeTask + SCFTask`。

- 6 步收敛；
- 最终 SCF 误差约 `9.0907e-9`；
- 最终总能量 `-5.9666002670969 Ha`；
- runner 未创建 UI；
- 数值基准测试通过。

另有 `RemoteJobManagerTest/remoteLiHBundleSurvivesManagerRestart` 通过实际 `batch` 执行同一 LiH snapshot，覆盖 ZIP bundle、worker 端解压、持久作业记录、新 `RemoteJobManager` 实例恢复、结果回收、导入标记和本地 bundle 清理。最终能量相对基准误差不超过 `1e-6`。该测试还验证提交前后客户端 `Atom` 类解析路径不变，并可紧接着再次执行本地 LiH。

测试曾发现把源码目录直接作为 `AttachedFiles` 会让 MATLAB 客户端依赖扫描加载临时 bundle 中的类；清理 bundle 后可造成后续 `Atom` 不可见。实现已改为附加单一 ZIP，由 `RemoteBundleBootstrap` 仅在 worker 临时目录解压执行，顺序回归通过且不再产生整目录依赖扫描警告。

### UI 全套回归

执行：

```matlab
results = runtests('+kssolv/+ui/+test', IncludeSubfolders=true);
assertSuccess(results);
```

结果：`102/102` 通过，0 failed，0 incomplete。新增集成测试还验证了远程结果 envelope 只在本地 UI 侧导入 Project Results，并刷新 Project Browser。首次运行发现 R2026b macOS HiDPI 下既有建模对话框高度为 240.5，而旧测试上限为 230；阈值校准为仍属紧凑布局的 245 后复跑全绿。

### 静态与资源检查

```text
buildtool check
git diff --check
xmllint --noout <四份本地化 XML>
```

Bridge 实现后复跑结果：通过；共分析 `2009` 个 MATLAB 文件，0 error、0 warning。`git diff --check` 与四份本地化 XML 解析同样通过。

### 打包与隔离安装

执行 `buildtool validate`，依次完成静态检查、P-code、资源暂存、`.mltbx` 打包和解压验证，6 个任务全部通过。Bridge 实现后的 `.mltbx` 明确包含以下 P-code：

- `RemoteAccessFactory.p`；
- `RemoteMatlabBridge.p`；
- `RemoteMatlabBridgeEntrypoint.p`；
- `RemoteBridgeConnectionTestSession.p`。

另从完全不含工作树源码的 `.buildtool/staging` 加载打包 P-code，实际构建并解压 worker ZIP，确认 ZIP 含 `RemoteMatlabBridgeEntrypoint.p` 且不含 `+test`。此前同版本包的独立 `MATLAB_PREFDIR` / Add-On 根目录安装验收还验证了：

- 安装元数据为 `KSSOLV Toolbox 0.4.0`；
- `RemoteConnectionTestSession`、`RemoteBundleBootstrap` 和 `HomeTab` 均从隔离安装目录中的 P-code 解析，而非当前仓库；
- 中文远程计算用户指南包含在安装副本中；
- 自动卸载后隔离环境的已安装工具箱数量恢复为 0；
- 用户日常环境中既有的 KSSOLV 0.3.1 未被覆盖。

Bridge 实现后的安装包大小约 `48 MiB`，SHA-256 为 `d2dfa325d48e5fd0d21b750484cdd8deac7fe4c434d71600855f95c5624aba1d`。

## 真实 Slurm/2FA 证据

- SSH Password + 2FA 登录成功；
- `sbatch`、`squeue`、`scancel`、`sinfo` 可用；
- `MATLAB` 分区在线；
- R2024a MATLAB smoke job 在计算节点完成，返回 release `2024a`、计算结果 `3`，DCT 许可测试为真；
- 独立取消作业由 Slurm 记录为 `CANCELLED`；
- 两个远端测试输出文件均已删除；
- R2026b MATLAB 的标准 Slurm Profile validation 到达 SSH MFA 提示，人工取消后无残留 KSSOLV Profile；本地测试验证该错误映射为 `ConnectionRequired`。
- 增强后的 Bridge 通过 MFA 登录后使用目标模板 `ssh node7 -- {command}`，实际在 node7 启动 R2024a MATLAB；该 Bridge 向 `mySLURMCluster` 提交最小作业，Slurm `21356` 在 node5 以 `COMPLETED / 0:0` 结束并回收结果 `3`，worker 报告 release `2024a`；
- Bridge 改用无 JobStorage 镜像的缓存 SSH/SFTP 传输，并以 `KSSOLV_BRIDGE_STATUS` 作为跳板命令完成边界，避免 MathWorks ServiceHost 继承 SSH 文件描述符造成结果已落盘但客户端仍等待；
- 本机真实 PTY 测试验证了登录后密码提示、一次性 RSA 加密交换、错误重试上限和临时文件清理。真实集群的 node7 跳转为免密，因此没有请求或记录额外提权密码。
- `StandaloneMatlab` Bridge 随后使用相同的 MFA 和 `ssh node7 -- {command}`，在 node7 脱离 SSH 启动普通 R2024a MATLAB，未创建 MATLAB Job、Slurm job 或 Scheduler ID；状态完成 `Queued → Finished → Retrieved`，回收 `Result=3`、`Hostname=node7`、release `2024a` 且 `SlurmJobId` 为空。

## 版本兼容性结论修订

对于 Slurm 等第三方调度器，MathWorks 支持的直接提交拓扑要求提交客户端与 MATLAB Parallel Server release 匹配。实现已在 Direct 模式的 Profile 构建前检测 `ClusterMatlabRoot` 中的 release，并抛出 `KSSOLV:Remote:ClusterMatlabReleaseMismatch`。

这不等价于“目标集群只有安装 R2026b 才能计算”。`RemoteMatlabBridge` 现已实现：在集群登录节点运行与 Parallel Server 匹配的 MATLAB，由它向同 release 的 Slurm/Parallel Server 提交；本地 R2026b 仅通过 SSH/2FA 传输 snapshot、状态、ZIP 和 MAT 结果。Bridge 会核对配置路径指示的 release 与实际桥接进程，并由连接 smoke job 核对 worker release。

当前仍未通过的 P8 项是：

- 通过 KSSOLV R2026b/Parallel Server 执行远端 LiH；
- 从该真实作业取回并导入 Project Results；
- 关闭 R2026b 客户端后等待该作业、重开再回收。

Bridge 的跨 release 最小计算、MFA、node7 目标命令、Parallel Server 分支和不依赖 Parallel Server 的 Standalone 分支均已通过真实集群验证。真实 P8 的剩余解除条件是轮换凭据后，继续完整 LiH、重启恢复和结果导入验收。

## 最终本地环境清理检查

- KSSOLV 管理的 MATLAB Cluster Profile 数量：`0`；
- Processes Profile 遗留测试作业数量：`0`；
- 测试临时目录中未发现遗留的 remote bundle；
- `git diff --check` 通过，四份中英文本地化 XML 解析通过；
- 隔离安装测试的偏好目录已移入系统废纸篓；日常 Add-On 注册表未被修改。
