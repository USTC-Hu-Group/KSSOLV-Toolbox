# Windows 安装包

Windows 与 macOS 都采用两阶段流程：先运行 `buildInstaller()` 生成 MathWorks
基础安装包，再运行平台脚本生成最终分发包。Windows 使用 Inno Setup 7，安装
最后一步执行完整桌面预热；macOS 使用 `scripts/macos` 的 PKG 流程分发 Swift
启动宿主及同一份 HTML 卡片，并沿用安装后的预热。

## 构建

需要 MATLAB Compiler、项目所需 Add-On、Inno Setup 7 和 Windows 自带的
.NET Framework 4.x 编译器。可用 `winget install --id JRSoftware.InnoSetup.7 -e`
安装 Inno Setup，或设置环境变量 `KSSOLV_ISCC` 指向 `ISCC.exe`。
构建机还需 WebView2 Runtime，用于将共用 HTML 渲染成中英文首屏 PNG。

第一阶段，在 MATLAB 的项目根目录运行，生成基础安装包：

```matlab
buildInstaller();             % MathWorks 联网基础安装包
buildInstaller("installer"); % MathWorks 离线基础安装包，需要 Runtime 安装源
buildInstaller("none");      % MathWorks 仅应用基础安装包
```

基础包输出为 `Release/StandaloneDesktopApp/KSSOLV_Toolbox_V<版本>.exe`，
载荷较大时 MathWorks 会输出 `.zip`。此阶段不调用 PowerShell 或 Inno Setup，
不要求安装 Inno Setup，也不会自动生成最终 Windows 分发包。

第二阶段，在 PowerShell 中单独运行：

```powershell
.\scripts\windows\package_installer.ps1
```

第二阶段完全不启动 MATLAB，也不要求 MATLAB 在 PATH 中。
RuntimeRelease 和 RuntimeVersion 从基础构建产物 `build/runtime-metadata.json`
自动获取，无需手动传入。
该文件由 `buildInstaller()` 记录实际 MATLAB 构建环境，包含应用版本；打包脚本
拒绝缺失、版本不符或早于编译产物的元数据，不根据本机其他 MATLAB 版本猜测。
它检查基础包中的应用 SHA-256 与当前编译产物一致，再由
`installer/RuntimePayload.cs` 复用 MathWorks 的安装引导程序和 Runtime 载荷。
EXE 基础包读取原生资源；大型 ZIP 基础包读取 `data/bundle.zip` 和
`data/InstallAgent.zip`。只把应用安装清单精简为 Runtime 专用清单，原样保留
`MCRProducts` 依赖列表和完整的 Runtime 组件载荷，不重复下载或生成组件。
ZIP 解压会检查路径边界。每次使用独立暂存目录，不修改基础包。

默认 `-RuntimeDelivery auto` 自动沿用基础包的 web / installer / none 模式。
离线基础包直接复用已经包含的 `InstallAgent.zip`；联网基础包直接复用下载地址。
显式指定不匹配的模式会报错，需先生成对应基础包。`-RuntimeDelivery none`
可以主动省略 Runtime 载荷。此前重复生成载荷的 `prepareRuntime.m` 已移除。
预热仍由最终安装包在用户安装末尾执行。

最终输出 `Release/StandaloneDesktopApp/KSSOLV_Toolbox_V<版本>_Windows.exe`。
第一阶段 `buildInstaller("installer")` 后，第二阶段无需参数即可生成离线分发包。
离线包启用分卷，必须一起分发同名 `.bin` 文件。仅复用已有 Runtime 时指定
`-RuntimeDelivery none`。
版本统一从 `KSSOLV_Toolbox.Version` 自动获取，无需在脚本或界面填写。
打包前核对已编译 EXE 的版本；不一致时拒绝打包，需要重新运行 `buildInstaller()`。

## 日常启动卡片

