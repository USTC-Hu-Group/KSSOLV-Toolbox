function isAvailable = isLLMWithMATLABAddonAvailable(provider)
%ISLLMWITHMATLABADDONAVAILABLE 检查 Large Language Models (LLMs) with MATLAB 工具是否可用
arguments
    provider (1, 1) string = ""
end

% 开发者：杨柳
% 版权 2025-2026 合肥瀚海量子科技有限公司

isAvailable = kssolv.services.llm.Addon.isAvailable(provider);
end
