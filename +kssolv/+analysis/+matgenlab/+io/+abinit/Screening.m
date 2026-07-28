classdef Screening < kssolv.analysis.matgenlab.io.abinit.AbivarAble
    properties,ecuteps;nband;w_type="RPA";sc_mode="one_shot";hilbert=[];ecutwfn=[];inclvkb=2;gwpara=2;awtr=1;symchi=1;optdriver=3;end
    properties (Dependent),use_hilbert;end
    methods
        function obj=Screening(e,n,w,s,h,ew,i),obj.ecuteps=e;obj.nband=n;if nargin>2,obj.w_type=w;end;if nargin>3,obj.sc_mode=s;end;if nargin>4,obj.hilbert=h;end;if nargin>5,obj.ecutwfn=ew;end;if nargin>6,obj.inclvkb=i;end,end
        function v=get.use_hilbert(obj),v=~isempty(obj.hilbert);end
        function d=to_abivars(obj),d=struct("ecuteps",obj.ecuteps,"ecutwfn",obj.ecutwfn,"inclvkb",obj.inclvkb,"gwpara",2,"awtr",1,"symchi",1,"nband",obj.nband,"optdriver",3);if obj.use_hilbert,n=obj.hilbert.to_abivars();f=fieldnames(n);for i=1:numel(f),d.(f{i})=n.(f{i});end,end,end
    end
end
