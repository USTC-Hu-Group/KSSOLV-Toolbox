classdef ElectronsAlgorithm < kssolv.analysis.matgenlab.util.MSONable
    properties, variables=struct(); end
    methods
        function obj=ElectronsAlgorithm(varargin)
            for i=1:2:numel(varargin),obj.variables.(char(varargin{i}))=varargin{i+1};end
        end
        function d=to_abivars(obj),d=obj.variables;end
        function d=as_dict(obj),d=kssolv.analysis.matgenlab.util.msonDict("pymatgen.io.abinit.abiobjects","ElectronsAlgorithm",obj.variables);end
        function d=asDict(obj),d=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(d), d=rmfield_if(d,["x_module","x_class"]); n=fieldnames(d);a={};for i=1:numel(n),a(end+1:end+2)={n{i},d.(n{i})};end;obj=kssolv.analysis.matgenlab.io.abinit.ElectronsAlgorithm(a{:});end
        function obj=fromDict(d),obj=kssolv.analysis.matgenlab.io.abinit.ElectronsAlgorithm.from_dict(d);end
    end
end
function d=rmfield_if(d,n),for i=1:numel(n),if isfield(d,n(i)),d=rmfield(d,n(i));end,end,end