快捷方式仍指向 `KssolvLauncher.exe`。打包时直接渲染共用的
`scripts/startup/index.html`，生成带项目版本的中英文首屏 PNG。启动器先用原生窗口
绘制匹配语言及版本的 PNG，同时提供可用的关闭按钮；首屏绘制后立即启动
Runtime，并行初始化 WebView2。HTML 画面就绪后替换首屏，继续显示动态进度和子状态。
没有匹配版本的首屏资源时兼容使用原有 HTML 路径，不显示其他版本的图像。
HTML、logo 和材料科学主视觉会随 Inno Setup 安装到应用的 `startup` 目录，无需联网加载内容。
卡片使用两端共用的 800 × 494 布局，长宽比约 1.6194，接近黄金比例：左侧为品牌、产品标题和启动信息，右侧为深蓝
晶格与电子密度曲面插画。图像来源和提示词见 `scripts/startup/README.md`。
按 Toolbox 保存的 Locale 显示中英文，配置缺失时才回退到环境及系统语言。
上方固定显示启动主提示，下方灰色子状态按确认的 25 条文案顺序更新，始终单行显示；
不显示启动耗时或估算百分比。艺术图完全固定，进度段按每个渲染帧更新 transform。
左侧显示从 `KSSOLV_Toolbox.Version` 生成的配置版本号及完整中英文公司名的版权信息。
版本由宿主读取 `launcher.ini` 后传给页面，HTML 不写死版本号。
文字使用 Segoe UI，中文优先微软雅黑 UI；标题 36 px、主信息 14 px、辅助信息 12 px。
启动器嵌入系统 DPI 感知清单，按实际像素创建窗口，避免高 DPI 下整窗位图拉伸。
构建会下载校验固定版本的 WebView2 SDK，Inno 随附两份托管程序集、x64 loader 和
完整 SDK 许可。启动时只复用系统已有的 WebView2 Runtime，不在线安装组件；缺少该
运行时的旧系统使用 MSHTML 兼容路径，该路径无法保证 120fps。高刷显示器上优先路径
没有 25/60/120fps 人为上限，实际频率取决于渲染器、刷新率和系统负载。
文案采用确认的 25 条中英文提示，上方固定显示“正在启动 KSSOLV Toolbox”。
按用户要求，前 23 条以加权随机时长顺序推进，每次启动重新生成约 24–27 秒的
展示计划，随后停留第 24 条，不循环。文案是预计展示阶段，与实际窗口交接信号分开。
主窗口提前就绪时跳过剩余预计阶段，交接前依次绘制第 24、25 条，各经过两个动画帧；
确认已绘制后立即交接，不为播完计划而等待，不设置额外固定停留。
`presentation` 日志记录计划、实际展示顺序和末两条绘制确认，宿主存活检查不改写文字。
关闭按钮在原生预览和 HTML 两层均不显示聚焦高亮，保留悬停、点击取消。
原生首屏及共享 HTML 均不绑定 Escape 取消，避免误触中断启动。
MATLAB 端仅在 deploy 且存在本次启动的握手参数时控制窗口交接。工具条及面板
配置仍在创建原生窗口前完成；原生窗口创建后即发布 `shell-ready`，收到确认后显示
主窗口并关闭卡片，不等 Project Browser 完全加载。主窗口保留忙碌状态，后续渲染
完成后解除。`startup-loaded.json` 以本次 nonce 记录完整加载，独立于卡片交接，供验收
检查提前显示后仍能正常完成启动。该文件位于本次用户及构建的 RuntimeCache 目录。
用户取消、应用失败或超时会清理本次启动的 Runtime 子进程。

第一阶段必须使用包含 `StartupProtocolVersion=1` 的新构建元数据，避免新启动器
等待旧 EXE 不会发送的信号。普通 MATLAB 运行和安装阶段的 `--prewarm` 不显示卡片。
协议测试运行 `scripts/windows/tests/Test-StartupSplash.ps1`；安装后的真实应用统一验证：

```powershell
.\scripts\windows\tests\Test-InstalledStartup.ps1 -ApplicationRoot '<实际应用安装目录>' -Runs 3
```

该验证在测试专用进程组内启动 Toolbox，确认提前交接及完整加载后关闭本次测试的应用进程。
安装包文件名、中英文版本标签、Windows 版本信息和启动器配置均使用该版本。
Runtime 版本与应用 SHA-256 从当前构建产生，不能混用不同构建的启动器配置。

仅修改安装界面时，直接重跑第二阶段即可，无需重新运行 `buildInstaller()`。

## 安装与界面

