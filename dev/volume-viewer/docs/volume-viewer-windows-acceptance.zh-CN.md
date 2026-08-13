# Volume Viewer Windows 发布验收执行单

本执行单用于完成详细开发计划中的 P12.7。它必须在与 macOS 候选版本完全相同
的提交上执行，普通浏览器测试不能代替 MATLAB `AppContainer + uihtml`。

## 1. 环境登记

执行前记录：

- Windows 版本和补丁号；
- MATLAB 版本、Update、安装路径和许可证类型；
- GPU 型号、驱动版本、DPR/缩放比例和显示分辨率；
- Node.js、pnpm 版本；
- Git commit、工作树是否干净；
- `feature('WebWindowType')`、WebGL renderer 和
  `MAX_3D_TEXTURE_SIZE`。

验收：以上字段不得为空；MATLAB 必须属于项目声明支持的版本；候选 commit
必须与 macOS 验收记录一致。

## 2. 干净构建与自动测试

在 PowerShell 中运行：

```powershell
cd frontend
pnpm install --frozen-lockfile
pnpm -r test
pnpm --filter @kssolv/volume-viewer typecheck
pnpm --filter @kssolv/volume-viewer build
pnpm sync:runtime
```

回到仓库根目录，在 MATLAB 中运行计划规定的 VolumeIO、CommonIO、
VaspOutputs frozen oracle、Crystal/Molecule Scene Builder、Babel inventory
和 Molecule 测试，并对所有本次修改的 `.m` 文件执行 `checkcode(..., '-id')`。

验收：

- 所有前端测试返回 0；
- MATLAB 无失败测试；外部 `pymatgen` oracle 若因环境缺失被 assumption
  filter，必须单独登记，不能计为通过；
- Code Analyzer 为 0 issue；
- `dist` 与 `@VolumeDisplay/VolumeViewer` 的相对文件清单和 SHA-256 完全一致；
- entry gzip `<250 KiB`，所有 JavaScript gzip 合计 `<750 KiB`。

## 3. 七个真实产品场景

每个场景都从完整 `kssolv('', false)` 启动，并使用 production runtime。

1. 打开 `CHGCAR.nospin.gz`：应为 `32×32×32`、1 channel，等值面、切片、
   direct volume 均可切换。
2. 打开 `CHGCAR.spin.gz`：应为 `48×48×48`、4 channels；切换 total/diff/
   up/down 100 次，最终 channel 和阈值不得 stale。
3. 打开 `elec.cube.gz`：应为 `23×23×24`、1 channel；原点、非正交 voxel
   vectors 和 Å/Bohr 规范化与 oracle 一致。
4. 打开 `datagrid_3d.xsf`：应为 `2×2×2`、1 channel；I/J/K 切片方向和
   世界坐标与 oracle 一致。
5. 在加载/等值面计算过程中关闭文档，再立即打开第二个文件：旧 request、
   Worker、dataset 和 GPU 对象必须释放，第二个文件正常显示。
6. 触发 WebGL context loss/recovery；在不支持 WebGL2 的机器上走
   Canvas2D fallback：至少保留晶格切片与 PNG/CSV 导出。
7. 打开损坏文件、超限维度文件和不支持格式：显示可操作的本地化错误，主程序
   不永久 Busy，不泄漏普通用户不需要的调用栈。

验收：七项逐项保存实际 dimensions/channelCount、状态文本和截图；任何 blank
viewport、无限 spinner、stale scene、崩溃或不可恢复 Busy 均为失败。

## 4. 交互、性能与长期稳定性

- 50 次打开/关闭同一文档；
- 200 次连续阈值变化；
- I/J/K、相机旋转/缩放/平移、Space 拟合和信息简洁模式；
- 运行 30 分钟 soak，每 5 分钟执行一次真实 context loss/recovery。

验收：

- `128³` decode + 首等值面 `<2 s`，切片和热缓存 `<100 ms`；
- orbit `≥30 FPS`，峰值内存 `<400 MiB`；
- 第 50 次稳定 heap 相对第 10 次增长 `≤10%`；
- `renderer.info.memory` 回到允许基线；
- 30 分钟 0 应用错误、0 stale result、0 无限 spinner。

## 5. 证据归档与签收

归档环境登记、命令输出、MATLAB 日志、浏览器错误日志、性能表、截图、runtime
checksum 和未解决问题清单。S0/S1/S2 必须为零；S3 必须注明责任人和目标版本。
Windows 执行者与发布负责人分别签名后，P12.7 才能标记完成。
