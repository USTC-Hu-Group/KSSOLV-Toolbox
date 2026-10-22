classdef Preferences
    %PREFERENCES Stable Online choices; desktop keeps MATLAB preferences.
    properties (Constant, Access = private)
        Group = 'KSSOLVToolbox'
    end
    methods (Static)
        function values = read()
            if kssolv.settings.Preferences.usesDataVolume()
                file = fullfile(kssolv.util.userDataDirectory(), 'preferences.json');
                values = struct();
                if isfile(file)
                    values = jsondecode(fileread(file));
                    if ~isstruct(values) || ~isscalar(values)
                        error('KSSOLV:Settings:InvalidPreferences', ...
                            'The saved preferences are invalid.');
                    end
                end
            elseif ispref(kssolv.settings.Preferences.Group)
                values = getpref(kssolv.settings.Preferences.Group);
            else
                values = struct();
            end
        end

        function stored = has(name)
            stored = isfield(kssolv.settings.Preferences.read(), name);
        end

        function write(values)
            allowed = {'Locale', 'LLMType', 'OllamaServerURL', ...
                'OllamaModel', 'OpenAIBaseURL', 'OpenAIModel'};
            names = fieldnames(values);
            assert(all(ismember(names, allowed)), ...
                'KSSOLV:Settings:InvalidPreferenceName', ...
                'Only non-secret application choices belong in preferences.');
            if ~kssolv.settings.Preferences.usesDataVolume()
                for index = 1:numel(names)
                    setpref(kssolv.settings.Preferences.Group, names{index}, values.(names{index}));
                end
                return
            end
            folder = kssolv.util.userDataDirectory();
            if ~isfolder(folder), mkdir(folder); end
            temporary = [tempname(folder) '.json'];
            cleanup = onCleanup(@() removeTemporary(temporary));
            writelines(jsonencode(values), temporary, Encoding='UTF-8');
            if isunix
                kssolv.util.Platform.restrictPermissions(temporary, 'rw-------');
            end
            [moved, detail] = movefile(temporary, fullfile(folder, 'preferences.json'), 'f');
            if ~moved
                error('KSSOLV:Settings:PreferenceWriteFailed', '%s', detail);
            end
            clear cleanup
        end
    end
    methods (Static, Access = private)
        function enabled = usesDataVolume()
            enabled = isKSSOLVOnline() && strlength(getenv('KSSOLV_USER_DATA_DIR')) > 0;
        end
    end
end

function removeTemporary(file)
if isfile(file), delete(file); end
end
