# Configuration

Most KSSOLV Toolbox settings can be changed in the application. Environment
variables are useful for source checkouts, managed workstations, and automated
launchers.

[简体中文](configuration.zh-CN.md)

## Interface language

Set `KSSOLV_LOCALE` to `en_US` or `zh_CN`. If it is not set, KSSOLV Toolbox
uses the MATLAB interface language when available and otherwise uses English.
A language change takes effect after the application restarts.

## LLM provider

KSSOLV Toolbox supports local Ollama and OpenAI-compatible chat services.

| Variable | Purpose |
| --- | --- |
| `KSSOLV_LLM_TYPE` | `Ollama` or `OpenAICompatible` |
| `KSSOLV_LLM_MODEL` | Model identifier used when no saved preference exists |
| `KSSOLV_OLLAMA_ENDPOINT` | Ollama base URL, such as `http://127.0.0.1:11434` |
| `OPENAI_PROXY_URL` | OpenAI-compatible base URL, such as `https://api.openai.com/v1` |
| `OPENAI_API_KEY` | API key; use `EMPTY` only if authentication is not required |
| `OPENAI_MODEL_LIST` | Optional comma-separated fallback model list |

Enter a base URL rather than a specific `/chat/completions` or `/models`
endpoint. Use the settings dialog to test the service before sending prompts.

Example for Ollama:

```bash
KSSOLV_LLM_TYPE="Ollama"
KSSOLV_LLM_MODEL="qwen2.5:7b"
KSSOLV_OLLAMA_ENDPOINT="http://127.0.0.1:11434"
```

Example for an OpenAI-compatible service:

```bash
KSSOLV_LLM_TYPE="OpenAICompatible"
KSSOLV_LLM_MODEL="gpt-5-mini"
OPENAI_PROXY_URL="https://api.openai.com/v1"
OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxx"
```

## Source checkout

When running from source, copy `.env.example` to `.env` in the repository root
and enable only the settings you need. Do not commit `.env` or place secrets in
example files. The standalone application does not read the repository `.env`;
use the settings dialog or the operating-system environment instead.

## Precedence and credential storage

For non-sensitive values, a preference saved in the settings dialog takes
priority over an environment variable, which takes priority over the built-in
default.

An API key saved through the settings dialog is stored locally in encrypted
form. This avoids plaintext preference storage, but it is not a substitute for
an operating-system credential vault: anyone with access to the same user
account may still be able to recover locally usable credentials. Remove saved
keys from the settings dialog when they are no longer needed.

## Browser-hosted interface

`KSSOLV_HOST_IN_BROWSER` accepts common true and false values. Enable it only
when the application must host its AppContainer interface in the system
browser; the normal desktop configuration leaves it disabled.
