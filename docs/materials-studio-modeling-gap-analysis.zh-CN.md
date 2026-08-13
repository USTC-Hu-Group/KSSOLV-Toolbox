# Materials Studio 建模能力调研与 KSSOLV Toolbox 差距审计

调研快照：2026-08-09。本文区分“公开资料确认的能力”“常见操作资料”和“KSSOLV 当前候选版本的实测证据”；没有 Materials Studio 授权环境可复测的点击数与耗时不作推测。

## 1. Materials Studio 的成熟手感来自什么

Dassault Systèmes 将 Materials Studio 定义为统一的多尺度建模与模拟环境，Materials Visualizer 是其中构建、操作、查看和分析分子、晶体与聚合物的公共前端。官方产品说明明确覆盖 Visualizer、Amorphous Cell、聚合物/复合材料和自动化工作流。2025 版又为 Mesocite 增加 Construction、Packing、ConfinedLayer，说明其成熟度并非静态功能表，而是“构建器 + 可视化 + 任务工作流 + 数据管理”的持续产品化。

公开资料确认的关键建模闭环如下：

| 能力域 | Materials Studio 基准能力 | 成熟手感的来源 |
| --- | --- | --- |
| 通用交互 | 选择、旋转、平移、缩放、直接拖动、属性编辑 | 同一 3D 文档内完成，工具状态清晰 |
| 分子 Sketch | 点原子、连键、键级、合并、环、补氢、Clean、片段 | 高频动作不必往返多个对话框 |
| 晶体 | 晶格、空间群、非对称单元、对称展开、表面、层与界面 | 参数与 3D 预览相互反馈 |
| 聚合物 | repeat unit、均聚/共聚、链长、立构、初始构象 | 聚合物语义是一等模型而非原子复制脚本 |
| 非晶 | Construction、Packing、Confined Layer、组成、密度、区域 | 构建期间检查 close contact、ring spearing，并明确后续平衡 |
| 自动化 | 脚本、任务、批处理、Pipeline Pilot/作业基础设施 | GUI 结果可进入可复现的生产流程 |

官方 Amorphous Cell 资料特别说明：链按 segment 生长，候选构象会做 ring spearing 与 close-contact 检查，再按能量和随机数选择；Packing 可向已有结构/非正交盒/等值面填充，Confined Layer 可沿 A/B/C 限制。这是 KSSOLV 几何装箱与 Materials Studio 能量偏置构建之间仍需明确标注的科学边界。

## 2. 快捷键与便捷操作

Materials Studio 的完整当前快捷键表位于授权产品帮助中，公开官方页面没有给出稳定、版本化的全表。可公开核对的培训/Quick Start 资料显示其核心模式是：空白处拖框多选、旋转/缩放/平移模式、Sketch 中点击原子或空白添加、依次点两个原子连键、拖到另一原子合并、单击键改变键级、`Esc` 退出 Sketch，以及用修饰键移动/旋转选中对象。对标时应在实际授权版本内导出或截取帮助表，不能把旧版资料当成 2026 的精确键位合同。

KSSOLV 当前默认键位：

| 输入 | 操作 |
| --- | --- |
| 点击 / Shift+点击 | 选择 / 切换原子 |
| `⌘/Ctrl+A` | 全选原子 |
| `Delete/Backspace` | 删除选择 |
| `⌘/Ctrl+Z` / `Shift+⌘/Ctrl+Z` | 撤销 / 重做 |
| `B` / `L` | 框选 / 套索 |
| `G` / `R` | 移动 / 旋转选择 |
| `X` / `Y` / `Z` | 轴约束 |
| `Space` | 居中 |
| `Esc` | 取消工具或清除选择 |
| `I` | 极简界面 |
| `?` | 快捷键帮助与自定义 |

输入框、下拉框和文本区域聚焦时快捷键暂停；当前候选版本采用固定单键映射，并在视窗内的 `?` 面板中集中展示。

### 2.1 3D Sketch、精确操纵与通用吸附质的复刻合同

Visualizer 官方数据表确认了以下产品级不变量：独立的 3D sketcher、自动补氢、片段草绘、精确的原子/对象移动与旋转、精确定位、键级/杂化编辑以及多级撤销；Dassault Systèmes 的 Materials Design 培训又把 `master sketching techniques` 与晶体、聚合物、纳米材料 builder 放在同一 Visualizer 工作流中。公开官方资料没有给出 Materials Studio 2026 每个鼠标修饰键的版本化合同，因此 KSSOLV 只复刻可验证的交互语义，不声称逐键复制未公开帮助。

本次为 slab 增加的 KSSOLV 合同是：

