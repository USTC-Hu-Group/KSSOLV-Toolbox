# KSSOLV Toolbox Online Management

入口为所配置主域名的 `/online/admin`。使用独立管理员凭据，界面沿用 MathWorks 浅色对话框、标签页、表格与菜单；支持中英文和浏览器语言偏好。

## 部署结构

普通 Portal Pod 负责账号、用户工作空间生命周期和资源档位，不获得宿主机 root 或集群管理员权限。
管理服务以 systemd 服务独立运行在虚拟化宿主机，绑定 `127.0.0.1:8095`，通过已有 HTTPS edge 代理。
`/online/admin` 只允许主域名访问，工作空间子域名返回 404。Kubernetes API 凭据和 libvirt 控制只留在宿主机。
即使 Kubernetes VM 重启，管理入口仍可访问。宿主机本身重启则管理入口会暂时离线。

安装器应在完成新 Portal 镜像导入后、由宿主机 root 执行：

```sh
python3 scripts/k8s/admin/install_admin.py \
  --origin https://cloud.example.org \
  --kubeconfig /root/k8s-lab/admin.conf \
  --portal-image docker.io/library/kssolv-portal:versioned-tag
```

在包含 `server/` 与 `scripts/` 的完整仓库快照中运行安装器。
安装器从 `server/admin/`、`server/portal/` 和运维入口显式组装 `/opt/kssolv-admin/app/`，
部署后仍使用 `/opt/kssolv-admin/app/admin/` 下既有服务与 CLI 路径，systemd 的启动位置保持兼容。
不要仅复制 `scripts/k8s/`，该目录不再包含生产服务实现。现有环境默认使用
`kssolv-edge.service`、`/etc/kssolv/nginx-edge.conf`、`k8s-cp1` 和两个 worker；其他环境应通过参数指定节点，
并适配 edge unit 名称。安装器保留现有证书和上游，验证 nginx 配置后通过 systemd Reload，避免 PrivateTmp PID 文件不可见。
首次部署使用 Portal 的注册账号认证，宿主配置不保存用户密码或密码哈希。
Portal bridge 令牌位于 `/opt/kssolv-secrets/admin-bridge-token` 和专用 Kubernetes Secret，永不发送给浏览器。
管理会话、任务、审计和监控位于 `/var/lib/kssolv-admin/`；`/etc/kssolv/admin.json` 只保存管理服务配置。

## 管理员设置与登录

管理员角色绑定到 Portal 的工作空间账号，由账号数据库中的 `users.role` 保存；
不是对 SSH 用户、Kubernetes ServiceAccount 或外部服务账号的授权。
`user` 为普通用户，`admin` 为普通管理员，`superadmin` 为唯一超级管理员。
管理页统一使用该 Portal 账号原有的密码，不创建第二套管理员密码。

### 当前东风云绑定记录

以下为 2026-10-22 本次部署完成时的绑定记录，后续授权变更以管理页、数据库和审计记录为准：

| 项目 | 绑定信息 |
| --- | --- |
| 管理入口 | <https://kssolv.glea.moe/online/admin> |
| 超级管理员用户名 | `yliu7949` |
| 超级管理员角色标识 | `superadmin` |
| 登录密码 | 该用户原有的工作空间密码，绑定时未修改 |
| 其他现有用户 | 保持普通用户，需超级管理员显式授权后才可访问管理页 |
| 绑定方法 | 宿主机 root 执行 `set_superadmin.py yliu7949` |

### 首位注册用户与超级管理员

全新部署中，第一个**成功注册**的工作空间账号自动成为唯一的超级管理员（`superadmin`）。
注册必须先通过邀请码、密码确认及备忘问题验证；并发注册通过数据库事务保证只有一位超级管理员。
初始化标记持久保存，后续注册用户均为普通用户（`user`），不会因删除账号、重启或重装服务而再次触发首用户提权。
已有数据库升级时不会自动挑选某个旧账号提权，需要宿主机管理员指定超级管理员。
首次绑定标记为 `portal_settings.superadmin_bootstrapped`；它与 `users.role` 一同保存在 Portal 的账号 PVC 中。
备份或迁移集群时需要保留账号数据库。删除该数据库会丢失账号和角色，不能用于找回管理员权限。

