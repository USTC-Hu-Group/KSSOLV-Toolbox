classdef Smearing < kssolv.analysis.matgenlab.util.MSONable
    properties, occopt=1; tsmear=0; end
    properties (Dependent), mode; end
    methods
        function obj=Smearing(occopt,tsmear),if nargin>0,obj.occopt=occopt;obj.tsmear=tsmear;end,end
        function v=get.mode(obj), names=["nosmearing","fermi_dirac","marzari4","marzari5","methfessel","gaussian"]; ids=[1 3 4 5 6 7]; v=names(ids==obj.occopt);end
        function d=to_abivars(obj),d=struct("occopt",obj.occopt,"tsmear",obj.tsmear);end
        function d=as_dict(obj),d=kssolv.analysis.matgenlab.util.msonDict("pymatgen.io.abinit.abiobjects","Smearing",struct("occopt",obj.occopt,"tsmear",obj.tsmear));end
        function d=asDict(obj),d=obj.as_dict();end
    end
    methods (Static)
        function obj=as_smearing(value)
            if isempty(value)||string(value)=="nosmearing",obj=kssolv.analysis.matgenlab.io.abinit.Smearing.nosmearing();return;end
            if isa(value,"kssolv.analysis.matgenlab.io.abinit.Smearing"),obj=value;return;end
            p=split(string(value),":"); names=["fermi_dirac","marzari4","marzari5","methfessel","gaussian"]; ids=[3 4 5 6 7];
            q=split(strip(p(2))); x=str2double(q(1)); if numel(q)>1&&lower(q(2))=="ev",x=x/27.211386245988;end
            obj=kssolv.analysis.matgenlab.io.abinit.Smearing(ids(names==p(1)),x);
        end
        function obj=nosmearing(),obj=kssolv.analysis.matgenlab.io.abinit.Smearing(1,0);end
        function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.abinit.Smearing(d.occopt,d.tsmear);end
        function obj=fromDict(d),obj=kssolv.analysis.matgenlab.io.abinit.Smearing.from_dict(d);end
    end
end
