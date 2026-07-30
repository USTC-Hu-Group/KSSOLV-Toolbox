# KSSOLV Toolbox

[![Github Release Version](https://img.shields.io/github/v/release/yliu7949/KSSOLV-Toolbox?color=blue&include_prereleases)](https://github.com/yliu7949/KSSOLV-Toolbox/releases/latest)
[![License: BUSL-1.1](https://img.shields.io/badge/license-BUSL--1.1-blue)](https://github.com/yliu7949/KSSOLV-Toolbox/blob/main/LICENSE)
[![GitHub top language](https://img.shields.io/github/languages/top/yliu7949/KSSOLV-Toolbox)](https://matlab.mathworks.com/)
![MATLAB Versions Tested](https://img.shields.io/badge/tested%20with-R2026b%20%7C%20R2026a%20%7C%20R2025b-blue)

**KSSOLV Toolbox** 是一个基于 MATLAB 的图形化工具箱，用来更轻松地运行 **Kohn-Sham Solver (KSSOLV)** 包提供的密度泛函理论 (DFT) 计算。它的目标是让研究人员摆脱繁琐的脚本编写，让研究人员能够以更直观的方式完成从结构导入、计算参数设置到结果分析的完整流程。

![KSSOLV Toolbox GUI](https://github.com/yliu7949/KSSOLV-Toolbox/blob/main/assets/KSSOLV%20Toolbox%20GUI.png)

## 主要特性

**KSSOLV Toolbox** 采用模块化的设计： 

* **预处理模块**：导入晶体/分子结构并分析对称性；查看 CHGCAR、Cube、XSF
  三维体数据、等值面、晶格切片和原子结构叠加。
* **计算模块**：支持 SCF 和 Non-SCF 等常用计算任务。
* **后处理模块**：负责能带结构等结果的计算与处理。
* **可视化模块**：内置多种绘图模板，用于快速绘制计算结果。

## 安装

**KSSOLV Toolbox** 支持在 **MATLAB® 桌面版环境** 中安装使用，同时也提供可在 Windows、macOS 和 Linux 平台上部署的**独立应用程序版本**。

有关具体的安装方式与操作说明，请参阅[用户使用文档](https://github.com/yliu7949/KSSOLV-Toolbox/blob/main/docs/usage/start.md)。

## 贡献指南

**🎯** 欢迎提交 **Issues** 和 **PR**！

- **新功能？** 请先在 Issue 中详细说明需求，讨论确认后再提交代码。
- **修复 Bug？** 可以直接提交 PR，请附上问题描述和修复方案。

> 向本项目提交代码、文档或任何其他贡献，即表示贡献者确认其有权提交该贡献，并在法律允许的最大范围内，以永久、不可撤销、全球范围且免许可费的方式，将该贡献中全部可转让的著作财产权及相关权利自动、无条件地转让给 **KSSOLV Development Team**。对于依法不能转让或上述转让未能生效的任何权利，贡献者授予权利所有人永久、不可撤销、全球范围、免许可费、可转让且可完全再许可的许可，允许权利所有人以任何方式使用、复制、修改、改编、发表、分发及再许可该贡献，包括根据 BUSL-1.1、Change License 和商业许可证进行授权。提交贡献即视为接受上述条款。
>

## 许可证

**KSSOLV Toolbox** 的原创部分采用 **Business Source License 1.1
(BUSL-1.1)**：

- BUSL-1.1 允许非生产性使用。
- `Additional Use Grant` 允许用于教学与教育、符合条件的学术或个人研究，以及符合条件的慈善或非营利活动等生产性使用。
- 其他生产性使用，包括商业研究与开发，必须另行取得[商业许可证](COMMERCIAL-LICENSE.md)。
- 在 **2030 年 7 月 22 日**，或某一版本首次以 BUSL-1.1 公开发布满四周年之日（以较早者为准），该版本将自动改用 **GNU GPL v3.0 或更高版本**。

BUSL-1.1 是源码可用许可证；在适用的 Change Date 之前，它不是开源许可证。第三方组件继续适用各自的许可证，详情参见[第三方许可证说明](THIRD-PARTY-LICENSES.md)。本次许可证变更前已经发布的版本，继续适用其发布时随附的许可证。

## 引用

如果你在研究工作或论文中使用了 **KSSOLV Toolbox**，请引用下面的论文。

```latex
@article{YangLiu_KSSOLV_Toolbox_2026,
  author = {Yang, Liu and Yang, Jinlong and Hu, Wei},
  title = {KSSOLV Toolbox: A MATLAB Graphical User Interface for Plane-Wave Density Functional Theory Calculations},
  journal = {Journal of Chemical Theory and Computation},
  volume = {22},
  number = {11},
  pages = {5579--5593},
  year = {2026},
  doi = {10.1021/acs.jctc.6c00523},
  note = {PMID: 42175909},
  url = {https://doi.org/10.1021/acs.jctc.6c00523},
  eprint = {https://doi.org/10.1021/acs.jctc.6c00523}
}
```
