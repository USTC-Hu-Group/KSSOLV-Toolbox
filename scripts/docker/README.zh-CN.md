# KSSOLV Toolbox Online

此方案以官方 MATLAB Runtime 镜像运行编译后的独立应用，启动时强制启用
`KSSOLV_HOST_IN_BROWSER=true` 和 `KSSOLV_ONLINE=true`。每个容器只支持一个活动浏览器会话。
不要同时用多个浏览器、多个标签页连接同一容器：本机测试触发了 MATLAB 的
`Multi Client Usage Detected` 内部断言并导致进程退出。应用使用 MATLAB 内部 AppContainer/Connector
接口，属于需要随 MATLAB 发行版回归验证的实验性部署方式。

2026-10-18 已在 Linux x86-64 上以 `-nojvm` 编译，并在选择性安装的真实 Runtime
容器内通过 Chrome 单客户端验证 `.ks` 上传、超胞建模、SCF、CIF 下载及含计算
数据集的 `.ks` 保存/下载/上传往返。Online 对话框使用页内模态窗口。
独占连接控制、工作流/绘图刷新恢复及代理崩溃恢复已完成指定场景测试；GPU 计算、
完整跨平台回归和 Kubernetes 多租户控制面尚未验收。gpu6 临时 K3s 集群已验证两个独立租户的
认证、网络/PVC 隔离、升级保留项目、Runtime 崩溃重启、OOM 和私有临时卷写满后的恢复。
这是单节点测试集群；生产入口、会话分配及存储硬配额仍需单独部署和验证。

## Online 资源状态

Online 左下角每约 2 秒显示 CPU 使用率、当前使用／分配的核数，以及内存已用／总量。
Kubernetes 使用当前 Runtime 容器的 cgroup 计数器和 Downward API 限额；每个工作区
Pod 仅有这一个容器，因此对应整个工作区 Pod。CPU 百分比以分配的核数为 100%，
内存为使用量减去非活跃文件缓存的工作集。采集在 Python 后台线程中进行，
浏览器直接更新状态栏，MATLAB 计算期间也会刷新；暂时不可用时显示 `—`。
接口复用工作区认证，不需要 Kubernetes API 凭据或 metrics-server。

普通 Docker 部署显示 `/proc` 提供的 Linux 宿主机 CPU 与内存，忽略容器限额。
Docker Desktop 中的宿主机指 Docker Linux 虚拟机。若容器平台另行虚拟化了
`/proc`，显示的是该平台提供的视图。原生桌面模式不添加此状态。

## 构建

需要 Linux x86-64 环境中的 MATLAB R2025b 或更高版本、MATLAB Compiler
许可及项目原有的 LLM Add-On（最低版本由构建入口检查）。Runtime 镜像本身
只能运行编译产物，不能代替 MATLAB Compiler 编译源码。macOS 和 Windows
独立应用不能直接放入 Linux 镜像运行。Apple silicon 上使用 Docker 时指定
`linux/amd64`，通过仿真运行 Linux 镜像；性能验证应在目标 Linux 主机重做。

先按 [frontend 构建说明](../../frontend/README.md) 更新并验证前端运行资源，
然后在仓库根目录、Linux MATLAB 环境执行：

```sh
python3 scripts/docker/build_application.py
python3 scripts/docker/build_image.py --payload Release/OnlineCPU/build --image kssolv-toolbox:local
```

容器构建脚本默认不包含 GPU 计算依赖。它在临时源码副本中选择 CPU 实现，
不会修改工作区或上游子模块，并检查 Compiler 生成的依赖清单中没有必需 GPU Runtime。
编译前以 `-nojvm` 检查波函数拼接、FFT 往返及 CPU 模式拒绝启用 GPU。
默认产物位于 `Release/OnlineCPU/build`；`--include-gpu` 保留 GPU 实现，默认输出到
`Release/OnlineGPU/build`。`--output` 可以指定另一个空目录。
浏览器端的晶体三维视图需要可用的 WebGL。CPU/GPU 构建选项决定服务器的计算后端；
浏览器禁用 WebGL 时，文件和菜单仍可使用，但无法绘制三维结构；视图会显示渲染失败提示。
R2026b 的无桌面会话可通过 `--llm-addon /path/to/llms_with_matlab@4.9.0`
为本次构建显式加载已下载的 Add-On 包目录。MATLAB 始终以 `-nojvm` 启动。