1. `Adsorbate` 瞬时选择器接受 OH、COOH 等内置片段，以及同一契约提供的项目/用户片段；OH 不拥有专用入口或兼容字段；
2. 第一段从表面原子左拖 Host–Anchor 键和锚原子，第二段左拖确定整个片段朝向，视窗实时更新锚点键长和接触诊断；
3. `Alt` 调整第一段深度，`Shift+Alt` 沿当前方向伸缩锚点距离，完成后右键拖动使整个片段绕 Host–Anchor 轴旋转；
4. 拖动期间只渲染临时原子、键和接触诊断，`Enter/Apply` 才把完整片段作为一次事务写入；`Esc` 整体取消；
5. 提交只保存通用 species/coordinates/bonds/anchor 契约，保证任意片段的撤销、恢复和 recipe 重放仍可审计。

这条直接草绘路径不替代对称性约化的 top/bridge/hollow 吸附位搜索；二者分别服务于快速人工构型与系统候选枚举。

通用分子/对象交互同时形成以下合同：

1. Molecule 的 Sketch 从已有原子拖向空间可连续预览待建原子、化学键和键长；拖到另一已有原子上则建立显式拓扑键，而不是生成重叠原子；
2. 3D 草图通过视窗快捷键与鼠标手势激活，元素、键级、环尺寸和显式键编辑由 MATLAB `建模` 工具栏承载；
3. `G/R` 鼠标拖动保留 Snap 手感，同时提供笛卡尔/分数精确位移和精确角度输入；数值变化先驱动 GPU 预览，Apply 后才进入 MATLAB 原子事务；
4. 2/3/4 原子选择自动显示距离/角度/二面角；测量模式把下一原子的 hover 坐标纳入计算，数值和 3D 标注同步刷新；
5. 草绘、变换、键级与几何反向编辑都复用 CommandCatalog、EditTransaction 和文档历史，不存在只改前端画面的旁路状态。

## 3. KSSOLV 差距与当前结论

P1-P10 实施前，最大差距不是缺少某一个晶体算法，而是缺少贯通选择、预览、事务、直接操纵、化学拓扑、构建器、重放和恢复的统一交互层。当前候选版本已经补齐这些工程主干：统一 Crystal/Molecule 编辑、Sketch/几何/片段、空间群/缺陷、表面/吸附/界面、高分子、密度装箱、版本 API、recipe/batch 和恢复日志均有 MATLAB R2026b 证据。

仍需客观保留的差距：

1. KSSOLV 的非晶构建器目前是确定性几何装箱，虽检查 close contact 与 ring piercing，但没有 Materials Studio Amorphous Cell 的力场能量偏置 segment-growth；结果明确标记 `packed_not_equilibrated`。
2. KSSOLV 的 repeat-unit/片段内置库规模仍小于商业产品，用户库管理 UI 尚可继续扩充。
3. 真实“同样手感”不能由开发者自评。自动化 12 任务已具备，但 `10 名领域用户、两产品同硬件盲测` 必须取得 Materials Studio 授权和外部参与者数据；仓库提供严格分析器，空数据不会通过。
4. 当前平台终验是 macOS + MATLAB R2026b；Materials Studio Visualizer 的桌面基准主要面向 Windows，跨平台产品对标需控制输入设备、显示缩放和平台差异。

## 4. 主要来源

- [Dassault Systèmes：BIOVIA Materials Studio 产品页](https://www.3ds.com/products/biovia/materials-studio)
- [Dassault Systèmes：Materials Science Modeling 产品说明（Visualizer 与各模块）](https://www.3ds.com/fileadmin/PRODUCTS-SERVICES/BIOVIA/PDF/MATERIALS-SCIENCE-MODELING-SIMULATION-BIOVIA-MATERIALS-STUDIO-PRODUCT-DESCRIPTIONS.pdf)
- [Dassault Systèmes：Materials Studio Visualizer 数据表](https://www.3ds.com/fileadmin/PRODUCTS-SERVICES/BIOVIA/PDF/materials-studio-visualizer.pdf)
- [Dassault Systèmes：Materials Studio 2025 新功能](https://www.3ds.com/assets/invest/2025-02/materials-studio-whats-new-2025-ds.pdf)
- [Dassault Systèmes：Amorphous Cell 数据表](https://www.3ds.com/assets/invest/2023-10/biovia-material-studio-amorphous-cell.pdf)
- [Dassault Systèmes Materials Design 培训页](https://events.3ds.com/materials-studio-build-structures-model)
- [Cambridge CASTEP Workshop：Materials Studio 初学者练习](https://www.tcm.phy.cam.ac.uk/castep/CASTEP_talks_07/Tuesday_exercises.pdf)
