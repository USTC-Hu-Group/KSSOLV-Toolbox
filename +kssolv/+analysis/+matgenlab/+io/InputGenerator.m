classdef InputGenerator < kssolv.analysis.matgenlab.util.MSONable
    %INPUTGENERATOR Recipe interface producing an InputSet.
    methods
        function inputSet=get_input_set(~,varargin)
            inputSet=[]; %#ok<NASGU>
            error("KSSOLV:Matgenlab:InputGenerator:Abstract", ...
                "get_input_set must be implemented by a concrete generator.");
        end
        function inputSet=getInputSet(obj,varargin)
            inputSet=obj.get_input_set(varargin{:});
        end
        function data=asDict(~)
            data=kssolv.analysis.matgenlab.util.msonDict( ...
                "pymatgen.io.core","InputGenerator",struct());
        end
        function data=as_dict(obj),data=obj.asDict();end
    end
    methods (Static)
        function obj=fromDict(~)
            obj=kssolv.analysis.matgenlab.io.InputGenerator();
        end
        function obj=from_dict(data)
            obj=kssolv.analysis.matgenlab.io.InputGenerator.fromDict(data);
        end
    end
end