默认安装供所有用户使用，需要 UAC。也可通过 `/CURRENTUSER` 安装到当前用户
可写的路径；此模式复用现有 Runtime 无需管理员权限，安装新 Runtime 时仍需 UAC。

安装器包含简体中文和英文，按系统语言选择，也可通过 `/LANG=zh`、`/LANG=en`
选择。界面使用 Segoe UI / Microsoft YaHei UI，760 × 480 逻辑像素布局，
200 宽浅色侧栏和 496 宽正文，全部页面共用标题、表单和按钮对齐线。
侧栏使用仓库官方 `companyLOGO.png`，安装器、启动器和快捷方式的 ICO 从原图
H 标志等比例转换，不重新绘制品牌。`installer/assets/crystal.png` 是内置 imagegen
生成的晶体插画，按 3:4 原比例显示；生成提示词见同目录 `README.md`。
用户界面仅显示常规安装与配置状态，不展示预热、缓存及内部就绪检查细节。
布局在 `installer/Design.iss`，中英文文案与安装逻辑在 `installer/KSSOLV.iss`。
保持原生键盘导航、文字控件和 DPI 缩放；不依赖第三方美化 DLL。

应用目录和新 Runtime 目录可以分别选择任意本地盘符。例如应用安装到
`E:\Apps\KSSOLV Toolbox`，Runtime 安装到 `E:\MathWorks\MATLAB Runtime`。
Runtime 目录只支持 ASCII 字符，实际 Runtime 位于该目录下的 `R2026b` 子目录。
已检测到的 Runtime 可以复用，安装后通过完整图形预热检查实际可用性。

预热和快捷方式都使用 `KssolvLauncher.exe`，共享相同的进程级 Runtime PATH 和
当前用户的 `MCR_CACHE_ROOT`。缓存位于
`%LOCALAPPDATA%\KSSOLV Toolbox\RuntimeCache\<Runtime release>\<build hash>`，
不写入应用安装目录；非 C 盘安装不会改变 Windows 用户目录及系统临时目录的位置。
启动器不修改系统或用户的 PATH 环境变量。

安装最后一步必须满足：

1. 在运行安装器的原始 Windows 桌面用户会话中启动 `--prewarm`。
2. MATLAB 应用等待完整 UI 就绪，关闭界面后写入带本次随机 nonce 的就绪文件。
3. 应用正常退出（退出码 0），启动器核验就绪文件，再写入成功标记。
4. 安装器同时检查启动器退出码和当前构建的成功标记后，才显示安装完成。

最长等待 15 分钟。失败可重试，静默模式返回非零退出码；没有就绪信号、非零
退出码、旧 nonce 均不算成功。超时/失败时 Windows Job Object 回收该次预热的
Runtime 子进程，不影响其他应用实例。系统服务的 Session 0 不支持完整图形预热，
因此应在实际使用者的交互式桌面会话中运行安装器，而非 SYSTEM 部署任务。

预热是把一次性初始化提前到安装阶段，并不保证后续启动没有 Runtime 初始化时间。
每个 Windows 用户及每个新构建拥有独立缓存；安装时只预热当前用户。

## 静默安装

以下命令显式接受工具箱与 Runtime 许可，需在交互式桌面用户会话中执行。
首次安装 Runtime 时安装器需要管理员权限。路径应使用实际的本地盘符。

```powershell
$installer = Get-ChildItem .\Release\StandaloneDesktopApp\KSSOLV_Toolbox_V*_Windows.exe |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
& $installer.FullName /VERYSILENT /SUPPRESSMSGBOXES /NORESTART `
  /LANG=zh /DIR="E:\Apps\KSSOLV Toolbox" `
  /RUNTIMEFOLDER="E:\MathWorks\MATLAB Runtime" /REUSERUNTIME=no `
  /ACCEPTRUNTIMELICENSE=yes /LOG="E:\Logs\kssolv-install.log"
