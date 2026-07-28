classdef ExcHamiltonian < kssolv.analysis.matgenlab.io.abinit.AbivarAble
    properties,bs_loband;nband;mbpt_sciss;coulomb_mode;ecuteps;spin_mode;mdf_epsinf=[];exc_type="TDA";algo="haydock";with_lf=true;bs_freq_mesh=[];zcut=[];kwargs=struct();end
    properties (Dependent),inclvkb;use_haydock;use_cg;use_direct_diago;end
    methods
        function obj=ExcHamiltonian(low,n,sciss,coul,eps,spin,mdf,type,algo,lf,mesh,zcut,varargin)
            obj.bs_loband=low;obj.nband=n;obj.mbpt_sciss=sciss;obj.coulomb_mode=string(coul);obj.ecuteps=eps;
            if nargin<6,spin="polarized";end;obj.spin_mode=kssolv.analysis.matgenlab.io.abinit.SpinMode.as_spinmode(spin);
            if nargin>6,obj.mdf_epsinf=mdf;end;if nargin>7,obj.exc_type=string(type);end;if nargin>8,obj.algo=string(algo);end;if nargin>9,obj.with_lf=lf;end;if nargin>10,obj.bs_freq_mesh=mesh;end;if nargin>11,obj.zcut=zcut;end
            for i=1:2:numel(varargin),obj.kwargs.(char(varargin{i}))=varargin{i+1};end
            if isscalar(low),obj.bs_loband=repmat(low,1,obj.spin_mode.nsppol);end
        end
        function v=get.inclvkb(obj),if isfield(obj.kwargs,"inclvkb"),v=obj.kwargs.inclvkb;else,v=2;end,end
        function v=get.use_haydock(obj),v=obj.algo=="haydock";end
        function v=get.use_cg(obj),v=obj.algo=="cg";end
        function v=get.use_direct_diago(obj),v=obj.algo=="direct_diago";end
        function d=to_abivars(obj),alg=["direct_diago","haydock","cg"];d=struct("bs_calctype",1,"bs_loband",obj.bs_loband,"mbpt_sciss",obj.mbpt_sciss,"ecuteps",obj.ecuteps,"bs_algorithm",find(alg==obj.algo),"bs_coulomb_term",21,"mdf_epsinf",obj.mdf_epsinf,"bs_exchange_term",double(obj.with_lf),"inclvkb",obj.inclvkb,"zcut",obj.zcut,"bs_freq_mesh",obj.bs_freq_mesh,"bs_coupling",double(obj.exc_type=="coupling"),"optdriver",99);if obj.use_haydock,d.bs_haydock_niter=100;d.bs_hayd_term=0;d.bs_haydock_tol=[.05 0];end;f=fieldnames(obj.kwargs);for i=1:numel(f),d.(f{i})=obj.kwargs.(f{i});end,end
    end
end
