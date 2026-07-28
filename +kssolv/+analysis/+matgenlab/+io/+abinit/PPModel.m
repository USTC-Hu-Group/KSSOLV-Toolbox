classdef PPModel < kssolv.analysis.matgenlab.util.MSONable
    properties,mode="godby";plasmon_freq=[];end
    methods
        function obj=PPModel(mode,f),if nargin>0,obj.mode=string(mode);end;if nargin>1,obj.plasmon_freq=f;end,end
        function d=to_abivars(obj),names=["noppmodel","godby","hybersten","linden","farid"];i=find(names==obj.mode)-1;if i==0,d=struct();else,d=struct("ppmodel",i,"ppmfrq",obj.plasmon_freq);end,end
        function d=as_dict(obj),d=kssolv.analysis.matgenlab.util.msonDict("pymatgen.io.abinit.abiobjects","PPModel",struct("mode",char(obj.mode),"plasmon_freq",obj.plasmon_freq));end
        function d=asDict(obj),d=obj.as_dict();end
    end
    methods (Static)
        function o=as_ppmodel(v),if isa(v,"kssolv.analysis.matgenlab.io.abinit.PPModel"),o=v;return;end;p=split(string(v),":");f=[];if numel(p)>1,q=split(strip(p(2)));f=str2double(q(1));if numel(q)>1&&lower(q(2))=="ev",f=f/27.211386245988;end,end;o=kssolv.analysis.matgenlab.io.abinit.PPModel(p(1),f);end
        function o=get_noppmodel(),o=kssolv.analysis.matgenlab.io.abinit.PPModel("noppmodel",[]);end
        function o=from_dict(d),o=kssolv.analysis.matgenlab.io.abinit.PPModel(d.mode,d.plasmon_freq);end
        function o=fromDict(d),o=kssolv.analysis.matgenlab.io.abinit.PPModel.from_dict(d);end
    end
end
