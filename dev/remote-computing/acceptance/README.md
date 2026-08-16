# 远程计算验收证据

此目录保存 KSSOLV Toolbox 远程计算功能的可复现验收记录。

自动化测试报告放在 `reports/<run-id>/`。报告应记录 MATLAB release、Git commit、测试命令、通过/失败数量和非敏感诊断。真实集群报告不得包含主机凭据、密码、OTP、TOTP seed、私钥内容或可复用会话信息。

真实集群验收只使用 LiH 原胞和 2--4 workers，不运行 Li500H500 或数百 workers。

`run_live_lih.m` 是 Bridge/Mirror 的生产路径验收入口。目标地址、用户名、
MATLAB 根目录、远端存储和 Profile 通过 `KSSOLV_ACCEPTANCE_*` 环境变量提供；
密码、OTP、TOTP seed 不得放入环境变量。脚本会通过 MATLAB 的交互认证接收
密码和 2FA，并在成功后清理远端 workspace 与本地 bundle。

报告只含 mode、release、hostname、Slurm ID、科学指标、耗时以及 diary/代码包
SHA-256，不含认证信息。建议把 `KSSOLV_ACCEPTANCE_REPORT` 指向
`reports/<run-id>/bridge.json` 或 `mirror.json`。
