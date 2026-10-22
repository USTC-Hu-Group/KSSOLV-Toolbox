# KSSOLV Toolbox V0.5.0 功能介绍

12 页中文 LaTeX Beamer，16:9。保留大图排版，增加完整建模功能分类、Materials Studio 对照、用户文档与示例，以及两页 KSSOLV Toolbox Online 工作区和管理功能。放映画面不显示来源说明小字；每页右下角显示页码（1–12）。

## 使用与编译

放映 `KSSOLV-Toolbox-V0.5.0.pdf`。编辑 `main.tex` 后执行：

```sh
mkdir -p build
xelatex -interaction=nonstopmode -halt-on-error -output-directory=build main.tex
xelatex -interaction=nonstopmode -halt-on-error -output-directory=build main.tex
```

需要 Beamer、ctex、fontspec、TikZ、booktabs、TeX Gyre 等常见 TeX Live 组件。中文字体依次选择 PingFang SC、Noto Sans CJK SC、Fandol。本机最终采用 PingFang SC，并检查中文提取与渲染。图片采用相对路径，源码包可独立复制使用。构建不要求 Java/JVM，没有新增 C、C++、Fortran 或 MEX 源代码。

`main.tex` 中隐藏的 `\note{...}` 保存来源、讲解提示和适用范围。`modeling-inventory.json` 完整保存命令目录的 10 类、75 项命令 ID 与中文名称；演示稿将关联操作合并成可读的分类列表，未省略命令类别。

## 内容与来源

| 页 | 内容 | 主要证据 |
| --- | --- | --- |
| 1 | 封面 | `KSSOLV_Toolbox.m` 与吡啶查看器截图 |
| 2 | 分子与晶体交互建模 | 建模指南、`ModelingTab.m` |
| 3 | 全部建模功能分类 | `+kssolv/+modeling/CommandCatalog.m`，中文 `modeling.xml` |
| 4 | 复杂材料结构 | `+kssolv/+modeling/` builders 与真实初始结构截图 |
| 5 | Materials Studio 对照 | 仓库实现与下列 Dassault Systèmes 官方资料 |
| 6 | 三维体数据可视化 | `docs/volume-viewer-user-guide.zh-CN.md` |
| 7 | 工作流与资源配置 | `README-zh.md`、`ExecutionResources.m` |
| 8 | 远程计算 | `docs/remote-computing-user-guide.zh-CN.md` |
| 9 | 安装与启动 | `scripts/windows/README.zh-CN.md`、`scripts/startup/README.md` |
| 10 | 文档与示例 | `docs/README.md`、`docs/manual-zh/` 当前源码和示例 |
| 11 | KSSOLV Toolbox Online 用户工作区 | `scripts/docker/README.zh-CN.md`、`scripts/k8s/README.zh-CN.md` |
| 12 | KSSOLV Toolbox Online 管理控制台 | `scripts/k8s/admin/README.zh-CN.md` 与本次只读采集的真实页面 |

上述路径相对于仓库根目录。V0.5.0 按当前工作区版本常量介绍；该工作区有未提交修改。本稿没有把已有能力统称为 V0.5.0 新增。

## Materials Studio 比较依据

2026-10-22 查阅以下官方一手资料：

- [Materials Studio Visualizer 数据表](https://www.3ds.com/fileadmin/PRODUCTS-SERVICES/BIOVIA/PDF/materials-studio-visualizer.pdf)：分子、晶体、聚合物、表面、层状结构与脚本接口。
- [Materials Studio 产品总览](https://www.3ds.com/assets/invest/2023-10/biovia-materials-studio-overview.pdf)：Amorphous Cell、Forcite Plus、CASTEP、DMol3、MaterialsScript 与 Pipeline Pilot。
- [Materials Studio 产品主页](https://www.3ds.com/products/biovia/materials-studio)：当前产品定位与云平台形态。

对照比较功能范围和方法定位，未作精度、性能或力场等价声明。Toolbox 的通用分子模型用于初始几何准备；Materials Studio 的 Forcite Plus 是力场优化与分子动力学模块。不假定任何一种许可包含全部模块，也不将 Materials Studio 描述为没有云端产品。

## 图像与文档预览

`image-sources.json` 记录来源、哈希与裁切。既有截图来源清单位于本地 `docs/manual-zh/images/CAPTURE-MANIFEST.md`，该手册目录未纳入 Git。原子模型、曲线与界面内容没有重绘。第 7 页的能带工作流与 H2 SCF 曲线属于不同示例体系。

文档封面从现有 `manual-style.sty` 的 `manualcover` 渲染，仅替换字体加载以保证中文可见，没有修改既有手册源文件。中英文使用指南指仓库确有的 Markdown 指南；图示为中文手册，不声称英文完整 PDF 已经验收。

管理页截图于 2026-10-22 从用户已打开的管理会话只读采集，展示已有账户核时和实例 CPU 曲线。未修改权限、邀请码、资源或实例状态，未执行脚本，未启动新工作空间；采集后恢复原标签页。截图仅代表当时界面，不作为性能基准。

## 验证范围

验证演示稿编译、12 页页数、中文文本、全部建模目录计数、图片引用与逐页布局。没有重新运行 Toolbox 科学计算、安装器、远程作业或完整 KSSOLV Toolbox Online 功能验收。默认资源档位、恢复边界和管理员权限按当前文档记录介绍，详细条件在源码备注中保留。

## 设计复核

按用户要求完成三位独立审查者的初审与改稿复核。统一字号、边距、自然中文图注、图片基线与表格层级，并重排建模目录、文档和两页 KSSOLV Toolbox Online。详见 `DESIGN-REVIEW.md`。

## 演示稿中的访问链接

第 10 页包含可点击的[代码仓库](https://github.com/USTC-Hu-Group/KSSOLV-Toolbox)和[用户文档](https://github.com/USTC-Hu-Group/KSSOLV-Toolbox-Manual)入口。2026-10-22 核对 Git origin；用户文档链接按用户指定的独立手册仓库更新并核实。
