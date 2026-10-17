# 仓库级开发约束

以下规则适用于本仓库的所有目录和代码，包括 MATLAB 源码、脚本、测试、构建工具及第三方依赖的引入与使用。

## 禁止依赖 Java 和 JVM

- 本仓库的任何代码都不得直接或间接依赖 Java 或 JVM；运行、测试、构建和打包均不得要求 Java 运行环境。
- MATLAB 代码中禁止编写、嵌入或调用 Java 代码，包括 `java.*`、`javax.*`、`javaObject`、`javaMethod`、`javaArray`、`javaaddpath`、`javaclasspath` 及其他 Java 桥接接口。
- 禁止通过系统命令、外部脚本、MEX、第三方库或其他封装间接启动 Java、加载 JVM、执行 JAR 文件或调用 Java 服务来实现仓库功能。
- 不得引入需要 Java 或 JVM 的依赖，也不得将 Java/JVM 实现作为可选路径、兼容路径或回退方案。
- 实现功能时应使用不依赖 Java/JVM 的 MATLAB 原生接口或其他无需 Java/JVM 的实现；选择接口时需确认其执行路径不要求 JVM。
- 修改涉及既有 Java/JVM 依赖的代码时，应将相关依赖替换为无需 Java/JVM 的实现，不得新增或扩散此类依赖。
- 验证受影响功能时，应检查其在无 Java/JVM 环境下的可用性；适用的 MATLAB 非图形功能应在 `-nojvm` 模式下验证。若暂时无法验证，需如实说明，不能声称已满足该约束。

## 新增编译型源代码需开发者明确许可

- 除非开发者明确允许，不得额外引入需要编译的源代码，例如 C、C++、Fortran 等，也不得通过第三方依赖或自动生成代码的方式间接引入。
- 使用 MEX 不构成例外：此类实现仍需处理不同平台、编译器及依赖库的编译与兼容问题，会增加构建、分发和维护成本。
- 应优先考虑使用 MATLAB 代码替代实现。若认为必须引入编译型源代码，应先说明原因、MATLAB 替代方案及其局限，以及跨平台编译和依赖维护成本，征求开发者意见；获得明确许可后方可引入。
- 一般性的功能开发、性能优化或问题修复授权，不视为允许新增编译型源代码；许可应明确覆盖该实现方式及范围。

## Git 提交信息格式

- 提交信息标题必须使用 `<type>(<scope>): <subject>` 格式，冒号后保留一个空格。
- `type` 表示提交类型，可使用 `feat`、`fix`、`chore`、`docs`、`style`、`refactor`、`test`、`perf`、`deps`、`revert`、`merge`、`wip`、`conflict` 等与变更性质相符的类型。
- `scope` 表示代码或变更所在的范围，例如模块、目录或功能；范围为空时仍必须保留括号，例如 `docs(): update repository development rules`。
- 提交信息中的简短说明（`subject`）及详细描述正文（`body`）都必须使用英文。
- `subject` 应简明、准确地描述本次变更。例如：`fix(startup): fix startup path resolution`。