当前东风云集群的超级管理员为 `yliu7949`。访问 <https://kssolv.glea.moe/online/admin>，
使用 `yliu7949` **已有的工作空间账号密码**登录。其他环境使用其主域名下的 `/online/admin`。
登录管理页不会启动工作空间，也不会延长工作空间的空闲回收计时。

### 授予和撤销普通管理员

超级管理员登录管理页后，在“用户管理”中找到目标用户，通过其“操作”菜单选择：

- **授予管理员权限**：输入该用户的用户名确认后，其角色变为普通管理员（`admin`），可使用自己的账号密码登录管理页，管理账户、工作空间和集群，并通过自定义脚本以宿主机 root 身份执行 Shell。应将此角色授予可信的宿主机管理员。
- **撤销管理员权限**：输入用户名确认后，角色恢复为普通用户，已有管理会话立即失效，工作空间账号、登录和数据保留。

普通管理员可以使用 Pod、监控、资源、账户、节点、集群和自定义脚本功能。只有超级管理员可以通过**账户管理界面和对应 API**授予或撤销管理员权限；该限制不构成对宿主机 root 的安全隔离。普通管理员可执行任意 root Shell，因此具备修改宿主机、集群和账号库的实际能力。
账户管理界面及对应 API 均实施角色校验，不能在其中降级或冻结超级管理员。超级管理员转移使用宿主机 root 命令；具备自定义脚本执行权限的管理员也拥有同等宿主机执行能力。
被冻结的账号不能登录管理页，须先恢复账号再授权。授权变更写入审计记录。
每次管理请求重新核验 Portal 会话和角色；排队任务执行前再次核验。已经开始的管理任务可能继续完成。
管理登录与工作空间登录使用独立会话；空闲释放工作空间不结束管理会话。
密码重置、账号冻结会使管理会话失效。管理员密码找回与普通用户相同，使用入口的“忘记密码”和备忘问题。

### 已有集群绑定、恢复或转移超级管理员

在虚拟化宿主机上以 root 执行：

```sh
sudo python3 /opt/kssolv-admin/app/admin/set_superadmin.py yliu7949
```

目标必须是已注册且未冻结的工作空间账号。命令更新 Portal 数据库中的角色、初始化标记并撤销该账号已有管理会话，
不修改密码、不启动或重启工作空间，不修改数据卷。首次绑定时不会影响其他普通用户。
已有其他超级管理员时默认拒绝覆盖；确需转移时显式指定：

```sh
sudo python3 /opt/kssolv-admin/app/admin/set_superadmin.py new-owner --replace-existing
```

该操作将旧超级管理员降为普通管理员，并撤销新旧账号的管理会话，随后绑定新的超级管理员；转移在同一数据库事务中完成。
命令仅允许宿主机 root 执行，使用 `/etc/kssolv/admin.json` 指定的 kubeconfig，并记录 `superadmin-bind` 审计。
普通工作空间不提供该宿主机权限。旧版网页脚本登记仅登记路径；新版“自定义脚本”允许所有管理员以 root 执行 Shell，因此也能调用此命令。不要将普通管理员视为仅能查看页面或受限于账号管理按钮的角色。

### 核查当前绑定

超级管理员可在管理页“用户管理”的“角色”列核查绑定；管理页顶部身份区域显示当前登录账号及角色。
也可以在东风云宿主机使用以下只读查询，输出用户名、角色和冻结标记（`0` 为正常、`1` 为冻结）：

```sh
sudo kubectl --kubeconfig /root/k8s-lab/admin.conf -n kssolv-system exec deploy/portal -- \
  python3 -c "import sqlite3; db=sqlite3.connect('file:/data/portal/accounts.sqlite3?mode=ro', uri=True); print(db.execute('SELECT username,role,frozen FROM users ORDER BY username').fetchall()); db.close()"
```

