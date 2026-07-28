classdef KSampling < kssolv.analysis.matgenlab.util.MSONable
    properties,mode="monkhorst";num_kpts=0;kpts=[1 1 1];kpt_shifts=[.5 .5 .5];kpts_weights=[];use_symmetries=true;use_time_reversal=true;chksymbreak=[];comment=[];abivars=struct();end
    properties (Dependent),is_homogeneous;end
    methods
        function obj=KSampling(mode,numKpts,kpts,shifts,weights,useSym,useTR,chksym,comment)
            if nargin<1,mode="monkhorst";end;if nargin<2,numKpts=0;end;if nargin<3,kpts=[1 1 1];end;if nargin<4,shifts=[.5 .5 .5];end;if nargin<5,weights=[];end;if nargin<6,useSym=true;end;if nargin<7,useTR=true;end;if nargin<8,chksym=[];end;if nargin<9,comment=[];end
            obj.mode=string(mode);obj.num_kpts=numKpts;obj.kpts=kpts;obj.kpt_shifts=shifts;obj.kpts_weights=weights;obj.use_symmetries=useSym;obj.use_time_reversal=useTR;obj.chksymbreak=chksym;obj.comment=comment;
            if obj.mode=="monkhorst",k=1+double(~useSym)+2*double(~useTR);obj.abivars=struct("ngkpt",reshape(kpts,1,3),"shiftk",reshape(shifts,[],3),"nshiftk",size(reshape(shifts,[],3),1),"kptopt",k,"chksymbreak",chksym); %#ok<ALIGN>
            elseif obj.mode=="path",obj.abivars=struct("ndivsm",numKpts,"kptbounds",reshape(kpts,[],3),"kptopt",-size(reshape(kpts,[],3),1)+1);
            else,obj.abivars=struct("kptopt",0,"kpt",reshape(kpts,[],3),"nkpt",numKpts,"kptnrm",ones(numKpts,1),"wtk",weights,"chksymbreak",chksym);end
        end
        function v=get.is_homogeneous(obj),v=obj.mode~="path";end
        function d=to_abivars(obj),d=obj.abivars;end
        function d=as_dict(obj),p=struct("mode",char(obj.mode),"num_kpts",obj.num_kpts,"kpts",obj.kpts,"kpt_shifts",obj.kpt_shifts,"kpts_weights",obj.kpts_weights,"use_symmetries",obj.use_symmetries,"use_time_reversal",obj.use_time_reversal,"chksymbreak",obj.chksymbreak,"comment",obj.comment);d=kssolv.analysis.matgenlab.util.msonDict("pymatgen.io.abinit.abiobjects","KSampling",p);end
        function d=asDict(obj),d=obj.as_dict();end
    end
    methods (Static)
        function o=gamma_only(),o=kssolv.analysis.matgenlab.io.abinit.KSampling("monkhorst",0,[1 1 1],[0 0 0]);end
        function o=gamma_centered(k,varargin),if nargin<1,k=[1 1 1];end;o=kssolv.analysis.matgenlab.io.abinit.KSampling("monkhorst",0,k,[0 0 0]);end
        function o=monkhorst(k,s,varargin),if nargin<2,s=[.5 .5 .5];end;o=kssolv.analysis.matgenlab.io.abinit.KSampling("monkhorst",0,k,s);end
        function o=monkhorst_automatic(~,k,varargin),o=kssolv.analysis.matgenlab.io.abinit.KSampling.monkhorst(k);end
        function o=path_from_structure(n,~)
            % Standard primitive-cell path used when no symmetry database is requested.
            bounds=[0 0 0;.5 0 .5;.5 .5 .5;0 0 0];
            o=kssolv.analysis.matgenlab.io.abinit.KSampling.explicit_path(n,bounds);
        end
        function o=explicit_path(n,b),o=kssolv.analysis.matgenlab.io.abinit.KSampling("path",n,b,[]);end
        function o=automatic_density(s,kppa,varargin)
            l=s.lattice.abc;
            scale=(kppa/max(1,s.num_sites)*prod(l))^(1/3);
            n=max(1,round(scale./l));
            if all(abs(l-mean(l))<1e-6),n=repmat(max(1,round((kppa/max(1,s.num_sites))^(1/3))),1,3);end
            o=kssolv.analysis.matgenlab.io.abinit.KSampling.monkhorst(n);
            for i=1:2:numel(varargin)
                if string(varargin{i})=="chksymbreak",o.chksymbreak=varargin{i+1};o.abivars.chksymbreak=varargin{i+1};end
                if string(varargin{i})=="shifts",o.kpt_shifts=varargin{i+1};o.abivars.shiftk=reshape(varargin{i+1},[],3);o.abivars.nshiftk=size(o.abivars.shiftk,1);end
            end
        end
        function o=from_dict(d),o=kssolv.analysis.matgenlab.io.abinit.KSampling(d.mode,d.num_kpts,d.kpts,d.kpt_shifts,d.kpts_weights,d.use_symmetries,d.use_time_reversal,d.chksymbreak,d.comment);end
        function o=fromDict(d),o=kssolv.analysis.matgenlab.io.abinit.KSampling.from_dict(d);end
    end
end
