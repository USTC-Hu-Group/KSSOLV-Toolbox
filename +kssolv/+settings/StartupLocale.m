classdef StartupLocale
    %STARTUPLOCALE Export only the deployed application's resolved UI locale.
    % MATLAB preferences remain authoritative. Installation prewarm creates this
    % small, non-sensitive projection so native hosts can read it before MCR starts.
    methods (Static)
        function file = filePath()
            if ispc
                base = string(getenv('APPDATA'));
            elseif ismac
                base = fullfile(kssolv.util.Platform.home(), ...
                    'Library', 'Application Support');
            else
                base = string(getenv('XDG_CONFIG_HOME'));
                if strlength(base) == 0
                    base = fullfile(kssolv.util.Platform.home(), '.config');
                end
            end
            file = fullfile(base, 'KSSOLV Toolbox', 'startup.json');
        end

        function write(locale, file)
            arguments
                locale (1, 1) string
                file (1, 1) string = kssolv.settings.StartupLocale.filePath()
            end
            if strlength(locale) == 0
                locale = string(feature('locale').messages);
                locale = extractBefore(locale + ".", ".");
            end
            % Match Localizer's supported locales and English fallback exactly.
            if ~ismember(locale, ["zh_CN", "en_US"])
                locale = "en_US";
            end
            payload = jsonencode(struct('version', 1, 'locale', locale));
            temporary = "";
            try
                if isfile(file) && strcmp(strtrim(fileread(file)), payload)
                    return
                end
                folder = fileparts(file);
                if ~isfolder(folder), mkdir(folder); end
                temporary = string(tempname(folder));
                writelines(payload, temporary, Encoding="UTF-8");
                movefile(temporary, file, 'f');
            catch
                % A startup hint must never prevent the application from loading.
                if strlength(temporary) > 0 && isfile(temporary), delete(temporary); end
            end
        end
    end
end