其他集群应相应修改 kubeconfig 路径和 Portal namespace。查询不读取密码哈希或会话令牌。
角色变更审计中，网页授权／撤权分别记为 `role-admin`／`role-user`，宿主机绑定或转移记为 `superadmin-bind`。

### 旧版独立凭据迁移

旧版独立的 `admin` 用户、`admin.json` 中的 `account` 及 `admin-login.json` 已不参与认证；旧管理会话迁移后失效。
不再通过编辑私密凭据文件或重置独立管理员密码来授权。历史凭据文件可作为升级备份保留，不要将其提交到仓库。

服务使用 Secure / HttpOnly / SameSite=Strict cookie，4 小时会话，登录限流、同源检查及 CSRF token。
操作先生成 2 分钟有效、绑定会话的单次确认票据。工作空间操作显示用户名、内部目标及具体资源，输入用户名确认；节点、工作负载和集群操作按页面提示输入完整目标名称。提交仍绑定已审阅的后端目标，任务串行执行并留审计。
服务重启后未完成任务标为 interrupted，不自动重复高影响操作。

重新生成宿主 edge 配置时应保留管理路由：

```sh
python3 scripts/k8s/tls_edge.py --render-only --no-http-redirect \
  --domain cloud.example.org --tenant-domain cloud.example.org \
  --cert /etc/kssolv/tls/fullchain.pem --key /etc/kssolv/tls/private.key \
  --upstream worker:30088 --admin-upstream 127.0.0.1:8095
```

## 工作空间配置与操作

默认小／中／大分别为 2 CPU / 8 GiB、4 CPU / 24 GiB、8 CPU / 52 GiB。
用户在登录或重新创建工作空间前选择档位；登录已运行的实例沿用原资源，扩缩容需在管理页单独操作。
管理页“实例配置 → 修改档位配置”可分别设置三档的 CPU 核数与内存 GiB（正整数），一次保存三档。
设置持久保存到 Portal 账号数据库，服务或 Pod 重启后保留，并优先于部署文件中的初始值；修改记入审计。
用户入口会在重新聚焦及定期刷新时更新选项；已有实例和存储保持不变。并发修改会拒绝覆盖旧配置。
旧实例保持原配置，显示为“自定义”。初始档位通过 Portal `workspace_profiles` 配置，
或 `deploy.py --profile-config profiles.json` 设置，JSON 格式如下：

```json
{"small":{"cpu":"2","memory":"8Gi"},"medium":{"cpu":"4","memory":"24Gi"},"large":{"cpu":"8","memory":"52Gi"}}
```

工作空间原地扩缩容使用 Kubernetes `pods/resize`，同步配额、ReplicaSet 与 Deployment 模板及用户资源记录，避免未来重建恢复旧规格。
缩内存前要求新鲜采样并保留余量；运行期间内存增长仍可能造成中断。API 拒绝或延迟时显示具体状态，不自动回退为重启。
界面同时显示实际与目标请求值，详情提供 limits 与容器实际状态。
单个工作空间的“调整配置”和“启动”对话框可直接输入 CPU 核数与内存 GiB，也可选择档位快速填入。
修改输入后自动标记为“自定义”；该实例的资源独立保存，不修改全局档位，未来重建继续使用该配置。
旧入口 `/admin` 与 `/admin/` 会跳转到 `/online/admin`；管理会话 cookie 仅发送至新管理路径，迁移后需要重新登录。
关闭、重启、冻结、销毁实例会影响未保存内容；“销毁实例”删除 compute Deployment，保留账号和 PVC。
冻结撤销所有账号会话并停止实例，恢复账号不自动启动实例。
邀请码更新会同步 Portal 持久设置、Kubernetes Secret 和宿主私密邀请码文件；失败时尝试恢复旧值并记录状态。

## 系统 Pod 与节点

