# KSSOLV Toolbox 远程计算用户指南

KSSOLV Toolbox 可以把工作流提交到远端 MATLAB 环境，并将结果导回当前项目。远程计算
要求用户已经能够访问集群或远端 MATLAB；KSSOLV Toolbox 不负责创建账户、安装调度器，
也不会在没有用户操作时启动云资源。

[English](remote-computing-user-guide.md)

## 选择执行模式

| 模式 | 适用情况 | 主要要求 |
| --- | --- | --- |
| **Standard** | 本地 MATLAB 通过 MATLAB Parallel Server 和 Slurm 提交 | 本地 MATLAB、Parallel Server 和 worker 使用相同 release |
| **Bridge** | 由远端 MATLAB 向其 Cluster Profile 提交 | 远端 MATLAB 与其 worker 使用相同 release |
| **Mirror** | 单个远端节点可以运行普通 MATLAB | 远端具备 MATLAB 和所需许可；不要求 Parallel Server |
| **Cloud** | 已有可用的云端 MATLAB Cluster Profile | 所选 Profile 已经配置并可正常使用 |

所有模式都要求本地 MATLAB 安装 Parallel Computing Toolbox。独立部署还必须包含当前
工作流和远程模式所需的产品。

优先选择环境能够支持的最简单模式。版本已经一致时使用 Standard；必须从远端 MATLAB
发起集群提交时使用 Bridge；只需要单个远端 MATLAB 进程时使用 Mirror。

## 准备环境

新建配置前，准备以下信息：

- 使用直连 SSH 时的主机和用户名；
- 认证方式以及私钥路径（如适用）；
- 远端 MATLAB 根目录和可写的作业存储目录；
- Bridge、Standard Profile 或 Cloud 模式使用的 Cluster Profile 名称；
- Managed Slurm 使用的分区、账户、QoS 和时间限制；
- 远端环境采用的 KSSOLV 部署方式。

Standard 模式下，本地 MATLAB、MATLAB Parallel Server 和所有 worker 必须使用相同
release。Bridge 模式只要求远端 MATLAB 与其 worker 一致。登录节点、目标节点和 worker
必须都能访问用作共享远程作业存储的目录。

## 新建配置

1. 打开 **远程计算 → 配置远程集群…**。
2. 选择 **新增**，填写便于识别的名称，并选择执行模式。
3. 在 **连接** 页填写 SSH、认证设置、登录脚本以及站点要求的提示规则。
4. 在 **计算** 页填写当前模式需要的 MATLAB、Profile、调度器、存储、worker 和
   KSSOLV 部署设置。
5. 测试连接；可用时探测资源；检查发现的值，然后保存。

标记为可选的字段，可以在当前模式能够自动发现时留空。资源探测只更新表单，不会自动
保存配置。

### 认证

直连 SSH 配置支持 SSH Agent、Identity File、密码和多因素认证。站点允许时，优先使用
SSH Agent 或受保护的私钥文件。

保存的密码和选择保留的 TOTP 密钥会针对当前本机安装加密，不会写入作业记录或日志。
但这种存储不能防御已经控制同一操作系统账户的人。不要共享配置或凭据目录；不再需要
无人值守访问时，应删除已保存的凭据。

如果没有保留 TOTP 密钥，应用会在新建认证会话时要求输入一次性验证码。

## 登录后路由命令

登录脚本用于初始化 shell，例如：

```bash
source /etc/profile
module load matlab/R2026b
export TMPDIR=/scratch/$USER/tmp
```

脚本必须成功结束，远程操作才会继续。

只有命令必须转发到其他节点或 shell 时，才使用计算命令模板。模板必须恰好包含一次
`{command}`，例如：

```bash
exec ssh compute01 -- {command}
```

提示规则可以回答预期的 `sudo`、`su` 或第二跳提示。只添加站点确实需要的提示，并按
出现顺序排列；先使用无破坏性的命令测试路由。遇到未知或重复提示时，操作会失败，不会
猜测应使用的凭据。

