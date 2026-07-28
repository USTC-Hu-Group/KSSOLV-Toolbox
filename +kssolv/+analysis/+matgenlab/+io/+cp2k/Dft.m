classdef Dft < kssolv.analysis.matgenlab.io.cp2k.Section
%#ok<*NOCOMMA>
 methods,function obj=Dft(varargin),obj@kssolv.analysis.matgenlab.io.cp2k.Section("DFT");obj.setitem("BASIS_SET_FILE_NAME","BASIS_MOLOPT");obj.setitem("POTENTIAL_FILE_NAME","GTH_POTENTIALS");obj.setitem("UKS",true);for i=1:2:numel(varargin),key=upper(string(varargin{i}));if key=="BASIS_SET_FILENAMES",key="BASIS_SET_FILE_NAME";end;obj.setitem(key,varargin{i+1});end,end,end
end
