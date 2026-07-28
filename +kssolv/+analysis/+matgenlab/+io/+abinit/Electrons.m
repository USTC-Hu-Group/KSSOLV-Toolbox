classdef Electrons < kssolv.analysis.matgenlab.util.MSONable
    properties, spin_mode; smearing; algorithm=[]; nband=[]; fband=[]; charge=0; comment=[]; end
    properties (Dependent),nsppol;nspinor;nspden;end
    methods
        function obj=Electrons(spinMode,smearing,algorithm,nband,fband,charge,comment)
            if nargin<1,spinMode="polarized";end;if nargin<2,smearing="fermi_dirac:0.1 eV";end
            if nargin<3,algorithm=[];end;if nargin<4,nband=[];end;if nargin<5,fband=[];end
            if nargin<6,charge=0;end;if nargin<7,comment=[];end
            obj.spin_mode=kssolv.analysis.matgenlab.io.abinit.SpinMode.as_spinmode(spinMode);
            obj.smearing=kssolv.analysis.matgenlab.io.abinit.Smearing.as_smearing(smearing);
            obj.algorithm=algorithm;obj.nband=nband;obj.fband=fband;obj.charge=charge;obj.comment=comment;
        end
        function v=get.nsppol(obj),v=obj.spin_mode.nsppol;end
        function v=get.nspinor(obj),v=obj.spin_mode.nspinor;end
        function v=get.nspden(obj),v=obj.spin_mode.nspden;end
        function d=to_abivars(obj),d=obj.spin_mode.to_abivars();d.nband=obj.nband;d.fband=obj.fband;d.charge=obj.charge;if ~isempty(obj.smearing)&&obj.smearing.occopt~=1,d=merge(d,obj.smearing.to_abivars());end;if ~isempty(obj.algorithm),if isstruct(obj.algorithm),d=merge(d,obj.algorithm);else,d=merge(d,obj.algorithm.to_abivars());end,end,end
        function d=as_dict(obj),p=struct("spin_mode",obj.spin_mode.as_dict(),"smearing",obj.smearing.as_dict(),"algorithm",obj.algorithm,"nband",obj.nband,"fband",obj.fband,"charge",obj.charge,"comment",obj.comment);d=kssolv.analysis.matgenlab.util.msonDict("pymatgen.io.abinit.abiobjects","Electrons",p);end
        function d=asDict(obj),d=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.abinit.Electrons(kssolv.analysis.matgenlab.io.abinit.SpinMode.from_dict(d.spin_mode),kssolv.analysis.matgenlab.io.abinit.Smearing.from_dict(d.smearing),d.algorithm,d.nband,d.fband,d.charge,d.comment);end
        function obj=fromDict(d),obj=kssolv.analysis.matgenlab.io.abinit.Electrons.from_dict(d);end
    end
end
function a=merge(a,b),n=fieldnames(b);for i=1:numel(n),a.(n{i})=b.(n{i});end,end
