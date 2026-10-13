classdef Platform
    %PLATFORM Native operating-system helpers shared by Toolbox services.
    methods (Static)
        function value = home()
            if ispc, value = string(getenv('USERPROFILE'));
            else, value = string(getenv('HOME')); end
            if strlength(value) == 0
                error('KSSOLV:Platform:HomeUnavailable','The user home directory is unavailable.');
            end
        end

        function value = hostname()
            if ispc, value = string(getenv('COMPUTERNAME'));
            else, value = string(getenv('HOSTNAME')); end
            if strlength(value) == 0
                [status,text] = system('hostname');
                if status == 0, value = strip(string(text)); end
            end
            if strlength(value) == 0, value = "unknown"; end
        end

        function values = environment()
            values = containers.Map('KeyType','char','ValueType','char');
            if ispc, command = 'set'; else, command = 'env'; end
            [status,text] = system(command);
            if status ~= 0
                error('KSSOLV:Platform:EnvironmentUnavailable','Unable to enumerate process environment variables.');
            end
            lines = splitlines(string(text));
            for index = 1:numel(lines)
                tokens = regexp(char(lines(index)), '^([^=]+)=(.*)$','tokens','once');
                if ~isempty(tokens), values(tokens{1}) = tokens{2}; end
            end
        end

        function value = canonicalPath(value)
            value = char(string(value));
            if ispc
                value = strrep(value,'/',filesep);
                root = regexp(value,'^[A-Za-z]:\\|^\\\\[^\\]+\\[^\\]+\\?','match','once');
            else
                root = regexp(value,'^/','match','once');
            end
            if isempty(root), value = fullfile(pwd,value); end
            if ispc
                root = regexp(value,'^[A-Za-z]:\\|^\\\\[^\\]+\\[^\\]+\\?','match','once');
            else, root = '/'; end
            parts = strsplit(value(numel(root)+1:end),filesep);
            normalized = {};
            for index = 1:numel(parts)
                if isempty(parts{index}) || strcmp(parts{index},'.'), continue; end
                if strcmp(parts{index},'..')
                    if ~isempty(normalized), normalized(end) = []; end
                else
                    normalized{end+1} = parts{index}; %#ok<AGROW>
                end
            end
            value = string(fullfile(root,normalized{:}));
            [found,attributes] = fileattrib(char(value));
            if found && isscalar(attributes), value = string(attributes.Name); end
        end

        function restrictPermissions(path, mode)
            if ~isunix, return; end
            mode = char(string(mode));
            if numel(mode) ~= 9 || any(~ismember(mode,'rwx-'))
                error('KSSOLV:Platform:Permissions','Invalid owner/group/other permission mode.');
            end
            digits = zeros(1,3);
            for index = 1:3
                bits = mode(3*index-2:3*index) ~= '-';
                digits(index) = sum(bits .* [4 2 1]);
            end
            path = char(string(path));
            quote = char(39); backslash = char(92);
            quoted = [quote strrep(path,quote,[quote backslash quote quote]) quote];
            [status,~] = system(sprintf('chmod %d%d%d %s',digits,quoted));
            if status ~= 0
                error('KSSOLV:Platform:Permissions','Unable to restrict file permissions.');
            end
        end
    end
end
