classdef HilbertTransform < kssolv.analysis.matgenlab.io.abinit.AbivarAble
    properties,nomegasf;domegasf=[];spmeth=1;nfreqre=[];freqremax=[];nfreqim=[];freqremin=[];end
    methods
        function obj=HilbertTransform(a,b,c,d,e,f,g),obj.nomegasf=a;if nargin>1,obj.domegasf=b;end;if nargin>2,obj.spmeth=c;end;if nargin>3,obj.nfreqre=d;end;if nargin>4,obj.freqremax=e;end;if nargin>5,obj.nfreqim=f;end;if nargin>6,obj.freqremin=g;end,end
        function d=to_abivars(obj),d=struct("nomegasf",obj.nomegasf,"domegasf",obj.domegasf,"spmeth",obj.spmeth,"nfreqre",obj.nfreqre,"freqremax",obj.freqremax,"nfreqim",obj.nfreqim,"freqremin",obj.freqremin);end
    end
end
