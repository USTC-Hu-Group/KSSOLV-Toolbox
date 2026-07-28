classdef QS < kssolv.analysis.matgenlab.io.cp2k.Section
%#ok<*NOCOMMA>
 methods,function obj=QS(method,eps_default,eps_pgf_orb,extrapolation,varargin),if nargin<1,method="GPW";end;if nargin<2,eps_default=1e-10;end;if nargin<3,eps_pgf_orb=[];end;if nargin<4,extrapolation="ASPC";end;obj@kssolv.analysis.matgenlab.io.cp2k.Section("QS");obj.setitem("METHOD",method);obj.setitem("EPS_DEFAULT",eps_default);if ~isempty(eps_pgf_orb),obj.setitem("EPS_PGF_ORB",eps_pgf_orb);end;obj.setitem("EXTRAPOLATION",extrapolation);end,end
end
