classdef ModelDielectricFunction < kssolv.analysis.matgenlab.io.abinit.AbivarAble
    properties,mdf_epsinf;end
    methods,function obj=ModelDielectricFunction(v),obj.mdf_epsinf=v;end,function d=to_abivars(obj),d=struct("mdf_epsinf",obj.mdf_epsinf);end,end %#ok<NOCOMMA>
end
