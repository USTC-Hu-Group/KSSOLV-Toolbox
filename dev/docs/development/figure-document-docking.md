# 独立应用 FigureDocument 自动浮动调查

调查日期：2026-10-14。实测环境：macOS arm64，MATLAB 与 MATLAB Runtime 均为
R2026b `26.2.0.3386108`；已安装 KSSOLV Toolbox 0.4.1。

## 结论与修复

已通过独立编译的最小程序重现并修复。Runtime 默认关闭内部设置
`matlab.ui.figure.DockFigureInDeployment`，原生图形属性设置路径因此不能保留
`Figure.WindowStyle="docked"`。FigureDocument 的 Document 模型最初仍是
`Docked=true`，但它持有的 Figure 已经是 `WindowStyle="normal"`；前端启动后
依据 Figure 的窗口样式将文档同步为浮动。这发生在加载工作流 HTML 之前。

在创建 AppContainer、FigurePanel、FigureDocument 前执行：

```matlab
if isdeployed
    s = settings;
    s.matlab.ui.figure.DockFigureInDeployment.TemporaryValue = true;
end
```

实现位于 `+kssolv/+ui/+util/configureFigureDocumentDocking.m`，由
`kssolv.KSSOLVToolbox` 构造函数最开始调用。这样覆盖 Workflow、MoleculeDisplay、
DataPlot、VolumeDisplay 及各 FigurePanel。TemporaryValue 只影响当前会话，不改永久
用户设置；MATLAB 非部署模式直接返回。

这是一项内部 MathWorks 设置，而非公开支持的稳定 API。当前版本已经实测；不能
承诺未来 Runtime 不改变它。若设置不可用，会产生
`KSSOLV:UI:FigureDocumentDockingUnavailable` 警告，现有逐文档补救仍保留。
该兼容分支不代表旧补救能在所有未来版本奏效。

## 证据与因果链

1. Project Browser 双击进入 `createWorkflowItem()` 或已有文档的
   `showWorkflowDisplay()`，最终进入 UI `Workflow.Display()`。
2. `FigureDocument` 构造函数设置 `Document.Docked=true`，并设置
   `Figure.WindowStyle='docked'`。`IgnoreDockingRestriction` 是该类本身添加的动态
   属性；实测部署模式下它存在，但不能解除本次原生限制。
3. REA/Hopper 在 Runtime 的 `bin/maca64/libmwhg.dylib` 中识别
   `gbtobjects::isDockingEnabled()`，地址 `0x1a37c8`。其反编译结果读取
   `matlab.ui.figure` 组的 `DockFigureInDeployment` 布尔设置。调用者包括
   `Windowable::setWindowStyleImpl`、`Figure::WindowStylePostSet` 和
   `Figure::PostSetInitialize`。这提供了开关位于原生图形路径的证据。
4. Runtime 发货 JS 的 `UIContainerFigureController._setWindowStyleFromServer`
   根据 `WindowStyle==='docked'` 计算并写回 `IS_DOCKED`。FigurePanel 有强制停靠
   的特殊处理，因此左侧浏览器能正常停靠并不说明 FigureDocument 也能正常停靠。
5. 同一编译程序仅改变该会话设置，初始 `normal` 变为 `docked`，文档渲染后也保持
   `Docked=true`。这组对照实验确认了开关对实际故障的因果作用。

MathWorks 确实有显式的部署停靠开关。现有证据足以解释技术行为，不能判断其商业
动机，也不能将传统 MATLAB Desktop docking 的限制直接等同于 AppContainer
嵌入文档必须浮动。

## 实测对照

| 环境 / 操作 | 构造后 Figure.WindowStyle | 渲染稳定后 Document.Docked |
| --- | --- | --- |
| MATLAB，默认设置 false | docked | true |
| Runtime，默认设置 false | normal | false |
| Runtime，add 前再次设置 WindowStyle 与 Docked | normal | false |
| Runtime，渲染后设置 Docked=true | normal | 再次变为 false |
| Runtime，创建前 TemporaryValue=true | docked | true |
| Runtime，调用项目中的修复函数 | docked | true |

修复后的部署探针还验证了连续创建三个文档，以及主动浮动后再停靠：均通过。
MATLAB 对照运行保持设置为 false，文档仍正确停靠；现有
`DeploymentCompatibilityTest/prewarmRendersApplicationAndCleansUp` 通过。
新增函数和探针的 MATLAB Code Analyzer 检查无问题。

旧的 `waitfor(FigureViewReady)` 后 redock 会触发前端销毁/重建，再次接收 `normal`
并浮动；日志中可观察到重复 FigureViewReady 状态变化。延长 pause 或永久强制
Docked=true 的监听器不能解决根因，后者还会破坏用户主动浮动的行为。

