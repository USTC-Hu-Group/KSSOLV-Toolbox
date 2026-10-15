# Windows 安装包

Windows 与 macOS 都采用两阶段流程：先运行 `buildInstaller()` 生成 MathWorks
基础安装包，再运行平台脚本生成最终分发包。Windows 使用 Inno Setup 7，安装
最后一步执行完整桌面预热；macOS 的基础打包及 `scripts/macos` PKG 流程不变。

## 构建

需要 MATLAB Compiler、项目所需 Add-On、Inno Setup 7 和 Windows 自带的
.NET Framework 4.x 编译器。可用 `winget install --id JRSoftware.InnoSetup.7 -e`
安装 Inno Setup，或设置环境变量 `KSSOLV_ISCC` 指向 `ISCC.exe`。

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
scripts/windows/tests/Test-RuntimePayload.ps1
python scripts/windows/tests/Test-PlatformScope.py <本次变更之前的提交>
```

启动器测试覆盖正常预热、进程失败、缺少就绪信号、旧 nonce、子进程回收与父进程
环境变量不变。平台测试比较非 Windows 实际执行语句，并检查 Mac 脚本及共享启动
入口未修改。仍需真实安装包测试完整 MATLAB Runtime 和界面。

Runtime 载荷测试使用实际联网基础包，以及离线 EXE / ZIP 格式夹具，检查组件
清单不变、离线 agent 字节不变、原始基础包不变、应用 SHA-256 匹配、分发模式
匹配和 ZIP 路径越界拒绝。夹具不包含可安装的真实离线 Runtime；完整离线安装
仍需用真实 `buildInstaller("installer")` 产物验证。

`matlabruntime_license_agreement.pdf` 是 MathWorks Runtime 随附的原始许可文件，
未经修改；工具箱许可仍使用仓库 `LICENSE`，第三方声明一并随安装包分发。