可查看全部命名空间的 Pod，并管理 Deployment、StatefulSet、DaemonSet、Job 等受支持工作负载。
Pod 操作先解析并验证控制器 UID；控制器操作影响其全部副本，依赖该工作负载的服务可能暂时不可用，确认页会说明影响。
系统控制器调资源使用其更新策略滚动重建；KSSOLV 工作空间使用前述原地调整。
自建 operator 控制的 Pod 交由其 operator 管理；静态控制平面 Pod 通过节点／集群重启处理。
停止工作负载后仍可在“系统工作负载”列表重新启动；独立 Pod 没有重建控制器。
销毁不提供 PVC 删除。StatefulSet 先设置 Retain；命名空间存在其他控制器归属的 PVC 时拒绝可能导致自动回收的操作，需在宿主机检查保留策略。

worker CPU／内存修改采用优雅关机、保存并修改 libvirt 持久 XML、再启动，不改虚拟磁盘。
须先关闭该节点用户实例；内存为宿主保留至少 4 GiB，CPU 不超过宿主可分配总核数。
有 NUMA 配置的 VM 需手动修改。变更后等待新的 boot ID 和 Ready 状态，避免将旧 Node Ready 误判为已完成重启。
集群重启先停止用户实例，优雅关闭 worker 和控制平面，再启动控制平面和 worker；不强制销毁 VM。
用户在节点恢复后按需重开实例，已保存数据保留。

## 监控和核时

每 15 秒通过 Kubernetes API 的 kubelet stats summary 采样，使用现有 TLS 和宿主 kubeconfig，
无需外网、metrics-server、额外二进制或 JVM。静态 Pod 的 kubelet UID 与 mirror Pod UID 不同，按命名空间／名称匹配。
CPU 显示使用核数与百分比，内存显示 working set；不可用／过期样本显示缺失，不填零。
曲线按分钟聚合，保留 7 天原始采样；Pod／节点监控仅提供这段保留期内的时间范围。缺失值及采样时间缺口断线显示，采样明细可查看最近 200 条。用户核时按 UTC 小时聚合保留 366 天：
分配核时积分已记录的 CPU 请求，实际 CPU 核时使用累计 CPU 时间差；跳过超过 60 秒的采样缺口、重复样本和计数器重置。
统计从启用时开始，不能回补以前未采集的数据；页面同时显示覆盖时长。

## 自定义脚本

管理页 `/online/admin` → **自定义脚本** 支持在线编写、上传 UTF-8 Shell 文件、保存版本、一次性执行、定期执行和查看运行结果。所有普通管理员及超级管理员均可使用。

脚本由独立的 `kssolv-script-runner.service` **以 root 身份在虚拟化宿主机运行**，不是在用户 Pod 中运行。脚本拥有宿主机和 Kubernetes 管理权限。页面显示实际宿主机、执行身份、完整源码、版本及 SHA-256；执行或启用计划前必须输入脚本标识确认。网页服务仍保留 `ProtectSystem=strict`，不通过放宽网页服务的文件系统保护来执行 Shell。

1. **新建／上传**：上传只填入编辑器，不会执行。标识以小写字母开头，可用小写字母、数字和连字符（2–40 个字符）；源码最多 128 KiB，保存时执行 Bash 语法检查。
2. **保存版本**：每次保存产生不可变版本。并发编辑按预期版本检查，避免覆盖其他管理员修改。立即执行和计划均记录所确认的版本、源码哈希及操作者。
3. **立即执行**：确认后加入持久队列，执行服务取出任务前重新核对操作者仍为未冻结的管理员。每个脚本同一时刻只允许一个排队／运行任务，全局最多并行 2 个，队列最多 20 个。
4. **定期执行**：支持每隔 1–10080 分钟、每天指定时间和五字段 Cron（分、时、日、月、周；支持数字、星号、范围、列表及步长）。时区默认 `Asia/Shanghai`，可在 `/etc/kssolv/admin.json` 配置 `script_timezone` 后重启网页和执行服务。计划固定使用确认时的版本；编辑后必须重新保存并确认计划才更新执行版本。支持暂停；不会补跑停机期间错过的次数，同一脚本忙碌时记录为跳过。创建者被冻结或撤销管理员权限后，待执行任务会被阻止，计划会自动停用。Portal 暂不可用时保留队列并等待恢复，不跳过权限核对。
5. **运行记录／结果**：记录创建、开始、结束、触发方式、状态、操作者、版本、退出码和耗时；可按脚本筛选、加载更早记录、查看执行版本及下载日志。标准输出与错误输出合并，每次最多保存 4 MiB，超出时明确标注；页面滚动显示最后 128 KiB，完整已保存日志可下载。
6. **停止与超时**：可取消排队任务或停止运行中的任务。每次运行超时为 1–86400 秒，默认 300 秒。使用独立进程组，结束时清理仍在该进程组内的子进程；不要用脚本启动需要长期驻留或脱离进程组的守护进程，应使用 systemd 管理。执行器停止／重启时结束其进程，未完成记录标为中断，不会自动重复执行。

