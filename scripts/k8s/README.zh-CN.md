# KSSOLV Toolbox Online：Kubernetes 多用户部署

入口提供邀请码注册、登录和按需启动。地址栏固定为所配置入口 origin 下的 `/online`；
登录和工作空间均在此页面内显示，内部 iframe 使用独立来源。每位用户拥有独立子域名、namespace、Runtime Deployment、
Service、访问 Secret 和 PVC。Runtime 使用当前已验证的 Linux CPU 镜像，不需要宿主 MATLAB 或许可证，
不启动 JVM。入口只使用 Python 标准库和现有 nginx，没有 pip/npm 安装或新的编译型源码。

本入口的账号用于访问集群工作空间，与应用内面向外部服务的 Gleamoe 登录窗口独立。
登录、注册及入口文件确认窗口沿用 MATLAB 轻色对话框的字体、控件尺寸和布局。
登录、注册、密码找回、工作空间状态及错误恢复页支持中文和英文，标题栏可切换语言。
选择保存在当前浏览器的 `localStorage`（`kssolv.portal.language`），刷新或重新打开后沿用；
未选择时根据浏览器语言显示中文或英文。切换不会清空表单或重载工作空间，
不改变 Toolbox 内部的语言设置。存储被禁用时，本页仍可切换语言。
连接后的页面不显示额外顶部导航；用户名位于 MATLAB Toolstrip 的专用用户区域。
“我的账户”打开现有设置的账号页；“退出 KSSOLV Toolbox”返回入口，保留运行实例和当前标签页内的界面；“注销”释放实例并结束登录。

保留入口标签页且未空闲超时时，“重连工作空间”直接显示原 iframe，不重新加载 Runtime，保留浏览器、面板和对话框。关闭或刷新标签页、浏览器丢弃页面、网络断开导致客户端重建后，不保证所有临时界面状态原样恢复。实例释放后需重新启动，仅已保存文件和设置持久保留。
若 Runtime 入口未响应，页面使用 MathWorks 风格的恢复界面和灰色 H 图标，并保存连接失败状态，刷新不会自动重试故障实例。可先点击“重试连接”；持续失败时点击“重启工作空间”，确认后替换当前实例，保留登录、已保存文件和设置。未保存内容和临时界面状态会丢失。入口请求超时不会自动重启实例，避免中断仍在执行的计算。

Runtime 因 OOM 等原因重启后，入口每 5 秒检查实例标识；确认新容器已就绪后自动
刷新工作空间 iframe，使用新的连接入口，保留账号登录。即使两次检查之间已完成重启，
也能识别同一 Pod 中更换的容器。网络短暂中断且容器未更换时保留原界面；返回入口、
注销或空闲释放后不会自动打开工作空间。自动重连不延长空闲回收计时。
功能升级前已打开的页面需先手动刷新一次，以加载新的检测逻辑。
Pod Ready 和代理的 `/healthz` 只能确认基础服务可用，不能证明 MATLAB 应用正在响应；恢复路径还会检查应用入口。重启完成须同时满足 Deployment 已观测到新版本、新副本已更新且可用，避免把旧实例误判为恢复成功。
入口在脚本、样式及会话查询完成前显示加载遮罩；应用使用原生 AppContainer Busy 屏蔽未就绪的控件。
Online 设置新增“账号”页，显示用户名、连接状态和空闲回收阈值，并提供重连与注销操作。

## 资源档位与云管理

