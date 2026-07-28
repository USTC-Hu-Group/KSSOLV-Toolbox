classdef AbstractFeffInputSet < handle
 %#ok<*STOUT,*UNRCH,*AGROW,*PROP>
 %ABSTRACTFEFFINPUTSET Shared FEFF input-set writer.
 methods
  function value=header(~,varargin),error("KSSOLV:Matgenlab:Feff:Abstract","header must be implemented by a FEFF input set.");value=[];end
  function value=all_input(obj),value=struct("HEADER",obj.header(),"PARAMETERS",obj.tags);if ~obj.tags.has("RECIPROCAL"),value.POTENTIALS=obj.potential;value.ATOMS=obj.atoms;end,end
  function value=write_input(obj,outputDir,makeDir),if nargin<2,outputDir=".";end;if nargin<3,makeDir=true;end;if makeDir&&~isfolder(outputDir),mkdir(outputDir);end;parts=obj.all_input();names=fieldnames(parts);for i=1:numel(names),fid=fopen(fullfile(outputDir,names{i}),"w");c=onCleanup(@()fclose(fid));fprintf(fid,"%s",char(parts.(names{i})));clear c,end;order=["HEADER","PARAMETERS","POTENTIALS","ATOMS"];text=strings(0,1);for name=order,if isfield(parts,name),text(end+1)=string(char(parts.(char(name))));end,end;fid=fopen(fullfile(outputDir,"feff.inp"),"w");c=onCleanup(@()fclose(fid));separator=string(newline)+string(newline);fprintf(fid,"%s",join(text,separator));clear c;if ~isfield(parts,"ATOMS"),tags=parts.PARAMETERS;filename=tags("CIF");obj.atoms.struct.to(fullfile(outputDir,filename),"cif");end;value=string(outputDir);end
 end
 properties(Dependent),atoms;tags;potential;end
 methods
  function value=get.atoms(obj),value=obj.build_atoms();end
  function value=get.tags(obj),value=obj.build_tags();end
  function value=get.potential(obj),value=obj.build_potential();end
  function value=build_atoms(~),error("KSSOLV:Matgenlab:Feff:Abstract","atoms must be implemented by a FEFF input set.");value=[];end
  function value=build_tags(~),error("KSSOLV:Matgenlab:Feff:Abstract","tags must be implemented by a FEFF input set.");value=[];end
  function value=build_potential(~),error("KSSOLV:Matgenlab:Feff:Abstract","potential must be implemented by a FEFF input set.");value=[];end
 end
end