脚本使用 `/bin/bash --noprofile --norc`，不加载登录 Shell 环境。工作目录为 `/var/lib/kssolv-admin/script-runs/<运行标识>/`，包含本次 `script.sh` 和 `output.log`；标准输入关闭。环境包含系统 `PATH`、`HOME=/root`、`LANG=C.UTF-8`、计划时区和管理配置中的 `KUBECONFIG`。需要特定环境或依赖时应在脚本中明确设置。

数据保存在 `/var/lib/kssolv-admin/management.sqlite3` 和 `script-runs/`，权限限 root；日志和脚本可能包含敏感信息，应纳入宿主机备份和磁盘管理。目前不自动删除历史版本或日志。停止网页服务不会暂停计划：停用所有自定义脚本执行需停止 `kssolv-script-runner.service`，或在管理页分别暂停计划。

```sh
systemctl status kssolv-admin.service kssolv-script-runner.service
journalctl -u kssolv-script-runner.service
# 暂停执行服务（队列、计划和记录仍保留）
systemctl stop kssolv-script-runner.service
# 重新启用
systemctl start kssolv-script-runner.service
```

安装器同时部署网页服务和执行服务。已有仅登记路径的 `.py` / `.sh` 条目保留在“原有手动脚本登记”中，仍可通过原 CLI 手动运行；它们不会自动转换成网页执行任务。默认允许目录 `/opt/kssolv-admin/scripts/`，拒绝目录穿越及符号链接。原 CLI 保持可用：

```sh
sudo python3 /opt/kssolv-admin/app/admin/host_ops.py \
  --config /etc/kssolv/admin.json run-script my-maintenance
```

CLI 使用已验证文件描述符交给 Python 或 Bash，保留原审计。`script_dir` 仅影响此兼容的手动登记功能，不改变新版版本库的位置。

## 验证与回滚

使用 `python3 -m unittest discover -s scripts/k8s/tests -v` 和 `node --test scripts/k8s/tests/*.cjs`。
Linux 镜像验收包含真实 nginx；扩缩容及系统工作负载验收使用独立临时命名空间，不对生产节点执行重启。
2026-10-22 东风云发布记录为 `/opt/kssolv-deploy/20261022-cloud-admin-01/`，包含 Portal／edge／账号库备份、镜像校验、隔离验收和发布后检查。
关闭管理入口可停止 `kssolv-admin.service`（如同时停用脚本执行，还需停止 `kssolv-script-runner.service`），并移除 edge 的管理 location，再验证配置和 reload；用户 Runtime 不依赖管理服务。
回滚 Portal 镜像前保留新数据库备份；新增字段是增量迁移，勿用旧备份覆盖后来用户保存的账号变更。

