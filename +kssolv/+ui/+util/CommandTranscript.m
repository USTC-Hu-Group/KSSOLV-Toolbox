classdef CommandTranscript < handle
    %COMMANDTRANSCRIPT Bounded, in-memory display state for Online terminals.
    properties (Access = private)
        Records cell = {}
        Commands cell = {}
        Truncated logical = false
        MaxCharacters double
    end
    methods
        function this = CommandTranscript(maxCharacters)
            arguments
                maxCharacters (1,1) double {mustBeInteger,mustBePositive} = 2*1024*1024
            end
            this.MaxCharacters = maxCharacters;
        end

        function recordCommand(this, command, remote)
            arguments
                this
                command (1,1) string
                remote (1,1) logical = false
            end
            command = char(command);
            % Never recall a truncated command: it could execute something else.
            if numel(command) <= this.MaxCharacters
                this.Commands{end+1} = command;
                while numel(this.Commands) > 200 || ...
                        sum(cellfun(@numel,this.Commands)) > this.MaxCharacters
                    this.Commands(1) = [];
                end
            end
            if ~isempty(regexpi(command,'^clc\s*;?$','once'))
                this.Records = {};
                this.Truncated = false;
            else
                this.append('prompt',command,remote);
            end
        end

        function append(this, kind, data, remote)
            arguments
                this
                kind (1,1) string
                data string
                remote (1,1) logical = false
            end
            % OpenAI-compatible streams may contain an empty content delta.
            % MATLAB decodes JSON null as [], which converts to a 0-by-0 string.
            if isempty(data), return, end
            if ~isscalar(data)
                error('KSSOLV:CommandTranscript:NonScalarText', ...
                    'Transcript data must be scalar text.');
            end
            data = char(data);
            if isempty(data), return, end
            % Keep think boundaries separate: the renderer consumes these events.
            merge = kind == "tokens" && ~isempty(this.Records) && ...
                strcmp(this.Records{end}.Kind,'tokens') && ...
                ~contains(data,{'<think>','</think>'}) && ...
                ~contains(this.Records{end}.Data,{'<think>','</think>'});
            if merge
                this.Records{end}.Data = [this.Records{end}.Data,data];
            else
                this.Records{end+1} = struct('Kind',char(kind), ...
                    'Data',data,'Remote',remote);
            end
            while numel(this.Records) > 1 && ...
                    sum(cellfun(@(r)numel(r.Data),this.Records)) > this.MaxCharacters
                this.Records(1) = [];
                this.Truncated = true;
            end
            if numel(this.Records{1}.Data) > this.MaxCharacters
                this.Records{1}.Data = this.Records{1}.Data(end-this.MaxCharacters+1:end);
                this.Truncated = true;
            end
        end

        function state = snapshot(this)
            state = struct('Records',{this.Records},'Commands',{this.Commands}, ...
                'Truncated',this.Truncated);
        end
    end
end
