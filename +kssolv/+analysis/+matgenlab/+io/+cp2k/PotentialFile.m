classdef PotentialFile < kssolv.analysis.matgenlab.io.cp2k.DataFile
%#ok<*NOCOMMA,*NOSEMI>
 methods,function obj=PotentialFile(objects),if nargin<1,objects={};end;obj@kssolv.analysis.matgenlab.io.cp2k.DataFile(objects);end,end
 methods(Static),function obj=from_str(text),chunks=kssolv.analysis.matgenlab.io.cp2k.chunk(text);items=cellfun(@(x)kssolv.analysis.matgenlab.io.cp2k.GthPotential.from_str(x),chunks,"UniformOutput",false);obj=kssolv.analysis.matgenlab.io.cp2k.PotentialFile(items);end;function obj=from_file(filename),obj=kssolv.analysis.matgenlab.io.cp2k.PotentialFile.from_str(fileread(filename));for i=1:numel(obj.objects),obj.objects{i}.filename=string(filename);end,end,end
end