参考：[Kubernetes 原地资源调整](https://kubernetes.io/docs/tasks/configure-pod-container/resize-container-resources/)、
[资源指标管线](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)。

## 用户活动日志与 Pod 列表

“用户日志”页签支持按账号和分类筛选。也可以在“用户管理”中，通过目标用户的“操作 → 用户日志”直接查看。
日志按时间倒序排列，可加载更早记录，支持中英文界面；时间使用浏览器本地时区。

- **登录与账户**：成功登录、主动登出、管理员登录／退出、冻结与恢复账号。
- **工作空间**：启动／重启／停止请求、就绪、启动／停止失败、返回入口及关闭工作空间。
- **Pod 生命周期**：创建、容器启动／重启、资源配置变更、终止请求及停止。
- **配置变更**：管理员保存的单个工作空间配置，包含当时的 CPU、内存和档位。

事件保存当时的资源配置、用户、时间、Pod 名称和命名空间；后续修改档位不会改变旧日志。
工作空间“已关闭”表示控制器已接受缩容操作，不代表 Pod 已完成退出；实际 Pod 停止单独记录。
管理服务每 15 秒观察一次 Kubernetes：有 `startedAt`／`finishedAt` 时使用 Kubernetes 的时间；
仅观察到 Pod 消失时，以观察时间记录，并明确标注无法取得准确终止时间。
服务停机期间创建后又消失的短命 Pod 可能无法观察到，不将推测写成历史事件。

登录和工作空间事件从此功能启用后开始记录，既往未记录的操作无法补齐。
首次观察既有 Pod 时，可引用 Kubernetes 保留的创建／启动时间，并标明首次观察。
关闭标签页不是主动登出，不生成“登出”事件；返回入口也不会记作 Pod 已停止。
日志不包含密码、备忘答案、邀请码、Cookie、访问凭据或用户项目内容，也不读取容器标准输出。
这是一份用户活动记录；原“任务与审计”中的管理员操作审计继续保留。

活动日志持久保存在 Portal 账号 PVC 的 `accounts.sqlite3`（`user_events` 表），随账号库一同备份。
宿主机 `management.sqlite3` 的 `observed_pods` 和 `pod_event_outbox` 保存观察状态及待送达事件；
Portal 暂时不可用时保留待送达事件，恢复后重试，并按事件键去重。
目前不自动删除活动日志；查询分页有上限，只有已授权的管理员可以访问，普通用户不能读取日志接口。

Pod 和工作负载列表只显示 `kssolv-system` 命名空间、标有 `app.kubernetes.io/managed-by=kssolv-portal`
或 `app=kssolv-portal` 的 KSSOLV 资源，不再列出 DNS、网络、存储等 Kubernetes 系统组件。
工作节点的 CPU／内存统计仍反映整个节点的实际消耗。

## 用户管理布局

“用户管理”将账号与运行资源分开：上方账号列表仅显示用户名、角色、登录权限和账号操作，
支持按用户名查找及按可登录／已冻结筛选。点击用户名后，下方单独显示该用户的当前工作空间，
包括 Pod、就绪状态、当前配置及实时 CPU／内存使用情况，启停、重启、调配和销毁操作也集中在此区域。
用户账号可登录不代表工作空间正在运行；工作空间已停止也不表示账号被冻结。

没有 Pod 时显示“下次启动配置”，不把保存的配置当作已分配资源。
控制器显示运行中但尚未采集到 Pod 时提示等待更新；实时指标过期时不显示旧用量。
原地扩缩容尚未完成时同时显示当前配置和目标配置。

日志、核时统计、冻结／恢复和管理员授权放在账号操作中；普通管理员仍不能授权其他管理员。
核时统计对话框保留累计分配核时、实际 CPU 核时、采样覆盖时长以及按所选时间范围显示的图表。

## 管理页交互

导航支持方向键及 Home／End，窄屏可横向滚动。对话框保持标题和操作按钮可见，内容单独滚动。自动刷新会保留正在操作的表格菜单，过期 CPU／内存用量显示为缺失，不作为实时数值展示。任务与审计显示最近 30 个管理任务和 100 条审计记录。

自定义脚本未保存时，新建、换选和退出管理会先确认放弃修改；保存或执行提交期间不接受重复提交。脚本编辑器不会用迟到的加载／上传响应覆盖新内容，执行版本变更后须重新载入。每日计划再次编辑时保留具体时间，执行结束后停止结果轮询。
