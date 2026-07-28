classdef Scf < kssolv.analysis.matgenlab.io.cp2k.Section
%#ok<*NOCOMMA>
 methods,function obj=Scf(max_scf,eps_scf,scf_guess,varargin),if nargin<1,max_scf=50;end;if nargin<2,eps_scf=1e-6;end;if nargin<3,scf_guess="RESTART";end;obj@kssolv.analysis.matgenlab.io.cp2k.Section("SCF");obj.setitem("MAX_SCF",max_scf);obj.setitem("EPS_SCF",eps_scf);obj.setitem("SCF_GUESS",scf_guess);end,end
end
