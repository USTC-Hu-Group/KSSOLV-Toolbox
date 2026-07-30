# KSSOLV 三维体数据查看器用户指南

## 打开数据

在 Project Browser 中双击 `Volume` 文件夹，选择 VASP
`CHGCAR/CHG`、Gaussian Cube (`.cube/.cub`) 或 XCrySDen (`.xsf`)
文件；`.gz` 压缩文件可以直接打开。文件会进入独立的 `Volume`
文档，不再经过分子或晶体字符串解析器。

大网格会先显示保持物理范围不变的 LOD 预览，再由 MATLAB 分块发送全分辨率
Float32 数据；新请求或关闭文档会立即取消旧传输。左下角状态会显示接收、错误或
GPU 降级原因。

## 显示和交互

- 左键拖动旋转；滚轮缩放；右键拖动平移。
- 空格键只重新居中和拟合缩放，不改变当前观察方向。
- `I` 键切换简洁模式，同时隐藏左上角数据摘要、右下角数值分布图和工具栏。
- 双击体数据可显示笛卡尔坐标、网格坐标和插值数值。
- 右下角 `VALUE DISTRIBUTION` 显示当前通道的数值直方图；在等值面模式下，
  点击柱状区域可快速设置阈值，负值设置负等值面阈值，其他值设置正等值面阈值；
  在切片和直接体渲染模式下，点击会调整距离点击值最近的颜色范围端点。
- Settings 中可选择等值面、I/J/K 晶格方向切片或 GPU 直接体渲染。
- Atoms、Bonds、Unit cell、Coordination polyhedra 和 Lattice axes
  控制结构叠加。

切片遵循体素矢量，不把非正交 XSF 网格误当成 XYZ 正交平面。线性索引始终为
`x + nx * (y + ny * z)`。

## 通道

- 非自旋 CHGCAR：`total`。
- 自旋 CHGCAR：`total`、`diff`，以及派生的 `up/down`。
- 非共线 CHGCAR：原始磁化分量和 `sqrt(mx²+my²+mz²)`。
- Cube：普通值或由 dataset ID/NVAL 拆分的多个通道。
- XSF：每个带标签 Datagrid 是一个独立通道；2D Datagrid 自动进入切片模式。

CHGCAR 在 MATLAB 端规范化为 `1/Angstrom^3`。Cube 的 Bohr/Å 轴符号、
非零原点和非正交 voxel vectors 也在 MATLAB 端统一解释。

## 导出

- 相机按钮组的相机图标导出当前 PNG。
- 下载图标导出不含体素数组的 scene manifest JSON。
- 等值面模式可导出自包含 glTF、GLB、PLY 或 STL；所有顶点均已转换为 Å
  笛卡尔坐标。
- 切片模式可导出当前平面的 PNG 或 CSV；CSV 包含 I/J/K、Å 坐标和数值。

## 故障排查

- 若 WebGL2 完全不可用，应用会保留 CPU 晶格切片查看以及 PNG/CSV 导出。
- 若 GPU 的 3D texture 上限不足，应用会在上传前显示原因并回退到 K 切片。
- 若 float-linear filtering 不可用，会自动使用 nearest sampling。
- Direct volume 在点击和旋转期间保持相同采样质量；非常稀疏的网格仍只代表源数据
  的线性插值，不能替代高分辨率体数据。
- WebGL context 丢失后会保留相机并重建纹理；若持续失败，切换到等值面或切片。
- “still building or contains no triangles” 表示 Worker 尚未完成，或阈值在数据范围外。
- 损坏、NaN/Inf、维度溢出或超限文件会在 MATLAB 分配大型数组前被拒绝。
