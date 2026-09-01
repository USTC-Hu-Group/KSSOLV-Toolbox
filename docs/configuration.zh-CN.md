# 应用配置

KSSOLV Toolbox 的大多数设置都可以在应用中修改。对于源码运行、受管理的工作站或
自动启动脚本，也可以使用环境变量。

[English](configuration.md)

## 界面语言

将 `KSSOLV_LOCALE` 设置为 `en_US` 或 `zh_CN`。未设置时，KSSOLV Toolbox 会优先使用
MATLAB 的界面语言，不受支持时使用英文。语言修改在应用重启后生效。

## LLM 服务

KSSOLV Toolbox 支持本地 Ollama 和 OpenAI 兼容的对话服务。

| 变量 | 用途 |
| --- | --- |
| `KSSOLV_LLM_TYPE` | `Ollama` 或 `OpenAICompatible` |
| `KSSOLV_LLM_MODEL` | 没有已保存设置时使用的模型标识 |
| `KSSOLV_OLLAMA_ENDPOINT` | Ollama 基础 URL，例如 `http://127.0.0.1:11434` |
| `OPENAI_PROXY_URL` | OpenAI 兼容服务基础 URL，例如 `https://api.openai.com/v1` |
| `OPENAI_API_KEY` | API 密钥；只有服务不要求认证时才使用 `EMPTY` |
| `OPENAI_MODEL_LIST` | 可选的逗号分隔备用模型列表 |

URL 应填写服务根地址，不要附加 `/chat/completions` 或 `/models`。发送提示前，建议在
设置对话框中测试服务。

Ollama 示例：

```bash
KSSOLV_LLM_TYPE="Ollama"
KSSOLV_LLM_MODEL="qwen2.5:7b"
KSSOLV_OLLAMA_ENDPOINT="http://127.0.0.1:11434"
```

OpenAI 兼容服务示例：

```bash
KSSOLV_LLM_TYPE="OpenAICompatible"
KSSOLV_LLM_MODEL="gpt-5-mini"
OPENAI_PROXY_URL="https://api.openai.com/v1"
OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxx"
```

## 从源码运行

从源码运行时，可以把仓库根目录下的 `.env.example` 复制为 `.env`，并只启用需要的
设置。不要提交 `.env`，也不要把密钥写入示例文件。独立应用不会读取仓库中的 `.env`；
请改用设置对话框或操作系统环境变量。

## 设置优先级和凭据存储

对于非敏感设置，设置对话框中保存的值优先于环境变量，环境变量优先于内置默认值。

通过设置对话框保存的 API 密钥会在本地加密存储。这样可以避免把密钥以明文写入偏好
设置，但不能替代操作系统凭据保险库：能够访问同一用户账户的人仍可能取得本地可用的
凭据。不再使用密钥时，应在设置对话框中将其删除。

## 浏览器承载界面

`KSSOLV_HOST_IN_BROWSER` 接受常见的 true/false 表示。只有需要在系统浏览器中承载
AppContainer 界面时才启用；普通桌面使用应保持关闭。