## REA 证据索引

完整输出保存在本次工作区的 `.codex_tmp/figure-docking-20261014/`。
下列是实际返回的 REA Evidence ID；运行探针日志是普通 MATLAB/Runtime 观测，
不是 REA 原生运行捕获。

- `native-dockpolicy-rea.json`：
  `ev_f36b03e1c495d65e68d212a391a0d4596611ee84120b0377dbf93128b38c2008`。
  原生 `isDockingEnabled()` 反编译、引用字符串、调用者。
- `native-windowstyle-setter-rea.json`：
  `ev_f73a96fb5f67beec1677e2493d6ca488767d263f6fbeab7c296f84674409e31e`。
  `Windowable::setWindowStyleImpl`，地址 `0x37b50`，包含停靠开关调用、
  `IgnoreDockingRestriction` 与 `DockingUnsupported` 字符串引用。
- `native-windowstyle-postset-rea.json`：
  `ev_da1d6963e02bf0ce0a30bae87cc74de9f9b82a3f5997dda88edd44d5a410c891`。
  `Figure::WindowStylePostSet`，地址 `0x432b8`，同样检查原生停靠开关。
- `native-docksetting-search.json`：
  `ev_2ed1f98260cb93dc2308b42d1047df6871cf01e123d0b61102b263d571d77921`。
  设置字符串地址 `0x4c0322`。
- `native-docksetting-xrefs.json`：
  `ev_c10afdc3aeffe728b4ffee098f93a5a6e934a30658711abb4b60696d98f62327`。
  设置字符串交叉引用 `0x1a38a0`、`0x1a38a4`。
- `runtime-uicontainer-rea.json`：
  `ev_42a8d9362478b9b2bdeae6aa6c94f7313aea3b3658441956b834a9539b439e76`。
  Runtime figureuicontainer JS 静态分析。解析无错误，但大包超出关系展开预算，
  应用图及语义覆盖为 partial；不能用这份结果声称没有其他路径。
- `installed-launcher-rea.json`：
  `ev_d3cf03563d2afe3b8a5c4ae02b01561fd474c576b63813e99b94b43c14ad821d`。
  已安装应用启动器为 arm64 Mach-O 的身份信息。

`libmwhg.dylib` SHA-256：
`f1d24e99a57f0ff61685420f277c897e90f50c2ac7056af6b854bf7e44cdd533`。
Hopper 输出是恢复的伪代码，不是原始 C++ 源码；不能从静态分析声称已经观察到
Windows 执行。REA 6.4.0 通过本机缓存的 CLI 使用；本次没有修改 Codex MCP 配置，
没有修改 MATLAB/Runtime 二进制或已安装应用。

## 可重复执行的回归检查

在干净的 MATLAB 会话中，从仓库根目录运行：

```matlab
addpath(pwd);
addpath(fullfile(pwd, 'dev', 'deployment'));
dockingProbe("fixed", fullfile(tempdir, "desktop-docking.json"));
buildDockingProbe(fullfile(pwd, '.codex_tmp', 'docking-regression'));
```

在 macOS 上，用生成的 `run_dockingProbe.sh` 启动：

```sh
<output>/run_dockingProbe.sh <MATLAB_Runtime/R2026b> fixed <absolute-output.json>
```

在 Windows 上，在对应 Runtime 已安装的环境中运行生成的 EXE：

```powershell
& '<output>\dockingProbe.exe' fixed '<absolute-output.json>'
```

默认 `fixed` 模式会调用真正的项目修复函数，检查三个文档初始停靠及主动浮动/
再停靠，并输出 JSON。失败写入 `error` 后抛出异常。`baseline`、`preadd`、
`redock` 模式用于重复故障对照。每次使用新进程，避免 TemporaryValue 污染对照。
测试窗口会短暂显示；对照模式的浮动窗口可能导致 Runtime 进程在日志写入后仍
存活，确认 JSON 已写入后只关闭该探针进程。

## 验证范围与发布状态

macOS R2026b 的最小复现与项目修复函数已在真正的编译后程序中运行。
Windows 本次没有本机或远程运行环境，提供了同一探针的 Windows 编译路径，尚未
执行 Windows 验收。该修复不含操作系统专用分支，Windows 适用性有共同设置与
图形架构依据，仍应以 Windows 实测为准。

本次修改的是仓库源码；已安装的 KSSOLV Toolbox 0.4.1 不会因此自动更新。完整
应用需要重新运行现有 `buildInstaller` 流程并安装新产物。完整安装包、签名/
公证、Project Browser 的端到端点击以及其他 MATLAB 版本尚未验收，因此这里
不宣称所有平台和未来版本已“完美解决”。