```

已有 Runtime 时可省略 `/RUNTIMEFOLDER` 和 `/REUSERUNTIME=no`。不指定
`/ACCEPTRUNTIMELICENSE=yes` 时，静默安装拒绝继续。

安装日志包含 `KSSOLV_INSTALL_PREWARM_OK`；应用目录的 `installation-state`
保存每次预热的 JSON 结果，用户缓存目录保存 `prewarm.log` 和
`prewarm-success.json`。成功记录包含用户 SID、Runtime 路径、应用完整 SHA-256、
缓存位置和耗时，便于区分同版本不同构建。

卸载只移除应用、快捷方式和安装状态，不删除共享 Runtime 或用户缓存。
运行中的应用会由 Inno Setup 的 Restart Manager 提示处理。

## 验证

```powershell
scripts/windows/tests/Test-Launcher.ps1
scripts/windows/tests/Test-StartupSplash.ps1
# 在至少 120Hz 的显示器上验证高刷新目标：
scripts/windows/tests/Test-StartupSplash.ps1 -MinimumAnimationFps 120
# 安装后的真实 Runtime 验收（测试退出后只清理本次启动的进程）：
scripts/windows/tests/Test-InstalledStartup.ps1 -ApplicationRoot 'E:\Apps\KSSOLV Toolbox' -Runs 3
# 截取实际 WebView2 渲染像素；临时 Locale 夹具在测试结束后恢复：
scripts/windows/tests/Test-InstalledStartup.ps1 -ApplicationRoot 'E:\Apps\KSSOLV Toolbox' -Locale zh_CN -Capture -Runs 1
# 等待人工点击卡片右上角关闭按钮，核对后台进程树退出：
scripts/windows/tests/Test-InstalledStartup.ps1 -ApplicationRoot 'E:\Apps\KSSOLV Toolbox' -ManualCancel -Runs 1
scripts/windows/tests/Test-RuntimePayload.ps1
python scripts/windows/tests/Test-PlatformScope.py <本次变更之前的提交>
```

启动器测试覆盖正常预热、进程失败、缺少就绪信号、旧 nonce、子进程回收与父进程
环境变量不变。平台测试比较非 deploy 实际执行语句，覆盖共享启动入口、Toolbox
构造和显示。HTML 宿主测试另检查阶段补齐、中英文、版权完整及排版、原 logo、
动态进度段的逐帧更新、艺术图静止、握手顺序和旧 nonce 拒绝，并覆盖旧系统
兼容宿主。`.animation` 文件记录回调/样式更新频率和帧间隔，不等同于 GPU 实际扫描输出。
安装后验收另输出逐次 JSON、timings.csv 和可选的原生 PNG；截图用例在同一安装目录中
临时编译诊断入口，调用实际启动器入口和已安装的完整 Toolbox，其他用例使用原始启动器。
正常用例检查主窗口可见后才关闭卡片；取消用例检查后台父子进程均退出。

MATLAB 入口和 Toolbox 构造函数不包含逐阶段的卡片进度埋点，保持原有初始化逻辑。
窗口显示边界只调用一次 `StartupSplash.tryShow(this)`，组件内部集中处理 deploy
判断、主窗口尽早交接及完成诊断；非 deploy 立即返回，不操作窗口。中英文子状态由
共享 HTML 独立调度。宿主仅处理 `shell-ready`、`visible` 和 `failed` 三种信号，
不再转发细粒度进度或向页面发送心跳。

卡片语言使用 Toolbox 当前 Locale。部署程序加载或保存设置时，将解析后的语言同步到
`%APPDATA%\KSSOLV Toolbox\startup.json`；原 MATLAB 首选项仍是设置来源，安装预热会
生成此文件，文件只包含协议版本和语言。启动器优先读取它，其次为 `KSSOLV_LOCALE`
和系统语言，安装器界面语言不覆盖用户的 Toolbox 语言。非 deploy 不写这份文件。

Runtime 载荷测试使用实际联网基础包，以及离线 EXE / ZIP 格式夹具，检查组件
清单不变、离线 agent 字节不变、原始基础包不变、应用 SHA-256 匹配、分发模式
匹配和 ZIP 路径越界拒绝。夹具不包含可安装的真实离线 Runtime；完整离线安装
仍需用真实 `buildInstaller("installer")` 产物验证。

`matlabruntime_license_agreement.pdf` 是 MathWorks Runtime 随附的原始许可文件，
未经修改；工具箱许可仍使用仓库 `LICENSE`，第三方声明一并随安装包分发。