`buildInstaller` 的第二个参数为 `false` 时，只生成完整独立应用载荷，不生成
安装程序；原有调用保持原行为。构建使用已有 `mcc -R -nojvm` 路径，不新增
C/C++、Fortran 或 MEX 实现。镜像构建脚本检查 ELF 架构和元数据，仅将独立
应用、Compiler 启动脚本及构建元数据复制进临时构建上下文，不会复制仓库
`.env`、凭证、下载的安装包和本地 Runtime 缓存。

基础镜像默认取编译时的发行版，例如
`containers.mathworks.com/matlab-runtime:r2026b`。可通过
`--runtime-image containers.mathworks.com/matlab-runtime:r2026b@sha256:...`
固定镜像摘要。容器启动会检查 Runtime 构建版本不得早于编译器版本。
默认镜像不含 GPU 库；需要 GPU 时应选择匹配发行版的官方 `-full` 镜像，
并单独验证 GPU 设备映射。

## 使用官方 API 生成精简 Runtime

采用 MathWorks 官方支持的选择性安装方案：
[`compiler.runtime.createDockerImage`](https://www.mathworks.com/help/compiler/compiler.runtime.createdockerimage.html)
根据应用编译生成的 `buildresult.json`，仅安装所需 Runtime 产品。
官方概览见 [Reduce MATLAB Runtime Size](https://www.mathworks.com/help/compiler/reduce-matlab-runtime-size.html)。
不手工删除官方镜像里的库，也不读取内部文件归属清单进行裁剪。
默认由官方 API 创建系统依赖层，并使用 MathWorks 的 Runtime 安装器镜像构建。
不要将完整 Runtime 镜像作为 `BaseImage`，否则完整 Runtime 的层仍会保留。

Linux 应用编译完成后，先生成构建上下文以便检查：

```sh
matlab -nojvm -batch "addpath('scripts/docker'); buildRuntimeImage('Release/OnlineCPU/build/buildresult.json', ImageName='kssolv-runtime:r2026b-kssolv', ExecuteDockerBuild=false);"
```

默认输出到 `Release/DockerRuntime/`，包括官方 `Dockerfile.runtime`、系统依赖
Dockerfile，以及记录清单、平台、版本和构建状态的 `kssolv-runtime-build.json`。
此步骤仅生成文件，不构建镜像。它可以在 macOS 上预览依赖，但不能据此认定
Linux 应用已经可用。

检查依赖后执行实际构建，再复用现有 Online 应用打包脚本：

```sh
matlab -nojvm -batch "addpath('scripts/docker'); buildRuntimeImage('Release/OnlineCPU/build/buildresult.json', ImageName='kssolv-runtime:r2026b-kssolv');"
python3 scripts/docker/build_image.py \
  --payload Release/OnlineCPU/build \
  --runtime-image kssolv-runtime:r2026b-kssolv \
  --image kssolv-toolbox:local
```

`buildRuntimeImage` 要求 MATLAB R2025b 或更新版本，并验证当前进程未启用 JVM。
实际镜像构建要求同一目录内有 Linux `-nojvm` 编译产生的 `runtime-metadata.json`；
仅有 macOS 产物时，允许生成上下文，但拒绝最终镜像构建。
应用与构建 Runtime 的 MATLAB 发行版必须一致。

默认使用 `IncludeGPU=false` 和 `OptionalDependencies="none"`；应用所需的必需图形
支持仍按 Compiler 清单安装。CPU 模式遇到包含 GPU 产品的清单会直接报错，不会
修改清单或强行删除依赖。需要 GPU 发行包时，先运行：

```sh
python3 scripts/docker/build_application.py --include-gpu
matlab -nojvm -batch "addpath('scripts/docker'); buildRuntimeImage('Release/OnlineGPU/build/buildresult.json', IncludeGPU=true, ImageName='kssolv-runtime:r2026b-gpu');"
python3 scripts/docker/build_image.py --payload Release/OnlineGPU/build --runtime-image kssolv-runtime:r2026b-gpu --image kssolv-toolbox:gpu
```

GPU 容器还需要宿主机 NVIDIA 驱动、容器 GPU 支持和设备映射（如 `--gpus all`）。
`IncludeGPU=true` 允许使用 GPU 编译清单；它不会把 CPU 应用变成 GPU 应用。
`OptionalDependencies` 不会删除编译清单中标为必需的产品，也不是禁用 JVM 的开关。

若构建节点无法访问 Docker Hub，可在本机拉取生成的 `Dockerfile.deps` 中指定的
官方 Ubuntu 基础镜像，再上传到构建节点导入缓存。以下以 Ubuntu 24.04 为例：

```sh
docker pull --platform linux/amd64 ubuntu:24.04
docker image save --platform linux/amd64 -o ubuntu-amd64.tar ubuntu:24.04
# 将 ubuntu-amd64.tar 传到构建节点，并核对传输前后的 SHA-256。
docker load -i ubuntu-amd64.tar
```

Docker Hub 不可用时，也可以使用 [Canonical 官方 Ubuntu OCI 仓库](https://ubuntu.com/docs/oci-registries/oci-how-to/getting-started/)
的 `public.ecr.aws/ubuntu/ubuntu:24.04`，在本机拉取后标记为 `ubuntu:24.04` 再导出。
无需修改主机全局 DNS 或重启 Docker。导入的是操作系统基础镜像，Runtime 依然由
官方 API 按应用依赖清单选择性安装。安装器镜像和 apt 软件源也需要可达或预先缓存。

2026-10-18 在同一台 Linux Docker 主机上用 `docker image inspect` 测得：
官方 R2026b CPU Runtime 为 7,890,815,207 字节；官方 API 根据本项目 CPU 清单
生成的 Runtime 为 3,326,695,135 字节，减少约 58%；Online 应用镜像为
3,411,145,930 字节（transcript-empty 构建，gpu6 Docker 的镜像大小）。CPU 清单包含 7 个 Runtime 产品，没有 Parallel GPU。
这些数值对应本次 R2026b 构建，后续版本应重新测量。
构建需为安装器镜像、临时安装目录及最终镜像预留充足磁盘空间。
生成上下文和依赖检查均不能替代真实 Linux Runtime 的 Online 功能验收。

## 本机运行

阅读并接受 [MathWorks Runtime 许可](https://www.mathworks.com/products/compiler/matlab-runtime.html)
后，可运行下面的 Compose 配置（其中已声明接受许可）：

```sh
docker compose -f scripts/docker/compose.yaml up -d
docker compose -f scripts/docker/compose.yaml logs -f
```

健康状态变为 `healthy` 后，打开 [KSSOLV Toolbox Online](http://localhost:8080/online)。
根路径 `/` 和 `/online/` 也支持直接访问。首次解包可能需要数分钟。
入口页通过同源 iframe 承载 MATLAB 会话，地址栏保持固定入口，不跳转到带参数的
内部地址。每次接入由 Runtime 事件循环生成新令牌，避免复用已经过期的启动地址。
MATLAB 所需的会话参数仍保留在 iframe 内，不写入容器日志。已有 WebSocket 时，
第二个入口或连接返回 409；关闭旧标签页后点击 Retry。刷新原标签页时，若旧连接
尚在释放，页面只自动重试一次；重复标签页不会循环抢占会话。
如将端口映射为 `18081:8080`，访问 `http://localhost:18081/online`；远程部署使用
对应的 HTTPS 域名，例如 `https://kssolv.example.com/`。启动日志也会提示入口格式。
`/healthz` 表示代理已经启动、会话 URL 已发布，不表示所有 UI 组件已渲染。

```sh
docker compose -f scripts/docker/compose.yaml ps
docker compose -f scripts/docker/compose.yaml down
```

命名卷 `kssolv-data` 保存 `/data`，包含用户主目录和工作目录 `/data/work`。
Online 镜像显式设置 `KSSOLV_USER_DATA_DIR=/data/preferences/KSSOLV_Toolbox`，
日志、缓存与加密凭证使用该目录；六项非敏感设置保存为权限 600 的 `preferences.json`。
不能仅依赖 `MATLAB_PREFDIR`：此 Runtime 实际的 `prefdir` 位于临时解包目录。
桌面模式仍使用原来的目录和 MATLAB preferences。重建容器时保留数据卷；新卷获得独立用户数据。
绑定宿主机目录时，需要预先赋予 UID/GID `10001:10001` 写权限。
Runtime 解包缓存保存在 `/data/cache/runtime`；临时会话文件及 nginx 配置保存在
`/tmp`，不会持久化。
容器以非 root 用户运行，Compose 关闭额外 capabilities 并启用只读根文件系统。

容器内 Xvfb 仅提供虚拟显示，不开放 X11 TCP 端口；浏览器流量通过 nginx
转发到同一容器内的 Connector，保留 nonce、Cookie 和 WebSocket。无需挂载
宿主机显示服务器。停止容器时，监督进程结束 Runtime、显示和代理进程组。
nginx 使用单进程，由容器监督进程恢复异常退出，避免 worker 崩溃后共享连接计数残留；
一分钟内最多恢复三次，持续失败则退出实例。Runtime 或显示进程退出会结束实例。
浏览器刷新或关闭标签页保留服务端应用。
Online 代理针对当前 Runtime 的 AppContainer 前端协议做三处兼容处理：区分 pagehide
和显式关闭，并在浏览器断开时保留服务端数据模型。再次进入 `/online` 时，应用重新创建
浏览器视图，恢复项目、已打开的结构及工作流、命令工作区和聊天上下文；建模草稿先同步
到内存中的项目。命令窗口的显示记录、流式回复和最近命令也保存在同一 Runtime 内存中，
页面重建后回放，不重新执行命令或发起模型请求；显示缓存最多 2,097,152 个字符，召回最多
200 条命令，较早的显示输出超限时会提示省略。撤销历史和完整布局不保证恢复，此机制也不替代项目
保存或容器退出后的磁盘恢复。原 Runtime 文件不修改；启动前确认三处协议片段都唯一，
否则明确报错，更新 Runtime 后必须重新验收。此处理只用于 Online 镜像，不改变桌面版
关闭行为。

## Linux 服务与后续 Kubernetes

Compose 默认只绑定宿主机 loopback。对外服务应通过带身份验证的 HTTPS
入口访问，并保留 WebSocket Upgrade。Connector 返回 Secure Cookie，远程
HTTP 域名不能可靠承载该会话；localhost 用于本机验证。建议给每个会话独立
子域名，将整个域名根路径转发到容器 8080，避免给 MATLAB 内部资源增加
未经验证的 URL 路径前缀。

未来的会话分配服务可为每位用户创建一个 Pod、Service、独立 PVC 和访问域名，
固定镜像摘要，限制 CPU/内存，并为其设置 NetworkPolicy、ServiceAccount 和
独立 Secrets。一个 Deployment 多副本负载均衡不能提供独立用户会话；同一
用户重连必须路由到原 Pod，且先结束旧客户端连接。nginx 限制每个实例的活动 WebSocket
及入口连接数为 1，在进入 Runtime 之前拒绝重复连接。项目导入、文件选择、导出和外部工具调用仍须进行
远程浏览器回归测试；当前没有实现租户控制面。

可设置 `KSSOLV_AUTH_FILE=/run/secrets/kssolv.htpasswd`，并将 nginx 密码文件以只读方式
挂载到该路径（UID 10001 必须可读）。启用后，入口、内部资源、下载和 WebSocket 均
验证实例凭证；仅 `/healthz` 公开。每个租户使用独立的高强度凭证和 Secret。外层仍需
可信 HTTPS 或受信任的 SSH 隧道，Basic Auth 本身不加密传输。默认 Compose 是本机验证
配置，未提供此文件时没有用户身份认证。支持的密码文件格式见
[nginx 官方文档](https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html)。

## Online 模式与文件

`isKSSOLVOnline()` 仅解析显式的 `KSSOLV_ONLINE` 环境变量（`1/true/yes/on`）。
`hostInBrowser` 本身可以用于本机浏览器托管，不等同于远程文件模式。
Docker 默认启用 Online；源码模式可在启动前 `setenv('KSSOLV_ONLINE','true')`。
标题显示为 KSSOLV Toolbox Online，客户端标题不显示服务端项目目录。

公共 UI 的文件入口统一经过 `kssolv.ui.util.FileDialog`。Chrome/Edge 在 HTTPS 或
localhost 下优先使用 File System Access API：Open 直接打开客户端原生文件选择器，
选择后自动上传读取。Save As 先写出并完整接收文件，再打开客户端原生保存窗口。
浏览器文件句柄只保留在当前页面，MATLAB 只接收文件名，不接收客户端磁盘路径。
用户取消原生窗口会取消操作。若用户激活已过期，显示紧凑按钮以重新打开原生窗口；
不支持该 API 的浏览器使用紧凑的文件输入/文件名界面和普通下载链接。
导入仍经现有 `uihtml` 事件逐块上传并确认，文件名不允许包含路径。
每个文件最多 128 MiB，每次上传最多 128 MiB、100 个文件；下载上限同为 128 MiB。
文件保留在会话临时目录。上传进度按服务端已确认字节计数，显示百分比、进度条和传输量。
Online 保存先使用建议文件名生成私有工作副本，写入完成后打开下载模态窗口。窗口准备文件时，使用 MATLAB 内置
`matlab.ui.internal.URLUtils` 即时生成包含 Connector nonce 和 CSRF token 的授权 URL，
立即流式取回数据，显示实际接收进度。HTTP 状态和完整字节数校验通过后，才允许打开
原生保存窗口并写入完整数据；网络失败、短响应及下载阶段取消不会触及客户端文件。
这是必要的保存顺序：showSaveFilePicker 确认替换时就会清空已有文件，不能依靠后续
createWritable.abort 恢复。原生保存与 Browser download 备用链接共用完整、校验后的 Blob。
用户激活已过期时显示 Save as… 按钮；普通下载完成后需点击 Finish 确认。
Connector 授权只可使用一次且会过期，不能将该 URL 长期放在下载按钮上。
准备失败时显示 Retry download，每次重试重新申请授权；不会将错误响应当作文件保存。
普通下载链接的完整数据在窗口内保留，支持停留后下载及重复点击，每个窗口最多占用 128 MiB 文件数据。
副本使用固定 ASCII 存储名，容器代理通过标准 UTF-8 `Content-Disposition` 提供原文件名，
避免 Connector 对特殊文件名返回 `Bad URI syntax`；只公开单独临时目录中的副本。
浏览器可能规范化文件名，例如将 `?` 替换为 `_`。
关闭下载窗口即删除副本，并释放该窗口的 Blob URL、取消未完成的数据请求。
浏览器下载目标由浏览器设置控制。
关闭项目/应用时选择保存，原生保存成功关闭写入流后才继续；普通下载模式需要在浏览器
完成下载后点击 Finish 才继续关闭。Cancel 保持项目打开。
会话临时文件不会因挂载 `/data` 而自动成为持久项目库。

Online 的 About、Settings、建模、文件、密码及确认窗口统一使用 `OnlineModal`。
它复用 MATLAB 随附的 `mw-dialogs/Dialogs` 模态组件，以 `divfigure` 和
`DivFigureFactory` 直接承载 MATLAB 控件；不会为对话框创建 FigureDocument。
背景遮罩、焦点限制、X/Escape 取消、嵌套窗口、尺寸变化和宿主销毁都有对应处理。
Online 外壳移除自身重复的内容边距，尺寸只额外计入标题栏和边框；各个 MATLAB
对话框原有的 Padding 和按钮布局保持不变，桌面模式不使用这段外壳处理。
设置、关于、许可、更新和 Materials Project 入口通过 `SessionDialog.open` 先显示
同一个页内窗口的转圈遮罩，再构建/更新控件；构建结束、客户端布局稳定后解除遮罩。
所有 Online 模态窗口初次渲染和复用时也会屏蔽尚未稳定的内容。
超过浏览器视口的参数窗口保留 MATLAB 的完整布局，由外层内容区提供滚动，
使长表单的底部按钮始终可达；桌面模式的尺寸和间距不变。

Open Log 在页内显示最近 512 KiB 的 UTF-8 日志，支持刷新和下载完整日志。
Settings 的 Test Connection 在容器中使用监督进程提供的 HTTP worker。
这是 Python 标准库线程服务，仅监听容器回环地址，使用每次启动随机生成的内部凭证；
端口和凭证仅注入应用进程，不通过 nginx 发布。MATLAB 以短请求查询状态，
避免 Runtime 中后台任务始终停在 `queued`。停止、关闭、重试会取消网络连接并删除任务；
连接/响应超时为 10 秒，客户端总期限为 20 秒。响应上限为 1 MiB，任务数量受限，
不跟随重定向，也不将提供商密钥明文写入文件、命令行或日志。普通 MATLAB 会话保留
原生后台 HTTP 路径；两条路径都不启动 Java/JVM。

聊天在收到 SSE 完成标记后才提交本轮历史。流式连接中途断开或回复因长度限制
被截断时显示失败提示，已显示的部分文本不作为完整回复写入历史；用户可重新发送。
应用不会静默重试并把两个响应拼接在一起。Settings 点击 OK 后，
下一次聊天会创建新客户端和历史。协议回归可在 Linux 上无 JVM 执行：

```sh
matlab -nojvm -batch "addpath(pwd); r=runtests('kssolv.services.llm.test.StreamResponseTest'); assertSuccess(r);"
```

Official Site、Documentation、Community 和快捷帮助都由客户端打开链接。
工具条可能为一次真实点击额外派发合成点击，链接桥仅处理可信的用户事件，
并在组件重建时清理旧监听，避免重复开页。官网提供的论坛仍使用 HTTP，
若 Chrome 显示安全连接警告，应由论坛维护方启用 HTTPS 后再验收站点内容。
Online 在主页面和嵌入页统一处理 Ctrl/Command+O、S、Shift+S、Z、Shift+Z 及 Ctrl+Y。
模态窗口阻止后台项目命令；输入框的撤销/重做保留给文本编辑。
快捷撤销/重做根据当前文档作用于结构或工作流；快捷保存与 Home Save 共用
项目及建模草稿保存路径。浏览器取消保存后项目仍保留未保存状态，可重试。
未选远程集群时，连接测试和远程命令执行显示为禁用。Online 的 Parallel
配置和同步计算 Stop 尚不可用，按钮明确禁用；普通桌面模式保持原行为。
Request Support 在浏览器真实点击或键盘激活事件中打开 `mailto:`，由客户端默认邮件
应用接管；使用独立浏览上下文，避免离开当前 Online 会话。邮件客户端是否可用由用户系统配置决定。
不支持原生保存时，通过普通可见链接保存已经完整取回的数据。上述路径已在 `-nojvm` 下验证，
不新增 Java/JVM 或编译型源代码。
MATLAB 内部下载接口仍需随版本验证。与 MATLAB Online 的托管文件空间及
Web App Server 的文件服务并非同一运行环境，不能仅通过环境标志冒充它们。

探针可使用 HTTP `/healthz`（端口 8080），startupProbe 至少预留 300 秒，
readinessProbe 复用该路径。以 UID/GID 10001 运行，PVC 使用匹配的 fsGroup，
并提供允许加载本地扩展的 `/data/cache/runtime`、可写 `/tmp` 和适量 `/dev/shm`。按照实际任务规模
设置资源限额；示例 Compose 的 `/tmp` 上限为 4 GiB、共享内存为 512 MiB。
外部 API 密钥在启动时注入环境或 Secrets，不要写入镜像。

## 验证

生产服务源代码位于 `server/runtime/`，`scripts/docker/` 保留构建、部署和数值验收入口。
镜像构建显式暂存三份运行服务文件；测试和本地诊断文件不会进入运行镜像。

```sh
python3 -m unittest discover -s scripts/docker/tests -p 'test_*.py' -v
node scripts/ui/tests/test_online_html_bootstrap.cjs
node scripts/ui/tests/test_online_download.cjs
node scripts/ui/tests/test_online_modal.cjs
node scripts/ui/tests/test_online_actions.cjs
node scripts/ui/tests/test_command_window.cjs
docker compose -f scripts/docker/compose.yaml config --quiet
```

在带 nginx 的 Linux 容器内运行上述 Python 测试，可实际检查固定入口页、会话参数
转义、Cookie 透传、下载文件名和 WebSocket Upgrade/数据转发；无 nginx 时该集成用例会明确跳过。
Node.js 测试检查 Online HTML 的初始化顺序和数据事件回放，不需要浏览器。
Command Window 测试使用 frontend 已有的 happy-dom，先按 frontend 说明安装依赖；
覆盖桥接早到/晚到、命令发送、`$`/`$$`、历史、补全、`clc`、重建后的无副作用回放，
以及流式回复续接和链接只执行一次。`CommandTranscriptTest` 和 `OnlineReconnectStateTest`
可在 Linux MATLAB `-nojvm` 下验证服务端缓存及重连状态。
Runtime 命令窗口支持已打包的函数及 Runtime 中可用的赋值、矩阵和内置运算；
它不承诺完整 MATLAB 开发环境或未打包工具箱。当前 Linux Runtime 中
`parfeval(backgroundPool,...)` 可长期停在 `queued`，不能据此认为后台计算可用。
Settings 因此使用上述独立网络任务服务。
文件回归测试覆盖原生打开/保存/取消、完整接收后才选择保存目标、用户激活失效后的重试，
以及下载授权重试、CIF/KS 重复保存、128 MiB 边界、上传 ACK/下载流进度、
完整字节数、写入失败/取消和窗口关闭清理。模态测试覆盖加载遮罩、消息合并及复用，
协议链接测试覆盖真实点击/键盘激活、合成点击过滤、主题编码、重复初始化及旧监听器清理。

回归测试不能代替实际 Linux 编译应用的端到端验证。发行前还需检查正常启动、
项目导入/保存、建模、计算、浏览器刷新与重连、进程退出、数据卷复用，并检查
Runtime 进程映射中没有加载 `libjvm`。本机源码 `-nojvm` 验证只能覆盖源码模式。

官方依据：

- [MATLAB Runtime 容器](https://www.mathworks.com/help/compiler/get-matlab-runtime-container.html)：
  从 R2025b 起不含 JRE，必须声明接受 Runtime 许可。
- [独立应用编译](https://www.mathworks.com/help/compiler/create-standalone-app-from-matlab-function.html)：
  可执行程序取决于构建平台。
- [Runtime 启动选项](https://www.mathworks.com/help/compiler/matlab-runtime-startup-options.html)：
  `-nojvm` 在编译时嵌入启动配置。

Online 文件参考：

- [Chrome File System Access API](https://developer.chrome.com/docs/capabilities/web-apis/file-system-access)：原生打开/保存窗口、用户激活和写入流的关闭语义。
- [Web App Server 文件访问](https://www.mathworks.com/help/webappserver/ug/access-files-on-matlab-web-app-server.html)：公开 uigetfile/uiputfile 在 Web App Server 环境下的上传和下载语义。
- [MATLAB Online 文件访问](https://www.mathworks.com/help/matlab/matlab_env/access-files-in-matlab-online.html)：托管文件空间与本机文件传输的区别。

保存顺序的规范依据：[showSaveFilePicker](https://wicg.github.io/file-system-access/#api-showsavefilepicker)。

### 持久卷与 Runtime 缓存

容器启动脚本在启动 Runtime 前将文件描述符软、硬上限限制为最多 65536，
并保留管理员设置的更低限制。部分 Docker/Kubernetes 宿主机传入超过 10 亿的
`RLIMIT_NOFILE`；Runtime 图形启动器会逐个关闭这些编号，造成首次绘图时
子进程长时间占用一个 CPU 核心、SCF 已完成但 Plot 节点持续等待。
排查时可检查 Runtime 进程的 `/proc/<pid>/limits`。此设置不需要 Java/JVM。

容器以 UID/GID 10001 创建 `/data/work`。Kubernetes 空 PVC 应设置
`runAsUser: 10001`、`runAsGroup: 10001`、`fsGroup: 10001`；升级旧卷时可使用
`fsGroupChangePolicy: Always` 修正已有目录的组权限。镜像从 `/data` 启动，再由应用用户
创建并进入工作目录，避免 CRI 自动创建不可写的 root 工作目录。

`MCR_CACHE_ROOT` 默认是 `/data/cache/runtime`。Runtime 会把 CTF 中的本地扩展提取到
该目录，因此该文件系统必须允许加载本地代码；`/tmp` 的默认 `noexec` 挂载不能用作
组件缓存。启动时会检查这一条件并报告错误。缓存可在停止容器后删除，下一次启动会
重新提取；它不是项目备份。参考 [MathWorks Runtime 缓存文档](https://www.mathworks.com/help/compiler/matlab-runtime-component-cache-and-deployable-archive-embedding.html)。

上传文件属于当前会话的临时文件，原生保存和下载把文件保存到客户端。需要容器重建后
保留服务端文件时，应写到 `/data/work` 等持久卷路径。建模恢复快照、配方、预设、项目模板及建模作业保存在显式数据卷目录中，
不跟随 Compiler 的版本缓存目录；
重建后重新打开已保存项目，再选择恢复草稿。命令工作区和聊天上下文目前只支持同一
Runtime 进程内的浏览器重连。

Linux 构建还需要预编译的 `patchelf` 工具，可通过 `--patchelf /path/to/patchelf`
指定（默认从 PATH 查找）。脚本仅在临时构建副本中把已有 MEX 的 MATLAB 绝对链接
改成 Runtime 可解析的库名，去掉构建机器的 RPATH，并记录原生库依赖和 SHA256。
不会修改仓库中的 MEX，也不编译或引入新的 C/C++ 源码；不认识的绝对依赖或 JVM
依赖会中止打包。编译前会用已知简单立方结构验证空间群 221。
