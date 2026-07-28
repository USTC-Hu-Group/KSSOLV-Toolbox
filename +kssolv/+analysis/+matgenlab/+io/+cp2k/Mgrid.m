classdef Mgrid < kssolv.analysis.matgenlab.io.cp2k.Section
%#ok<*NOCOMMA>
 methods,function obj=Mgrid(cutoff,rel_cutoff,ngrids,progression_factor,varargin),if nargin<1,cutoff=1200;end;if nargin<2,rel_cutoff=80;end;if nargin<3,ngrids=5;end;if nargin<4,progression_factor=3;end;obj@kssolv.analysis.matgenlab.io.cp2k.Section("MGRID");obj.setitem("CUTOFF",cutoff);obj.setitem("REL_CUTOFF",rel_cutoff);obj.setitem("NGRIDS",ngrids);obj.setitem("PROGRESSION_FACTOR",progression_factor);end,end
end
