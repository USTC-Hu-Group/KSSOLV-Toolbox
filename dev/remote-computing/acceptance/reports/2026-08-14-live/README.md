# 2026-08-14 真实 LiH 验收

环境：本地 MATLAB R2026b Prerelease Update 3；远端 MATLAB/Parallel Server
R2024a；Slurm。工作负载为两原子 LiH、PBE、`ecut=4`、`1×1×1` k-point，未运行
Li500H500。

## 结果

- Bridge：通过 MFA 建立 OpenSSH ControlMaster，由远端 R2024a MATLAB 的
  `mySLURMCluster` Profile 提交；worker 为 `node5`，MATLAB Job 2，Slurm Job
  21367。Build/SCF 均为 `Finished`。
- Mirror：通过 MFA 后使用登录后模板 `ssh node7 -- {command}`，在 `node7`
  的普通 R2024a MATLAB 后台进程执行；MATLAB Job、Scheduler Job、Slurm Job
  均为空。Build/SCF 均为 `Finished`。
- 两者最终能量均为 `-5.966600267096851 Ha`，SCF error 均约
  `9.0907e-9`，相对参考误差约 `8.19e-15`。

## 开发中发现并修复

1. MathWorks 内置 keyboard-interactive 回调在 `-nodesktop` 强制使用不可见的
   Swing 对话框；Bridge/Mirror MFA 改用系统 OpenSSH ControlMaster。
2. macOS 长临时目录超过 Unix socket 长度限制；控制 socket 改用短 `/tmp`
   路径。
3. R2024a 没有 `matlabProcessID`；Mirror 增加 `feature('getpid')` 兼容回退。
4. 字符型 Slurm ID `21367` 曾被归一化为单字符数组；已修复为标量。
5. 提交期间异常曾遗留 workspace；transport 内部现注册失败清理器。

验收结束后确认：Slurm 队列中该用户作业数为 0，Bridge workspace 数为 0，
Mirror 活动 workspace 数为 0，`node7` 上匹配 Mirror workspace 的 MATLAB 进程数
为 0；用于 Mirror 的临时预安装 KSSOLV 副本已删除。

## 自动化与构建证据

- 远程服务测试：76/76 passed，0 failed，0 incomplete；包含四 Backend、v1→v2
  迁移、MFA 提示规则、作业恢复/取消/fetch、Cloud 模拟 Profile 和本地真实 LiH。
- 全量 UI 测试：105/105 passed，0 failed，0 incomplete；远程计算 UI 专项 8/8。
- `buildtool validate`：6/6 tasks passed；2034 个 MATLAB 文件静态检查为
  0 error、0 warning，P-code、staging、`.mltbx` 打包和解包验证通过。
- Bridge 提交失败清理已有回归测试，确认本地 bundle 与已创建远端 workspace
  均被清理。
- Mirror 额外通过本地独立 MATLAB 实测：提交端返回后继续运行 LiH，删除配置并
  新建 Manager 后仍能回收；立即取消和明确进入 Running 后取消均通过，PID 身份
  不匹配时不会终止无关 MATLAB。
- Project Results 通过作业对话框实际执行 fetch、导入、持久标记和 bundle 清理；
  远程作业 ID 提供幂等身份，崩溃重试不会重复创建 Dataset。
- Standard、Bridge、Mirror 的普通命令与登录后跳转路径均有合约测试；提交、
  status、cancel 走目标路由，登录节点与目标节点不共享 workspace 时预检拒绝。

## 外部环境核查

本地只有 `Processes`、`Threads` 两个 Profile，没有实际 Standard Slurm 或 Cloud
Profile；目标集群没有可复用的非交互 SSH 通道。本次核查未再次使用对话中暴露的
凭据，未创建云资源，也未产生费用。Standard/Cloud 真实 LiH，以及目标集群上的
重启恢复和运行中取消，仍需新的外部环境或轮换后的 MFA 凭据。

报告不包含主机密码、OTP、TOTP seed、私钥或复用 socket 信息。
