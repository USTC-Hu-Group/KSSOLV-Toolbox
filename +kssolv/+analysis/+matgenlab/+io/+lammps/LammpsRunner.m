classdef LammpsRunner
    properties
        input_filename="lammps.in"; bin="lammps"; executor=[]
    end
    methods
        function obj=LammpsRunner(input_filename,bin,executor)
            if nargin>0, obj.input_filename=input_filename; end
            if nargin>1, obj.bin=bin; end
            if nargin>2, obj.executor=executor; end
        end
        function [stdout,stderr]=run(obj)
            if isempty(obj.executor)
                error("KSSOLV:Matgenlab:LammpsRunner:ExecutorRequired", ...
                    "An explicit LAMMPS executor must be supplied.");
            end
            request=struct("command",string(obj.bin),"args", ...
                ["-in",string(obj.input_filename)], ...
                "input_filename",string(obj.input_filename), ...
                "working_directory",string(pwd));
            result=obj.executor(request);
            if ~isstruct(result)
                result=struct("status",0,"stdout",string(result), ...
                    "stderr","");
            end
            if ~isfield(result,"status"), result.status=0; end
            if ~isfield(result,"stdout"), result.stdout=""; end
            if ~isfield(result,"stderr"), result.stderr=""; end
            if result.status~=0
                error("KSSOLV:Matgenlab:LammpsRunner:ExecutionFailed", ...
                    "LAMMPS execution failed with status %d: %s", ...
                    result.status,string(result.stderr));
            end
            stdout=uint8(char(string(result.stdout)));
            stderr=uint8(char(string(result.stderr)));
        end
    end
end
