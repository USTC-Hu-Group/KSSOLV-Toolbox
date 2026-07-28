classdef DataFile < handle
%#ok<*INUSD,*STOUT,*UNRCH>
 properties,objects cell={};end
 methods
  function obj=DataFile(objects),if nargin>0,obj.objects=objects;end,end
  function write_file(obj,filename),fid=fopen(filename,"w");c=onCleanup(@()fclose(fid));fprintf(fid,"%s",obj.get_str());end
  function value=get_str(obj),parts=cellfun(@(x)string(x.get_str()),obj.objects,"UniformOutput",false);value=char(join(string([parts{:}]),newline));end
 end
 methods(Static)
  function obj=from_file(filename),if strcmp(className(),"DataFile"),error("KSSOLV:Matgenlab:Cp2k:AbstractDataFile","DataFile.from_str is abstract.");end;obj=[];end
  function obj=from_str(~),error("KSSOLV:Matgenlab:Cp2k:AbstractDataFile","DataFile.from_str is abstract.");obj=[];end
 end
end
function n=className(),n="DataFile";end
