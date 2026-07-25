classdef Addon
    %ADDON Large Language Models with MATLAB 附加功能的版本边界。

    % 开发者：杨柳
    % 版权 2026 合肥瀚海量子科技有限公司

    properties (Constant)
        Name = "Large Language Models (LLMs) with MATLAB"
        MinimumVersion = "4.9.0"
    end

    methods (Static)
        function available = isAvailable(provider)
            %ISAVAILABLE 检查所需类和最低 Add-On 版本。
            arguments
                provider (1, 1) string = ""
            end

            commonAvailable = exist('messageHistory', 'class') == 8 && ...
                exist('openAIFunction', 'class') == 8;
            openAIAvailable = ...
                commonAvailable && exist('openAIChat', 'class') == 8;
            ollamaAvailable = ...
                commonAvailable && exist('ollamaChat', 'class') == 8;

            switch lower(provider)
                case {"openaichat", "openaicompatible"}
                    available = openAIAvailable;
                case {"ollamachat", "ollama"}
                    available = ollamaAvailable;
                otherwise
                    available = openAIAvailable || ollamaAvailable;
            end
            if ~available || isdeployed
                return
            end

            available = ...
                kssolv.services.llm.Addon.hasSupportedInstallation();
        end

        function supported = isVersionSupported(version)
            %ISVERSIONSUPPORTED 判断版本是否不低于最低要求。
            actual = kssolv.services.llm.Addon.versionParts(version);
            minimum = kssolv.services.llm.Addon.versionParts( ...
                kssolv.services.llm.Addon.MinimumVersion);
            if isempty(actual)
                supported = false;
                return
            end

            count = max(numel(actual), numel(minimum));
            actual(end + 1:count) = 0;
            minimum(end + 1:count) = 0;
            firstDifference = find(actual ~= minimum, 1);
            supported = isempty(firstDifference) || ...
                actual(firstDifference) > minimum(firstDifference);
        end

        function [installed, version] = hasSupportedInstallation()
            %HASSUPPORTEDINSTALLATION 查找已安装且已启用的受支持版本。
            installed = false;
            version = "";
            if isdeployed
                installed = true;
                version = kssolv.services.llm.Addon.MinimumVersion;
                return
            end

            try
                addons = matlab.addons.installedAddons;
            catch
                return
            end

            candidates = strcmpi(strip(string(addons.Name)), ...
                kssolv.services.llm.Addon.Name);
            if ismember('Enabled', addons.Properties.VariableNames)
                candidates = candidates & logical(addons.Enabled);
            end
            indices = find(candidates);
            for index = indices(:).'
                candidateVersion = string(addons.Version(index));
                if kssolv.services.llm.Addon.isVersionSupported( ...
                        candidateVersion)
                    installed = true;
                    version = candidateVersion;
                    return
                end
            end
        end
    end

    methods (Static, Access = private)
        function parts = versionParts(version)
            tokens = regexp(char(string(version)), '\d+', 'match');
            if isempty(tokens)
                parts = [];
                return
            end
            parts = str2double(tokens(1:min(3, numel(tokens))));
        end
    end
end