登录／启动工作空间时可选择小（2 核 / 8 GiB）、中（4 核 / 24 GiB）、大（8 核 / 52 GiB），
已运行实例不因登录选择而自动调整。默认并发实例数仍受 `max_running` 限制，节点资源由 Kubernetes 调度器保留。
独立管理入口为主域名 `/online/admin`，具备 KSSOLV Pod／工作负载监控、用户活动日志、KSSOLV 原地扩缩容、
生命周期、账户冻结／恢复、邀请码更新、核时统计、worker 配置、集群重启和自定义 Shell 脚本（编辑、上传、版本保存、即时／定期执行、日志及结果）。
详情、凭据位置、安装及保留数据策略见 [管理服务说明](admin/README.zh-CN.md)。
管理员绑定、登录及授权步骤见下文[管理员绑定与权限](#管理员绑定与权限)，
完整说明见 [管理服务说明中的管理员设置与登录](admin/README.zh-CN.md#管理员设置与登录)。
宿主管理服务不向普通 Portal 或用户 Pod 授予宿主权限。

## 管理员绑定与权限

管理员绑定的是 **Portal 工作空间注册账号**，角色保存在账号数据库中。
管理页使用该账号原有的用户名和密码，不需要另设管理员密码，也不使用 SSH、Kubernetes ServiceAccount 或 Toolbox 外部服务账号登录。

| 角色 | 标识 | 访问管理页面 | 权限范围 |
| --- | --- | --- | --- |
| 普通用户 | `user` | 不允许 | 使用自己的工作空间 |
| 普通管理员 | `admin` | 允许 | Pod、监控、资源、账户、节点及集群管理；不能授予或撤销管理员 |
| 超级管理员 | `superadmin` | 允许 | 全部管理功能，包括授予或撤销普通管理员；同一部署唯一 |

**首次部署：**空账号数据库中的第一个成功注册用户自动绑定为超级管理员，其他注册用户默认为普通用户。
邀请码、密码确认、备忘问题等注册验证全部通过后才计入首位注册；并发注册仅产生一位超级管理员。
初始化标记持久保存，服务重启、升级或重新部署不会重新挑选超级管理员。
升级已有账号数据库不会自动提权某个旧用户，必须由宿主机 root 显式绑定。

**东风云初始绑定记录（2026-10-22）：**超级管理员为 `yliu7949`，管理入口为
<https://kssolv.glea.moe/online/admin>，使用 `yliu7949` 原有的工作空间密码登录；此次绑定未修改密码。
其他现有用户未自动获得管理员权限。登录管理页不会启动工作空间。

**授予或撤销普通管理员：**超级管理员登录后进入“用户管理”，在目标用户的“操作”菜单中选择
“授予管理员权限”或“撤销管理员权限”，输入目标用户名确认。
被授权用户使用自己的原有账号密码登录管理页；撤权后已有管理会话立即失效，工作空间账号和数据保留。
超级管理员不能在网页中降级或冻结。

**已有集群绑定或恢复超级管理员：**在虚拟化宿主机上以 root 执行以下命令，目标须已注册且未被冻结：

```sh
sudo python3 /opt/kssolv-admin/app/admin/set_superadmin.py yliu7949
```

已有其他超级管理员时，命令默认拒绝覆盖。需要转移时使用
`set_superadmin.py new-owner --replace-existing`，其中 `new-owner` 替换为已注册的目标用户名；
旧超级管理员降为普通管理员，新旧管理会话均被撤销。绑定和转移不修改密码、工作空间资源或数据卷。

绑定保存在 Portal 的 `users.role` 字段，首次初始化标记为 `portal_settings.superadmin_bootstrapped`。
须保留并备份 Portal 账号 PVC；删除账号数据库会丢失账号和绑定信息，不是管理员恢复方法。
核查当前角色、转移说明、会话失效规则及旧版凭据迁移说明见
[管理员设置与登录](admin/README.zh-CN.md#管理员设置与登录)。
旧版独立的 `admin` 凭据文件已经停用，修改 `admin-login.json` 或 `admin.json` 的旧 `account` 字段不能绑定管理员。

## 已有集群部署

### PDF 用户手册

Portal 镜像可以包含中文和英文用户手册。构建时由开发者按需传入 PDF 的位置：
`--manual-zh /绝对路径/中文手册.pdf`、`--manual-en /绝对路径/英文手册.pdf`。
路径可以位于仓库之外，脚本会校验文件并复制到临时构建上下文，不修改原文件，也不把本机路径写入镜像。
两个参数均为可选，也可以只提供一种语言。未提供的语言版本由固定路由通过 HTTP 302
跳转到 [GitHub 最新 Release](https://github.com/USTC-Hu-Group/KSSOLV-Toolbox-Manual/releases/latest)
中的对应 PDF；不会在构建或服务启动时下载手册，也不要求集群能够访问 GitHub，用户浏览器需能访问 GitHub。
已显式提供的文件不存在或 PDF 不完整时仍会报错，不会默默使用外部版本。
Portal 生产实现和网页资源位于 `server/portal/`，宿主管理服务位于 `server/admin/`；
`scripts/k8s/` 保留构建、部署、运维入口和测试。部署脚本从这些目录显式组装独立镜像上下文，
所以应通过下面的部署构建命令准备镜像，不能直接用 `scripts/k8s/` 作为 Docker 构建上下文。
部署已经构建好的镜像（不加 `--build`）无需再次提供本机 PDF。

| 手册 | 固定路由 |
| --- | --- |
| 中文 | `/online/docs/zh-CN.pdf` |
| English | `/online/docs/en-US.pdf` |

已打包的版本由 nginx 从镜像中的 `/opt/kssolv/portal/manuals/` 提供文件，无需启动用户工作空间或登录；
路由只公开这两份手册，不开放目录浏览。支持浏览器内联预览、分页范围请求和缓存重新验证。
外部版本分别使用 `/releases/latest/download/KSSOLV_Toolbox_User_Manual_zh-CN.pdf`
和 `/releases/latest/download/KSSOLV_Toolbox_User_Manual_en.pdf`，不固定某个发布标签；跳转响应不缓存。
更新手册时重新构建并发布 Portal 镜像，原有固定链接保持不变；无需重编 MATLAB Runtime 或重启用户 Pod。
镜像内 `manuals/manifest.json` 记录已打包文件的 SHA-256 和字节数，可用于核对发行内容；不打包时为 `{}`。

Online 的 Documentation（及快速访问栏 Help）在新标签页打开手册：
Toolbox locale 为中文时选择中文 PDF，英文及其他语言选择英文 PDF。
这里使用 **Toolbox 内部语言**，与入口登录页的浏览器语言设置独立；更改 Toolbox 语言后按应用提示重新启动界面生效。
链接使用当前部署的入口域名，不写死东风云域名。入口注入的浏览器桥接也支持已有 Runtime 镜像，
发布后已经打开的工作空间需刷新页面才能加载新跳转逻辑；刷新前请先保存项目。

要求集群支持 NetworkPolicy、动态 RWO 存储、IPv4 Pod 网络，并能获取所配置的镜像。
部署者需要创建专用 namespace/RBAC 的权限。控制器的 ServiceAccount 可创建租户 namespace
和固定工作负载、缩放实例；它不具有集群管理员权限，也不能读取其他 Secret 或执行 Pod 命令。
Runtime Pod 不挂载 ServiceAccount 令牌、Docker socket 或宿主路径。

```sh
python3 scripts/k8s/deploy.py \
  --context kind-cloud \
  --runtime-image kssolv-toolbox:files-browser \
  --portal-image kssolv-portal:20261018-15 \
  --build --kind-cluster cloud \
  --manual-zh /path/to/KSSOLV_Toolbox_User_Manual_zh-CN.pdf \
  --manual-en /path/to/KSSOLV_Toolbox_User_Manual_en.pdf \
  --storage-class standard \
  --secrets-dir /opt/kssolv-k8s-secrets \
  --accept-runtime-license --wait
```

`--accept-runtime-license` 表示部署者已审阅并接受 MathWorks Runtime 许可。
用户 Runtime 默认资源为 `4` CPU / `52Gi` 内存，CPU 和内存的 `requests` 与 `limits`
分别使用 `--cpu`、`--memory` 的值，避免调度器仅按较小请求量安排多个高内存实例。
东风云两个 worker 的默认及持久配置为 28 vCPU / 56 GiB，
为操作系统和集群服务保留余量；该限额仍可能终止超过预算的计算，不会自动降低计算内存。
Runtime 启动前检查虚拟显示的锁文件和 Unix socket，仅清理没有存活进程、没有监听服务的
残留文件，使 OOM/SIGKILL 后保留 `/tmp` 的容器重启能够恢复；正常退出也执行清理。
`--build` 构建入口镜像；`--kind-cluster` 仅向已有 kind 集群导入镜像，不创建或重置集群。
非 kind 集群应将两个镜像推送到自己的可信仓库，省略该参数。
生产环境推荐使用镜像 digest；不要复用可变版本标签。

邀请码保存在 `--secrets-dir/registration-code`（目录 700、文件 600）。不打印或提交邀请码，
不要把该目录放进源码仓库。重复部署会验证邀请码与已有 Secret 一致，防止意外替换。
账号数据库单独保存在入口 PVC 中，密码使用独立盐值和 scrypt 哈希；会话与跳转码仅保存哈希。
SQLite 数据库还包含连接各租户的高熵机器凭证，其备份应作为秘密保存。

默认入口是 `http://kssolv-k8s.localhost:18130`，适用于 SSH 回环转发测试。例如：

```sh
# 在云端查到 kind worker 的 INTERNAL-IP；不把入口直接暴露到公网 HTTP。
ssh -N -L 127.0.0.1:18130:172.18.0.3:30088 user@your-server
```

本机浏览器打开入口并注册。用户名为 3–32 位小写字母、数字或连字符，以字母开头；密码 12–128 个字符。
登录后显示启动状态，就绪后在固定 `/online` 页面内进入自己的工作空间。实例已启动时重登会复用它。
MATLAB 自身仍限制每个实例只有一个浏览器客户端，重复标签页会提示先关闭已有连接。

校园网和公网部署均须配置 HTTPS 和通配符 DNS/证书，使入口域名及内部用户域名都到达同一入口 Service。
用 `--origin https://online.example.org` 设置外部 origin。HTTP 仅允许 `.localhost` 测试域名。
外部 Ingress 需允许 WebSocket、256 MiB 请求及足够长的连接时间，不能重写应用根路径。
入口和租户的 Cookie 均为 Host-only、HttpOnly、SameSite=Lax；HTTPS 模式同时启用 Secure。
HTTPS Cookie 使用 `__Host-` 前缀，防止兄弟子域通过父域 Cookie 覆盖入口会话。
代理保留 MATLAB 的资源 CSP，仅替换 `frame-ancestors` 为入口 origin 和工作区自身；
不能简单叠加第二个 CSP，因为浏览器会同时执行原策略并继续拒绝外层入口。
账号与工作空间由服务端会话关联，地址栏不包含用户 ID、令牌或 MATLAB 参数；
内部一次性跳转码有效 30 秒、消费后失效，不能复制给其他用户复用。
主入口不读取内部工作空间 DOM。文件选择和另存为由外层原生浏览器接口承接，
通过严格校验来源和窗口的消息传递，直接打开系统文件选择／保存窗口，不再叠加入口确认框。
若服务器准备文件期间浏览器的点击授权过期，只在原有传输窗口显示“选择文件／另存为”重试按钮。
文件句柄仅留在外层页面，内部工作空间只能提交此用户刚选择的文件，单文件/单次上限 128 MiB。

### 自定义域名配置

部署脚本和 HTTPS 入口共用以下环境变量；每个对应的命令行参数优先于环境变量。
脚本不会自动加载仓库 `.env`，应在同一个 shell 中 `export` 或显式加载部署专用的环境文件。

| 环境变量 | 部署参数 | HTTPS 入口参数 | 含义 |
| --- | --- | --- | --- |
| `KSSOLV_PUBLIC_ORIGIN` | `--origin` | 自动提取主机名；可用 `--domain` 覆盖 | 外部 origin，例如 `https://online.example.org`，不含 `/online` 或末尾 `/` |
| `KSSOLV_TENANT_DOMAIN` | `--tenant-domain` | `--tenant-domain` | 工作区域名后缀，例如 `online.example.org`，不含 `*.`、协议或端口 |

未设置租户后缀时，默认使用入口主机名，生成 `u-<id>.online.example.org`。
也支持显式设置独立后缀，例如 `workspaces.example.org`。部署脚本把最终的 `origin` 和
`tenant_domain` 写入 `portal-config-<配置摘要>` 不可变 ConfigMap；Portal 从该配置生成跳转地址、CSP、消息桥和来源校验，
不绑定某个部署域名。修改部署环境变量后必须重新运行部署脚本，并同步重新生成 HTTPS 入口配置；
仅修改宿主 shell 环境不会更新运行中的 Pod。ConfigMap 的配置摘要会触发 Portal 更新，已有 PVC 保留。
换域名后需重新登录，旧域名的浏览器 Cookie 不会迁移。
每次配置变化会创建新名称并更新 Pod 引用，避免新进程读取节点缓存中的旧配置；历史配置保留供回滚。

未设置外部 origin 时，部署脚本保留 `.localhost` 测试入口。HTTPS 入口不再默认某个生产域名，
必须显式传入 `--domain` 或 `KSSOLV_PUBLIC_ORIGIN`，避免误启动到别人的域名。
本脚本的 TLS 入口固定对外使用 443；其他外部端口需要单独配置边缘代理。

### 云服务器 HTTPS 入口

提供 PEM 完整证书链和匹配私钥。已有明确 DNS 记录的其他子域名仍优先于通配符记录。
证书必须同时覆盖入口主机名和工作区通配符；例如 `online.example.org` 与 `*.online.example.org`。
单层 `*.example.org` 证书不能覆盖 `u-<id>.online.example.org`。
安全组开放 TCP **443**；TCP **80** 仅用于跳转 HTTPS，可省略。无需公开 NodePort 或 6443。
宿主有 Docker 时可启动 HTTPS 容器。下面是已有 kind 集群的例子，两个命令在同一个 root shell 中执行：
先将 `KSSOLV_EDGE_SOURCE_CIDR` 设为 portal 实际看到的专用 HTTPS 边缘源地址/CIDR，
再运行部署命令；地址选择和 NodePort SNAT 注意事项见下文。

```sh
export KSSOLV_PUBLIC_ORIGIN=https://online.example.org
export KSSOLV_TENANT_DOMAIN=online.example.org
python3 scripts/k8s/deploy.py --context kind-cloud \
  --secrets-dir /opt/kssolv-k8s-secrets \
  --trusted-proxy "$KSSOLV_EDGE_SOURCE_CIDR" \
  --accept-runtime-license --wait
python3 scripts/k8s/tls_edge.py \
  --cert /secure/fullchain.pem --key /secure/private.key \
  --state-dir /opt/kssolv-tls --upstream cloud-worker:30088
```

脚本先验证证书链、有效期、域名和私钥匹配及 nginx 配置，再启动只读非 root HTTPS 容器。
证书及私钥必须保存在仓库外；脚本不会打印私钥。它只替换自己管理的入口，不重置集群。
已有 Ingress 可直接接入 portal Service，无需运行这个宿主边缘容器。

认证限流使用客户端 IP。直接访问 portal 时忽略客户端提交的所有转发头；经过 HTTPS
边缘或 Ingress 时，部署 portal 需额外重复传入 `--trusted-proxy <边缘IP或CIDR>`，
填写 portal nginx 实际看到的可信代理源地址。边缘必须覆盖 `X-Forwarded-For` 为客户端
连接地址；本仓库的 `tls_edge.py` 已执行覆盖，不会拼接外部提交的头。只信任专用边缘地址，
不要信任所有私网或多个客户端共享的 NodePort SNAT 节点地址；该情况下应先配置保留源地址
的入口，并用防火墙限制 NodePort 仅供边缘访问。未配置可信代理时，限流会安全地按直接
连接方计数，边缘后的用户会共享代理额度。portal 到本地 Python 的 IP 头另有每进程随机凭据，
外部伪造该头无法改变限流身份；配置变更需重新部署 portal 生效。
已有部署升级时，应构建并使用包含此修复的新 portal 镜像版本，保留原部署参数，补上
`--trusted-proxy` 后重新运行 `deploy.py`。该参数写入不可变 ConfigMap，配置校验和会触发
portal Pod 更新；只更新 Python 文件、只重新启动 TLS 边缘或不传信任参数均无法启用跨代理的客户端隔离。

### 东风云校园网 443 端口映射

入口规划为 `https://kssolv.glea.moe/online`，用户工作区为 `u-<id>.kssolv.glea.moe`。
网络映射将 `114.214.240.136:443` 转发到东风云宿主机 443，因此可以直接在宿主终止 TLS，
再代理到 worker 的 Portal NodePort；不需要公网中继、SSH 服务隧道或出站外网认证。
客户端到映射地址的校园网连通性仍由网络侧保证，域名解析不会扩大可访问的网段。

配置 DNS（如使用 DNS 代理服务，应选择仅 DNS 解析，使校内浏览器直接连接映射地址）：

| DNS 记录 | 类型 | 地址 |
| --- | --- | --- |
| `kssolv.glea.moe` | A | `114.214.240.136` |
| `*.kssolv.glea.moe` | A | `114.214.240.136` |

证书的 SAN 应覆盖 `kssolv.glea.moe` 和 `*.kssolv.glea.moe`，提供受客户端信任的完整证书链。
域名证书可在有外网的机器使用 DNS-01 取得后安全安装到宿主；不需要 80 端口。
这只是部署配置示例，不表示 DNS、证书或集群已就绪；还需准备可用 StorageClass、网络策略执行器和镜像。

在东风云宿主机同一个 root shell 中设置部署域名：

```sh
export KSSOLV_PUBLIC_ORIGIN=https://kssolv.glea.moe
export KSSOLV_TENANT_DOMAIN=kssolv.glea.moe
```

然后按“已有集群部署”运行 `deploy.py`，使用实际 context `kubernetes-admin@kubernetes`、
已准备的两个镜像和实际 StorageClass；不要传 `--kind-cluster`。本拓扑设置 `--max-running 2`。

宿主使用 containerd、不依赖 Docker 时，可为已有原生 nginx 生成独立的完整配置：

```sh
install -d -m 700 /etc/kssolv
umask 077
python3 scripts/k8s/tls_edge.py --render-only --no-http-redirect \
  --upstream 192.168.250.11:30088 \
  --cert /secure/fullchain.pem --key /secure/private.key \
  > /etc/kssolv/nginx-edge.conf
nginx -t -c /etc/kssolv/nginx-edge.conf
```

`--render-only` 只向 stdout 输出配置，不读取证书/私钥、不启动服务、不调用 Docker；
它使用宿主 443 和指定的证书路径，而容器模式内部仍用 8443。
生成文件是独立的完整 nginx 配置，不能直接放入通常只接受 `server` 块的 `conf.d/`。
应检查已有 443 服务并合并或替换其入口，经 `nginx -t` 后由宿主服务管理器使用该配置启动/重载；
不要同时启动两个占用 443 的进程，也不要覆盖无关站点。nginx 用户需能读取证书和私钥。
`--no-http-redirect` 不监听 80；所有 Host、路径、Cookie、WebSocket 均保留，不能只转发 `/online`。
外层代理不要额外添加会阻止工作区 iframe 的 CSP 或 X-Frame-Options。

可以先用 `curl --resolve kssolv.glea.moe:443:114.214.240.136 https://kssolv.glea.moe/online`
验证映射、SNI 和证书，再用两个真实用户验证工作区和 WebSocket。该单域名 curl 检查不替代
通配符 DNS、工作区域名证书、存储及隔离的端到端验收。正常用户只需在校园网浏览器打开固定入口。

### 2026-10-18 东风云部署记录

当前已部署到 `kubernetes-admin@kubernetes`，使用以下配置：

| 项目 | 当前值 |
| --- | --- |
| 入口 | `https://kssolv.glea.moe/online` |
| 工作区 | `https://u-<24 位用户 ID>.kssolv.glea.moe` |
| Runtime 镜像 | `docker.io/library/kssolv-toolbox:dongfeng-20261019-axes-export-01` |
| Portal 镜像 | `docker.io/library/kssolv-portal:dongfeng-20261020-entry-retry-01` |
| 存储 | `kssolv-local`，每用户 10 GiB PVC，账号库 1 GiB PVC |
| 容量 | 最多 10 个账号、同时 3 个 Runtime；每实例上限 16 CPU / 32 GiB |
| 回收 | 连续 1800 秒无人的操作后释放实例，保留已保存文件 |
| HTTPS | 宿主 `kssolv-edge.service` → `192.168.250.11:30088` → Portal → 用户 Runtime |

镜像在 gpu6 使用 R2026b Linux Compiler、`-nojvm` 和 CPU Runtime 重新构建，已预装到三个 worker。
2026-10-19 的账号入口更新只重建 Portal，继续使用 2026-10-18 的 CPU Runtime；
该次入口源码、镜像、数据库升级前备份及找回密码验收记录位于宿主
`/opt/kssolv-deploy/20261019-accounts-01/`。账号数据库迁移可重复执行，只增加备忘字段。
随后精简登录/注册页提示，注册页不显示工作空间说明；该次入口文案版本记录位于
`/opt/kssolv-deploy/20261019-copy-01/`，账号逻辑与 Runtime 未变。
2026-10-19 将现有用户 ResourceQuota、Runtime Deployment 和入口创建配置统一调整为
8 CPU / 16 GiB；CPU / 内存请求仍为 500m / 2 GiB。该次 Python 统计修复基于
`dongfeng-20261019-chat-resize-02` 镜像追加文件层，复用原有 MATLAB 可执行文件和 Runtime，
已在三个 worker 预装。部署入口及原地扩容验收记录位于
`/opt/kssolv-deploy/20261019-resource-limits-01/`；其中 `redeploy.sh` 保留本次完整部署参数。
临时 Pod 从 4 CPU / 8 GiB 扩到 8 CPU / 16 GiB 后，容器 ID 和进程未变、重启次数为 0，
页面资源统计同步更新；更新时正式用户处于停止状态，其现有 Deployment 已同步供下次启动使用。
Flannel 配合独立的 `kube-network-policies` 执行租户网络策略；存储由 local-path-provisioner 提供。
2026-10-20 将三个 worker 的虚拟机规格及工作空间上限分别同步为 16 CPU / 32 GiB；
用户 PVC 仍为 10 GiB，账号库仍为 1 GiB，CPU / 内存请求仍为 500m / 2 GiB。
worker 磁盘已从 16 GiB 扩至 32 GiB。所有 VM 仍位于同一宿主，不提供宿主故障容错。
宿主上的 `kssolv-guest-time-sync.timer` 每 30 秒检查四个节点的时钟；仅在宿主 NTP
已同步、虚拟机运行且偏差超过 2 秒时，通过 QEMU guest agent 校准，不重启工作空间。
该配置用于避免虚拟机时钟落后而使页面将资源统计误判为过期；记录位于
`/opt/kssolv-deploy/20261020-metrics-clock-01/`。
`kssolv-local` 的卷固定在创建它的节点上，采用 `Retain`；PVC 声明的大小不构成硬磁盘配额。
账号数量上限也不会预留全部用户磁盘空间，应持续检查宿主及各 worker 的剩余空间。

宿主上的运维文件（均不应提交到 Git）：

| 路径 | 用途 |
| --- | --- |
| `/opt/kssolv-deploy/20261018-01/` | 源码快照、构建记录、镜像归档、验收报告和基础设施备份 |
| `/opt/kssolv-secrets/registration-code` | 注册邀请码；通过已授权 SSH 读取并按需分发 |
| `/etc/kssolv/nginx-edge.conf` | 独立 nginx 配置，只监听 443 |
| `/etc/systemd/system/kssolv-edge.service` | HTTPS 开机启动服务 |
| `/etc/kssolv/tls/kssolv.glea.moe/` | 完整证书链和私钥 |
| `/var/lib/kssolv-volumes/`（各节点内） | 本地持久卷；需连同账号库制定备份 |

检查与重载：

```sh
kubectl get nodes -o wide
kubectl get pods -A
kubectl -n kssolv-system get deploy,svc,pvc
systemctl status kssolv-edge.service
nginx -t -c /etc/kssolv/nginx-edge.conf && systemctl reload kssolv-edge.service
```

证书覆盖入口和通配工作区域名，2027-01-16 21:54:54（北京时间）到期。
当前使用手工 DNS-01，**没有自动续期**。到期前需重新完成 TXT 验证，更新上述证书目录后重载服务。
宿主 ACME 客户端位于 `/opt/kssolv-acme/acme.sh`；续期需要短时外网连通，正常校内服务无需登录网络通。

### 2026-10-20 0.5.0 发布

Runtime 和 Portal 已更新为 `docker.io/library/kssolv-toolbox:v0.5.0-20261020-01`
和 `docker.io/library/kssolv-portal:v0.5.0-20261020-01`。镜像在 gpu6 以 R2026b、
`-nojvm`、CPU 模式重新编译，三个 worker 的镜像 ID 均已核对。
双原子、3 个能带点的 HSE06 串行/双线程及对象传递回归共 4 项通过；
云端临时实例确认版本 0.5.0、未加载 JVM、原生页面响应和工作目录写入正常。

账号库及现有 PVC 保留，配额、域名和回收配置不变。已有运行会话保留，
在用户重启工作空间后使用新版本；停止的实例已更新镜像。
发布、镜像、备份和回滚参数记录在 `/opt/kssolv-deploy/20261020-v050-01/`。
导入期间宿主磁盘曾写满并暂停虚拟机，清理历史镜像归档后已恢复全部节点与入口；
后续镜像采用逐节点导入，清理记录见该目录的 `host-archive-cleanup.json`。

### 2026-10-20 内存预算和异常退出恢复补丁

Runtime 与 Portal 补丁镜像标签为 `v0.5.0-20261020-memory-recovery-01`。
默认及两个现有用户 Deployment 的 `requests.memory`、`limits.memory` 均为 `28Gi`，
租户内存限额同步更新；入口与 Kubernetes 系统组件保留原资源设置。
yliu7949 的故障实例已替换并恢复就绪，houbk 保持停止，原有 PVC 身份保留。

测试实例以 `28Gi` 请求及限额启动后，强制结束整个容器，在同一个 Pod 中自动重启，
保留临时卷与数据标记，认证入口返回 200。显示服务的残留锁和 socket 已能安全清理。
部署、镜像核对、恢复测试及最终验证报告位于
`/opt/kssolv-deploy/20261020-memory-recovery-01/`。

### 2026-10-20 worker 和 Runtime 资源调整

三个 worker 的运行及持久规格统一为 12 vCPU / 36 GiB；宿主
`/root/k8s-lab/provision-host.py` 的 worker 创建默认值同步为 12 / 36864 MiB。
控制平面保持 4 vCPU / 8 GiB。调整经确认后逐台关机启动，保留原虚拟磁盘与用户 PVC。

Runtime 默认和现有工作空间的 CPU 请求及上限均为 `8`，内存请求及上限均为 `32Gi`，
租户限额同步为 8 CPU / 32 GiB。Portal 镜像使用
`docker.io/library/kssolv-portal:v0.5.0-20261020-capacity-8c32g-01`，
Runtime 继续使用已修复显示锁的 `v0.5.0-20261020-memory-recovery-01`。
备份、节点和 Pod 验证记录位于 `/opt/kssolv-deploy/20261020-capacity-12c36g-01/`。

### 2026-10-20 两个 worker 的资源与存储迁移

当前保留 `k8s-worker1`、`k8s-worker2`，运行及持久规格均为 28 vCPU / 56 GiB。
节点创建脚本默认只创建这两个 worker 和原有控制平面，Runtime 的默认及现有
CPU 请求和上限为 `8`、内存请求和上限为 `52Gi`，同时运行实例数为 2。

yliu7949 的本地数据从 worker3 停写后复制到 worker2，源目录、宿主备份和目标目录
的内容哈希、所有权及权限已核对。通过新 PV 和同名 PVC 绑定到 worker2；旧 PV、
旧节点磁盘及源数据保留供回滚。worker3 已退出 Kubernetes、停机并禁用自动启动，
旧节点的 kubelet 也已禁用。账号库仍在 worker2，houbk 数据仍在 worker1。

备份、存储迁移、节点和运行配额验证记录位于
`/opt/kssolv-deploy/20261020-two-workers-28c56g-01/`。重建或迁移 PVC 时，先停止
对应 Runtime 和入口生命周期控制，确认 `Retain`，完整校验副本，再绑定目标 PV；
不得直接删除旧卷数据。回滚先停止新实例，再用该目录的快照恢复绑定和节点配置。

迁移或重建同名 PVC 时，必须保留 `kssolv-user` 和
`app.kubernetes.io/managed-by=kssolv-portal` 归属标签；缺失用户标签会被入口的
租户隔离校验拒绝。绑定后核对 PV 的 `claimRef` 命名空间、名称及 UID 与目标 PVC
一致，并实际验证工作空间启动。2026-10-21 已补齐 yliu7949 迁移卷遗漏的标签，
保留原 PVC UID、PV 绑定及存储规格；修复记录位于
`/opt/kssolv-deploy/20261021-pvc-owner-01/`。

### 2026-10-20 Runtime CPU 原地调整为 4 核

默认及两个现有 Runtime 的 CPU 请求和上限均调整为 `4`，内存请求和上限保持 `52Gi`。
通过 Pod `resize` 子资源调整运行配额，并在暂停 Deployment 更新期间同步所属
ReplicaSet 和 Deployment 模板，随后恢复控制器；先用隔离小实例验证该流程。
两个正式 Pod 的 UID、容器 ID 和重启次数在调整前后均未变化，内核 CPU 配额与
认证资源接口均确认 4 核 / 52 GiB。入口配置重载后，新建及重建实例沿用相同配置。
备份及验证记录位于 `/opt/kssolv-deploy/20261020-pods-4c52g-01/`。

### 2026-10-20 OOM 后自动重连

Portal 镜像为 `docker.io/library/kssolv-portal:v0.5.0-20261020-auto-reconnect-01`，
Runtime 镜像及计算进程无需更新。入口状态接口返回 Pod UID 与运行容器 ID 的哈希，
前端在实例更换且就绪后获取新的单次入口，避免继续使用旧 WebSocket 和 Connector nonce。
控制器仅新增 Pod 元数据 `list` 权限，不授予 `pods/exec` 或 Secret 读取权限。
前端回归覆盖重启、网络错误、返回入口、注销及单次入口失败；部署和 OOM 验证记录
位于 `/opt/kssolv-deploy/20261020-auto-reconnect-01/`。

### 2026-10-21 入口中英文切换

Portal 镜像更新为 `docker.io/library/kssolv-portal:v0.5.0-20261021-language-01`。
登录、注册、找回密码、运行状态、重启确认及错误恢复页共用语言字典和浏览器偏好；
服务端校验错误随当前选择显示，用户填写的问题与答案不做翻译。
独立错误页回到入口时传递语言选择，刷新后继续沿用。
入口镜像在两个现有 worker 上校验导入，隔离容器完成 43 项 Python 检查，
前端完成 41 项 JavaScript 检查；发布前后用户 Runtime Pod、容器及资源配置不变。
发布、回滚快照和验证记录位于 `/opt/kssolv-deploy/20261021-language-01/`。

## 注册和找回密码

注册时必须填写两次一致的密码（12–128 个字符）、自定义备忘问题（4–200 个字符）、
备忘答案（2–128 个字符）和邀请码。前后端均检查密码确认，答案使用独立随机盐和 scrypt 哈希保存，不保存明文。
答案比较会进行 Unicode NFKC 规范化、忽略大小写及首尾空白；密码始终精确比较。

登录页的“忘记密码”先根据用户名显示备忘问题，再提交答案、新密码及确认密码。
问题公开展示，不能填写秘密；应选择非公开、难以猜测的答案。正确答案是本流程的恢复凭据，
知道答案即可修改密码，不提供多因素保障（参见 [OWASP 的安全问题说明](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html#security-questions)）。
每账号 15 分钟最多提交 5 次重置请求，另有入口来源的总量限制；查询问题每账号 5 分钟最多 10 次。
答错不会修改密码或撤销会话。成功后重新加盐保存新密码，撤销该账号全部入口/租户会话及未使用的跳转码，
释放 Runtime，再从普通登录入口登录；UID、Runtime 机器凭证和 PVC 不变，已保存文件保留。
若集群暂时无法停止旧 Runtime，访问先撤销，后台继续重试停止；其他用户不受影响。

首次启动新版本时通过 SQLite 增量迁移添加备忘字段，保留原账号、密码、会话和文件。
旧账号下次登录可验证当前密码后补设问题，或选择“稍后设置”继续使用工作区；
未设置问题的旧账号无法自助找回密码，需联系管理员。补设接口要求有效入口会话和正确当前密码，
不能匿名补设或覆盖已设置的问题。备忘答案丢失时同样需联系管理员。

接口使用相同的 Host/Origin 和 JSON 校验：`register` 额外要求 `passwordConfirmation`、
`recoveryQuestion`、`recoveryAnswer`；公开的 `recovery-question` 接收 `username`，
`reset-password` 接收 `username`、`recoveryAnswer`、`password`、`passwordConfirmation`；
已登录的 `recovery-setup` 接收当前 `password`、`recoveryQuestion`、`recoveryAnswer`。

## 空闲回收和重新连接

- 默认连续 **30 分钟无人的操作** 后撤销登录会话并将该用户 Deployment 缩为 0，释放 Pod、CPU 和内存。
- 检测键盘、点击、触摸和滚动；普通请求、状态轮询、WebSocket 保活及只把标签页留在前台都不延长时间。
- 页面在回收前两分钟提醒保存。后台回收检查默认每 10 秒执行，Pod 终止宽限 25 秒。
- 重新登录后以同一身份、PVC 和访问凭证启动。已保存项目、设置及现有恢复文件保留；
  Pod 回收后 RAM 中的命令变量、聊天历史、运行中的计算和未保存项目不保证恢复。请在离开前保存。
- 关闭网页不会注销。重新访问固定 `/online` 入口时，若 Pod 仍存活，会复用该 Pod 和内存会话；
  此次明确连接重置空闲计时。普通状态查询仍不会延长空闲时间。
- 显式退出登录会撤销该用户所有访问会话并释放实例。入口 Pod 更新不会删除账号库或租户卷。

通过 `--idle-seconds` 修改阈值。测试可以临时设为 120 秒，完成后重新部署恢复 1800 秒。
启动最多有 450 秒宽限，以免首次启动尚未就绪就被较短的测试阈值回收。

## 云端文件

Online 左侧的“文件”面板显示当前用户 PVC 中 `/data/work` 的内容，支持目录展开、刷新、新建文件夹、
上传、导入和下载。面板采用紧凑的名称表头、目录优先的文件树和底部路径/大小状态栏；
表头箭头切换名称升降序，右侧“⋮”及右键菜单提供文件操作。刷新或排序保留展开目录和选中文件，
右键操作针对实际点击的文件；文件夹或空白处禁用导入/下载。双击 `.ks` 打开项目，结构文件导入当前项目，`.wf` 导入工作流；其他文件仍可保存和下载。
Online 的“保存”和“另存为”优先保存到云端文件。新项目或另存为时，在页内窗口输入文件名，目标目录是
文件树当前选择的文件夹。选择“文件”面板的下载操作可另存到本机；上传和下载沿用 128 MiB 上限与进度显示。
桌面模式及没有持久化工作目录的开发会话沿用现有文件行为。

工作目录由容器监督进程明确指定。路径解析和列表访问通过仅绑定 loopback 且带随机鉴权令牌的 Python 标准库服务，
拒绝绝对路径、目录穿越及指向目录外的符号链接；不会将用户配置和密钥目录列入文件浏览器。
上传和项目保存先写同目录临时文件，成功后替换目标；覆盖已有目标需要确认（原路径直接保存除外）。
退出和重新登录不会删除云端文件；请保存项目后再释放工作区。

文件面板复用 MATLAB 的 AppContainer、原生树、菜单和页内对话框。
它不调用桌面 `filebrowser` 或内置 WorkspaceBrowser：R2026b Compiler 将这两者列为不支持部署，
纯 Linux Runtime 探针也无法解析它们。旧版 UIHTML WorkspaceBrowser 在 `-nojvm` MATLAB 中可创建，
但编译后缺少桌面 Workspace 服务类，不能直接作为独立 Runtime 组件使用。
这与 MathWorks 的[Compiler 支持范围](https://www.mathworks.com/products/compiler/compiler_support.html)中
预置应用、UI 和开发工具的限制一致；完整 MATLAB 中可用不代表 Runtime 中可部署。

## 配额与隔离

默认最多注册 100 个用户、同时运行 2 个实例；`--max-users` / `--max-running` 可调整。
每租户默认 4 CPU / 52 GiB 内存、20 GiB PVC，一个 Runtime Pod；可通过 CLI 修改。
CPU / 内存的请求和上限一致，调度器按请求预留节点资源；实际使用仍受节点及宿主负载影响。
临时内存卷 4 GiB 和共享内存 512 MiB 计入该 Pod 内存使用。

Kubernetes 1.36 支持通过 Pod 的 `resize` 子资源原地调整 CPU / 内存，默认无需重启容器。
调整前须先提高 ResourceQuota，并同步入口配置和 Deployment 模板，防止重建后恢复旧值。
直接修改 Deployment 模板会触发部署更新；本项目 Runtime 使用 `Recreate` 策略，
不要将模板更新误认为原地扩容。页面资源统计优先读取实时 cgroup 限制，
仅在无限制时回退到启动时的 Downward API 环境变量。

每个 namespace 的 NetworkPolicy 只允许入口 Pod 访问 Runtime；租户仅允许访问集群 DNS 及公网
80/443，拒绝其他租户、控制面、节点、私网及元数据网络。必须在实际 CNI 中验证策略已执行，
不能只以 YAML 创建成功作为隔离通过。Basic 机器凭证为每用户独立的第二道访问边界。
入口通过独立子域名隔离浏览器 origin，验证 Host、Origin、会话用户，并在转发前移除入口 Cookie。

PVC 的 `requests.storage` 和 ResourceQuota 限制存储申请量，**不等同于文件系统硬限额**。
kind 默认 local-path 存储适合验证，卷绑定到节点，不提供多节点数据复制或节点故障自动迁移。
生产环境应使用支持备份、恢复和所需容量限制的 CSI 存储；定期备份入口数据库和用户卷。
这是进程/容器及 Kubernetes 策略层面的隔离，不是内核逃逸审计。

## 检查与测试

```sh
kubectl --context kind-cloud -n kssolv-system get pods,svc,pvc
kubectl --context kind-cloud get ns -l app.kubernetes.io/managed-by=kssolv-portal
kubectl --context kind-cloud -n kssolv-system logs deployment/portal
python3 -m unittest discover -s scripts/k8s/tests -v
node --test scripts/k8s/tests/test_file_bridge.cjs
node --test scripts/k8s/tests/test_account_ui.cjs
node --test scripts/k8s/tests/test_account_shell.cjs
node --test scripts/k8s/tests/test_i18n.cjs
```

`test_gateway.py` 需要 nginx，主机没有时会明确跳过。完整验证在只读容器里运行：

```sh
docker run --rm --network none --read-only --tmpfs /tmp:rw,nosuid,nodev,size=256m \
  --mount type=bind,src="$PWD",dst=/workspace,readonly \
  --workdir /workspace --env PYTHONDONTWRITEBYTECODE=1 \
  --entrypoint python3 kssolv-portal:20261018-15 -m unittest discover -s scripts/k8s/tests -v
```

真实验收至少使用两个独立账号，覆盖注册/错误密码、登录、文件持久化、刷新、空闲回收、重新登录、
跨用户 Cookie/URL/WebSocket、Pod 间网络及控制面访问。测试凭证、报表和截图放到仓库外，避免提交秘密。
删除工作负载时不要顺带删除用户 namespace/PVC；该操作会丢失用户数据。

参考：[Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)、
[Pod 安全标准](https://kubernetes.io/docs/concepts/security/pod-security-standards/)。
