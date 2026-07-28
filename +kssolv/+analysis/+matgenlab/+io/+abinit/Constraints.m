classdef Constraints < kssolv.analysis.matgenlab.io.abinit.AbivarAble
    properties,variables=struct();end
    methods,function obj=Constraints(v),if nargin>0,obj.variables=v;end,end,function d=to_abivars(obj),d=obj.variables;end,end %#ok<NOCOMMA>
end
