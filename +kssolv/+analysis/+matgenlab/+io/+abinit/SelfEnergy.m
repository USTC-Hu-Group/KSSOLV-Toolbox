classdef SelfEnergy < kssolv.analysis.matgenlab.io.abinit.AbivarAble
    properties,type;sc_mode;nband;ecutsigx;screening;gw_qprange=1;ppmodel=[];ecuteps;ecutwfn=[];gwpara=2;end
    properties (Dependent),use_ppmodel;gwcalctyp;symsigma;end
    methods
        function obj=SelfEnergy(t,s,n,e,screen,q,p,eps,w,g),obj.type=string(t);obj.sc_mode=string(s);obj.nband=n;obj.ecutsigx=e;obj.screening=screen;if nargin>5,obj.gw_qprange=q;end;if nargin>6&&~isempty(p),obj.ppmodel=kssolv.analysis.matgenlab.io.abinit.PPModel.as_ppmodel(p);end;if nargin>7&&~isempty(eps),obj.ecuteps=eps;else,obj.ecuteps=screen.ecuteps;end;if nargin>8,obj.ecutwfn=w;end;if nargin>9,obj.gwpara=g;end,end
        function v=get.use_ppmodel(obj),v=~isempty(obj.ppmodel);end
        function v=get.gwcalctyp(obj),types=["gw","hartree_fock","sex","cohsex","model_gw_ppm","model_gw_cd"];ids=[0 5 6 7 8 9];sc=["one_shot","energy_only","wavefunctions"];v=str2double(string(find(sc==obj.sc_mode)-1)+string(ids(types==obj.type)));end
        function v=get.symsigma(obj),v=double(obj.sc_mode=="one_shot");end
        function d=to_abivars(obj),d=struct("gwcalctyp",obj.gwcalctyp,"ecuteps",obj.ecuteps,"ecutsigx",obj.ecutsigx,"symsigma",obj.symsigma,"gw_qprange",obj.gw_qprange,"gwpara",obj.gwpara,"optdriver",4,"nband",obj.nband);if obj.use_ppmodel,p=obj.ppmodel.to_abivars();f=fieldnames(p);for i=1:numel(f),d.(f{i})=p.(f{i});end,end,end
    end
end
