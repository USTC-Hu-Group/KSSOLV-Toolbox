# KSSOLV Toolbox 快速入门

KSSOLV Toolbox 为基于 KSSOLV 的密度泛函理论计算提供图形化环境，可用于准备结构、
组织工作流、运行计算和查看结果。本文介绍安装方法和第一个本地工作流。

[English](start.md)

## 安装

### MATLAB 工具箱

以 MATLAB Add-On 方式使用时，需要 MATLAB R2024b 或更高版本。

1. 从[最新发行版](https://github.com/USTC-Hu-Group/KSSOLV-Toolbox/releases/latest)
   下载 `KSSOLV_Toolbox.mltbx`。
2. 在 MATLAB 中打开下载的文件并完成安装。
3. 从 MATLAB 或 Add-On Manager 启动 KSSOLV Toolbox。

### 独立应用程序

项目为受支持的 Windows、macOS 和 Linux 系统提供独立安装包。独立版不需要完整的
MATLAB，但需要与应用版本匹配的 MATLAB Runtime。

1. 从最新发行版下载适合当前操作系统的安装包。
2. 运行安装程序，选择应用和 MATLAB Runtime 的安装位置。
3. 从系统应用菜单启动 KSSOLV Toolbox。

Linux 用户可在图形会话中运行安装程序；必要时先添加执行权限：

```bash
chmod +x KSSOLV_Toolbox.install
./KSSOLV_Toolbox.install
```

安装程序会显示当前发行版对应的启动命令和 Runtime 路径要求。

## 熟悉工作区

主窗口以中央文档区为核心：

- **Project Browser** 保存结构、工作流、结果和图形。
- **Information Browser** 显示当前项目项的详细信息。
- **Config Editor** 编辑选中的工作流节点。
- **Simulation Browser** 显示计算和结果状态。
- **Command Window** 可执行 MATLAB 命令；完成配置后也可发送 LLM 提示。

需要更大的文档区域时，可以折叠侧边面板。

## 导入结构

1. 准备 CIF、POSCAR、XYZ 等结构文件。
2. 选择 **Home → Structure → Import Structure from File…**。
3. 选择文件。

结构会加入 Project Browser，并在三维查看器中打开。拖动鼠标可旋转，滚轮可缩放，
右键菜单提供视图和选择命令。

结构编辑请参阅[建模用户指南](../modeling-user-guide.zh-CN.md)；MATLAB 导入导出接口
请参阅 [Structure I/O API](../structure-io-api.md)。

## 创建并运行工作流

1. 在 Project Browser 中双击 **Workflow** 创建工作流。
2. 从 **Workflow** Tab 添加所需的计算节点。
3. 按执行顺序连接节点。
4. 依次选择节点，在 Config Editor 中完成设置。
5. 保存项目，然后选择 **Run**。

一个基本的自洽场计算通常包含结构输入、SCF 任务以及结果或可视化步骤。运行期间，
Simulation Browser 会显示进度和消息。将结果用于后续计算前，应先检查其中的警告。

## 保存项目

KSSOLV Toolbox 项目使用 `.ks` 扩展名，可保存导入数据、工作流、设置、结果和图形。

- 窗口标题中的星号表示存在未保存的修改。
- 准备工作流时应定期选择 **Project → Save**。
- 打开其他项目前，请先保存或关闭当前项目。

## 可选功能

Command Window 可以连接本地 Ollama 或 OpenAI 兼容服务。远程计算可以使用已经配置的
集群、远端 MATLAB 或受支持的 MATLAB Cluster Profile。这些功能需要额外设置：

- [应用配置](../configuration.zh-CN.md)
- [远程计算用户指南](../remote-computing-user-guide.zh-CN.md)

建议先完成一个小型本地计算，再启用上述功能。这样可以更容易地区分工作流问题与
服务或集群配置问题。

## 后续阅读

- [建模用户指南](../modeling-user-guide.zh-CN.md)
- [三维体数据查看器用户指南](../volume-viewer-user-guide.zh-CN.md)
- [远程计算用户指南](../remote-computing-user-guide.zh-CN.md)
- [Modeling API v1](../modeling-api.md)