如果管理员可以提供普通 SSH 路径或 Cluster Profile，应避免复杂路由。不要把密码、OTP
或 TOTP 密钥写入登录脚本、命令模板、路径、调度器参数或环境变量。

## 测试连接和探测资源

**测试连接** 检查所选连接和登录路由。对于已有 MATLAB Profile 或 Cloud 配置，也可能
提交一个最小 worker 可达性作业。该操作不会发现或覆盖计算设置。

**探测资源** 会到达最终计算环境，并可以发现 MATLAB release 和根目录、worker 上限、
建议 Pool 大小及存储位置。保存前应检查所有值；在共享系统中，站点策略允许的上限可能
低于探测到的硬件上限。

连接测试和资源探测可以分别取消。连接测试成功并不表示完整科学工作流一定具备所需产品、
许可、内存或调度资源。

## 选择 KSSOLV 部署方式

远端没有兼容的 KSSOLV Toolbox 时，使用 **Attach Current Toolbox**。某个工具箱版本的
第一个作业可能需要较长时间传输代码。

由管理员维护远端 KSSOLV Toolbox 时，使用 **Cluster Installed**。提交前确认配置路径和
版本与工作流兼容。

## 提交和管理作业

1. 保存项目，并在本地完成工作流设置。
2. 从 **使用远程计算** 中选择已经保存的配置。
3. 提交工作流，并记录 KSSOLV Toolbox 显示的作业。
4. 打开 **远程作业与结果…**，刷新状态、查看 Diary、取消作业或取回已完成结果。

每个作业会保留识别其原始执行环境所需的非敏感配置。之后编辑配置，不会让已有作业
自动切换到另一个后端。

取回的结果使用远程作业 ID 标识，因此重复取回通常不会在项目中创建重复结果。把计算
视为成功前，应检查 Diary 和结果元数据。

## 远程 Command Window

**远程执行 Command Window 命令** 会通过所选的直连 SSH 配置启动一个长驻 MATLAB
会话。在切换目标、关闭远程命令或关闭 Command Window 之前，命令共享同一个 base
workspace。

该功能独立于工作流提交，并要求直连 SSH、远端 MATLAB 和可写的远程作业目录。只有
Profile、没有直连设置的配置不能使用。远程输入和输出以 `[remote]` 标记。

不要把重要结果只留在远程 base workspace 中。需要可复现性时，应把数据保存到合适的
远端路径，或改用工作流。

## Cloud Profile

Cloud 模式使用已经由相应 MathWorks 或站点工具创建或导入的 MATLAB Cluster Profile。
Provider 和区域字段用于描述 Profile；实际网络、许可、配额和费用仍由云账户及集群配置
控制。

启动或扩大计费资源前，应确认授权和预算。测试结束后，在云服务控制台检查仍在运行的
实例、集群、存储卷和其他计费资源。

## 故障排查

| 问题 | 检查内容 |
| --- | --- |
| 连接要求重新认证 | 网络、SSH Agent、私钥权限、密码或当前一次性验证码 |
| 作业状态为 Unknown | 确认网络和调度器后重试；`Unknown` 本身不表示作业失败 |
| Standard release 不匹配 | 使用一致的本地 MATLAB、Parallel Server 和 worker，或改用 Bridge |
| Bridge worker 不匹配 | 让远端 MATLAB 与远端 Profile 的 worker 使用相同 release |
| Mirror 进程消失 | 远端 MATLAB 许可、作业目录权限和 `standalone.log` |
| 登录路由等待输入 | 登录脚本、命令模板、提示顺序和站点要求的工具 |
| Slurm 提交失败 | 分区、账户、QoS、walltime 和允许的调度器参数 |
| Cloud Profile 失败 | 使用云或集群管理工具修复并验证 Profile，再重新提交 |

作业状态不明确时，在清理本地传输文件前保留 Diary 和作业标识。不要把长期密码或 TOTP
密钥粘贴到 Issue、聊天或日志中；已经暴露的凭据应立即轮换。
